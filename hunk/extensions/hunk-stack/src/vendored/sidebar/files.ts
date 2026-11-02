// Vendored from hunk v0.23.0 (7991d3034af1d2116e9c77db31265e409a73bd9f)
// upstream: packages/hunk/src/ui/lib/files.ts
// Local changes are marked with "mark-read:" or "stack:". Compare with `bun run vendor:diff hunk`.

import { basename, dirname } from "node:path/posix";
// mark-read: import paths point at local copies; @pierre/diffs is not a host
// module for extensions, so its FileDiffMetadata["type"] becomes the public
// change-type union (same five values).
import type { ExtensionVcsFileChangeType } from "hunkdiff/extension";
import { formatTerminalPath, normalizeDiffPath, readMetadataChangeType } from "./helpers";

type FileDiffMetadata = { type: ExtensionVcsFileChangeType };

export interface FileListEntry {
  kind: "file";
  id: string;
  name: string;
  depth: number;
  agentCommentsText: string | null;
  additionsText: string | null;
  deletionsText: string | null;
  changeType: FileDiffMetadata["type"];
  isUntracked: boolean;
  // stack: the review path, and the changeset a row belongs to when it is not the loaded one
  // (such a row has no patch, so it carries no stats and no read mark).
  path: string;
  changesetId?: string;
  // stack: in the flat file view, the directory shown after the name (absent at the root).
  dirname?: string;
}

/**
 * The slice of one reviewed file the sidebar needs to build its entries.
 *
 * Structural on purpose: Hunk's internal `DiffFile` satisfies it through
 * `metadata.type`, and the public `ExtensionDiffFile` view satisfies it through
 * its first-class `changeType`, so the built-in sidebar — which is itself a
 * bundled extension consuming the public props — and internal callers share
 * this one entry builder.
 */
export interface SidebarFileSource {
  id: string;
  path: string;
  previousPath?: string;
  stats: { additions: number; deletions: number };
  statsTruncated?: boolean;
  isUntracked?: boolean;
  agent?: { annotations: readonly unknown[] } | null;
  // stack: notes on a file of a changeset that is not loaded, which has no `agent` of its own.
  noteCount?: number;
  changeType?: FileDiffMetadata["type"];
  metadata?: unknown;
}

export interface FileGroupEntry {
  kind: "group";
  id: string;
  label: string;
}

export interface FileDirectoryEntry {
  kind: "directory";
  id: string;
  path: string;
  label: string;
  depth: number;
  descendantFileCount: number;
  // stack: set on rows of a changeset that is not loaded.
  changesetId?: string;
}

// stack: one stack changeset header. The loaded changeset's file rows follow it.
export interface ChangesetEntry {
  kind: "changeset";
  id: string;
  changesetId: string;
  /** Position in base to head order, 1-based. */
  index: number;
  total: number;
  title: string;
  /** Commit-unit headers only: the abbreviated sha and the branch that owns the commit. */
  sha?: string;
  branch?: string;
  prNumber?: number;
  /** The review is showing this changeset. */
  loaded: boolean;
  /** A reload to this changeset is running or queued. */
  pending: boolean;
  /** Its file rows are showing. */
  expanded: boolean;
  read: { read: number; total: number } | null;
}

export type FileSidebarMode = "flat" | "tree";
export type SidebarEntry = FileListEntry | FileGroupEntry | FileDirectoryEntry | ChangesetEntry;

export const TREE_FILE_SIDEBAR_MIN_CONTENT_WIDTH = 32;

/** Choose the compact or hierarchical sidebar projection for an available content width. */
export function resolveFileSidebarMode(contentWidth: number): FileSidebarMode {
  return contentWidth >= TREE_FILE_SIDEBAR_MIN_CONTENT_WIDTH ? "tree" : "flat";
}

/** Build the filename-first label shown inside one sidebar row. */
function sidebarFileName(file: SidebarFileSource) {
  const path = formatTerminalPath(normalizeDiffPath(file.path) ?? file.path);
  const previousPath = file.previousPath
    ? formatTerminalPath(normalizeDiffPath(file.previousPath) ?? file.previousPath)
    : undefined;

  if (!previousPath || previousPath === path) {
    return basename(path);
  }

  const previousName = basename(previousPath);
  const nextName = basename(path);
  return previousName === nextName ? nextName : `${previousName} -> ${nextName}`;
}

/** Hide zero-value file stats so the sidebar only shows real line deltas. */
function formatSidebarStat(prefix: "+" | "-", value: number, truncated = false) {
  return value > 0 ? `${prefix}${value}${truncated ? "+" : ""}` : null;
}

/** Build the visible stats badges for one sidebar row.
 * Keep the agent-note badge first so it reads as review context before line churn.
 */
export function sidebarEntryStats(
  entry: Pick<FileListEntry, "agentCommentsText" | "additionsText" | "deletionsText">,
) {
  const stats: Array<{ kind: "agent-comment" | "addition" | "deletion"; text: string }> = [];

  if (entry.agentCommentsText) {
    stats.push({ kind: "agent-comment", text: entry.agentCommentsText });
  }

  if (entry.additionsText) {
    stats.push({ kind: "addition", text: entry.additionsText });
  }

  if (entry.deletionsText) {
    stats.push({ kind: "deletion", text: entry.deletionsText });
  }

  return stats;
}

/** Measure the rendered sidebar stats width, including the space between badges. */
export function sidebarEntryStatsWidth(
  entry: Pick<FileListEntry, "agentCommentsText" | "additionsText" | "deletionsText">,
) {
  return sidebarEntryStats(entry).reduce(
    (width, stat, index) => width + stat.text.length + (index > 0 ? 1 : 0),
    0,
  );
}

// mark-read: removed mergeFileAnnotationsByFileId (needs hunk's internal DiffFile; unused by the sidebar).

/** Build the shared file-row metadata used by both sidebar projections. */
function buildSidebarFileEntry(file: SidebarFileSource, depth: number): FileListEntry {
  const agentCommentCount = file.noteCount ?? file.agent?.annotations.length ?? 0;

  return {
    kind: "file",
    id: file.id,
    name: sidebarFileName(file),
    depth,
    agentCommentsText: agentCommentCount > 0 ? `*${agentCommentCount}` : null,
    additionsText: formatSidebarStat("+", file.stats.additions, file.statsTruncated),
    deletionsText: formatSidebarStat("-", file.stats.deletions),
    changeType: file.changeType ?? readMetadataChangeType(file.metadata) ?? "change",
    isUntracked: file.isUntracked ?? false,
    path: file.path,
  };
}

/** Build compact grouped sidebar entries while preserving the review stream order. */
export function buildFlatSidebarEntries(files: readonly SidebarFileSource[]): SidebarEntry[] {
  const entries: SidebarEntry[] = [];
  let activeGroup: string | undefined;

  files.forEach((file, index) => {
    const path = formatTerminalPath(normalizeDiffPath(file.path) ?? file.path);
    const group = dirname(path);

    if (group !== activeGroup) {
      activeGroup = group;
      entries.push({
        kind: "group",
        id: `group:${group}:${index}`,
        label: group === "." ? "./" : `${group}/`,
      });
    }

    entries.push(buildSidebarFileEntry(file, 0));
  });

  return entries;
}

// stack: the flat file view. No group rows; each file carries its own directory, so a
// truncated row still shows the name first.
export function buildDirnameSidebarEntries(files: readonly SidebarFileSource[]): SidebarEntry[] {
  return files.map((file) => {
    const group = dirname(formatTerminalPath(normalizeDiffPath(file.path) ?? file.path));
    const entry = buildSidebarFileEntry(file, 0);
    return group === "." ? entry : { ...entry, dirname: group };
  });
}

/** Split a POSIX review path while retaining its absolute or UNC-style root marker. */
function sidebarDirectorySegments(parent: string) {
  if (parent === ".") {
    return [];
  }

  const root = parent.match(/^\/+/u)?.[0];
  const segments = parent.split("/").filter(Boolean);
  return root ? [root, ...segments] : segments;
}

/** Format one directory segment without doubling a retained root marker. */
function sidebarDirectoryLabel(segment: string) {
  return segment.startsWith("/") ? segment : `${segment}/`;
}

/** Join directory segments into the stable path represented by one row. */
function sidebarDirectoryPath(segments: readonly string[]) {
  const [root, ...rest] = segments;
  return root?.startsWith("/") ? `${root}${rest.join("/")}` : segments.join("/");
}

/** Return the number of leading directory segments shared by two active branches. */
function sharedDirectoryDepth(previous: readonly string[], next: readonly string[]) {
  const maxDepth = Math.min(previous.length, next.length);
  let depth = 0;

  while (depth < maxDepth && previous[depth] === next[depth]) {
    depth += 1;
  }

  return depth;
}

/** Return the stable logical paths for every directory containing one review path. */
export function sidebarDirectoryPaths(path: string): string[] {
  const terminalPath = formatTerminalPath(normalizeDiffPath(path) ?? path);
  const directories = sidebarDirectorySegments(dirname(terminalPath));
  return directories.map((_, depth) => sidebarDirectoryPath(directories.slice(0, depth + 1)));
}

/** Build an expanded hierarchy without regrouping files away from review order. */
export function buildTreeSidebarEntries(files: readonly SidebarFileSource[]): SidebarEntry[] {
  const entries: SidebarEntry[] = [];
  let activeDirectories: string[] = [];
  let activeDirectoryEntries: FileDirectoryEntry[] = [];

  files.forEach((file, fileIndex) => {
    const path = formatTerminalPath(normalizeDiffPath(file.path) ?? file.path);
    const parent = dirname(path);
    const directories = sidebarDirectorySegments(parent);
    const sharedDepth = sharedDirectoryDepth(activeDirectories, directories);
    activeDirectoryEntries = activeDirectoryEntries.slice(0, sharedDepth);

    for (let depth = sharedDepth; depth < directories.length; depth += 1) {
      const segment = directories[depth]!;
      const directoryPath = sidebarDirectoryPath(directories.slice(0, depth + 1));
      const directoryEntry: FileDirectoryEntry = {
        kind: "directory",
        id: `directory:${fileIndex}:${depth}:${directoryPath}`,
        path: directoryPath,
        label: sidebarDirectoryLabel(segment),
        depth,
        descendantFileCount: 0,
      };
      entries.push(directoryEntry);
      activeDirectoryEntries.push(directoryEntry);
    }

    entries.push(buildSidebarFileEntry(file, directories.length));
    for (const directoryEntry of activeDirectoryEntries) {
      directoryEntry.descendantFileCount += 1;
    }
    activeDirectories = directories;
  });

  return entries;
}

/** Expand the named ancestors while preserving unrelated collapsed directory paths. */
export function expandCollapsedDirectoryPaths(
  current: ReadonlySet<string>,
  paths: readonly string[],
): ReadonlySet<string> {
  const expandedPaths = paths.filter((path) => current.has(path));
  if (expandedPaths.length === 0) {
    return current;
  }

  const next = new Set(current);
  for (const path of expandedPaths) {
    next.delete(path);
  }
  return next;
}

/** Toggle one directory path without mutating the current collapsed-path set. */
export function toggleCollapsedDirectoryPath(
  current: ReadonlySet<string>,
  path: string,
): ReadonlySet<string> {
  const next = new Set(current);
  if (next.has(path)) {
    next.delete(path);
  } else {
    next.add(path);
  }
  return next;
}

/** Hide descendants of collapsed directory rows without changing the remaining review order. */
export function collapseTreeSidebarEntries(
  entries: readonly SidebarEntry[],
  collapsedDirectoryPaths: ReadonlySet<string>,
): SidebarEntry[] {
  if (collapsedDirectoryPaths.size === 0) {
    return [...entries];
  }

  const visible: SidebarEntry[] = [];
  let collapsedDepth: number | null = null;

  for (const entry of entries) {
    // stack: a changeset header ends any collapsed run, as a group header does.
    if (entry.kind === "group" || entry.kind === "changeset") {
      collapsedDepth = null;
      visible.push(entry);
      continue;
    }

    if (collapsedDepth !== null) {
      if (entry.depth > collapsedDepth) {
        continue;
      }
      collapsedDepth = null;
    }

    visible.push(entry);
    if (entry.kind === "directory" && collapsedDirectoryPaths.has(entry.path)) {
      collapsedDepth = entry.depth;
    }
  }

  return visible;
}

// mark-read: removed fileLabel/fileLabelParts (needs hunk's internal DiffFile; unused by the sidebar).
