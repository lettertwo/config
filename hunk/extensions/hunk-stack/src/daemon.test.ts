import { describe, expect, it } from "bun:test";
import { reloadArgs, Switcher, type Run, type RunResult } from "./daemon";
import type { Changeset } from "./stack/stack";

const PID = 4242;

function changeset(id: string, extra: Partial<Changeset> = {}): Changeset {
  return { id, title: id, base: `${id}-base`, head: id, baseSha: `${id}-base-sha`, headSha: `${id}-sha`, ...extra };
}

const ok = (stdout = ""): RunResult => ({ code: 0, stdout, stderr: "" });

/** A runner whose `session reload` calls wait for `release()`, so bursts can pile up behind one. */
function fakeRun(opts: { gate?: boolean; reloadResult?: () => RunResult } = {}) {
  const calls: string[][] = [];
  const waiting: (() => void)[] = [];
  const run: Run = async (args) => {
    calls.push([...args]);
    if (args[1] === "list") {
      return ok(JSON.stringify({ sessions: [{ sessionId: "other", pid: 1 }, { sessionId: "mine", pid: PID }] }));
    }
    if (opts.gate) {
      await new Promise<void>((resolve) => waiting.push(resolve));
    }
    return opts.reloadResult?.() ?? ok("{}");
  };
  return {
    run,
    calls,
    reloads: () => calls.filter((c) => c[1] === "reload"),
    release: () => waiting.shift()?.(),
  };
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("reloadArgs", () => {
  it("reloads a range by sha", () => {
    expect(reloadArgs(changeset("a"))).toEqual(["diff", "a-base-sha..a-sha"]);
  });

  it("reloads the uncommitted changeset against HEAD so staged changes show", () => {
    expect(reloadArgs({ ...changeset("uncommitted"), uncommitted: true, baseSha: undefined })).toEqual(["diff", "HEAD"]);
  });

  it("refuses a range with an unresolved end rather than passing a raw ref", () => {
    expect(reloadArgs(changeset("a", { baseSha: undefined, base: "--output=x" }))).toEqual({
      error: "Cannot resolve --output=x for a",
    });
  });
});

describe("Switcher", () => {
  it("finds its own session by pid and reloads it with the range", async () => {
    const fake = fakeRun();
    const switcher = new Switcher(fake.run, () => {}, PID);
    switcher.request(changeset("a"));
    await settle();
    expect(fake.calls[0]).toEqual(["session", "list", "--json"]);
    expect(fake.reloads()).toEqual([["session", "reload", "mine", "--json", "--", "diff", "a-base-sha..a-sha"]]);
    expect(switcher.loaded()).toBe("a");
    expect(switcher.getSnapshot()).toEqual({ loadedId: "a", pendingId: null });
  });

  it("looks the session up once across reloads", async () => {
    const fake = fakeRun();
    const switcher = new Switcher(fake.run, () => {}, PID);
    switcher.request(changeset("a"));
    await settle();
    switcher.request(changeset("b"));
    await settle();
    expect(fake.calls.filter((c) => c[1] === "list")).toHaveLength(1);
  });

  it("coalesces a burst to the first in flight and the last requested", async () => {
    const fake = fakeRun({ gate: true });
    const switcher = new Switcher(fake.run, () => {}, PID);
    switcher.request(changeset("a"));
    await settle();
    switcher.request(changeset("b"));
    switcher.request(changeset("c"));
    switcher.request(changeset("d"));
    // Stepping counts from the newest request, not from what is showing.
    expect(switcher.pendingTarget()?.id).toBe("d");
    expect(switcher.getSnapshot().pendingId).toBe("d");
    fake.release();
    await settle();
    fake.release();
    await settle();
    expect(fake.reloads().map((c) => c[6])).toEqual(["a-base-sha..a-sha", "d-base-sha..d-sha"]);
    expect(switcher.loaded()).toBe("d");
    expect(switcher.pendingTarget()).toBeNull();
  });

  it("hands the landing of the running reload out once", async () => {
    const fake = fakeRun({ gate: true });
    const switcher = new Switcher(fake.run, () => {}, PID);
    switcher.request(changeset("a"), { path: "src/x.ts" });
    await settle();
    expect(switcher.takeLanding()).toEqual({ path: "src/x.ts" });
    expect(switcher.takeLanding()).toBeNull();
    fake.release();
    await settle();
  });

  it("reports a failed reload and keeps what was loaded", async () => {
    const errors: string[] = [];
    let fail = false;
    const fake = fakeRun({ reloadResult: () => (fail ? { code: 1, stdout: "", stderr: "boom\n" } : ok("{}")) });
    const switcher = new Switcher(fake.run, (m) => errors.push(m), PID);
    switcher.request(changeset("a"));
    await settle();
    fail = true;
    switcher.request(changeset("b"));
    await settle();
    expect(errors).toEqual(["Loading b failed: boom"]);
    expect(switcher.loaded()).toBe("a");
    // The failure dropped the cached session id, so the next request looks it up again.
    switcher.request(changeset("c"));
    await settle();
    expect(fake.calls.filter((c) => c[1] === "list")).toHaveLength(2);
  });

  it("reports a session that the daemon does not list", async () => {
    const errors: string[] = [];
    const run: Run = async () => ok(JSON.stringify({ sessions: [] }));
    const switcher = new Switcher(run, (m) => errors.push(m), PID);
    switcher.request(changeset("a"));
    await settle();
    expect(errors).toEqual(["Cannot find this review's session in the hunk daemon"]);
  });

  it("notifies subscribers when the loaded changeset changes", () => {
    const switcher = new Switcher(fakeRun().run, () => {}, PID);
    let calls = 0;
    switcher.subscribe(() => calls++);
    switcher.setLoaded("a");
    switcher.setLoaded("a");
    switcher.setLoaded(null);
    expect(calls).toBe(2);
  });
});
