import { describe, expect, it } from "bun:test";
import { CommitIndex, findCommit, originInScope, parseOrigin, type NoteOrigin, type OriginCommit } from "./origin";
import { contextAt, hunksOfPatch, noteKey, parsePatch, planRestore, rehomeTarget, type NoteRecord, type RestoreView } from "./persist";
import { createStackSource, type Changeset, type Zoom } from "./stack/stack";
import { createSys } from "./stack/sys";
import { makeRepo, type TestRepo } from "./stack/testRepo";

const none = () => undefined;

describe("findCommit", () => {
  const stored: OriginCommit = { sha: "a1", patchId: "p1", subject: "add x", branch: "feat" };

  it("prefers the sha, then the patch id, then the subject on the same branch", () => {
    const calls: string[] = [];
    const ids: Record<string, string> = { b2: "p1" };
    const patchIdOf = (sha: string) => (calls.push(sha), ids[sha]);
    expect(findCommit(stored, [{ sha: "a1", subject: "other" }], patchIdOf)?.sha).toBe("a1");
    // An exact sha never asks git for a patch id.
    expect(calls).toEqual([]);
    expect(findCommit(stored, [{ sha: "b2", subject: "other" }], patchIdOf)?.sha).toBe("b2");
    expect(findCommit(stored, [{ sha: "c3", subject: "add x", branch: "feat" }], none)?.sha).toBe("c3");
  });

  it("does not match a subject on another branch, or any subject when the branch was not recorded", () => {
    expect(findCommit(stored, [{ sha: "c3", subject: "add x", branch: "other" }], none)).toBeUndefined();
    expect(findCommit({ ...stored, branch: undefined }, [{ sha: "c3", subject: "add x" }], none)).toBeUndefined();
  });

  it("holds a changeset to every origin commit", () => {
    const origin: NoteOrigin = { commits: [stored, { sha: "z9", subject: "second", branch: "feat" }] };
    expect(originInScope(origin, { commits: [{ sha: "a1", subject: "add x" }] }, none)).toBe(false);
    expect(originInScope(origin, { commits: [{ sha: "a1", subject: "add x" }, { sha: "z9", subject: "second" }] }, none)).toBe(true);
    expect(originInScope({ uncommitted: true, branch: "feat" }, { commits: [], uncommitted: { branch: "feat" } }, none)).toBe(true);
    expect(originInScope({ uncommitted: true, branch: "feat" }, { commits: [{ sha: "a1", subject: "x" }] }, none)).toBe(false);
  });

  it("rejects origins that name nothing", () => {
    expect(parseOrigin({ commits: [] })).toBeNull();
    expect(parseOrigin({ uncommitted: true })).toBeNull();
    expect(parseOrigin(undefined)).toBeNull();
  });
});

const BASE = "l1\nl2\nl3\nl4\nl5\n";

/** main has `a.ts`; `feat` holds two commits that both touch it. */
function featRepo(): TestRepo {
  const repo = makeRepo();
  repo.write("a.ts", BASE);
  repo.git("add", ".");
  repo.git("commit", "-qm", "add a.ts");
  repo.git("checkout", "-qb", "feat");
  repo.write("a.ts", BASE.replace("l2", "alpha"));
  repo.git("commit", "-qam", "alpha");
  repo.write("a.ts", BASE.replace("l2", "alpha").replace("l4", "beta"));
  repo.git("commit", "-qam", "beta");
  return repo;
}

function stackOf(repo: TestRepo) {
  const sys = createSys(repo.cwd);
  const source = createStackSource(sys);
  return { sys, source, index: new CommitIndex(sys, source) };
}

function noteOn(patch: string, text: string, origin: NoteOrigin): NoteRecord {
  const lines = parsePatch(patch);
  const [line] = [...lines.new].find(([, value]) => value === text)!;
  return {
    key: noteKey(1, "n"),
    id: "n",
    source: "user",
    path: "a.ts",
    side: "new",
    line,
    lineText: text,
    context: contextAt(lines, "new", line),
    summary: "why",
    origin,
  };
}

/** Judge a note against a changeset the way a live review would, from git's own patch. */
function verdictOn(record: NoteRecord, index: CommitIndex, changeset: Changeset, extra: Partial<RestoreView> = {}) {
  const patch = index.changesetPatch(changeset, "a.ts");
  const files = patch ? [{ path: "a.ts", patch, hunks: hunksOfPatch(patch) }] : [];
  return planRestore([record], { files, scope: index.scopeOf(changeset), patchIdOf: index.patchId, ...extra }, new Set()).verdicts.get(record.key);
}

describe("a commit's note against the stack", () => {
  it("shows on its commit and on the combined changeset, and waits on a sibling that touches the same file", () => {
    const repo = featRepo();
    const { source, index } = stackOf(repo);
    const commits = source.load("commit");
    const [first, second] = commits;
    expect(commits.map((cs) => cs.title)).toEqual(["alpha", "beta"]);
    const origin = index.originOf(index.scopeOf(first!));
    const note = noteOn(index.changesetPatch(first!, "a.ts")!, "alpha", origin);

    expect(verdictOn(note, index, first!)).toMatchObject({ kind: "shown" });
    expect(verdictOn(note, index, source.load("combined")[0]!)).toMatchObject({ kind: "shown" });
    // The sibling's own patch shows `alpha` as context, but the note was not written on it.
    expect(verdictOn(note, index, second!)).toEqual({ kind: "pending" });
  });

  it("is outdated, not pending, on a changeset that holds its commit but lost the line", () => {
    const repo = featRepo();
    const { source, index } = stackOf(repo);
    const origin = index.originOf(index.scopeOf(source.load("commit")[0]!));
    const note = noteOn(index.changesetPatch(source.load("commit")[0]!, "a.ts")!, "alpha", origin);
    // A third commit rewrites the line; the combined changeset still holds the origin commit.
    repo.write("a.ts", BASE.replace("l4", "beta"));
    repo.git("commit", "-qam", "revert alpha");
    const later = stackOf(repo);
    const verdict = verdictOn(note, later.index, later.source.load("combined")[0]!);
    expect(verdict).toMatchObject({ kind: "shown", outdated: true });
  });
});

describe("origin commits across history rewrites", () => {
  it("is found again after a rebase gives the commits new shas", () => {
    const repo = featRepo();
    const before = stackOf(repo);
    const first = before.source.load("commit")[0]!;
    const origin = before.index.originOf(before.index.scopeOf(first)) as { commits: OriginCommit[] };
    repo.git("checkout", "-q", "main");
    repo.commitFile("other.txt", "advance main");
    repo.git("checkout", "-q", "feat");
    repo.git("rebase", "-q", "main");

    const after = stackOf(repo);
    const rebased = after.source.load("commit")[0]!;
    expect(rebased.headSha).not.toBe(first.headSha);
    const scope = after.index.scopeOf(rebased);
    // A different subject on a different branch rules out the third step: only the patch id can match.
    const renamed = { commits: [{ ...origin.commits[0]!, subject: "renamed", branch: "gone" }] };
    expect(originInScope(renamed, scope, after.index.patchId)).toBe(true);
    expect(findCommit(renamed.commits[0]!, scope.commits, none)).toBeUndefined();
  });

  it("is found again after an amend changed the patch, by its subject on the same branch", () => {
    const repo = makeRepo();
    repo.write("a.ts", BASE);
    repo.git("add", ".");
    repo.git("commit", "-qm", "add a.ts");
    repo.git("checkout", "-qb", "feat");
    repo.write("a.ts", BASE.replace("l2", "alpha"));
    repo.git("commit", "-qam", "alpha");
    const before = stackOf(repo);
    const first = before.source.load("commit")[0]!;
    const origin = before.index.originOf(before.index.scopeOf(first));

    repo.write("a.ts", BASE.replace("l2", "alpha").replace("l5", "extra"));
    repo.git("commit", "-q", "--amend", "-am", "alpha");
    const after = stackOf(repo);
    const amended = after.source.load("commit")[0]!;
    const scope = after.index.scopeOf(amended);
    expect(amended.headSha).not.toBe(first.headSha);
    const stored = (origin as { commits: OriginCommit[] }).commits[0]!;
    expect(after.index.patchId(amended.headSha!)).not.toBe(stored.patchId);
    expect(stored.branch).toBe("feat");
    expect(originInScope(origin, scope, after.index.patchId)).toBe(true);
  });

  it("matches nothing once an amend changed the subject as well as the patch", () => {
    const repo = featRepo();
    const before = stackOf(repo);
    const origin = before.index.originOf(before.index.scopeOf(before.source.load("commit")[1]!));
    repo.write("a.ts", BASE.replace("l2", "alpha").replace("l4", "other"));
    repo.git("commit", "-q", "--amend", "-am", "renamed");
    const after = stackOf(repo);
    const amended = after.source.load("commit")[1]!;
    expect(amended.title).toBe("renamed");
    expect(originInScope(origin, after.index.scopeOf(amended), after.index.patchId)).toBe(false);
  });
});

describe("an uncommitted note", () => {
  it("re-homes to the commit that now holds its line", () => {
    const repo = makeRepo();
    repo.write("a.ts", BASE);
    repo.git("add", ".");
    repo.git("commit", "-qm", "add a.ts");
    repo.git("checkout", "-qb", "feat");
    repo.write("a.ts", BASE.replace("l3", "gamma"));

    const dirty = stackOf(repo);
    const uncommitted = dirty.source.load("commit").find((cs: Changeset) => cs.uncommitted)!;
    const origin = dirty.index.originOf(dirty.index.scopeOf(uncommitted));
    expect(origin).toEqual({ uncommitted: true, branch: "feat" });
    const note = noteOn(dirty.index.changesetPatch(uncommitted, "a.ts")!, "gamma", origin);
    expect(verdictOn(note, dirty.index, uncommitted)).toMatchObject({ kind: "shown" });

    repo.git("commit", "-qam", "gamma");
    const committed = stackOf(repo);
    const commit = committed.source.load("commit")[0]!;
    const rehome: RestoreView["rehome"] = (record, branch) => rehomeTarget(record, committed.index.branchCommits(branch), committed.index.commitPatch);
    const plan = planRestore(
      [note],
      { files: [{ path: "a.ts", patch: committed.index.changesetPatch(commit, "a.ts")!, hunks: hunksOfPatch(committed.index.changesetPatch(commit, "a.ts")!) }], scope: committed.index.scopeOf(commit), patchIdOf: committed.index.patchId, rehome },
      new Set(),
    );
    expect(plan.rehomed).toHaveLength(1);
    expect(plan.rehomed[0]!.origin).toMatchObject({ commits: [{ sha: commit.headSha, subject: "gamma", branch: "feat" }] });
    expect(plan.batches[0]![0]!.target).toMatchObject({ side: "new" });
  });
});

describe("CommitIndex", () => {
  it("lists a changeset's commits with their branch, and caches patch ids by sha", () => {
    const repo = featRepo();
    const { source, index } = stackOf(repo);
    const combined = index.scopeOf(source.load("combined")[0]!);
    expect(combined.commits.map((commit) => [commit.subject, commit.branch])).toEqual([["beta", "feat"], ["alpha", "feat"]]);
    const sha = combined.commits[0]!.sha;
    expect(index.patchId(sha)).toMatch(/^[0-9a-f]{40}$/);
    expect(index.describe(sha)).toMatchObject({ sha, subject: "beta", branch: "feat" });
    expect(index.describe("0".repeat(40))).toBeNull();
  });

  it("has no commits for the uncommitted changeset, which stands on its branch", () => {
    const repo = featRepo();
    repo.write("a.ts", "dirty\n");
    const { source, index } = stackOf(repo);
    const zooms: Zoom[] = source.zooms;
    expect(zooms).toContain("combined");
    const uncommitted = source.load("commit").find((cs) => cs.uncommitted)!;
    expect(index.scopeOf(uncommitted)).toEqual({ commits: [], uncommitted: { branch: "feat" } });
  });
});
