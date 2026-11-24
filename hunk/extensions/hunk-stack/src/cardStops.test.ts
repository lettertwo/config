import { describe, expect, it } from "bun:test";
import type { ExtensionReviewSnapshotNote } from "hunkdiff/extension";
import { cardsBeside, fileStops, noteMove, patchRows, step, threadOrder } from "./cardStops";

const PATCH = ["@@ -1,3 +1,4 @@", " keep", "-gone", "+added one", "+added two", " tail", "@@ -10,1 +11,1 @@", "-x", "+y"].join("\n");

function note(id: string, line: number, extra: Record<string, unknown> = {}): ExtensionReviewSnapshotNote {
  const hunk = line >= 10 ? 1 : 0;
  return {
    id,
    source: "agent",
    fileKey: "k",
    anchor: { newRange: [line, line], preferred: { side: "new", line }, ownerHunkIndex: hunk, intersectingHunkIndices: [hunk] },
    summary: id,
    editable: false,
    resolution: "active",
    ...extra,
  } as unknown as ExtensionReviewSnapshotNote;
}

const stopIds = (stops: ReturnType<typeof fileStops>) => stops.map((stop) => (stop.kind === "card" ? stop.noteId : `row${stop.row}`));

describe("patchRows", () => {
  it("lists a change block's deletions before its additions in unified layout", () => {
    expect(patchRows(PATCH, "unified")).toEqual([
      { hunkIndex: 0, old: 1, new: 1 },
      { hunkIndex: 0, old: 2 },
      { hunkIndex: 0, new: 2 },
      { hunkIndex: 0, new: 3 },
      { hunkIndex: 0, old: 3, new: 4 },
      { hunkIndex: 1, old: 10 },
      { hunkIndex: 1, new: 11 },
    ]);
  });

  it("pairs a change block's deletions with its additions in split layout", () => {
    expect(patchRows(PATCH, "split")).toEqual([
      { hunkIndex: 0, old: 1, new: 1 },
      { hunkIndex: 0, old: 2, new: 2 },
      { hunkIndex: 0, new: 3 },
      { hunkIndex: 0, old: 3, new: 4 },
      { hunkIndex: 1, old: 10, new: 11 },
    ]);
  });
});

describe("stops", () => {
  const rows = patchRows(PATCH, "unified");
  const notes = [note("a", 2), note("b", 4), note("a-reply", 2, { parentId: "a" }), note("c", 2)];

  it("orders threads root first, replies depth-first", () => {
    expect(threadOrder(notes).map((n) => n.id)).toEqual(["a", "a-reply", "b", "c"]);
  });

  it("puts each card under its anchor row, in thread order", () => {
    expect(stopIds(fileStops(rows, notes))).toEqual(["row0", "row1", "row2", "a", "a-reply", "c", "row3", "row4", "b", "row5", "row6"]);
  });

  it("steps from a line onto the cards under it and back up onto the row above's cards", () => {
    const stops = fileStops(rows, notes);
    expect(step(stops, rows, { kind: "line", side: "new", line: 2 }, 1)).toEqual({ kind: "card", noteId: "a", row: 2 });
    expect(step(stops, rows, { kind: "card", noteId: "a" }, 1)).toEqual({ kind: "card", noteId: "a-reply", row: 2 });
    expect(step(stops, rows, { kind: "card", noteId: "c" }, 1)).toEqual({ kind: "line", row: 3 });
    expect(step(stops, rows, { kind: "line", side: "new", line: 3 }, -1)).toEqual({ kind: "card", noteId: "c", row: 2 });
    expect(step(stops, rows, { kind: "card", noteId: "a" }, -1)).toEqual({ kind: "line", row: 2 });
    expect(step(stops, rows, { kind: "line", side: "new", line: 99 }, 1)).toBeNull();
  });

  it("finds the cards beside a line on either side", () => {
    const stops = fileStops(rows, notes);
    expect(cardsBeside(stops, rows, { kind: "line", side: "new", line: 2 })).toEqual(["a", "a-reply", "c"]);
    expect(cardsBeside(stops, rows, { kind: "line", side: "new", line: 3 })).toEqual(["a", "a-reply", "c"]);
    expect(cardsBeside(stops, rows, { kind: "line", side: "new", line: 1 })).toEqual([]);
  });
});

describe("noteMove", () => {
  const order = new Map([["k", 0]]);
  const notes = [note("late", 11), note("b", 4), note("a", 2), note("a-reply", 2, { parentId: "a" })];

  it("steps through every note in review order from a card", () => {
    expect(noteMove(notes, order, { activeNoteId: "a" }, 1)).toBe("a-reply");
    expect(noteMove(notes, order, { activeNoteId: "a-reply" }, 1)).toBe("b");
    expect(noteMove(notes, order, { activeNoteId: "b" }, 1)).toBe("late");
    expect(noteMove(notes, order, { activeNoteId: "late" }, 1)).toBeNull();
  });

  it("goes by the selected hunk alone from a line", () => {
    expect(noteMove(notes, order, { fileKey: "k", hunkIndex: 0 }, 1)).toBe("a");
    expect(noteMove(notes, order, { fileKey: "k", hunkIndex: 0 }, -1)).toBe("b");
    expect(noteMove(notes, order, { fileKey: "k", hunkIndex: 1 }, -1)).toBe("late");
  });
});
