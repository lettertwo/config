import { describe, expect, it } from "bun:test";
import { NoteTally, type NotedFile } from "./notes";

const noted = (path: string, ...ids: (string | undefined)[]): NotedFile => ({
  path,
  agent: { annotations: ids.map((id) => ({ id })) },
});

describe("NoteTally", () => {
  it("counts every note and sidecar annotation on the loaded files by path", () => {
    const tally = new NoteTally();
    tally.observe([noted("a.ts", "n1", "n2", undefined), noted("b.ts"), { path: "c.ts", agent: null }]);
    expect([...tally.getSnapshot()]).toEqual([["a.ts", 3]]);
  });

  it("keeps the counts of paths a later load leaves out, and replaces the ones it shows", () => {
    const tally = new NoteTally();
    tally.observe([noted("a.ts", "n1"), noted("b.ts", "n2")]);
    tally.observe([noted("b.ts", "n3"), noted("c.ts")]);
    expect(Object.fromEntries(tally.getSnapshot())).toEqual({ "a.ts": 1, "b.ts": 1 });
  });

  it("forgets a removed note on a path that is not loaded", () => {
    const tally = new NoteTally();
    tally.observe([noted("a.ts", "n1", "n2")]);
    tally.observe([noted("b.ts")]);
    tally.forget("n1");
    tally.forget("n1");
    expect(tally.getSnapshot().get("a.ts")).toBe(1);
    tally.forget("n2");
    expect(tally.getSnapshot().has("a.ts")).toBe(false);
  });

  it("notifies and swaps the snapshot only when a count changes", () => {
    const tally = new NoteTally();
    let calls = 0;
    tally.subscribe(() => calls++);
    tally.observe([noted("a.ts", "n1")]);
    const first = tally.getSnapshot();
    tally.observe([noted("a.ts", "n1")]);
    tally.forget("unknown");
    expect(calls).toBe(1);
    expect(tally.getSnapshot()).toBe(first);
  });
});
