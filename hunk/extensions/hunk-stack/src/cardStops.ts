import type { ExtensionReviewSnapshotNote } from "hunkdiff/extension";
import type { NoteSide } from "./persist";

/**
 * A model of the stops Hunk's `stepDown`/`stepUp` and `nextNote`/`previousNote` walk, used to
 * guess which note card is active. Hunk clears the current line while a card is active and the
 * extension API does not say which card it is, so hunk-stack follows the motions it runs itself.
 * The model mirrors Hunk 0.25: a row per context line, a change block's deletions and additions
 * zipped into rows in split layout and listed deletions first in unified layout, and each visible
 * note drawn as its own card under its anchor row, roots and replies in thread order.
 */

type Note = ExtensionReviewSnapshotNote;

export interface Row {
  hunkIndex: number;
  old?: number;
  new?: number;
}

export type Stop = { kind: "line"; row: number } | { kind: "card"; noteId: string; row: number };

export type Position = { kind: "line"; side: NoteSide; line: number } | { kind: "card"; noteId: string };

const HUNK_HEADER = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/u;

/** The rows Hunk draws for `patch` in `layout`, hunk headers and collapsed gaps left out. */
export function patchRows(patch: string, layout: "split" | "unified"): Row[] {
  const rows: Row[] = [];
  let hunkIndex = -1;
  let oldLine = 0;
  let newLine = 0;
  let oldLeft = 0;
  let newLeft = 0;
  let deletions: number[] = [];
  let additions: number[] = [];
  const flush = () => {
    if (layout === "split") {
      for (let i = 0; i < Math.max(deletions.length, additions.length); i++) {
        rows.push({ hunkIndex, ...(i < deletions.length ? { old: deletions[i] } : {}), ...(i < additions.length ? { new: additions[i] } : {}) });
      }
    } else {
      deletions.forEach((old) => rows.push({ hunkIndex, old }));
      additions.forEach((line) => rows.push({ hunkIndex, new: line }));
    }
    deletions = [];
    additions = [];
  };
  for (const text of patch.split("\n")) {
    const header = oldLeft === 0 && newLeft === 0 ? HUNK_HEADER.exec(text) : null;
    if (header) {
      flush();
      hunkIndex += 1;
      oldLine = Number(header[1]);
      newLine = Number(header[3]);
      oldLeft = header[2] === undefined ? 1 : Number(header[2]);
      newLeft = header[4] === undefined ? 1 : Number(header[4]);
      continue;
    }
    if ((oldLeft === 0 && newLeft === 0) || text[0] === "\\") {
      continue;
    }
    if (text[0] === "-") {
      deletions.push(oldLine++);
      oldLeft -= 1;
    } else if (text[0] === "+") {
      additions.push(newLine++);
      newLeft -= 1;
    } else {
      flush();
      rows.push({ hunkIndex, old: oldLine++, new: newLine++ });
      oldLeft -= 1;
      newLeft -= 1;
    }
  }
  flush();
  return rows;
}

export function ownerHunk(note: Note): number {
  return note.anchor.ownerHunkIndex ?? note.anchor.intersectingHunkIndices[0] ?? 0;
}

function anchorLine(note: Note): { side: NoteSide; line: number } {
  return note.anchor.preferred ?? { side: "new", line: 1 };
}

/** Notes in Hunk's thread order: each root in store order, followed by its replies depth-first. */
export function threadOrder(notes: readonly Note[]): Note[] {
  const ids = new Set(notes.map((note) => note.id));
  const children = new Map<string, Note[]>();
  for (const note of notes) {
    if (note.parentId !== undefined && ids.has(note.parentId)) {
      children.set(note.parentId, [...(children.get(note.parentId) ?? []), note]);
    }
  }
  const ordered: Note[] = [];
  const seen = new Set<string>();
  const visit = (note: Note) => {
    if (seen.has(note.id)) {
      return;
    }
    seen.add(note.id);
    ordered.push(note);
    (children.get(note.id) ?? []).forEach(visit);
  };
  notes.filter((note) => note.parentId === undefined || !ids.has(note.parentId)).forEach(visit);
  return ordered;
}

/** The row a note's card sits under: the first row of its hunk at or past its anchor line. */
function anchorRow(rows: readonly Row[], note: Note): number | undefined {
  const hunk = ownerHunk(note);
  const owned = rows.map((row, index) => ({ row, index })).filter(({ row }) => row.hunkIndex === hunk);
  const candidates = owned.length > 0 ? owned : rows.map((row, index) => ({ row, index }));
  const { side, line } = anchorLine(note);
  let preceding: number | undefined;
  for (const { row, index } of candidates) {
    const number = row[side];
    if (number === undefined) {
      continue;
    }
    if (number >= line) {
      return index;
    }
    preceding = index;
  }
  return preceding ?? candidates[0]?.index;
}

/** Every stop of one file in order: each row, then the cards anchored under it. */
export function fileStops(rows: readonly Row[], notes: readonly Note[]): Stop[] {
  const cards = new Map<number, string[]>();
  for (const note of threadOrder(notes)) {
    const row = anchorRow(rows, note);
    if (row !== undefined) {
      cards.set(row, [...(cards.get(row) ?? []), note.id]);
    }
  }
  return rows.flatMap((_, row): Stop[] => [{ kind: "line", row }, ...(cards.get(row) ?? []).map((noteId): Stop => ({ kind: "card", noteId, row }))]);
}

function indexOf(stops: readonly Stop[], rows: readonly Row[], at: Position): number {
  if (at.kind === "card") {
    return stops.findIndex((stop) => stop.kind === "card" && stop.noteId === at.noteId);
  }
  return stops.findIndex((stop) => stop.kind === "line" && rows[stop.row]?.[at.side] === at.line);
}

/** The stop one `stepDown` (+1) or `stepUp` (-1) lands on from `at`, or null when it leaves the file. */
export function step(stops: readonly Stop[], rows: readonly Row[], at: Position, delta: 1 | -1): Stop | null {
  const index = indexOf(stops, rows, at);
  return index < 0 ? null : (stops[index + delta] ?? null);
}

/**
 * The cards next to a line: those under its row, which `stepDown` reaches, and those under the row
 * above, which `stepUp` reaches.
 */
export function cardsBeside(stops: readonly Stop[], rows: readonly Row[], at: Position & { kind: "line" }): string[] {
  const index = indexOf(stops, rows, at);
  if (index < 0) {
    return [];
  }
  const found: string[] = [];
  for (let i = index - 1; i >= 0 && stops[i]!.kind === "card"; i--) {
    found.unshift((stops[i] as Stop & { kind: "card" }).noteId);
  }
  for (let i = index + 1; i < stops.length && stops[i]!.kind === "card"; i++) {
    found.push((stops[i] as Stop & { kind: "card" }).noteId);
  }
  return found;
}

/**
 * The note `nextNote` (+1) or `previousNote` (-1) activates. From a card it steps through every
 * note in review order; from a line Hunk looks only at the selected hunk, so it lands on the first
 * note of that hunk or a later one (or the last of it or an earlier one).
 */
export function noteMove(
  notes: readonly Note[],
  fileOrder: ReadonlyMap<string, number>,
  from: { activeNoteId: string } | { fileKey: string; hunkIndex: number },
  delta: 1 | -1,
): string | null {
  const ordered = threadOrder(notes)
    .map((note, threaded) => ({ note, threaded, file: fileOrder.get(note.fileKey) }))
    .filter((item): item is typeof item & { file: number } => item.file !== undefined)
    .sort(
      (a, b) =>
        a.file - b.file ||
        ownerHunk(a.note) - ownerHunk(b.note) ||
        anchorLine(a.note).line - anchorLine(b.note).line ||
        a.threaded - b.threaded,
    );
  if ("activeNoteId" in from) {
    const at = ordered.findIndex((item) => item.note.id === from.activeNoteId);
    const next = at < 0 ? -1 : Math.min(Math.max(at + delta, 0), ordered.length - 1);
    return next < 0 || next === at ? null : ordered[next]!.note.id;
  }
  const selected = fileOrder.get(from.fileKey);
  if (selected === undefined) {
    return null;
  }
  const at = (item: (typeof ordered)[number]) => item.file > selected || (item.file === selected && ownerHunk(item.note) >= from.hunkIndex);
  if (delta > 0) {
    return ordered.find(at)?.note.id ?? null;
  }
  const before = ordered.filter((item) => item.file < selected || (item.file === selected && ownerHunk(item.note) <= from.hunkIndex));
  return before.at(-1)?.note.id ?? null;
}
