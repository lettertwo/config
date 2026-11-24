import { describe, expect, it } from "bun:test";
import type { ExtensionReviewSnapshotNote } from "hunkdiff/extension";
import { addTarget, editorHeading, noteChoices, ownNotesOnLine, replantItem, rootNoteOf, threadByDepth, threadsOnLine } from "./noteEditor";
import type { LoadedFile } from "./persist";

const file: LoadedFile = {
  path: "a.ts",
  patch: "",
  hunks: [{ oldRange: [1, 3], newRange: [1, 4] }],
};

function note(id: string, extra: Record<string, unknown> = {}): ExtensionReviewSnapshotNote {
  return {
    id,
    source: "agent",
    fileKey: "k",
    anchor: { newRange: [2, 2], preferred: { side: "new", line: 2 } },
    summary: `body ${id}`,
    editable: false,
    resolution: "active",
    ...extra,
  } as unknown as ExtensionReviewSnapshotNote;
}

describe("addTarget", () => {
  it("anchors at the selected line when a hunk spans it", () => {
    expect(addTarget(file, { side: "new", line: 4 })).toEqual({ path: "a.ts", side: "new", line: 4 });
    expect(addTarget(file, { side: "old", line: 1 })).toEqual({ path: "a.ts", side: "old", line: 1 });
  });

  it("refuses a line outside every hunk, a missing line, and a missing file", () => {
    expect(addTarget(file, { side: "new", line: 5 })).toEqual({ error: "A note needs a line inside a hunk" });
    expect(addTarget(file, { side: "old", line: 4 })).toEqual({ error: "A note needs a line inside a hunk" });
    expect(addTarget(file, null)).toEqual({ error: "Move to a line of the diff before writing a note" });
    expect(addTarget(null, { side: "new", line: 1 })).toEqual({ error: "Select a file before writing a note" });
  });
});

describe("finding notes on a line", () => {
  const notes = [
    note("root"),
    note("reply", { parentId: "root", anchor: { newRange: [9, 9] } }),
    note("other", { anchor: { newRange: [3, 3], preferred: { side: "new", line: 3 } } }),
    note("elsewhere", { fileKey: "k2" }),
    note("old-side", { anchor: { oldRange: [2, 2], preferred: { side: "old", line: 2 } } }),
  ];

  it("lists the thread roots whose range holds the line on that side, in one file", () => {
    expect(threadsOnLine(notes, "k", { side: "new", line: 2 }).map((n) => n.id)).toEqual(["root"]);
    expect(threadsOnLine(notes, "k", { side: "old", line: 2 }).map((n) => n.id)).toEqual(["old-side"]);
    expect(threadsOnLine(notes, "k", { side: "new", line: 1 })).toEqual([]);
  });

  it("falls back to the threads of the selected hunk when Hunk reports no line", () => {
    const hunked = [
      note("owned", { anchor: { newRange: [2, 2], ownerHunkIndex: 1, intersectingHunkIndices: [1] } }),
      note("spans", { anchor: { newRange: [5, 9], intersectingHunkIndices: [0, 1] } }),
      note("other-hunk", { anchor: { newRange: [20, 20], ownerHunkIndex: 2, intersectingHunkIndices: [2] } }),
      note("reply", { parentId: "owned", anchor: { newRange: [2, 2], ownerHunkIndex: 1, intersectingHunkIndices: [1] } }),
    ];
    expect(threadsOnLine(hunked, "k", { hunkIndex: 1 }).map((n) => n.id)).toEqual(["owned", "spans"]);
    expect(ownNotesOnLine(hunked, "k", { hunkIndex: 1 }, () => true).map((n) => n.id)).toEqual(["owned", "spans", "reply"]);
  });

  it("reaches a reply through its root, whatever line Hunk anchors it on", () => {
    const own = ownNotesOnLine(notes, "k", { side: "new", line: 2 }, () => true);
    expect(own.map((n) => n.id)).toEqual(["root", "reply"]);
  });

  it("keeps only the notes the caller calls its own", () => {
    const own = ownNotesOnLine(notes, "k", { side: "new", line: 2 }, (n) => n.id === "reply");
    expect(own.map((n) => n.id)).toEqual(["reply"]);
  });

  it("finds a thread's root from a reply and orders a thread by depth", () => {
    const chain = [note("a"), note("b", { parentId: "a" }), note("c", { parentId: "b" }), note("d", { parentId: "a" })];
    expect(rootNoteOf(chain, "c")?.id).toBe("a");
    expect(threadByDepth(chain, "a").map((depth) => depth.map((n) => n.id))).toEqual([["a"], ["b", "d"], ["c"]]);
  });

  it("makes dialog labels distinct for notes with the same text", () => {
    const labels = noteChoices([note("x", { summary: "same" }), note("y", { summary: "same" })]).map((choice) => choice.label);
    expect(new Set(labels).size).toBe(2);
  });
});

describe("editorHeading and replantItem", () => {
  it("says where a note goes, whom a reply answers, and what an edit changes", () => {
    expect(editorHeading({ kind: "add", path: "a.ts", side: "new", line: 3 })).toBe("Note on a.ts:3");
    expect(editorHeading({ kind: "reply", root: note("r", { summary: "first\nsecond" }), path: "a.ts" })).toBe("Reply to first");
    expect(editorHeading({ kind: "edit", note: note("r"), path: "a.ts" })).toBe("Edit a.ts: body r");
  });

  it("puts a root back on the line Hunk has it on, and a reply under its new parent", () => {
    expect(replantItem(note("r", { author: "you", rationale: "why" }), { path: "a.ts" }, "new text")).toEqual({
      filePath: "a.ts",
      newLine: 2,
      summary: "new text",
      author: "you",
      rationale: "why",
    });
    expect(replantItem(note("p", { parentId: "r", author: "Pi" }), { path: "a.ts", parentId: "mcp:9" }, "kept")).toEqual({
      replyTo: "mcp:9",
      summary: "kept",
      author: "Pi",
    });
  });
});
