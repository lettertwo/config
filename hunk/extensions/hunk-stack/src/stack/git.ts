import { isAbsolute, join } from "node:path";
import type { Sys } from "./sys";

export interface Commit {
  sha: string;
  subject: string;
}

/** The repo-wide git dir, shared across worktrees. Graphite and gh-stack state live here. */
export function commonDir(sys: Sys): string | null {
  const r = sys.git(["rev-parse", "--git-common-dir"]);
  const dir = r.stdout.trim();
  if (r.code !== 0 || dir === "") {
    return null;
  }
  // Plain repos answer a relative ".git".
  return isAbsolute(dir) ? dir : join(sys.cwd, dir);
}

export function currentBranch(sys: Sys): string {
  return sys.git(["rev-parse", "--abbrev-ref", "HEAD"]).stdout.trim() || "HEAD";
}

/**
 * origin/HEAD when a remote is configured, else whichever of main/master exists locally.
 * Errors rather than guessing: defaulting to "main" would diff against a branch that was never there.
 */
export function trunkBranch(sys: Sys): { trunk: string } | { error: string } {
  const origin = sys.git(["rev-parse", "--abbrev-ref", "origin/HEAD"]);
  if (origin.code === 0) {
    return { trunk: origin.stdout.trim().replace(/^origin\//, "") };
  }
  for (const name of ["main", "master"]) {
    if (sys.git(["show-ref", "--verify", "--quiet", `refs/heads/${name}`]).code === 0) {
      return { trunk: name };
    }
  }
  return { error: "no trunk branch found (no origin/HEAD, main, or master)" };
}

/** The current branch's upstream tracking ref (e.g. "origin/main"), or null when none is set. */
export function upstreamRef(sys: Sys): string | null {
  const r = sys.git(["rev-parse", "--abbrev-ref", "@{upstream}"]);
  const ref = r.stdout.trim();
  return r.code === 0 && ref !== "" ? ref : null;
}

/** First-parent commits in base..head, newest first as git prints them. */
export function logFirstParent(sys: Sys, base: string, head: string): Commit[] | { error: string } {
  const r = sys.git(["log", "--first-parent", "--format=%H %s", `${base}..${head}`]);
  if (r.code !== 0) {
    return { error: r.stderr };
  }
  const commits: Commit[] = [];
  for (const line of r.stdout.split("\n")) {
    const match = /^([0-9a-f]+) (.*)$/.exec(line);
    if (match) {
      commits.push({ sha: match[1]!, subject: match[2]! });
    }
  }
  return commits;
}

/**
 * Resolve several refs to commit shas in one process. `git rev-parse` stops at the first
 * failure, so it can't answer for a batch; `cat-file --batch-check` answers every line in
 * order and prints "<rev> missing" for a miss. Refs that don't resolve are absent from the map.
 */
export function revParseMany(sys: Sys, refs: readonly string[]): Map<string, string> {
  const order = [...new Set(refs.filter((ref) => ref !== ""))];
  const shas = new Map<string, string>();
  if (order.length === 0) {
    return shas;
  }
  const input = order.map((ref) => `${ref}^{commit}`).join("\n") + "\n";
  const r = sys.git(["cat-file", "--batch-check=%(objectname)"], input);
  const lines = r.stdout.split("\n");
  order.forEach((ref, i) => {
    const line = lines[i];
    if (line && /^[0-9a-f]{40,}$/.test(line)) {
      shas.set(ref, line);
    }
  });
  return shas;
}

/** Whether the worktree differs from HEAD in any way a `hunk diff` would show, untracked files included. */
export function hasUncommittedChanges(sys: Sys): boolean {
  return sys.git(["status", "--porcelain"]).stdout.trim() !== "";
}
