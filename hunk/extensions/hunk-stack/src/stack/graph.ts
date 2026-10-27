import { existsSync } from "node:fs";
import { join } from "node:path";
import { createGhStackGraph } from "./ghStack";
import { commonDir } from "./git";
import { createGitGraph } from "./gitGraph";
import { createGraphiteGraph } from "./graphite";
import type { StackGraph } from "./types";
import type { Sys } from "./sys";

/**
 * Precedence per focus branch: gh-stack, then Graphite, then git log. Each provider answers
 * only for a branch it tracks (a non-empty walk), and a branch tracked by both gh-stack and
 * Graphite goes to gh-stack. Throws when the git-log fallback cannot resolve a trunk, or
 * when the gh-stack file is a schema this reader does not know.
 */
export function createGraph(sys: Sys, branch?: string): StackGraph {
  // Graphite and gh-stack state key off the common git dir, shared across worktrees (a
  // bare-repo layout has no cwd/.git directory at all).
  const common = commonDir(sys);

  // An empty walk means the branch is untracked by gh-stack (or link-managed, which leaves
  // no local file), not that the stack is empty.
  const ghStack = createGhStackGraph(sys, common, branch);
  if (ghStack.nodes.length > 0) {
    return ghStack;
  }

  const db = common ? join(common, ".graphite_metadata.db") : null;
  if (db && existsSync(db) && sys.sqlite(":memory:", "select 1;").code === 0) {
    // A db can exist while gt doesn't track the branch (or the table is vestigial), so an
    // empty walk means Graphite has nothing to say here.
    const graphite = createGraphiteGraph(sys, common, branch);
    if (graphite.nodes.length > 0) {
      return graphite;
    }
  }
  return createGitGraph(sys, branch);
}
