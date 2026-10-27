import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { commonDir, currentBranch } from "./git";
import type { NodeMetadata, StackGraph, WalkRow } from "./types";
import type { Sys } from "./sys";
import { walk } from "./walk";

/** Parse sqlite3's `|`-separated rows of branch, parent, head revision, parent revision. */
export function parseMetadata(stdout: string): Map<string, WalkRow> {
  const byBranch = new Map<string, WalkRow>();
  for (const line of stdout.split("\n")) {
    if (line === "") {
      continue;
    }
    const parts = line.split("|");
    if (parts.length >= 2) {
      byBranch.set(parts[0]!, {
        branch: parts[0]!,
        parent: parts[1]!,
        headRev: parts[2] ?? "",
        parentRev: parts[3] ?? "",
      });
    }
  }
  return byBranch;
}

interface PrInfo {
  number?: number;
  title?: string;
  body?: string;
}

/** Cached PR info that `gt` writes next to its metadata; optional, and a bad file just means no PRs. */
function readPrInfo(path: string): Map<string, PrInfo> {
  const map = new Map<string, PrInfo>();
  if (!existsSync(path)) {
    return map;
  }
  try {
    const data = JSON.parse(readFileSync(path, "utf8"));
    for (const pr of data?.prInfos ?? []) {
      if (pr?.headRefName) {
        map.set(pr.headRefName, pr);
      }
    }
  } catch {
    // gt rewrites this file in place, so a torn read is a parse error; PR numbers are cosmetic.
  }
  return map;
}

/** Branch metadata read straight from the sqlite db, never by shelling out to `gt`. */
export function createGraphiteGraph(sys: Sys, common?: string | null, branch?: string): StackGraph {
  const dir = common ?? commonDir(sys) ?? join(sys.cwd, ".git");
  const focus = branch ?? currentBranch(sys);
  const r = sys.sqlite(
    join(dir, ".graphite_metadata.db"),
    "SELECT branch_name,parent_branch_name,branch_revision,parent_branch_revision FROM branch_metadata;",
  );
  const nodes = walk(parseMetadata(r.stdout), focus);
  const prs = readPrInfo(join(dir, ".graphite_pr_info"));

  return {
    kind: "graphite",
    nodes,
    isCommitGraph: false,
    baseRef: (node) => node.parentRev,
    // The db's branch_revision is a snapshot from gt-time and goes stale on a plain git
    // commit, so resolve the live ref and the head always reflects the branch's tip.
    headRef: (node) => `refs/heads/${node.branch}`,
    metadata(node): NodeMetadata {
      const pr = prs.get(node.branch) ?? {};
      return { prNumber: pr.number, title: pr.title, body: pr.body };
    },
  };
}
