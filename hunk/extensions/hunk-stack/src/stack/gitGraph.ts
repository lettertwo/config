import { currentBranch, logFirstParent, trunkBranch, upstreamRef, type Commit } from "./git";
import type { StackGraph, StackNode } from "./types";
import type { Sys } from "./sys";

/**
 * Nodes from a base/current pair and the first-parent commit list, newest first as git
 * prints it. Each commit's base is the next-older commit; the oldest bases on `base`
 * (trunk for a feature branch, the upstream ref for unpushed commits on trunk).
 * Nodes come back base to head.
 */
export function buildNodes(base: string, current: string, commits: Commit[] | null): StackNode[] {
  if (!commits || commits.length === 0) {
    if (current === base) {
      // On trunk with nothing in flight: one node for the last commit, so a review never opens empty.
      return [
        { id: "HEAD", branch: current, parentBranch: base, headRev: "HEAD", parentRev: "HEAD~1", title: "HEAD" },
      ];
    }
    // The entire branch as one changeset against base.
    return [
      { id: current, branch: current, parentBranch: base, headRev: current, parentRev: base, title: current },
    ];
  }
  const nodes: StackNode[] = [];
  for (let i = commits.length - 1; i >= 0; i--) {
    const commit = commits[i]!;
    const parent = i < commits.length - 1 ? commits[i + 1]!.sha : base;
    nodes.push({
      id: commit.sha,
      branch: commit.sha.slice(0, 8),
      parentBranch: parent,
      headRev: commit.sha,
      parentRev: parent,
      title: commit.subject,
    });
  }
  return nodes;
}

/**
 * Off trunk the base is trunk. On trunk it is the upstream tracking ref, so unpushed
 * commits show up one per changeset ("what's in flight from this worktree").
 */
export function createGitGraph(sys: Sys, branch?: string): StackGraph {
  const focus = branch ?? currentBranch(sys);
  const trunk = trunkBranch(sys);
  if ("error" in trunk) {
    throw new Error(trunk.error);
  }

  let nodes: StackNode[];
  if (focus !== trunk.trunk) {
    const commits = logFirstParent(sys, trunk.trunk, focus);
    nodes = buildNodes(trunk.trunk, focus, Array.isArray(commits) ? commits : null);
  } else {
    const upstream = upstreamRef(sys);
    const commits = upstream ? logFirstParent(sys, upstream, "HEAD") : null;
    nodes =
      upstream && Array.isArray(commits) && commits.length > 0
        ? buildNodes(upstream, focus, commits)
        : buildNodes(trunk.trunk, focus, null); // fully pushed: the last-commit node
  }

  return {
    kind: "git",
    nodes,
    isCommitGraph: true,
    baseRef: (node) => node.parentRev,
    headRef: (node) => node.headRev,
    metadata: (node) => ({ title: node.title ?? node.branch }),
  };
}
