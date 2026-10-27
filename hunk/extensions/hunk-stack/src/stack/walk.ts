import type { StackNode, WalkRow } from "./types";

function nodeFor(row: WalkRow): StackNode {
  return {
    id: row.branch,
    branch: row.branch,
    parentBranch: row.parent,
    headRev: row.headRev !== "" ? row.headRev : row.branch,
    parentRev: row.parentRev !== "" ? row.parentRev : (row.parent ?? "HEAD~1"),
  };
}

/**
 * Walk the whole stack around one branch: ancestors (via parent links), the branch itself,
 * then descendants (via inverted child links, depth-first with siblings sorted). Nodes come
 * back base to head with the focus branch between its ancestors and descendants.
 *
 * A branch with no row, or a row with no parent (trunk), returns nothing: the map would
 * otherwise hand back every other stack as a "descendant", and that is not a reviewable
 * stack. The caller falls through to the next provider.
 */
export function walk(byBranch: ReadonlyMap<string, WalkRow>, branch: string): StackNode[] {
  const row0 = byBranch.get(branch);
  if (!row0 || !row0.parent) {
    return [];
  }

  const nodes: StackNode[] = [];
  const visited = new Set<string>();

  let cur: string | undefined = branch;
  while (cur !== undefined && byBranch.has(cur) && !visited.has(cur)) {
    visited.add(cur);
    const row: WalkRow = byBranch.get(cur)!;
    if (!row.parent) {
      break;
    }
    nodes.unshift(nodeFor(row));
    cur = row.parent;
  }

  const children = new Map<string, string[]>();
  for (const [name, row] of byBranch) {
    if (row.parent) {
      const list = children.get(row.parent) ?? [];
      list.push(name);
      children.set(row.parent, list);
    }
  }
  // Stacks are almost always linear; the rare fork flattens depth-first.
  const descend = (from: string) => {
    for (const kid of (children.get(from) ?? []).sort()) {
      const row = byBranch.get(kid);
      if (row && !visited.has(kid)) {
        visited.add(kid);
        nodes.push(nodeFor(row));
        descend(kid);
      }
    }
  };
  descend(branch);

  return nodes;
}
