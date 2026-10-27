// Vendored from hunk-mark-read (1a76ae85bbd26753314d29db3a89796f1fc63580)
// upstream: src/core.ts
// Local changes are marked with "stack:". Compare with `bun run vendor:diff mark-read`.

import type { ExtensionLineHighlight, ExtensionStatusSpan } from "hunkdiff/extension";
// stack: the helpers path points at the sibling vendored sidebar.
import { formatTerminalPath, normalizeDiffPath } from "../sidebar/helpers";

/** The parts of a reviewed file its read key depends on. */
export interface KeyedFile {
  path: string;
  previousPath?: string;
  patch: string;
}

/**
 * A real hunk header: `@@ -a[,b] +c[,d] @@` (or `@@@ … @@@` for combined
 * diffs), optionally followed by function context. Only lines of exactly this
 * shape are reduced to a bare `@@`; anything else that merely starts with `@@`
 * is hashed verbatim.
 */
const HUNK_HEADER = /^(@{2,}) (?:-\d+(?:,\d+)? )+\+\d+(?:,\d+)? \1(?: .*)?$/u;
/** Git's blob-id line: `index <hex>..<hex>[ <mode>]` (comma-separated ids in combined diffs). */
const INDEX_LINE = /^index [0-9a-f]+(?:,[0-9a-f]+)*\.\.[0-9a-f]+(?: [0-7]{6})?$/u;
/** Rename/copy similarity score, which depends on rename detection rather than content. */
const SIMILARITY_LINE = /^(?:dis)?similarity index \d+%$/u;
/** Hunk's placeholder for an untracked binary: names the file, says nothing about its content. */
const SKIPPED_BINARY = /^Binary file skipped: /u;

/**
 * Reduce a patch to what the reviewer saw, by dropping only known noise.
 *
 * Everything is hashed except, before the first hunk, git's header lines
 * (`diff --git`, `index`, `similarity index`, `---`/`+++`) and, anywhere,
 * the numbers and function context of real hunk headers. Those shift for
 * reasons outside the reviewed lines: a rebase adding lines above, `git add`
 * adding an `index` line, local git vs GitHub formatting. Every other line
 * counts, including bare empty lines and unexpected prefixes in hand-edited
 * patches, so no change can hide from the key. Git writes all header lines
 * before the first hunk, so after it nothing but strict hunk headers is
 * reduced, and a mangled body line that looks like a header still counts.
 *
 * A diff without hunks keeps its `index` line, because the blob ids are the
 * only sign a binary changed. `trackable` is false when nothing in the patch
 * could reveal a change (files too large to diff, skipped untracked
 * binaries), so such files are never marked.
 */
export function normalizePatch(patch: string): { text: string; trackable: boolean } {
  const kept: string[] = [];
  const indexLines: string[] = [];
  let seenHunk = false;

  // Hunk trims each file's patch and appends one newline; ignore trailing newlines only.
  for (const line of patch.replace(/\n+$/u, "").split("\n")) {
    if (HUNK_HEADER.test(line)) {
      kept.push("@@");
      seenHunk = true;
      continue;
    }
    if (!seenHunk) {
      if (INDEX_LINE.test(line)) {
        indexLines.push(line);
        continue;
      }
      if (
        line === "" ||
        line.startsWith("diff --git ") ||
        line.startsWith("diff --cc ") ||
        line.startsWith("diff --combined ") ||
        line.startsWith("--- ") ||
        line.startsWith("+++ ") ||
        SIMILARITY_LINE.test(line) ||
        SKIPPED_BINARY.test(line)
      ) {
        continue;
      }
    }
    kept.push(line);
  }

  if (!seenHunk) {
    kept.push(...indexLines);
  }
  return { text: kept.join("\n"), trackable: kept.length > 0 };
}

/**
 * Identify one file's reviewed change: its paths plus a digest of the
 * normalized patch.
 *
 * Range, worktree, and branch never enter the key, so the same change stays
 * read across `HEAD~2..HEAD` and `HEAD~3..HEAD`, while any change to a
 * reviewed line yields a new key and therefore reads as unread. Returns `null`
 * for a file whose patch cannot reveal changes.
 */
export function readKey(file: KeyedFile): string | null {
  const { text, trackable } = normalizePatch(file.patch);
  if (!trackable) {
    return null;
  }
  const digest = new Bun.CryptoHasher("sha256").update(text).digest("hex");
  return `${file.path}\0${file.previousPath ?? ""}\0${digest}`;
}

/** The logical path a sidebar directory row uses for a file, as `buildTreeSidebarEntries` derives it. */
function sidebarPath(path: string) {
  return formatTerminalPath(normalizeDiffPath(path) ?? path);
}

/** Report whether `path` sits anywhere below the sidebar directory `directoryPath`. */
export function isUnderDirectory(path: string, directoryPath: string): boolean {
  const prefix = directoryPath.endsWith("/") ? directoryPath : `${directoryPath}/`;
  return sidebarPath(path).startsWith(prefix);
}

/**
 * Find the next unread file after `currentId` in review order, wrapping around.
 *
 * Returns `null` when every file is read. The current file itself is the last
 * candidate, so a single unread file that is already selected is found again.
 */
export function nextUnread<File extends { id: string }>(
  files: readonly File[],
  currentId: string | null,
  isRead: (file: File) => boolean,
): File | null {
  if (files.length === 0) {
    return null;
  }

  const currentIndex = files.findIndex((file) => file.id === currentId);
  for (let offset = 1; offset <= files.length; offset += 1) {
    const candidate = files[(currentIndex + offset + files.length) % files.length]!;
    if (!isRead(candidate)) {
      return candidate;
    }
  }
  return null;
}

/** A two-way hunk header with its starting line numbers; combined diffs are not dimmed. */
const NUMBERED_HUNK_HEADER = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(?: .*)?$/u;

/**
 * Cover every rendered line of a patch with a `"dim"` mark.
 *
 * Removed lines are addressed on the old side, added and context lines on the
 * new side, matching how Hunk numbers patch rows. A bare empty line counts as
 * an empty context line, as `git apply` reads it. Unrecognized lines are
 * skipped without ending the hunk; only the next hunk header ends it. Empty
 * lines carry no text to paint and are skipped.
 */
export function dimHighlights(patch: string): ExtensionLineHighlight[] {
  const highlights: ExtensionLineHighlight[] = [];
  let oldLine = 0;
  let newLine = 0;
  let inHunk = false;

  for (const rawLine of patch.replace(/\n+$/u, "").split("\n")) {
    const header = NUMBERED_HUNK_HEADER.exec(rawLine);
    if (header) {
      oldLine = Number(header[1]);
      newLine = Number(header[2]);
      inHunk = true;
      continue;
    }
    if (!inHunk) {
      continue;
    }

    const marker = rawLine[0];
    const text = rawLine.slice(1).replace(/\r$/u, "");
    if (marker === "-") {
      if (text.length > 0) {
        highlights.push({ side: "old", line: oldLine, range: [0, text.length], tone: "dim" });
      }
      oldLine += 1;
    } else if (marker === "+") {
      if (text.length > 0) {
        highlights.push({ side: "new", line: newLine, range: [0, text.length], tone: "dim" });
      }
      newLine += 1;
    } else if (marker === " " || rawLine === "") {
      if (text.length > 0) {
        highlights.push({ side: "new", line: newLine, range: [0, text.length], tone: "dim" });
      }
      oldLine += 1;
      newLine += 1;
    }
  }

  return highlights;
}

/** Build the status-line text for the review's read progress. */
export function progressSpans(read: number, total: number): ExtensionStatusSpan[] {
  if (total > 0 && read >= total) {
    return [{ text: `✓ all ${total} read`, tone: "added" }];
  }
  return [{ text: `${read}/${total} read`, tone: "muted" }];
}

/**
 * Sidebar text about read files that `H` removed from the review.
 *
 * `visible` is how many files the sidebar still lists; with none left the text
 * replaces the empty list. `keys` are the toggle command's current bindings, so
 * a remapped or unbound command never advertises a dead key.
 */
export function hiddenNotice(hidden: number, visible: number, keys: readonly string[]): string[] {
  if (hidden <= 0) {
    return [];
  }
  const files = hidden === 1 ? "file" : "files";
  const lines = [
    visible === 0 && hidden > 1
      ? `All ${hidden} read files hidden`
      : `${hidden} read ${files} hidden`,
  ];
  if (keys[0]) {
    lines.push(`${keys[0]} to show`);
  }
  return lines;
}
