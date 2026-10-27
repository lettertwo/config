import { describe, expect, it } from "bun:test";
import type { WalkRow } from "./types";
import { walk } from "./walk";

function row(branch: string, parent?: string, headRev = "", parentRev = ""): WalkRow {
  return { branch, parent, headRev, parentRev };
}
const table = (...rows: WalkRow[]) => new Map(rows.map((r) => [r.branch, r]));
const ids = (nodes: { id: string }[]) => nodes.map((n) => n.id);

describe("walk", () => {
  const by = table(
    row("feat-a", "main", "aaa111", "000aaa"),
    row("feat-b", "feat-a", "bbb222", "aaa111"),
    row("feat-c", "feat-b", "ccc333", "bbb222"),
    row("unrelated", "main", "ddd444", "000aaa"),
  );

  it("walks parents from the focus branch in base to head order", () => {
    const nodes = walk(by, "feat-c");
    expect(ids(nodes)).toEqual(["feat-a", "feat-b", "feat-c"]);
    expect(nodes[0]!.parentRev).toBe("000aaa");
    expect(nodes[2]!.headRev).toBe("ccc333");
  });

  it("includes descendants when mid-stack", () => {
    expect(ids(walk(by, "feat-a"))).toEqual(["feat-a", "feat-b", "feat-c"]);
  });

  it("flattens forks depth-first with sorted siblings", () => {
    const forked = table(
      row("feat-a", "main"),
      row("feat-b", "feat-a"),
      row("feat-c", "feat-b"),
      row("feat-b2", "feat-a"),
    );
    expect(ids(walk(forked, "feat-a"))).toEqual(["feat-a", "feat-b", "feat-c", "feat-b2"]);
  });

  it("does not treat unrelated stacks as descendants", () => {
    expect(ids(walk(by, "feat-b"))).not.toContain("unrelated");
  });

  it("excludes trunk's own row (empty parent)", () => {
    const withTrunk = table(row("develop", ""), row("feat", "develop", "fff111", "ddd000"));
    expect(ids(walk(withTrunk, "feat"))).toEqual(["feat"]);
    expect(walk(withTrunk, "develop")).toEqual([]);
  });

  it("returns empty when the focus branch has no row", () => {
    expect(walk(by, "main")).toEqual([]);
  });

  it("guards against parent cycles", () => {
    const cyclic = table(row("x", "y", "1", "2"), row("y", "x", "3", "4"));
    expect(walk(cyclic, "x")).toHaveLength(2);
  });

  it("falls back to branch name and parent when revisions are empty", () => {
    const nodes = walk(table(row("feat", "main")), "feat");
    expect(nodes[0]!.headRev).toBe("feat");
    expect(nodes[0]!.parentRev).toBe("main");
  });
});
