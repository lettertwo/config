import { describe, expect, it } from "bun:test";
import { changeTypeOf, listChangeset, parseNameStatus, spawnGit } from "./listing";
import type { Changeset } from "./stack/stack";
import { makeRepo } from "./stack/testRepo";

describe("parseNameStatus", () => {
  it("reads plain statuses and two-path renames", () => {
    expect(parseNameStatus("M\0a.ts\0A\0b/c.ts\0R087\0old.ts\0new.ts\0D\0gone.ts\0")).toEqual([
      { status: "M", path: "a.ts" },
      { status: "A", path: "b/c.ts" },
      { status: "R", previousPath: "old.ts", path: "new.ts" },
      { status: "D", path: "gone.ts" },
    ]);
  });

  it("is empty for empty output", () => {
    expect(parseNameStatus("")).toEqual([]);
  });
});

describe("changeTypeOf", () => {
  it("maps git letters to the file rows' vocabulary", () => {
    expect(["A", "C", "D", "R", "M", "T", "?"].map(changeTypeOf)).toEqual([
      "new",
      "new",
      "deleted",
      "rename-changed",
      "change",
      "change",
      "change",
    ]);
  });
});

describe("listChangeset", () => {
  const range = (repo: ReturnType<typeof makeRepo>, base: string, head: string): Changeset => ({
    id: "x",
    title: "x",
    base,
    head,
    baseSha: repo.git("rev-parse", base),
    headSha: repo.git("rev-parse", head),
  });

  it("lists a range with renames detected, without touching the worktree", async () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "topic");
    repo.git("mv", "base.txt", "renamed.txt");
    repo.commitFile("added.txt", "add");
    expect(await listChangeset(spawnGit, repo.cwd, range(repo, "main", "topic"))).toEqual([
      { status: "A", path: "added.txt" },
      { status: "R", previousPath: "base.txt", path: "renamed.txt" },
    ]);
  });

  it("lists the uncommitted changeset: staged, unstaged, and untracked", async () => {
    const repo = makeRepo();
    repo.write("base.txt", "changed\n");
    repo.write("new dir/odd name.txt", "x\n");
    const files = await listChangeset(spawnGit, repo.cwd, {
      id: "uncommitted",
      title: "Uncommitted",
      base: "HEAD",
      head: "WORKTREE",
      uncommitted: true,
    });
    expect(files).toEqual([
      { status: "M", path: "base.txt" },
      { status: "?", path: "new dir/odd name.txt" },
    ]);
  });

  it("answers null for an unresolved range or a failing git", async () => {
    const repo = makeRepo();
    expect(await listChangeset(spawnGit, repo.cwd, { id: "x", title: "x", base: "a", head: "b" })).toBeNull();
    expect(
      await listChangeset(spawnGit, "/nonexistent-stack-dir", { ...range(repo, "main", "main"), id: "y" }),
    ).toBeNull();
  });
});
