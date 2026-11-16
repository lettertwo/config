import { currentBranch } from "./stack/git";
import type { Changeset, StackSource } from "./stack/stack";
import type { Sys } from "./stack/sys";

/**
 * A commit as a note remembers it. A sha is exact until a rebase or amend rewrites it, so the
 * patch id (stable across a rebase) and the subject on a branch (stable across an amend that
 * changed the content) stand behind it.
 */
export interface OriginCommit {
  sha: string;
  /** `git patch-id --stable` of the commit; absent for a commit with no diff, such as a merge. */
  patchId?: string;
  subject: string;
  branch?: string;
}

/**
 * The changeset a note was written on. A committed changeset is the commits it held, so the note
 * belongs to every changeset that holds all of them. Uncommitted changes have no commits yet, so
 * the branch they sat on stands in until a commit takes the line.
 */
export type NoteOrigin = { commits: OriginCommit[] } | { uncommitted: true; branch: string };

/** What a loaded changeset holds, as far as a note's origin is concerned. */
export interface Scope {
  commits: readonly OriginCommit[];
  /** Set for the uncommitted changeset, which holds no commits. */
  uncommitted?: { branch: string };
}

export type PatchIdOf = (sha: string) => string | undefined;

export function parseCommit(value: unknown): OriginCommit | null {
  const commit = value as Partial<OriginCommit> | null;
  if (!commit || typeof commit.sha !== "string" || typeof commit.subject !== "string") {
    return null;
  }
  if ((commit.patchId !== undefined && typeof commit.patchId !== "string") || (commit.branch !== undefined && typeof commit.branch !== "string")) {
    return null;
  }
  return commit as OriginCommit;
}

export function parseOrigin(value: unknown): NoteOrigin | null {
  const origin = value as { commits?: unknown; uncommitted?: unknown; branch?: unknown } | null;
  if (!origin || typeof origin !== "object") {
    return null;
  }
  if (origin.uncommitted === true) {
    return typeof origin.branch === "string" ? (origin as NoteOrigin) : null;
  }
  if (Array.isArray(origin.commits) && origin.commits.length > 0 && origin.commits.every((commit) => parseCommit(commit) !== null)) {
    return origin as NoteOrigin;
  }
  return null;
}

/**
 * The candidate that is `stored` now. Each step runs only when the one before found nothing,
 * since a patch id costs a `git` call per candidate: the same sha, then the same patch id (a
 * rebase moved the commit), then the same subject on the same branch (an amend changed it).
 */
export function findCommit(stored: OriginCommit, candidates: readonly OriginCommit[], patchIdOf: PatchIdOf): OriginCommit | undefined {
  const bySha = candidates.find((candidate) => candidate.sha === stored.sha);
  if (bySha) {
    return bySha;
  }
  if (stored.patchId !== undefined) {
    const byPatch = candidates.find((candidate) => candidate.patchId === stored.patchId || patchIdOf(candidate.sha) === stored.patchId);
    if (byPatch) {
      return byPatch;
    }
  }
  if (stored.branch === undefined) {
    return undefined;
  }
  return candidates.find((candidate) => candidate.subject === stored.subject && candidate.branch === stored.branch);
}

/** Whether a changeset with this scope holds what the origin names. */
export function originInScope(origin: NoteOrigin, scope: Scope, patchIdOf: PatchIdOf): boolean {
  if ("uncommitted" in origin) {
    return scope.uncommitted?.branch === origin.branch;
  }
  return origin.commits.every((stored) => findCommit(stored, scope.commits, patchIdOf) !== undefined);
}

/** How far back a branch is searched for the commit that took an uncommitted note's line, with no stack. */
const UNSTACKED_BRANCH_COMMITS = 20;

/** Starts of the git log lines `commitsIn` reads: `<sha>\t<subject>`. */
const LOG_FORMAT = "--format=%H%x09%s";

function parseLog(stdout: string): { sha: string; subject: string }[] {
  const commits: { sha: string; subject: string }[] = [];
  for (const line of stdout.split("\n")) {
    const tab = line.indexOf("\t");
    if (tab > 0) {
      commits.push({ sha: line.slice(0, tab), subject: line.slice(tab + 1) });
    }
  }
  return commits;
}

/**
 * Commit facts for notes: which commits a changeset holds, which stack branch owns each, and
 * their patch ids. Patch ids are cached by sha, since a commit never changes; everything else is
 * read from git again after `refresh`.
 */
export class CommitIndex {
  private readonly patchIds = new Map<string, string | null>();
  private owned: { owner: Map<string, string>; byBranch: Map<string, { sha: string; subject: string }[]> } | null = null;
  private readonly patches = new Map<string, string | undefined>();

  constructor(
    private readonly sys: Sys,
    private readonly source: StackSource | null,
  ) {}

  /** Forget which branch owns which commit; call after the stack was read again. */
  refresh() {
    this.owned = null;
  }

  patchId = (sha: string): string | undefined => {
    let id = this.patchIds.get(sha);
    if (id === undefined) {
      const diff = this.sys.git(["show", "--no-color", "--no-ext-diff", "--format=", sha]);
      const out = diff.code === 0 && diff.stdout !== "" ? this.sys.git(["patch-id", "--stable"], diff.stdout) : null;
      id = out && out.code === 0 ? (out.stdout.split(/\s+/u)[0] || null) : null;
      this.patchIds.set(sha, id);
    }
    return id ?? undefined;
  };

  private ownership() {
    if (this.owned) {
      return this.owned;
    }
    const owner = new Map<string, string>();
    const byBranch = new Map<string, { sha: string; subject: string }[]>();
    const source = this.source;
    if (source) {
      // The git-log fallback has one node per commit and no branch names of its own.
      const checkedOut = source.graph.isCommitGraph ? currentBranch(this.sys) : null;
      for (const node of [...source.graph.nodes].reverse()) {
        const branch = checkedOut ?? node.branch;
        const log = this.sys.git(["log", LOG_FORMAT, `${source.graph.baseRef(node)}..${source.graph.headRef(node)}`]);
        for (const commit of log.code === 0 ? parseLog(log.stdout) : []) {
          if (!owner.has(commit.sha)) {
            owner.set(commit.sha, branch);
            byBranch.set(branch, [...(byBranch.get(branch) ?? []), commit]);
          }
        }
      }
    }
    this.owned = { owner, byBranch };
    return this.owned;
  }

  /**
   * The commits of a stack branch, newest first. With no stack to say where a branch starts, the
   * newest few commits reachable from it stand in, which is where a note's line is likeliest to
   * have landed.
   */
  branchCommits(branch: string): OriginCommit[] {
    if (!this.source) {
      const log = this.sys.git(["log", "-n", String(UNSTACKED_BRANCH_COMMITS), LOG_FORMAT, branch, "--"]);
      return (log.code === 0 ? parseLog(log.stdout) : []).map((commit) => ({ ...commit, branch }));
    }
    const { byBranch } = this.ownership();
    return (byBranch.get(branch) ?? []).map((commit) => ({ ...commit, branch }));
  }

  /** `sha` as a commit a note can store, or null when git does not know it. */
  describe(sha: string): OriginCommit | null {
    const log = this.sys.git(["log", "-1", LOG_FORMAT, sha]);
    const [found] = log.code === 0 ? parseLog(log.stdout) : [];
    if (!found) {
      return null;
    }
    const branch = this.ownership().owner.get(found.sha);
    return { sha: found.sha, patchId: this.patchId(found.sha), subject: found.subject, ...(branch === undefined ? {} : { branch }) };
  }

  /** The uncommitted changeset: no commits, standing on the checked-out branch. */
  uncommittedScope(): Scope {
    return { commits: [], uncommitted: { branch: currentBranch(this.sys) } };
  }

  /**
   * The commits in `base..head`, which may be any two revisions. Without a stack source no branch
   * owns a commit, so none is recorded and the subject-on-a-branch match is skipped for them;
   * a sha or a patch id still finds them.
   */
  scopeOfRange(base: string, head: string, fallbackBranch?: string): Scope {
    const { owner } = this.ownership();
    const log = this.sys.git(["log", LOG_FORMAT, `${base}..${head}`]);
    const commits = (log.code === 0 ? parseLog(log.stdout) : []).map((commit): OriginCommit => {
      const branch = owner.get(commit.sha) ?? fallbackBranch;
      return { ...commit, ...(branch === undefined ? {} : { branch }) };
    });
    return { commits };
  }

  /** The one commit `hunk show <revision>` displays. */
  scopeOfCommit(revision: string): Scope {
    const log = this.sys.git(["log", "-n", "1", LOG_FORMAT, revision, "--"]);
    const [commit] = log.code === 0 ? parseLog(log.stdout) : [];
    if (!commit) {
      return { commits: [] };
    }
    const branch = this.ownership().owner.get(commit.sha);
    return { commits: [{ ...commit, ...(branch === undefined ? {} : { branch }) }] };
  }

  scopeOf(changeset: Changeset): Scope {
    if (changeset.uncommitted) {
      return this.uncommittedScope();
    }
    if (!changeset.baseSha || !changeset.headSha) {
      return { commits: [] };
    }
    const fallback = changeset.branch && changeset.branch !== changeset.headSha.slice(0, 8) ? changeset.branch : undefined;
    return this.scopeOfRange(changeset.baseSha, changeset.headSha, fallback);
  }

  /** The origin a note written on a changeset with this scope carries; patch ids are filled in. */
  originOf(scope: Scope): NoteOrigin {
    if (scope.uncommitted) {
      return { uncommitted: true, branch: scope.uncommitted.branch };
    }
    return { commits: scope.commits.map((commit) => ({ ...commit, patchId: commit.patchId ?? this.patchId(commit.sha) })) };
  }

  /** What one commit changed in `path`, as a patch, or undefined when it left the file alone. */
  commitPatch = (commit: OriginCommit, path: string): string | undefined => {
    const key = `${commit.sha}\0${path}`;
    if (!this.patches.has(key)) {
      const shown = this.sys.git(["show", "--no-color", "--no-ext-diff", "--format=", commit.sha, "--", path]);
      this.patches.set(key, shown.code === 0 && shown.stdout !== "" ? shown.stdout : undefined);
    }
    return this.patches.get(key);
  };

  /** The patch of `path` in a changeset, read from git, for judging a note without a live review. */
  changesetPatch(changeset: Changeset, path: string): string | undefined {
    const args = changeset.uncommitted
      ? ["diff", "--no-color", "--no-ext-diff", "HEAD", "--", path]
      : changeset.baseSha && changeset.headSha
        ? ["diff", "--no-color", "--no-ext-diff", changeset.baseSha, changeset.headSha, "--", path]
        : null;
    const diff = args ? this.sys.git(args) : null;
    return diff && diff.code === 0 && diff.stdout !== "" ? diff.stdout : undefined;
  }
}
