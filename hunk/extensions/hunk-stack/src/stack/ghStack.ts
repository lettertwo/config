import { existsSync, lstatSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { commonDir, currentBranch } from "./git";
import type { StackGraph, WalkRow } from "./types";
import type { Sys } from "./sys";
import { walk } from "./walk";

const FILE_NAME = "gh-stack";

interface StackEntry {
  number?: number;
  id?: string;
  trunk?: { branch?: unknown };
  branches?: { branch?: string; head?: string; base?: string; pullRequest?: { number?: number } }[];
}

function sleepSync(ms: number) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

/**
 * Read and parse, retrying: gh-stack writes by truncating in place, so a reader can catch
 * the file half-written during any concurrent `gh stack` command. Three attempts, 25ms
 * apart, then the file is skipped. A schemaVersion above what this reader understands is
 * not a race and no retry fixes it, so it throws instead of being swallowed.
 */
function readStackFile(path: string): { stacks?: StackEntry[] } | null {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const data = JSON.parse(readFileSync(path, "utf8"));
      if (data && typeof data === "object") {
        const version = data.schemaVersion ?? 1;
        if (version > 1) {
          throw new SchemaVersionError(path, version);
        }
        return data;
      }
    } catch (error) {
      if (error instanceof SchemaVersionError) {
        throw error;
      }
    }
    if (attempt < 3) {
      sleepSync(25);
    }
  }
  return null;
}

class SchemaVersionError extends Error {
  constructor(path: string, version: number) {
    super(`gh-stack file ${path} has schemaVersion ${version}, newer than this reader understands`);
  }
}

/**
 * Every gh-stack file under `<common>/worktrees/` that is a regular file rather than a symlink, in
 * directory-name order. A worktree admin dir holds a symlink once something has
 * canonicalized it, and a dangling one is a valid not-yet-created state, so link-or-not is
 * judged by lstat and never followed.
 */
function unlinkedWorktreeFiles(commonDirPath: string): string[] {
  const worktrees = join(commonDirPath, "worktrees");
  if (!existsSync(worktrees) || !statSync(worktrees).isDirectory()) {
    return [];
  }
  const files: string[] = [];
  for (const name of readdirSync(worktrees).sort()) {
    const path = join(worktrees, name, FILE_NAME);
    try {
      if (lstatSync(path).isFile()) {
        files.push(path);
      }
    } catch {
      // No gh-stack file in this worktree's admin dir.
    }
  }
  return files;
}

/**
 * Two files can describe the same stack (the canonical plus a stale worktree copy), and
 * whichever is found first wins wholesale, since merging two disagreeing ordered branch
 * lists has no defined meaning.
 */
function stackIdentity(stack: StackEntry): string {
  if (stack.number) {
    return `number:${stack.number}`;
  }
  if (stack.id) {
    return `id:${stack.id}`;
  }
  return `trunk:${stack.trunk?.branch ?? ""}:${stack.branches?.[0]?.branch ?? ""}`;
}

/**
 * Fold a stack's linear branch list into the parent map: the first branch's parent is the
 * trunk, each later one's is the branch before it. The file's own `head` is a snapshot from
 * the last sync and is stale after a plain git commit, so it only rides along as the walk's
 * fallback and `headRef` never reads it.
 */
function foldStack(stack: StackEntry, byBranch: Map<string, WalkRow>, prNumbers: Map<string, number>) {
  let parent = stack.trunk!.branch as string;
  for (const br of stack.branches ?? []) {
    if (br.branch && !byBranch.has(br.branch)) {
      byBranch.set(br.branch, {
        branch: br.branch,
        parent,
        headRev: br.head ?? "",
        parentRev: br.base ?? "",
      });
      if (br.pullRequest?.number) {
        prNumbers.set(br.branch, br.pullRequest.number);
      }
    }
    parent = br.branch ?? parent;
  }
}

/** Reads gh-stack's own file rather than shelling out to `gh stack`. */
export function createGhStackGraph(sys: Sys, common?: string | null, branch?: string): StackGraph {
  const dir = common ?? commonDir(sys) ?? join(sys.cwd, ".git");
  const focus = branch ?? currentBranch(sys);

  const paths: string[] = [];
  const canonical = join(dir, FILE_NAME);
  if (existsSync(canonical)) {
    paths.push(canonical);
  }
  paths.push(...unlinkedWorktreeFiles(dir));

  const seen = new Set<string>();
  const byBranch = new Map<string, WalkRow>();
  const prNumbers = new Map<string, number>();
  for (const path of paths) {
    const data = readStackFile(path);
    for (const stack of data?.stacks ?? []) {
      // One entry without a well-formed trunk is skipped so it doesn't blind the rest of the file.
      if (typeof stack.trunk?.branch === "string" && stack.trunk.branch !== "") {
        const identity = stackIdentity(stack);
        if (!seen.has(identity)) {
          seen.add(identity);
          foldStack(stack, byBranch, prNumbers);
        }
      }
    }
  }

  return {
    kind: "gh-stack",
    nodes: walk(byBranch, focus),
    isCommitGraph: false,
    baseRef: (node) => node.parentRev,
    headRef: (node) => `refs/heads/${node.branch}`,
    metadata: (node) => ({ prNumber: prNumbers.get(node.branch) }),
  };
}
