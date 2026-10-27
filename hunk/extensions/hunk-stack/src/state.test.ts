import { describe, expect, it } from "bun:test";
import type { Landing, SwitcherSnapshot } from "./daemon";
import { NOT_A_STACK, StackState, type ChangesetSwitcher } from "./state";
import type { Changeset } from "./stack/stack";
import { spawnGit } from "./listing";
import { createSys } from "./stack/sys";
import { makeRepo, type TestRepo } from "./stack/testRepo";

class FakeSwitcher implements ChangesetSwitcher {
  requests: { changeset: Changeset; landing?: Landing }[] = [];
  private loadedId: string | null = null;
  private listeners = new Set<() => void>();
  request(changeset: Changeset, landing?: Landing) {
    this.requests.push({ changeset, landing });
  }
  pendingTarget() {
    return this.requests.at(-1)?.changeset ?? null;
  }
  loaded() {
    return this.loadedId;
  }
  setLoaded(id: string | null) {
    this.loadedId = id;
    this.listeners.forEach((l) => l());
  }
  getSnapshot(): SwitcherSnapshot {
    return { loadedId: this.loadedId, pendingId: this.pendingTarget()?.id ?? null };
  }
  subscribe(listener: () => void) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

/** main <- a1 (two commits) <- c1 (one commit), with a dirty worktree on c1. */
function stackRepo(dirty = true): TestRepo {
  const repo = makeRepo();
  repo.git("checkout", "-qb", "a1");
  repo.commitFile("a1x.txt", "a1: add x");
  repo.commitFile("a1y.txt", "a1: add y");
  repo.git("checkout", "-qb", "c1");
  repo.commitFile("c1z.txt", "c1: add z");
  if (dirty) {
    repo.write("base.txt", "dirty\n");
  }
  repo.writeGhStack({
    schemaVersion: 1,
    stacks: [{ trunk: { branch: "main" }, branches: [{ branch: "a1" }, { branch: "c1" }] }],
  });
  return repo;
}

function setup(repo: TestRepo) {
  const switcher = new FakeSwitcher();
  const state = new StackState(createSys, switcher);
  const opened = state.open(repo.cwd);
  return { state, switcher, opened };
}

describe("StackState", () => {
  it("opens on the uncommitted changeset", () => {
    const { state, switcher } = setup(stackRepo());
    expect(switcher.loaded()).toBe("uncommitted");
    expect(state.getSnapshot()).toMatchObject({
      enabled: true,
      zoom: "branch",
      zooms: ["combined", "branch", "commit"],
      loadedId: "uncommitted",
    });
    expect(state.getSnapshot().changesets.map((c) => c.id)).toEqual(["a1", "c1", "uncommitted"]);
  });

  it("opens on the focus branch when the worktree is clean", () => {
    const { state, switcher, opened } = setup(stackRepo(false));
    expect(opened).toMatchObject({ id: "c1" });
    expect(switcher.loaded()).toBe("c1");
    expect(state.getSnapshot().loadedId).toBe("c1");
  });

  it("steps toward the base from the uncommitted changeset and loads the range by sha", () => {
    const repo = stackRepo();
    const { state, switcher } = setup(repo);
    expect(state.step(-1)).toBe("c1");
    const [{ changeset }] = switcher.requests as [{ changeset: Changeset }];
    expect(changeset.id).toBe("c1");
    expect(changeset.headSha).toBe(repo.git("rev-parse", "c1"));
    expect(changeset.baseSha).toBe(repo.git("rev-parse", "a1"));
  });

  it("counts a step from the newest pending request, so repeated presses keep walking", () => {
    const { state, switcher } = setup(stackRepo());
    state.step(-1);
    state.step(-1);
    expect(switcher.requests.map((r) => r.changeset.id)).toEqual(["c1", "a1"]);
    expect(state.step(-1)).toBe("Already on the changeset nearest the base");
    expect(switcher.requests).toHaveLength(2);
  });

  it("says so at the head end", () => {
    const { state, switcher } = setup(stackRepo());
    expect(state.step(1)).toBe("Already on the changeset nearest the head");
    expect(switcher.requests).toHaveLength(0);
  });

  it("cycles zooms and lands on the newest changeset touching the file", () => {
    const { state, switcher } = setup(stackRepo());
    // branch -> commit: a1y.txt was added by one commit of a1.
    expect(state.cycleZoom("a1y.txt")).toBe("Zoom: commit");
    const landed = switcher.requests[0]!;
    expect(landed.changeset.title).toBe("a1: add y");
    expect(landed.landing).toEqual({ path: "a1y.txt" });
  });

  it("cycles commit to combined and combined to branch", () => {
    const { state, switcher } = setup(stackRepo());
    state.cycleZoom("a1x.txt"); // branch -> commit
    state.cycleZoom("a1x.txt"); // commit -> combined
    expect(switcher.requests.at(-1)).toMatchObject({ changeset: { id: "combined" }, landing: { path: "a1x.txt" } });
    switcher.setLoaded("combined");
    state.cycleZoom("a1x.txt"); // combined -> branch: the newest branch that touched it
    expect(state.getSnapshot().zoom).toBe("branch");
    expect(switcher.requests.at(-1)).toMatchObject({ changeset: { id: "a1" }, landing: { path: "a1x.txt" } });
  });

  it("falls back to the current changeset when no file is selected", () => {
    const { state, switcher } = setup(stackRepo());
    state.cycleZoom(null);
    expect(switcher.requests.at(-1)!.changeset.id).toBe("uncommitted");
  });

  it("lists every changeset's files as git answers, uncommitted last with untracked files", async () => {
    const repo = stackRepo();
    repo.write("fresh.txt", "x\n");
    const { state } = setup(repo);
    await state.settled();
    const { listings } = state.getSnapshot();
    expect(listings.get("a1")).toEqual([
      { status: "A", path: "a1x.txt" },
      { status: "A", path: "a1y.txt" },
    ]);
    expect(listings.get("c1")).toEqual([{ status: "A", path: "c1z.txt" }]);
    expect(listings.get("uncommitted")).toEqual([
      { status: "M", path: "base.txt" },
      { status: "?", path: "fresh.txt" },
    ]);
  });

  it("asks again for the uncommitted list on a read, and keeps range lists", async () => {
    const repo = stackRepo();
    const calls: string[] = [];
    const switcher = new FakeSwitcher();
    const state = new StackState(
      createSys,
      switcher,
      async (cwd, args) => {
        calls.push(args.join(" "));
        return spawnGit(cwd, args);
      },
    );
    state.open(repo.cwd);
    await state.settled();
    const first = calls.length;
    repo.write("later.txt", "x\n");
    state.step(-1);
    await state.settled();
    // Only the uncommitted changeset's two probes ran again.
    expect(calls.slice(first).map((c) => c.split(" ")[0])).toEqual(["diff", "ls-files"]);
    expect(state.getSnapshot().listings.get("uncommitted")?.map((f) => f.path)).toContain("later.txt");
  });

  // Twenty commits and their probes take ~5s, past bun's default timeout.
  it("limits how many git probes run at once", async () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "work");
    for (let i = 0; i < 20; i++) {
      repo.commitFile(`f${i}.txt`, `c${i}`);
    }
    let running = 0;
    let peak = 0;
    const state = new StackState(
      createSys,
      new FakeSwitcher(),
      async (cwd, args) => {
        running += 1;
        peak = Math.max(peak, running);
        const out = await spawnGit(cwd, args);
        running -= 1;
        return out;
      },
    );
    state.open(repo.cwd);
    await state.settled();
    expect(state.getSnapshot().changesets.length).toBeGreaterThan(8);
    expect(peak).toBeLessThanOrEqual(8);
    expect(state.getSnapshot().listings.size).toBe(state.getSnapshot().changesets.length);
  }, 30_000);

  it("expands only the loaded changeset until a header is toggled by hand", () => {
    const { state, switcher } = setup(stackRepo());
    expect([...["a1", "c1", "uncommitted"]].map((id) => state.isExpanded(id))).toEqual([false, false, true]);
    state.setExpanded("a1");
    state.setExpanded("uncommitted");
    expect(state.getSnapshot().expansion.get("a1")).toBe(true);
    expect(state.isExpanded("uncommitted")).toBe(false);
    switcher.setLoaded("c1");
    expect(state.isExpanded("c1")).toBe(true);
    state.setExpanded("a1", true);
    expect(state.isExpanded("a1")).toBe(true);
  });

  it("loads a changeset by id and refuses one that left the stack", () => {
    const { state, switcher } = setup(stackRepo());
    expect(state.select("a1")).toBeNull();
    expect(switcher.requests.map((r) => r.changeset.id)).toEqual(["a1"]);
    expect(switcher.requests[0]!.landing).toBeUndefined();
    expect(state.select("gone")).toBe("That changeset is no longer in the stack");
    expect(switcher.requests).toHaveLength(1);
  });

  it("loads another changeset's file by landing on its path", () => {
    const { state, switcher } = setup(stackRepo());
    expect(state.select("c1", "c1z.txt")).toBeNull();
    expect(switcher.requests[0]).toMatchObject({ changeset: { id: "c1" }, landing: { path: "c1z.txt" } });
  });

  it("toggles the outline order and cycles the tree projection", () => {
    const { state } = setup(stackRepo());
    expect(state.getSnapshot()).toMatchObject({ order: "head-first", tree: null });
    expect(state.toggleOrder()).toBe("Stack order: base-first");
    expect(state.getSnapshot().order).toBe("base-first");
    expect(state.toggleTree()).toBe("File tree: on");
    expect(state.toggleTree()).toBe("File tree: off");
    expect(state.toggleTree()).toBe("File tree: auto");
    expect(state.getSnapshot().tree).toBeNull();
  });

  it("observes the pane's review descriptor", () => {
    const repo = stackRepo();
    const { state, switcher } = setup(repo);
    const a1 = state.getSnapshot().changesets.find((c) => c.id === "a1")!;
    state.observeReview({ kind: "comparison", provider: "Git", title: "x", base: a1.baseSha!, head: a1.headSha! });
    expect(switcher.loaded()).toBe("a1");
    state.observeReview(null);
    expect(switcher.loaded()).toBe("uncommitted");
  });

  it("stays closed until opened, so other hunk commands get no stack", () => {
    const state = new StackState(createSys, new FakeSwitcher());
    expect(state.getSnapshot().enabled).toBe(false);
    expect(state.step(1)).toBe(NOT_A_STACK);
    expect(state.cycleZoom(null)).toBe(NOT_A_STACK);
    expect(state.toggleOrder()).toBe(NOT_A_STACK);
  });

  it("cycles the tree projection without a stack", () => {
    const state = new StackState(createSys, new FakeSwitcher());
    expect(state.toggleTree()).toBe("File tree: on");
    expect(state.getSnapshot()).toMatchObject({ enabled: false, tree: true });
  });

  it("refuses to open outside a git repo", () => {
    const state = new StackState(createSys, new FakeSwitcher());
    expect(state.open("/")).toEqual({ error: "not a git repository" });
    expect(state.getSnapshot().enabled).toBe(false);
  });

  it("says why it cannot open when no trunk can be found", () => {
    const repo = makeRepo();
    repo.git("branch", "-m", "main", "dev");
    const { state, opened } = setup(repo);
    expect(state.getSnapshot().enabled).toBe(false);
    expect("error" in opened && opened.error).toContain("no trunk branch");
  });
});
