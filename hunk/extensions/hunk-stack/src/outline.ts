import type { NavRow } from "./focus";
import { changeTypeOf, type ListedFile } from "./listing";
import type { Changeset } from "./stack/stack";
import type { ChangesetEntry, SidebarEntry, SidebarFileSource } from "./vendored/sidebar/files";
import { fitText } from "./vendored/sidebar/helpers";

export type StackOrder = "head-first" | "base-first";

export interface OutlineModel {
  changesets: readonly Changeset[];
  loadedId: string | null;
  pendingId: string | null;
  order: StackOrder;
  /** Read progress of the loaded changeset, from the read-marks store. */
  read: { read: number; total: number } | null;
  /** Files of changesets that are not loaded, as git listed them. */
  listings: ReadonlyMap<string, readonly ListedFile[]>;
  /** Headers toggled by hand; the loaded changeset is otherwise the only one expanded. */
  expansion: ReadonlyMap<string, boolean>;
}

export function isExpanded(
  expansion: ReadonlyMap<string, boolean>,
  loadedId: string | null,
  changesetId: string,
): boolean {
  return expansion.get(changesetId) ?? changesetId === loadedId;
}

/** Turns listed files into rows in the same projection (tree or flat) as the loaded changeset's. */
export type ProjectListed = (files: readonly SidebarFileSource[]) => SidebarEntry[];

/** The abbreviated sha shown on commit-zoom headers. */
const SHA_WIDTH = 8;

function headerEntry(changeset: Changeset, index: number, total: number, model: OutlineModel): ChangesetEntry {
  const loaded = changeset.id === model.loadedId;
  return {
    kind: "changeset",
    id: `changeset:${changeset.id}`,
    changesetId: changeset.id,
    index,
    total,
    title: changeset.title,
    // A commit header has no branch name of its own to show, only the owning branch's.
    sha: changeset.branch !== undefined ? (changeset.headSha ?? changeset.id).slice(0, SHA_WIDTH) : undefined,
    branch: changeset.branch,
    prNumber: changeset.prNumber,
    loaded,
    pending: changeset.id === model.pendingId && !loaded,
    expanded: isExpanded(model.expansion, model.loadedId, changeset.id),
    read: loaded ? model.read : null,
  };
}

/**
 * Rows for a changeset that is not loaded. Ids are prefixed with the changeset because
 * the projection numbers its rows from zero for every list it builds.
 */
function listedEntries(changesetId: string, files: readonly ListedFile[], project: ProjectListed): SidebarEntry[] {
  const sources = files.map<SidebarFileSource>((file) => ({
    id: `listed:${file.path}`,
    path: file.path,
    previousPath: file.previousPath,
    stats: { additions: 0, deletions: 0 },
    changeType: changeTypeOf(file.status),
    isUntracked: file.status === "?",
  }));
  return project(sources).map((entry) => ({ ...entry, id: `${changesetId}|${entry.id}`, changesetId }));
}

/**
 * Interleave changeset headers with their file rows. The loaded changeset's rows come from
 * the review (stats, read marks), and the others from git's name-status list (a letter and a
 * path), since hunk holds one diff at a time. `order` flips the display only: `[i/n]` always
 * counts base to head, the order next/previous walk.
 *
 * When no listed changeset is loaded (a clean worktree, or a range launched by hand) the
 * files lead the list instead, so they never vanish from the pane.
 */
export function outlineEntries(
  model: OutlineModel,
  fileEntries: readonly SidebarEntry[],
  project: ProjectListed,
): SidebarEntry[] {
  const { changesets } = model;
  const total = changesets.length;
  const loadedListed = changesets.some((cs) => cs.id === model.loadedId);
  const entries: SidebarEntry[] = loadedListed ? [] : [...fileEntries];

  const indices = changesets.map((_, i) => i);
  if (model.order === "head-first") {
    indices.reverse();
  }
  for (const i of indices) {
    const changeset = changesets[i]!;
    const header = headerEntry(changeset, i + 1, total, model);
    entries.push(header);
    if (!header.expanded) {
      continue;
    }
    if (header.loaded) {
      entries.push(...fileEntries);
    } else {
      const listed = model.listings.get(changeset.id);
      if (listed) {
        entries.push(...listedEntries(changeset.id, listed, project));
      }
    }
  }
  return entries;
}

/** The rows the keyboard cursor can rest on: headers and files, not directories or groups. */
export function navRows(entries: readonly SidebarEntry[], loadedId: string | null): NavRow[] {
  const rows: NavRow[] = [];
  for (const entry of entries) {
    if (entry.kind === "changeset") {
      rows.push({ entryId: entry.id, changesetId: entry.changesetId, path: null, fileId: null });
    } else if (entry.kind === "file") {
      rows.push({
        entryId: entry.id,
        changesetId: entry.changesetId ?? loadedId,
        path: entry.path,
        fileId: entry.changesetId ? null : entry.id,
      });
    }
  }
  return rows;
}

export type HeaderTone = "marker" | "counter" | "title" | "branch" | "read" | "readDone";

export interface HeaderSegment {
  text: string;
  tone: HeaderTone;
}

/**
 * The header's colored runs, fitted to `width` cells. The read count sits on the right and
 * keeps its place; the left side gives up its tail with an ellipsis, since the title is the
 * part a reviewer can recover from context.
 */
export function headerSegments(entry: ChangesetEntry, width: number): { left: HeaderSegment[]; right: HeaderSegment[] } {
  const left: HeaderSegment[] = [
    { text: entry.loaded ? "● " : entry.pending ? "○ " : "  ", tone: "marker" },
    { text: entry.expanded ? "⌄ " : "› ", tone: "counter" },
    { text: `[${entry.index}/${entry.total}] `, tone: "counter" },
  ];
  if (entry.sha) {
    left.push({ text: `${entry.sha} `, tone: "counter" });
  }
  left.push({ text: entry.title, tone: "title" });
  if (entry.branch) {
    left.push({ text: `  ${entry.branch}`, tone: "branch" });
  }
  if (entry.prNumber) {
    left.push({ text: `  #${entry.prNumber}`, tone: "counter" });
  }

  const right: HeaderSegment[] = [];
  if (entry.read && entry.read.total > 0) {
    const done = entry.read.read === entry.read.total;
    right.push({ text: `${entry.read.read}/${entry.read.total}`, tone: done ? "readDone" : "read" });
  }
  const rightWidth = right.reduce((sum, seg) => sum + Bun.stringWidth(seg.text), 0);
  // One cell separates the two sides when there is a right side.
  let budget = Math.max(0, width - (rightWidth > 0 ? rightWidth + 1 : 0));

  const fitted: HeaderSegment[] = [];
  for (const seg of left) {
    if (budget <= 0) {
      break;
    }
    const w = Bun.stringWidth(seg.text);
    if (w <= budget) {
      fitted.push(seg);
      budget -= w;
    } else {
      fitted.push({ text: fitText(seg.text, budget, "…"), tone: seg.tone });
      budget = 0;
    }
  }
  return { left: fitted, right };
}
