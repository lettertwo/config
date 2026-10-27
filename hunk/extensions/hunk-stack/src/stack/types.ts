/** One reviewable step of a stack: a branch, or a single commit on the git-log fallback. */
export interface StackNode {
  id: string;
  branch: string;
  parentBranch?: string;
  headRev: string;
  parentRev: string;
  title?: string;
}

export interface NodeMetadata {
  prNumber?: number;
  title?: string;
  body?: string;
}

/**
 * Where a stack comes from: gh-stack, Graphite, or the git-log fallback.
 * Nodes are ordered base to head.
 */
export interface StackGraph {
  kind: "gh-stack" | "graphite" | "git";
  nodes: StackNode[];
  /** The git-log fallback already has one node per commit, so it has no separate branch zoom. */
  isCommitGraph: boolean;
  baseRef(node: StackNode): string;
  headRef(node: StackNode): string;
  metadata(node: StackNode): NodeMetadata;
}

/** The branch-to-parent map both file-backed providers reduce their formats to. */
export interface WalkRow {
  branch: string;
  parent: string | undefined;
  headRev: string;
  parentRev: string;
}
