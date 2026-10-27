import { describe, expect, it } from "bun:test";
import { flipTarget, identifyLoaded, stepChangeset } from "./navigate";
import type { Changeset } from "./stack/stack";

function cs(id: string, extra: Partial<Changeset> = {}): Changeset {
  return { id, title: id, base: `${id}-base`, head: id, baseSha: `${id}-b`, headSha: `${id}-h`, ...extra };
}

describe("stepChangeset", () => {
  const list = [cs("a"), cs("b"), cs("c", { current: true }), cs("d")];
  const all = () => true;

  it("steps toward the head and the base", () => {
    expect(stepChangeset(list, "b", 1, all)?.id).toBe("c");
    expect(stepChangeset(list, "b", -1, all)?.id).toBe("a");
  });

  it("clamps at both ends", () => {
    expect(stepChangeset(list, "d", 1, all)).toBeNull();
    expect(stepChangeset(list, "a", -1, all)).toBeNull();
  });

  it("steps over changesets that touch no files", () => {
    expect(stepChangeset(list, "a", 1, (c) => c.id !== "b")?.id).toBe("c");
    expect(stepChangeset(list, "d", -1, (c) => c.id !== "c" && c.id !== "b")?.id).toBe("a");
  });

  it("opens on the current changeset when nothing is known to be showing", () => {
    expect(stepChangeset(list, null, 1, all)?.id).toBe("c");
    expect(stepChangeset(list, "gone", -1, all)?.id).toBe("c");
  });
});

describe("flipTarget", () => {
  const paths = (map: Record<string, string[]>) => (c: Changeset) => map[c.id] ?? [];

  it("lands commit to branch on the owning branch, on the same path", () => {
    const list = [cs("feat-a"), cs("feat-b", { current: true })];
    const flip = { from: "commit", to: "branch", prevPath: "x.ts", prevBranch: "feat-a" } as const;
    expect(flipTarget(list, flip, paths({ "feat-a": ["x.ts", "y.ts"] }))).toEqual({
      changeset: list[0]!,
      path: "x.ts",
    });
    // The owning branch has the changeset but not the file: open on its first file.
    expect(flipTarget(list, flip, paths({ "feat-a": ["y.ts"] }))).toEqual({ changeset: list[0]!, path: undefined });
  });

  it("falls back to the current changeset when the owning branch is gone", () => {
    const list = [cs("feat-b", { current: true })];
    const flip = { from: "commit", to: "branch", prevPath: "x.ts", prevBranch: "feat-a" } as const;
    expect(flipTarget(list, flip, paths({}))).toEqual({ changeset: list[0]! });
  });

  it("lands on the combined changeset", () => {
    const list = [cs("combined"), cs("uncommitted", { current: true })];
    const flip = { from: "branch", to: "combined", prevPath: "x.ts" } as const;
    expect(flipTarget(list, flip, paths({ combined: ["x.ts"] }))).toEqual({ changeset: list[0]!, path: "x.ts" });
  });

  it("lands on the newest changeset that touched the path", () => {
    const list = [cs("c1"), cs("c2"), cs("c3", { current: true })];
    const flip = { from: "branch", to: "commit", prevPath: "x.ts" } as const;
    expect(flipTarget(list, flip, paths({ c1: ["x.ts"], c2: ["x.ts"], c3: ["z.ts"] }))).toEqual({
      changeset: list[1]!,
      path: "x.ts",
    });
  });

  it("opens the current changeset when nothing touched the path, or no file was selected", () => {
    const list = [cs("c1"), cs("c2", { current: true })];
    const flip = { from: "branch", to: "commit", prevPath: "x.ts" } as const;
    expect(flipTarget(list, flip, paths({}))).toEqual({ changeset: list[1]! });
    expect(flipTarget(list, null, paths({}))).toEqual({ changeset: list[1]! });
  });

  it("returns null for an empty list", () => {
    expect(flipTarget([], null, paths({}))).toBeNull();
  });
});

describe("identifyLoaded", () => {
  const list = [cs("a"), cs("uncommitted", { uncommitted: true }), cs("sha1")];

  it("reads a comparison descriptor by the shas the reload passed", () => {
    const review = { kind: "comparison", provider: "Git", title: "x", base: "a-b", head: "a-h" } as const;
    expect(identifyLoaded(review, list)?.id).toBe("a");
  });

  it("falls back to the refs when the review was launched with names", () => {
    const review = { kind: "comparison", provider: "Git", title: "x", base: "a-base", head: "a" } as const;
    expect(identifyLoaded(review, list)?.id).toBe("a");
  });

  it("treats a review with no descriptor as the working tree", () => {
    expect(identifyLoaded(null, list)?.id).toBe("uncommitted");
    expect(identifyLoaded(null, [cs("a")])).toBeNull();
  });

  it("matches a commit by its sha", () => {
    const review = { kind: "commit", provider: "Git", title: "x", revision: "sha1" } as const;
    expect(identifyLoaded(review, list)?.id).toBe("sha1");
  });

  it("returns null for a range the stack does not list", () => {
    const review = { kind: "comparison", provider: "Git", title: "x", base: "q", head: "r" } as const;
    expect(identifyLoaded(review, list)).toBeNull();
  });
});
