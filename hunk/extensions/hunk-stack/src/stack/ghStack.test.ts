import { describe, expect, it } from "bun:test";
import { mkdirSync, mkdtempSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createGhStackGraph } from "./ghStack";
import type { Sys } from "./sys";

// The graph takes the common dir directly, so these never touch git.
const noSys = { cwd: "unused-cwd" } as Sys;

function tmpCommonDir() {
  return realpathSync(mkdtempSync(join(tmpdir(), "stack-gh-")));
}
function writeJson(path: string, data: unknown) {
  writeFileSync(path, JSON.stringify(data));
}
function stackDoc(stacks: unknown[]) {
  return { schemaVersion: 1, repository: "host:owner/repo", stacks };
}

describe("createGhStackGraph", () => {
  it("reads the canonical file and folds branches into a parent chain", () => {
    const common = tmpCommonDir();
    writeJson(
      join(common, "gh-stack"),
      stackDoc([
        {
          trunk: { branch: "main", head: "9566b29" },
          branches: [
            { branch: "a", head: "aaa", base: "trunk-rev" },
            { branch: "b", head: "bbb", base: "aaa" },
          ],
        },
      ]),
    );
    const g = createGhStackGraph(noSys, common, "b");
    expect(g.nodes.map((n) => n.id)).toEqual(["a", "b"]);
    expect(g.baseRef(g.nodes[0]!)).toBe("trunk-rev");
    // The head always resolves the live branch, never the file's recorded (and immediately stale) head.
    expect(g.headRef(g.nodes[1]!)).toBe("refs/heads/b");
  });

  it("returns no nodes for a branch the file doesn't track", () => {
    const common = tmpCommonDir();
    writeJson(join(common, "gh-stack"), stackDoc([{ trunk: { branch: "main" }, branches: [{ branch: "a" }] }]));
    expect(createGhStackGraph(noSys, common, "untracked").nodes).toEqual([]);
  });

  it("carries the PR number only, no title", () => {
    const common = tmpCommonDir();
    writeJson(
      join(common, "gh-stack"),
      stackDoc([
        {
          trunk: { branch: "main" },
          branches: [{ branch: "a", pullRequest: { number: 42, url: "https://x" } }],
        },
      ]),
    );
    const g = createGhStackGraph(noSys, common, "a");
    const meta = g.metadata(g.nodes[0]!);
    expect(meta.prNumber).toBe(42);
    expect(meta.title).toBeUndefined();
  });

  it("unions the canonical file with unlinked worktree files", () => {
    const common = tmpCommonDir();
    writeJson(join(common, "gh-stack"), stackDoc([{ trunk: { branch: "main" }, branches: [{ branch: "a" }] }]));
    mkdirSync(join(common, "worktrees", "wt1"), { recursive: true });
    writeJson(
      join(common, "worktrees", "wt1", "gh-stack"),
      stackDoc([{ trunk: { branch: "main" }, branches: [{ branch: "c" }] }]),
    );
    const g = createGhStackGraph(noSys, common, "c");
    expect(g.nodes).toHaveLength(1);
    expect(g.nodes[0]!.branch).toBe("c");
  });

  it("first wins wholesale when canonical and a worktree file share identity", () => {
    const common = tmpCommonDir();
    writeJson(
      join(common, "gh-stack"),
      stackDoc([{ number: 7, trunk: { branch: "main" }, branches: [{ branch: "a" }] }]),
    );
    mkdirSync(join(common, "worktrees", "wt1"), { recursive: true });
    // Same stack number, different (stale) branch list: dropped wholesale rather than merged in.
    writeJson(
      join(common, "worktrees", "wt1", "gh-stack"),
      stackDoc([{ number: 7, trunk: { branch: "main" }, branches: [{ branch: "a" }, { branch: "b" }] }]),
    );
    expect(createGhStackGraph(noSys, common, "b").nodes).toEqual([]);
  });

  it("excludes a worktree gh-stack that is a symlink, even a dangling one", () => {
    const common = tmpCommonDir();
    writeJson(join(common, "gh-stack"), stackDoc([{ trunk: { branch: "main" }, branches: [{ branch: "a" }] }]));
    mkdirSync(join(common, "worktrees", "wt1"), { recursive: true });
    // Points at a canonical file that doesn't exist yet, a valid state that is judged by link type only.
    symlinkSync("../../gh-stack-not-yet-created", join(common, "worktrees", "wt1", "gh-stack"));
    expect(createGhStackGraph(noSys, common, "a").nodes).toHaveLength(1);
  });

  it("skips a stack entry with no well-formed trunk, without failing the read", () => {
    const common = tmpCommonDir();
    writeJson(
      join(common, "gh-stack"),
      stackDoc([
        { branches: [{ branch: "orphan" }] },
        { trunk: { branch: "main" }, branches: [{ branch: "a" }] },
      ]),
    );
    expect(createGhStackGraph(noSys, common, "a").nodes).toHaveLength(1);
    expect(createGhStackGraph(noSys, common, "orphan").nodes).toEqual([]);
  });

  it("throws on a schemaVersion this reader doesn't understand", () => {
    const common = tmpCommonDir();
    writeJson(join(common, "gh-stack"), { schemaVersion: 2, stacks: [] });
    expect(() => createGhStackGraph(noSys, common, "a")).toThrow(/schemaVersion 2/);
  });
});
