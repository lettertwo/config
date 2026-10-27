import { describe, expect, it } from "bun:test";
import { createStackSource, type Changeset } from "./stack";
import { createSys } from "./sys";
import { GRAPHITE_SCHEMA, hasSqlite, makeRepo, type TestRepo } from "./testRepo";

const ids = (cs: Changeset[]) => cs.map((c) => c.id);
const source = (repo: TestRepo, focusBranch?: string) =>
  createStackSource(createSys(repo.cwd), { focusBranch });
/** The files a changeset's own range touches, via the shas it resolved. */
const filesOf = (repo: TestRepo, cs: Changeset) =>
  repo
    .git("diff", "--name-only", cs.baseSha!, cs.headSha!)
    .split("\n")
    .filter(Boolean);

// Mid-stack over a fabricated graphite db: whole-stack scope (descendants included),
// uncommitted placement next to the current branch, the current marker, and the restack flag.
describe.skipIf(!hasSqlite)("stack source (mid-stack, graphite)", () => {
  const repo = makeRepo();
  const mainSha = repo.git("rev-parse", "HEAD");
  repo.git("checkout", "-qb", "feat-a");
  repo.commitFile("a.txt", "feat a");
  const aSha = repo.git("rev-parse", "HEAD");
  repo.git("checkout", "-qb", "feat-b");
  repo.commitFile("b.txt", "feat b");
  const bSha = repo.git("rev-parse", "HEAD");
  // Sit mid-stack on feat-a with an uncommitted (untracked) file.
  repo.git("checkout", "-q", "feat-a");
  repo.write("dirty.txt", "dirty\n");
  // feat-b's recorded parent revision is main's sha, not feat-a's head, so it is pending a restack.
  repo.sqlite(
    ".graphite_metadata.db",
    GRAPHITE_SCHEMA +
      ` INSERT INTO branch_metadata VALUES ('feat-a','main','${aSha}','${mainSha}');` +
      ` INSERT INTO branch_metadata VALUES ('feat-b','feat-a','${bSha}','${mainSha}');`,
  );
  const changesets = source(repo).load("branch");

  it("orders ancestors, current, uncommitted, then descendants", () => {
    expect(ids(changesets)).toEqual(["feat-a", "uncommitted", "feat-b"]);
  });

  it("marks the uncommitted changeset as the review's starting position", () => {
    expect(changesets[1]!.current).toBe(true);
    expect(changesets[0]!.current).toBeUndefined();
    expect(changesets[2]!.current).toBeUndefined();
  });

  it("flags stale descendants as needing a restack", () => {
    expect(changesets[2]!.title).toContain("needs restack");
    expect(changesets[0]!.title).not.toContain("needs restack");
  });

  it("keeps per-changeset ranges commit-ranged and resolves them to shas", () => {
    expect(filesOf(repo, changesets[0]!)).toEqual(["a.txt"]);
    expect(changesets[0]!.headSha).toBe(aSha);
    expect(changesets[1]).toMatchObject({ base: "HEAD", head: "WORKTREE", uncommitted: true });
    expect(changesets[1]!.headSha).toBeUndefined();
  });
});

describe("stack source (gh-stack)", () => {
  function build() {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "a1");
    repo.commitFile("a1x.txt", "a1: add x");
    repo.commitFile("a1y.txt", "a1: add y");
    // Tracked, but with no commits of its own: contributes no commit changesets.
    repo.git("checkout", "-qb", "b1");
    repo.git("checkout", "-qb", "c1");
    repo.commitFile("c1z.txt", "c1: add z");
    repo.write("base.txt", "dirty\n");
    repo.writeGhStack({
      schemaVersion: 1,
      stacks: [{ trunk: { branch: "main" }, branches: [{ branch: "a1" }, { branch: "b1" }, { branch: "c1" }] }],
    });
    return repo;
  }

  it("offers combined, branch, commit and opens on branch", () => {
    const src = source(build());
    expect(src.zooms).toEqual(["combined", "branch", "commit"]);
    expect(src.defaultZoom).toBe("branch");
  });

  it("chains one changeset per commit, oldest first, skipping the zero-commit branch", () => {
    const repo = build();
    const cs = source(repo).load("commit");
    expect(cs).toHaveLength(4);
    expect(filesOf(repo, cs[0]!)).toEqual(["a1x.txt"]);
    expect(filesOf(repo, cs[1]!)).toEqual(["a1y.txt"]);
    expect(filesOf(repo, cs[2]!)).toEqual(["c1z.txt"]);
    expect(cs[3]!.id).toBe("uncommitted");
  });

  it("carries the owning branch on every commit header", () => {
    const cs = source(build()).load("commit");
    expect(cs.slice(0, 3).map((c) => c.branch)).toEqual(["a1", "a1", "c1"]);
  });

  it("places uncommitted right after the focus branch's newest commit, marked current", () => {
    const cs = source(build()).load("commit");
    expect(cs.map((c) => c.current)).toEqual([undefined, undefined, undefined, true]);
  });

  it("spans the bottom node's base to the top node's head, uncommitted after it and current", () => {
    const repo = build();
    const cs = source(repo).load("combined");
    expect(ids(cs)).toEqual(["combined", "uncommitted"]);
    expect(cs[0]!.title).toBe("Combined (3 branches)");
    expect(filesOf(repo, cs[0]!)).toEqual(["a1x.txt", "a1y.txt", "c1z.txt"]);
    expect(cs[0]!.current).toBeUndefined();
    expect(cs[1]!.current).toBe(true);
  });

  it("covers the whole stack regardless of focus, and is current when there is no uncommitted layer", () => {
    const repo = build();
    const cs = source(repo, "a1").load("combined");
    expect(ids(cs)).toEqual(["combined"]);
    expect(filesOf(repo, cs[0]!)).toEqual(["a1x.txt", "a1y.txt", "c1z.txt"]);
    expect(cs[0]!.current).toBe(true);
  });

  it("marks the focus branch current when the worktree is clean", () => {
    const repo = build();
    repo.git("checkout", "--", "base.txt");
    const cs = source(repo).load("branch");
    expect(ids(cs)).toEqual(["a1", "b1", "c1"]);
    expect(cs.map((c) => c.current)).toEqual([undefined, undefined, true]);
  });
});

describe("stack source (git-log fallback)", () => {
  it("offers combined and commit, opens on commit, and builds commit from node specs", () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feature");
    repo.commitFile("f1.txt", "feature: one");
    repo.commitFile("f2.txt", "feature: two");
    const src = source(repo);
    expect(src.zooms).toEqual(["combined", "commit"]);
    expect(src.defaultZoom).toBe("commit");

    const perCommit = src.load("commit");
    expect(perCommit).toHaveLength(2);
    expect(perCommit.map((c) => c.branch)).toEqual([undefined, undefined]);
    expect(filesOf(repo, perCommit[0]!)).toEqual(["f1.txt"]);
    expect(filesOf(repo, perCommit[1]!)).toEqual(["f2.txt"]);
    expect(perCommit[1]!.current).toBe(true);

    const combined = src.load("combined");
    expect(combined).toHaveLength(1);
    expect(combined[0]!.title).toBe("Combined (2 commits)");
    expect(filesOf(repo, combined[0]!)).toEqual(["f1.txt", "f2.txt"]);
  });

  it("throws when no trunk branch can be found", () => {
    const repo = makeRepo();
    repo.git("branch", "-m", "main", "dev");
    expect(() => source(repo)).toThrow(/no trunk branch/);
  });
});
