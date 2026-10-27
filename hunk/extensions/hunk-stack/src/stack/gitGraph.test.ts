import { describe, expect, it } from "bun:test";
import { buildNodes } from "./gitGraph";

describe("buildNodes", () => {
  it("builds one node per commit, base to head, bases chained to next-older", () => {
    // git log returns newest first
    const nodes = buildNodes("main", "feat", [
      { sha: "ccc", subject: "third" },
      { sha: "bbb", subject: "second" },
      { sha: "aaa", subject: "first" },
    ]);
    expect(nodes.map((n) => n.id)).toEqual(["aaa", "bbb", "ccc"]);
    expect(nodes[0]!.parentRev).toBe("main");
    expect(nodes[1]!.parentRev).toBe("aaa");
    expect(nodes[2]!.parentRev).toBe("bbb");
    expect(nodes[2]!.title).toBe("third");
  });

  it("builds per-commit nodes on trunk when ahead of upstream", () => {
    const nodes = buildNodes("origin/main", "main", [
      { sha: "bbb", subject: "newer" },
      { sha: "aaa", subject: "older" },
    ]);
    expect(nodes.map((n) => n.id)).toEqual(["aaa", "bbb"]);
    expect(nodes[0]!.parentRev).toBe("origin/main");
  });

  it("returns a HEAD node on trunk with nothing in flight", () => {
    const nodes = buildNodes("main", "main", null);
    expect(nodes).toHaveLength(1);
    expect(nodes[0]!.id).toBe("HEAD");
    expect(nodes[0]!.parentRev).toBe("HEAD~1");
  });

  it("treats the whole branch as one changeset when the log is empty", () => {
    for (const commits of [null, []]) {
      const nodes = buildNodes("main", "feat", commits);
      expect(nodes).toHaveLength(1);
      expect(nodes[0]!.id).toBe("feat");
      expect(nodes[0]!.parentRev).toBe("main");
      expect(nodes[0]!.headRev).toBe("feat");
    }
  });
});
