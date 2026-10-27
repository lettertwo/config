import { currentBranch, hasUncommittedChanges, logFirstParent, revParseMany } from "./git";
import { createGraph } from "./graph";
import type { StackGraph, StackNode } from "./types";
import type { Sys } from "./sys";

export type Zoom = "combined" | "branch" | "commit";

/**
 * One reviewable range. `base` and `head` are what the graph named; `baseSha` and `headSha`
 * are what they resolved to, and are what a reload should pass (a ref can start with `-`,
 * a sha cannot). The uncommitted changeset has head `WORKTREE` and no head sha.
 */
export interface Changeset {
  id: string;
  title: string;
  base: string;
  head: string;
  baseSha?: string;
  headSha?: string;
  prNumber?: number;
  /** Commit-zoom changesets only: the branch that owns the commit, for the outline's header label. */
  branch?: string;
  /** The changeset the review should open on. */
  current?: boolean;
  uncommitted?: boolean;
}

export interface StackSource {
  cwd: string;
  graph: StackGraph;
  zooms: Zoom[];
  defaultZoom: Zoom;
  /** The outline lists head first by default, while next/previous walk base to head. */
  defaultStackOrder: "head-first";
  /** Changesets in base to head order, with exactly one marked `current`. */
  load(zoom: Zoom): Changeset[];
}

export const UNCOMMITTED_ID = "uncommitted";
export const COMBINED_ID = "combined";
const RESTACK_SUFFIX = " (needs restack)";

type Spec = Omit<Changeset, "baseSha" | "headSha">;

/**
 * `focusBranch` defaults to the checked-out branch. The uncommitted layer only rides along
 * when the focus branch is the checked-out one, since a branch you aren't on has no worktree
 * state of its own to show.
 */
export function createStackSource(sys: Sys, opts: { focusBranch?: string } = {}): StackSource {
  const checkedOut = currentBranch(sys);
  const focusBranch = opts.focusBranch ?? checkedOut;
  const includeUncommitted = focusBranch === checkedOut;
  const graph = createGraph(sys, focusBranch);
  const isCommitGraph = graph.isCommitGraph;

  const zooms: Zoom[] = isCommitGraph ? ["combined", "commit"] : ["combined", "branch", "commit"];
  const defaultZoom: Zoom = isCommitGraph ? "commit" : "branch";

  function branchSpecs(nodes: StackNode[]): Spec[] {
    return nodes.map((node) => {
      const meta = graph.metadata(node);
      return {
        id: node.id,
        title: meta.title ?? node.branch ?? node.id,
        base: graph.baseRef(node),
        head: graph.headRef(node),
        prNumber: meta.prNumber,
        current: node.id === focusBranch || undefined,
      };
    });
  }

  /**
   * One spec spanning the whole stack regardless of focus. The id is a literal rather than a
   * sha so a position lookup by id can't match a real commit, and the restack lookup (keyed by
   * node id) never hits it.
   */
  function combinedSpecs(nodes: StackNode[]): Spec[] {
    if (nodes.length === 0) {
      return [];
    }
    const noun = isCommitGraph ? "commits" : "branches";
    return [
      {
        id: COMBINED_ID,
        title: `Combined (${nodes.length} ${noun})`,
        base: graph.baseRef(nodes[0]!),
        head: graph.headRef(nodes[nodes.length - 1]!),
      },
    ];
  }

  /**
   * One spec per first-parent commit across every node, oldest to newest within a branch and
   * in node order across the stack. A commit's base chains to the next-older commit's sha and
   * the oldest commit's base to the node's own base, so the specs tile each node's range. A
   * branch with no commits contributes nothing.
   */
  function commitSpecs(nodes: StackNode[]): Spec[] {
    const specs: Spec[] = [];
    for (const node of nodes) {
      const base = graph.baseRef(node);
      const log = logFirstParent(sys, base, graph.headRef(node));
      const commits = Array.isArray(log) ? log : [];
      for (let i = commits.length - 1; i >= 0; i--) {
        const commit = commits[i]!;
        specs.push({
          id: commit.sha,
          title: commit.subject,
          base: i < commits.length - 1 ? commits[i + 1]!.sha : base,
          head: commit.sha,
          branch: node.branch,
          current: (node.id === focusBranch && i === 0) || undefined,
        });
      }
    }
    return specs;
  }

  /** Descendants whose recorded parent revision no longer matches the parent branch's tip are pending a restack. */
  function staleIds(nodes: StackNode[], curIdx: number | null): Set<string> {
    const stale = new Set<string>();
    if (curIdx === null) {
      return stale;
    }
    const descendants = nodes.slice(curIdx + 1);
    const shas = revParseMany(
      sys,
      descendants.flatMap((n) => (n.parentBranch ? [`refs/heads/${n.parentBranch}`] : [])),
    );
    for (const node of descendants) {
      const sha = node.parentBranch ? shas.get(`refs/heads/${node.parentBranch}`) : undefined;
      if (sha && node.parentRev !== "" && sha !== node.parentRev) {
        stale.add(node.id);
      }
    }
    return stale;
  }

  function load(zoom: Zoom): Changeset[] {
    const nodes = graph.nodes;
    // The focus branch's position among the nodes: uncommitted changes sit on top of ITS
    // commits (not at the head of the whole stack), and the review opens here.
    let curIdx: number | null = null;
    nodes.forEach((node, i) => {
      if (node.id === focusBranch) {
        curIdx = i;
      }
    });

    let specs: Spec[];
    if (zoom === "combined") {
      specs = combinedSpecs(nodes);
    } else if (zoom === "commit" && !isCommitGraph) {
      specs = commitSpecs(nodes);
    } else {
      specs = branchSpecs(nodes);
    }

    // Stale keys are node ids, a commit spec's id is a sha, and the combined spec's is a
    // literal. With the commit or combined zoom no header gets the mark, since it describes
    // a branch and those headers don't stand for one.
    const stale = staleIds(nodes, curIdx);
    const all: Changeset[] = specs.map((spec) =>
      stale.has(spec.id) ? { ...spec, title: spec.title + RESTACK_SUFFIX } : { ...spec },
    );

    // With the commit zoom `all` has more entries than `nodes`, so curIdx doesn't address it;
    // each commit spec carries its own `current` flag instead.
    let focusIdx: number | null = curIdx;
    if (zoom === "combined") {
      focusIdx = 0;
    } else if (zoom === "commit") {
      focusIdx = null;
      all.forEach((cs, i) => {
        if (cs.current) {
          focusIdx = i;
        }
      });
    }

    if (includeUncommitted && hasUncommittedChanges(sys)) {
      const at = focusIdx === null ? all.length : focusIdx + 1;
      for (const cs of all) {
        delete cs.current;
      }
      all.splice(at, 0, {
        id: UNCOMMITTED_ID,
        title: "Uncommitted Changes",
        base: "HEAD",
        head: "WORKTREE",
        uncommitted: true,
        current: true,
      });
    } else {
      const target = focusIdx !== null && all[focusIdx] ? focusIdx : all.length - 1;
      all.forEach((cs, i) => {
        if (i === target) {
          cs.current = true;
        } else {
          delete cs.current;
        }
      });
    }

    const shas = revParseMany(
      sys,
      all.flatMap((cs) => [cs.base, cs.head]),
    );
    return all.map((cs) => ({ ...cs, baseSha: shas.get(cs.base), headSha: shas.get(cs.head) }));
  }

  return { cwd: sys.cwd, graph, zooms, defaultZoom, defaultStackOrder: "head-first", load };
}
