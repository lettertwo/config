import type { ExtensionReviewSnapshotNote } from "hunkdiff/extension";
import { USER_AUTHOR, anchorOf, covers, firstLine, type LoadedFile, type NoteSide } from "./persist";

export interface EditorLine {
  side: NoteSide;
  line: number;
}

/** What the editor pane is writing, so its header can say and the save path knows where the text goes. */
export type EditorRequest =
  | { kind: "add"; path: string; side: NoteSide; line: number }
  | { kind: "reply"; root: ExtensionReviewSnapshotNote; path: string }
  | { kind: "edit"; note: ExtensionReviewSnapshotNote; path: string };

/** Where a new note goes: the selected line, when a hunk of the selected file spans it. */
export function addTarget(
  file: LoadedFile | null,
  current: EditorLine | null,
): { path: string; side: NoteSide; line: number } | { error: string } {
  if (!file) {
    return { error: "Select a file before writing a note" };
  }
  if (!current) {
    return { error: "Move to a line of the diff before writing a note" };
  }
  if (!covers(file, current.side, current.line)) {
    return { error: "A note needs a line inside a hunk" };
  }
  return { path: file.path, side: current.side, line: current.line };
}

/**
 * Where a reply or an edit looks for notes: the current line, or the selected hunk when Hunk has
 * no current line to report. Hunk drops the line cursor while a note card is active (after `.` or
 * `,`), and the extension API does not say which note that is.
 */
export type NoteSpot = EditorLine | { hunkIndex: number };

function onLine(note: ExtensionReviewSnapshotNote, current: NoteSpot): boolean {
  if ("hunkIndex" in current) {
    const { ownerHunkIndex, intersectingHunkIndices } = note.anchor;
    return ownerHunkIndex === current.hunkIndex || intersectingHunkIndices.includes(current.hunkIndex);
  }
  const range = current.side === "old" ? note.anchor.oldRange : note.anchor.newRange;
  if (range !== undefined) {
    return current.line >= range[0] && current.line <= range[1];
  }
  const anchor = anchorOf(note.anchor);
  return anchor?.side === current.side && anchor.line === current.line;
}

/** The thread root `id` belongs to, following `parentId` upward. */
export function rootNoteOf(notes: readonly ExtensionReviewSnapshotNote[], id: string): ExtensionReviewSnapshotNote | undefined {
  const byId = new Map(notes.map((note) => [note.id, note]));
  const seen = new Set<string>();
  let current = byId.get(id);
  while (current?.parentId !== undefined && !seen.has(current.id)) {
    seen.add(current.id);
    const parent = byId.get(current.parentId);
    if (!parent) {
      break;
    }
    current = parent;
  }
  return current;
}

/** The notes of one thread, a depth per array: the root alone, then its replies, then theirs. */
export function threadByDepth(notes: readonly ExtensionReviewSnapshotNote[], rootId: string): ExtensionReviewSnapshotNote[][] {
  const root = notes.find((note) => note.id === rootId);
  const depths: ExtensionReviewSnapshotNote[][] = [];
  const seen = new Set<string>();
  let level = root ? [root] : [];
  while (level.length > 0) {
    depths.push(level);
    level.forEach((note) => seen.add(note.id));
    const ids = new Set(level.map((note) => note.id));
    level = notes.filter((note) => note.parentId !== undefined && ids.has(note.parentId) && !seen.has(note.id));
  }
  return depths;
}

/**
 * The thread roots of `fileKey` sitting on `current`: what a reply can answer. A note counts when
 * the range it covers on the current side holds the line.
 */
export function threadsOnLine(
  notes: readonly ExtensionReviewSnapshotNote[],
  fileKey: string,
  current: NoteSpot,
): ExtensionReviewSnapshotNote[] {
  return notes.filter((note) => note.fileKey === fileKey && note.parentId === undefined && onLine(note, current));
}

/**
 * Every note of the threads on `current`, roots and replies, that satisfy `mine`: what an edit can
 * change. A reply is found through its root, since Hunk may not anchor it on the line itself.
 */
export function ownNotesOnLine(
  notes: readonly ExtensionReviewSnapshotNote[],
  fileKey: string,
  current: NoteSpot,
  mine: (note: ExtensionReviewSnapshotNote) => boolean,
): ExtensionReviewSnapshotNote[] {
  const found = new Set<string>();
  for (const root of threadsOnLine(notes, fileKey, current)) {
    for (const depth of threadByDepth(notes, root.id)) {
      depth.forEach((note) => found.add(note.id));
    }
  }
  return notes.filter((note) => found.has(note.id) && mine(note));
}

/** Choices for a dialog over `notes`, made distinct since the dialog answers with the label alone. */
export function noteChoices(notes: readonly ExtensionReviewSnapshotNote[]): { label: string; note: ExtensionReviewSnapshotNote }[] {
  return notes.map((note, index) => ({
    label: `${index + 1}. ${note.author ?? note.source}: ${firstLine(note.summary, 50)}`,
    note,
  }));
}

/** The line above the textarea. */
export function editorHeading(request: EditorRequest): string {
  if (request.kind === "add") {
    return `Note on ${request.path}:${request.line}`;
  }
  if (request.kind === "reply") {
    return `Reply to ${firstLine(request.root.summary)}`;
  }
  return `Edit ${request.path}: ${firstLine(request.note.summary)}`;
}

/** One item of a `comment apply` batch that puts a thread's note back with its text possibly changed. */
export function replantItem(
  note: ExtensionReviewSnapshotNote,
  placement: { path: string; parentId?: string },
  summary: string,
): Record<string, unknown> {
  const body: Record<string, unknown> = { summary, author: note.author ?? USER_AUTHOR };
  if (note.rationale) {
    body.rationale = note.rationale;
  }
  if (placement.parentId !== undefined) {
    return { replyTo: placement.parentId, ...body };
  }
  const anchor = anchorOf(note.anchor)!;
  return { filePath: placement.path, [anchor.side === "old" ? "oldLine" : "newLine"]: anchor.line, ...body };
}
