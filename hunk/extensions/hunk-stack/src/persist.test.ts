import { afterEach, describe, expect, it } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Scope } from "./origin";
import {
  NoteJournal,
  anchorInFile,
  anchorOf,
  applyItem,
  contextAt,
  deepestFirst,
  groupSaved,
  hunksOfPatch,
  journalFileName,
  liveHostIds,
  lineTextAt,
  noteKey,
  parsePatch,
  planRestore,
  reanchorInFile,
  recordFromNote,
  rehomeTarget,
  replay,
  savedNoteLabel,
  type JournalEntry,
  type HostPlacement,
  type LoadedFile,
  type NoteOrigin,
  type NoteRecord,
  type RestoreView,
  type ThreadState,
} from "./persist";

const tempDirs: string[] = [];
afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    rmSync(dir, { recursive: true, force: true });
  }
});
function tempDir() {
  const dir = mkdtempSync(join(tmpdir(), "stack-notes-"));
  tempDirs.push(dir);
  return join(dir, "notes");
}

const PATCH = ["@@ -1,3 +1,4 @@", " keep", "-gone", "+added one", "+added two", " tail"].join("\n");
// New side: 1 keep, 2 added one, 3 added two, 4 tail. Old side: 1 keep, 2 gone, 3 tail.

function file(path: string, patch = PATCH, hunks?: LoadedFile["hunks"]): LoadedFile {
  return { path, patch, hunks: hunks ?? [{ oldRange: [1, 3], newRange: [1, 4] }] };
}

const C1 = { sha: "c1", subject: "one", branch: "feat" };
const C2 = { sha: "c2", subject: "two", branch: "feat" };
const ORIGIN: NoteOrigin = { commits: [C1] };
const SCOPE: Scope = { commits: [C1] };

function record(id: string, extra: Partial<NoteRecord> = {}): NoteRecord {
  return { key: noteKey(1, id), id, source: "agent", path: "a.ts", side: "new", line: 2, summary: `note ${id}`, origin: ORIGIN, ...extra };
}

/** A changeset holding `scope`'s commits, with `files` loaded. */
function view(files: LoadedFile[], extra: Partial<RestoreView> = {}): RestoreView {
  return { files, scope: SCOPE, patchIdOf: () => undefined, ...extra };
}

describe("patch parsing", () => {
  it("numbers lines per side and skips file headers", () => {
    const lines = parsePatch(`diff --git a/x b/x\n--- a/x\n+++ b/x\n${PATCH}\n`);
    expect([...lines.new]).toEqual([[1, "keep"], [2, "added one"], [3, "added two"], [4, "tail"]]);
    expect([...lines.old]).toEqual([[1, "keep"], [2, "gone"], [3, "tail"]]);
  });

  it("does not take a removed line that looks like a header for a header", () => {
    const patch = ["@@ -1,2 +1,1 @@", "--- not a header", " ctx"].join("\n");
    expect(parsePatch(patch).old.get(1)).toBe("-- not a header");
  });

  it("reads a line back by side", () => {
    expect(lineTextAt(PATCH, "old", 2)).toBe("gone");
    expect(lineTextAt(PATCH, "new", 9)).toBeUndefined();
  });
});

describe("journal replay", () => {
  const put = (t: number, note: NoteRecord): JournalEntry => ({ op: "put", t, note });

  it("keeps the latest put per key and drops removed notes", () => {
    const state = replay([
      put(1, record("a")),
      put(2, record("b")),
      put(3, record("a", { summary: "edited" })),
      { op: "remove", t: 4, key: noteKey(1, "b") },
    ]);
    expect([...state.notes.values()].map((note) => [note.id, note.summary])).toEqual([["a", "edited"]]);
  });

  it("orders by position in the file, so a clock that steps backwards cannot resurrect a removed note", () => {
    const state = replay([put(1000, record("a")), { op: "remove", t: 999, key: noteKey(1, "a") }]);
    expect(state.notes.size).toBe(0);
  });

  it("forgets the remaps of a removed note", () => {
    const state = replay([
      put(1, record("a")),
      { op: "remap", t: 2, pid: 9, key: noteKey(1, "a"), to: "mcp:1:0" },
      { op: "remove", t: 3, key: noteKey(1, "a") },
    ]);
    expect(state.remaps).toEqual([]);
  });
});

describe("thread status", () => {
  it("replays the last status per root, in file order, and clears it when the root is removed", () => {
    const fix = { sha: "f1", subject: "fix", branch: "feat" };
    const state = replay([
      { op: "put", t: 1, note: record("a") },
      { op: "status", t: 5, key: noteKey(1, "a"), status: "resolved", fix },
      { op: "put", t: 6, note: record("b") },
      { op: "status", t: 2, key: noteKey(1, "b"), status: "resolved" },
      { op: "status", t: 1, key: noteKey(1, "b"), status: "open" },
    ]);
    expect(state.statuses.get(noteKey(1, "a"))).toEqual({ status: "resolved", fix });
    expect(state.statuses.get(noteKey(1, "b"))).toEqual({ status: "open" });
    const removed = replay([
      { op: "put", t: 1, note: record("a") },
      { op: "status", t: 2, key: noteKey(1, "a"), status: "resolved" },
      { op: "remove", t: 3, key: noteKey(1, "a") },
    ]);
    expect(removed.statuses.size).toBe(0);
  });
});

describe("old journal records", () => {
  it("drops a put with no origin on read, with the status and remap that point at it", () => {
    const dir = tempDir();
    mkdirSync(dir, { recursive: true });
    const journal = new NoteJournal(dir, "/work/repo");
    const { origin: _origin, ...old } = record("old");
    writeFileSync(
      join(dir, journalFileName("/work/repo")),
      [
        JSON.stringify({ op: "put", t: 1, note: old }),
        JSON.stringify({ op: "remap", t: 2, pid: 9, key: noteKey(1, "old"), to: "mcp:1" }),
        JSON.stringify({ op: "put", t: 3, note: { ...old, key: noteKey(1, "bad"), origin: { commits: [] } } }),
      ].join("\n"),
      { flag: "w" },
    );
    journal.append([{ op: "put", t: 4, note: record("new") }]);
    const state = journal.load();
    expect([...state.notes.keys()]).toEqual([noteKey(1, "new")]);
    expect(state.remaps).toEqual([]);
  });
});

describe("NoteJournal", () => {
  it("round-trips appended entries and ignores a torn line", () => {
    const dir = tempDir();
    const journal = new NoteJournal(dir, "/work/repo");
    journal.append([{ op: "put", t: 1, note: record("a") }]);
    writeFileSync(join(dir, journalFileName("/work/repo")), '{"op":"put","t":2,"no', { flag: "a" });
    journal.append([{ op: "put", t: 3, note: record("b") }]);
    expect([...journal.load().notes.keys()]).toEqual([noteKey(1, "a"), noteKey(1, "b")]);
  });

  it("reads an empty journal before anything was saved", () => {
    expect(new NoteJournal(tempDir(), "/work/repo").load().notes.size).toBe(0);
  });

  it("keeps one file per worktree root, even for roots that share a basename", () => {
    expect(journalFileName("/a/repo")).not.toBe(journalFileName("/b/repo"));
    expect(journalFileName("/a/repo")).toMatch(/^repo-[0-9a-f]{12}\.jsonl$/);
  });

  it("prunes journals untouched for 30 days and keeps the rest", () => {
    const dir = tempDir();
    const old = new NoteJournal(dir, "/old");
    const fresh = new NoteJournal(dir, "/fresh");
    old.append([{ op: "put", t: 1, note: record("a") }]);
    fresh.append([{ op: "put", t: 1, note: record("a") }]);
    const stale = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
    utimesSync(join(dir, journalFileName("/old")), stale, stale);
    expect(fresh.prune()).toBe(1);
    expect(existsSync(join(dir, journalFileName("/old")))).toBe(false);
    expect(existsSync(join(dir, journalFileName("/fresh")))).toBe(true);
  });

  it("prunes nothing when the folder does not exist", () => {
    expect(new NoteJournal(tempDir(), "/x").prune()).toBe(0);
  });
});

describe("recordFromNote", () => {
  it("keeps the preferred line and the line's text", () => {
    const saved = recordFromNote(
      {
        id: "user:1",
        source: "user",
        anchor: { newRange: [2, 3], preferred: { side: "new", line: 3 } },
        summary: "why",
      },
      { pid: 7, path: "a.ts", origin: ORIGIN, lineText: "added two", lineContext: { before: ["added one"], after: ["tail"] } },
    );
    expect(saved).toEqual({
      key: "7:user:1",
      id: "user:1",
      source: "user",
      path: "a.ts",
      side: "new",
      line: 3,
      newRange: [2, 3],
      summary: "why",
      lineText: "added two",
      context: { before: ["added one"], after: ["tail"] },
      origin: ORIGIN,
    });
  });

  it("reads up to two lines of context on each side, from the same side of the patch", () => {
    const lines = parsePatch(PATCH);
    expect(contextAt(lines, "new", 3)).toEqual({ before: ["keep", "added one"], after: ["tail"] });
    expect(contextAt(lines, "new", 1)).toEqual({ before: [], after: ["added one", "added two"] });
    expect(contextAt(lines, "old", 2)).toEqual({ before: ["keep"], after: ["tail"] });
  });

  it("reads hunk ranges back out of a patch's headers", () => {
    expect(hunksOfPatch(["@@ -1,3 +1,4 @@", " a", "@@ -10 +11,0 @@"].join("\n"))).toEqual([
      { oldRange: [1, 3], newRange: [1, 4] },
      { oldRange: [10, 10], newRange: undefined },
    ]);
  });

  it("falls back to the start of a range when Hunk gave no preferred line", () => {
    expect(anchorOf({ oldRange: [4, 6] })).toEqual({ side: "old", line: 4 });
    expect(anchorOf({})).toBeNull();
  });
});

describe("anchorInFile", () => {
  const sameCtx = { before: ["keep"], after: ["added two", "tail"] };

  it("keeps a note at its saved line when the text still matches, whatever surrounds it", () => {
    const rec = record("a", { line: 2, lineText: "added one", context: { before: ["stale"], after: [] } });
    expect(anchorInFile(rec, file("a.ts"), parsePatch(PATCH))).toEqual({ side: "new", line: 2 });
  });

  it("finds a note whose line moved when both its text and its context match", () => {
    const patch = ["@@ -1,1 +1,4 @@", " a", "+b", "+c", "+added one"].join("\n");
    const moved = file("a.ts", patch, [{ oldRange: [1, 1], newRange: [1, 4] }]);
    const rec = record("a", { line: 2, lineText: "added one", context: { before: ["b", "c"], after: [] } });
    expect(anchorInFile(rec, moved, parsePatch(patch))).toEqual({ side: "new", line: 4 });
  });

  it("does not move a repeated line to a copy with different context", () => {
    const patch = ["@@ -1,1 +1,6 @@", " x", "+y", "+}", "+z", "+w", "+}"].join("\n");
    const loaded = file("a.ts", patch, [{ oldRange: [1, 1], newRange: [1, 6] }]);
    // Written on a `}` in other surroundings, at a line that no longer holds it.
    const rec = record("a", { line: 9, lineText: "}", context: { before: ["p", "q"], after: ["r"] } });
    expect(anchorInFile(rec, loaded, parsePatch(patch))).toBeNull();
    const same = record("a", { line: 9, lineText: "}", context: { before: ["z", "w"], after: [] } });
    expect(anchorInFile(same, loaded, parsePatch(patch))).toEqual({ side: "new", line: 6 });
  });

  it("takes the copy whose context matches when the text repeats", () => {
    const patch = ["@@ -1,1 +1,7 @@", " x", "+k", "+dup", "+m", "+n", "+dup", "+o"].join("\n");
    const loaded = file("a.ts", patch, [{ oldRange: [1, 1], newRange: [1, 7] }]);
    const lines = parsePatch(patch);
    const saved = (before: string[], after: string[]) => record("a", { line: 9, lineText: "dup", context: { before, after } });
    expect(anchorInFile(saved(["x", "k"], ["m", "n"]), loaded, lines)).toEqual({ side: "new", line: 3 });
    expect(anchorInFile(saved(["m", "n"], ["o"]), loaded, lines)).toEqual({ side: "new", line: 6 });
  });

  it("does not relocate a note that saved no context, and only counts lines inside a hunk", () => {
    const moved = file("a.ts", PATCH, [{ oldRange: [1, 3], newRange: [1, 4] }]);
    expect(anchorInFile(record("a", { line: 9, lineText: "added one" }), moved, parsePatch(PATCH))).toBeNull();
    const narrow = file("a.ts", PATCH, [{ oldRange: [1, 1], newRange: [1, 1] }]);
    expect(anchorInFile(record("b", { line: 2, lineText: "added one", context: sameCtx }), narrow, parsePatch(PATCH))).toBeNull();
  });

  it("checks the saved line against the hunks when no text was saved", () => {
    expect(anchorInFile(record("a", { line: 3 }), file("a.ts"), parsePatch(PATCH))).toEqual({ side: "new", line: 3 });
    expect(anchorInFile(record("b", { line: 90 }), file("a.ts"), parsePatch(PATCH))).toBeNull();
  });

  it("re-anchors in the hunk spanning the old line, else the first hunk", () => {
    expect(reanchorInFile(record("a", { line: 3 }), file("a.ts"))).toEqual({ side: "new", line: 3 });
    expect(reanchorInFile(record("a", { line: 90 }), file("a.ts"))).toEqual({ side: "new", line: 1 });
    expect(reanchorInFile(record("a", { line: 90 }), file("a.ts", PATCH, []))).toBeNull();
  });
});

describe("planRestore", () => {
  const none = new Set<string>();
  const lineA = { line: 2, lineText: "added one", context: { before: ["keep"], after: ["added two", "tail"] } };

  it("restores a note at its saved line when the text still matches", () => {
    const plan = planRestore([record("a", lineA)], view([file("a.ts")]), none);
    expect(plan.batches[0]?.[0]?.target).toEqual({ side: "new", line: 2 });
    expect(plan.pending).toEqual([]);
    expect(plan.outdated).toEqual([]);
  });

  it("shows a commit's note on its commit, its branch, and the combined changeset", () => {
    const rec = record("a", lineA);
    for (const commits of [[C1], [C1, C2], [{ sha: "c0", subject: "base", branch: "feat" }, C1, C2]]) {
      const plan = planRestore([rec], view([file("a.ts")], { scope: { commits } }), none);
      expect(plan.batches[0]?.[0]?.target).toEqual({ side: "new", line: 2 });
    }
  });

  it("holds a note pending, never outdated, on a sibling commit that touches the same file", () => {
    const sibling = file("a.ts", ["@@ -1,1 +1,2 @@", " keep", "+other"].join("\n"), [{ oldRange: [1, 1], newRange: [1, 2] }]);
    const plan = planRestore([record("a", lineA)], view([sibling], { scope: { commits: [C2] } }), none);
    expect(plan.pending.map((note) => note.id)).toEqual(["a"]);
    expect(plan.outdated).toEqual([]);
    expect(plan.batches).toEqual([]);
  });

  it("matches an origin commit by patch id after a rebase moved its sha", () => {
    const rebased = { sha: "c1-rebased", subject: "one", branch: "other" };
    const ids: Record<string, string> = { "c1-rebased": "pid-1" };
    const rec = record("a", { ...lineA, origin: { commits: [{ ...C1, patchId: "pid-1" }] } });
    const plan = planRestore([rec], view([file("a.ts")], { scope: { commits: [rebased] }, patchIdOf: (sha) => ids[sha] }), none);
    expect(plan.batches[0]).toHaveLength(1);
  });

  it("re-anchors an open thread whose line is gone from a changeset that holds its origin", () => {
    const plan = planRestore([record("a", { line: 3, lineText: "deleted since", context: { before: [], after: [] } })], view([file("a.ts")]), none);
    expect(plan.outdated.map((note) => note.id)).toEqual(["a"]);
    expect(plan.batches[0]?.[0]).toMatchObject({ target: { side: "new", line: 3 }, outdated: true });
    expect(applyItem(plan.batches[0]![0]!)).toMatchObject({ newLine: 3, author: "agent (outdated)" });
    // The saved anchor is untouched.
    expect(plan.batches[0]![0]!.record.line).toBe(3);
  });

  it("puts an outdated thread on the file's first hunk when no hunk spans its old line", () => {
    const plan = planRestore([record("a", { line: 90, lineText: "deleted since", context: { before: [], after: [] }, source: "user" })], view([file("a.ts")]), none);
    expect(plan.batches[0]?.[0]?.target).toEqual({ side: "new", line: 1 });
    expect(applyItem(plan.batches[0]![0]!).author).toBe("you (outdated)");
  });

  it("holds a note whose file is not in the changeset as pending", () => {
    const plan = planRestore([record("a", { path: "elsewhere.ts" })], view([file("a.ts")]), none);
    expect(plan.pending.map((note) => note.id)).toEqual(["a"]);
    expect(plan.outdated).toEqual([]);
  });

  it("puts a reply two levels deep in its own later batch", () => {
    const records = [
      record("c", { parentKey: noteKey(1, "b"), parentId: "b" }),
      record("b", { parentKey: noteKey(1, "a"), parentId: "a" }),
      record("a", lineA),
    ];
    const plan = planRestore(records, view([file("a.ts")]), none);
    expect(plan.batches.map((batch) => batch.map((planned) => planned.record.id))).toEqual([["a"], ["b"], ["c"]]);
    expect(plan.batches[1]?.[0]?.target).toBeUndefined();
  });

  it("lets a reply follow a parent that waits, and drops one whose parent is gone", () => {
    const records = [
      record("p", { path: "elsewhere.ts" }),
      record("pr", { parentKey: noteKey(1, "p") }),
      record("orphan", { parentKey: noteKey(1, "missing") }),
    ];
    const plan = planRestore(records, view([file("a.ts")]), none);
    expect(plan.pending.map((note) => note.id)).toEqual(["p", "pr"]);
    expect(plan.outdated.map((note) => note.id)).toEqual(["orphan"]);
  });

  it("skips a note the host already has and sends its new reply in the first batch", () => {
    const records = [record("a", lineA), record("r", { parentKey: noteKey(1, "a") })];
    const plan = planRestore(records, view([file("a.ts")]), new Set([noteKey(1, "a")]));
    expect(plan.batches.map((batch) => batch.map((planned) => planned.record.id))).toEqual([["r"]]);
  });

  it("survives a reply cycle", () => {
    const records = [
      record("x", { parentKey: noteKey(1, "y") }),
      record("y", { parentKey: noteKey(1, "x") }),
    ];
    expect(planRestore(records, view([file("a.ts")]), none).outdated).toHaveLength(2);
  });

  describe("live notes", () => {
    // New side of `base`: 1 a, 2 keep, 3 added one, 4 added two, 5 tail.
    const lineB = { line: 3, lineText: "added one", context: { before: ["a", "keep"], after: ["added two", "tail"] } };
    const base = file("a.ts", ["@@ -1,3 +1,5 @@", " a", " keep", "+added one", "+added two", " tail"].join("\n"), [{ oldRange: [1, 3], newRange: [1, 5] }]);
    /** The same lines after a commit put two more above them, so the note's line is now 5. */
    const shifted = file("a.ts", ["@@ -1,5 +1,7 @@", " p", " q", " a", " keep", "+added one", "+added two", " tail"].join("\n"), [{ oldRange: [1, 5], newRange: [1, 7] }]);
    const records = [record("a", lineB), record("r", { parentKey: noteKey(1, "a") }), record("deep", { parentKey: noteKey(1, "r") })];
    const live = new Set(records.map((note) => note.key));
    const at = (extra: Partial<HostPlacement> = {}): HostPlacement => ({ path: "a.ts", newRange: [3, 3], ...extra });
    const placed = (...entries: [string, HostPlacement][]) => new Map(entries.map(([id, placement]) => [noteKey(1, id), placement]));

    it("leaves a live note alone where the host already has it on its line", () => {
      const plan = planRestore(records, view([base], { placed: placed(["a", at()]) }), live);
      expect(plan.move).toEqual([]);
      expect(plan.hide).toEqual([]);
      expect(plan.batches).toEqual([]);
    });

    it("moves a live note the host has on another line, replies and all, replies removed first", () => {
      const plan = planRestore(records, view([shifted], { placed: placed(["a", at()]) }), live);
      expect(plan.move.map((note) => note.id)).toEqual(["deep", "r", "a"]);
      expect(plan.batches.map((batch) => batch.map((planned) => [planned.record.id, planned.target?.line]))).toEqual([
        [["a", 5]],
        [["r", undefined]],
        [["deep", undefined]],
      ]);
      expect(plan.hide).toEqual([]);
    });

    it("moves only the notes that are new when a live thread's root is in place, putting a reply under it as it is", () => {
      const fresh = [record("a", lineB), record("r", { parentKey: noteKey(1, "a") })];
      const plan = planRestore(fresh, view([base], { placed: placed(["a", at()]) }), new Set([noteKey(1, "a")]));
      expect(plan.move).toEqual([]);
      expect(plan.batches.map((batch) => batch.map((planned) => planned.record.id))).toEqual([["r"]]);
    });

    it("applies a reply that is not live after its moved root, one depth later", () => {
      const fresh = [record("a", lineB), record("r", { parentKey: noteKey(1, "a") })];
      const plan = planRestore(fresh, view([shifted], { placed: placed(["a", at()]) }), new Set([noteKey(1, "a")]));
      expect(plan.move.map((note) => note.id)).toEqual(["a"]);
      expect(plan.batches.map((batch) => batch.map((planned) => planned.record.id))).toEqual([["a"], ["r"]]);
    });

    it("moves a note whose host copy is on another file, or whose outdated label is wrong", () => {
      expect(planRestore([record("a", lineB)], view([base], { placed: placed(["a", at({ path: "b.ts" })]) }), live).move).toHaveLength(1);
      expect(planRestore([record("a", lineB)], view([base], { placed: placed(["a", at({ outdated: true })]) }), live).move).toHaveLength(1);
      const gone = record("a", { line: 4, lineText: "deleted since", context: { before: [], after: [] } });
      expect(planRestore([gone], view([base], { placed: placed(["a", at({ newRange: [3, 3] })]) }), live).move).toHaveLength(1);
      expect(planRestore([gone], view([base], { placed: placed(["a", at({ newRange: [4, 4], outdated: true })]) }), live).move).toEqual([]);
    });

    it("counts a multi-line host range as in place when it holds the line", () => {
      expect(planRestore([record("a", lineB)], view([base], { placed: placed(["a", at({ newRange: [1, 3] })]) }), live).move).toEqual([]);
    });

    it("leaves a note where it is when the host reports no range or the placement is unknown", () => {
      expect(planRestore([record("a", lineB)], view([shifted], { placed: placed(["a", { path: "a.ts" }]) }), live).move).toEqual([]);
      expect(planRestore([record("a", lineB)], view([shifted]), live).move).toEqual([]);
    });

    it("hides a live note the loaded changeset does not hold, replies first, and counts it pending", () => {
      const elsewhere = { scope: { commits: [C2] } };
      const plan = planRestore(records, view([base], elsewhere), live);
      expect(plan.hide.map((note) => note.id)).toEqual(["deep", "r", "a"]);
      expect(plan.pending.map((note) => note.id).sort()).toEqual(["a", "deep", "r"]);
      expect(plan.batches).toEqual([]);
    });

    it("hides a live note whose file is not loaded", () => {
      const plan = planRestore([record("a", { path: "gone.ts" })], view([base]), new Set([noteKey(1, "a")]));
      expect(plan.hide.map((note) => note.id)).toEqual(["a"]);
    });

    it("holds a reply that is not live pending when its live root is hidden", () => {
      const fresh = [record("a", lineB), record("r", { parentKey: noteKey(1, "a") })];
      const plan = planRestore(fresh, view([base], { scope: { commits: [C2] } }), new Set([noteKey(1, "a")]));
      expect(plan.hide.map((note) => note.id)).toEqual(["a"]);
      expect(plan.batches).toEqual([]);
      expect(plan.pending.map((note) => note.id).sort()).toEqual(["a", "r"]);
    });
  });

  describe("resolved threads", () => {
    const resolved = new Map<string, ThreadState>([[noteKey(1, "a"), { status: "resolved" }]]);
    const records = [record("a", lineA), record("r", { parentKey: noteKey(1, "a") }), record("deep", { parentKey: noteKey(1, "r") })];

    it("applies none of a resolved thread", () => {
      const plan = planRestore(records, view([file("a.ts")], { statuses: resolved }), none);
      expect(plan.batches).toEqual([]);
      expect(plan.resolved.map((note) => note.id)).toEqual(["a", "r", "deep"]);
      expect(plan.hide).toEqual([]);
    });

    it("lists the live notes of a resolved thread for removal, replies first", () => {
      const live = new Set(records.map((note) => note.key));
      const plan = planRestore(records, view([file("a.ts")], { statuses: resolved }), live);
      expect(plan.hide.map((note) => note.id)).toEqual(["deep", "r", "a"]);
    });

    it("applies a resolved thread the reviewer asked for, and leaves it resolved", () => {
      const plan = planRestore(records, view([file("a.ts")], { statuses: resolved, forced: new Set([noteKey(1, "a")]) }), none);
      expect(plan.batches.map((batch) => batch.map((planned) => planned.record.id))).toEqual([["a"], ["r"], ["deep"]]);
      expect(resolved.get(noteKey(1, "a"))?.status).toBe("resolved");
    });

    it("lists a resolved thread by its root in the dialog, under its own status", () => {
      const plan = planRestore(records, view([file("a.ts")], { statuses: resolved }), none);
      const groups = groupSaved(records, plan, none, resolved);
      expect(groups.resolved.map((note) => note.id)).toEqual(["a"]);
      expect([...groups.shown, ...groups.pending, ...groups.outdated]).toEqual([]);
    });
  });

  describe("uncommitted notes", () => {
    const uncommitted = (extra: Partial<NoteRecord> = {}) => record("u", { ...lineA, origin: { uncommitted: true, branch: "feat" }, ...extra });
    const missing = file("a.ts", ["@@ -1,1 +1,2 @@", " keep", "+other"].join("\n"), [{ oldRange: [1, 1], newRange: [1, 2] }]);

    it("shows on the uncommitted changeset of its branch and waits elsewhere", () => {
      const here = planRestore([uncommitted()], view([file("a.ts")], { scope: { commits: [], uncommitted: { branch: "feat" } } }), none);
      expect(here.batches[0]).toHaveLength(1);
      const other = planRestore([uncommitted()], view([file("a.ts")], { scope: { commits: [], uncommitted: { branch: "elsewhere" } } }), none);
      expect(other.pending).toHaveLength(1);
    });

    it("re-homes to the commit that holds its line once the uncommitted changeset has lost it", () => {
      const plan = planRestore(
        [uncommitted()],
        view([missing], {
          scope: { commits: [C2], uncommitted: undefined },
          rehome: (_note, branch) => (branch === "feat" ? C1 : null),
        }),
        none,
      );
      expect(plan.rehomed).toEqual([{ record: expect.objectContaining({ id: "u" }), origin: { commits: [C1] } }]);
      // C1 is not in this changeset, so the note waits for one that holds it.
      expect(plan.pending).toHaveLength(1);
    });

    it("finds the re-home commit by text and context in each commit's own patch", () => {
      const patches: Record<string, string> = { c2: ["@@ -1,1 +1,2 @@", " keep", "+other"].join("\n"), c1: PATCH };
      const found = rehomeTarget(uncommitted(), [C2, C1], (commit) => patches[commit.sha]);
      expect(found).toBe(C1);
      expect(rehomeTarget(uncommitted({ context: { before: ["nope"], after: [] } }), [C2, C1], (commit) => patches[commit.sha])).toBeNull();
    });
  });
});

describe("deepestFirst", () => {
  it("orders replies before the notes they answer", () => {
    const a = record("a");
    const b = record("b", { parentKey: a.key });
    const c = record("c", { parentKey: b.key });
    expect(deepestFirst([a, b, c], new Map([a, b, c].map((note) => [note.key, note]))).map((note) => note.id)).toEqual(["c", "b", "a"]);
  });
});

describe("liveHostIds", () => {
  const state = replay([{ op: "put", t: 1, note: record("a") }]);

  it("counts a note live while its remap's id is listed, and only for the restoring process", () => {
    const remaps = [{ pid: 9, key: noteKey(1, "a"), to: "mcp:1:0" }];
    expect(liveHostIds(state, remaps, 9, new Set(["mcp:1:0"]))).toEqual(new Map([[noteKey(1, "a"), "mcp:1:0"]]));
    expect(liveHostIds(state, remaps, 9, new Set())).toEqual(new Map());
    expect(liveHostIds(state, remaps, 10, new Set(["mcp:1:0"]))).toEqual(new Map());
  });

  it("does not confuse an id from another process with the same id live now", () => {
    // Hunk numbers user notes per process: `1:a` from an earlier run vs. a new native `a`.
    expect(liveHostIds(state, [], 2, new Set(["a"]))).toEqual(new Map());
    expect(liveHostIds(state, [], 1, new Set(["a"]))).toEqual(new Map([[noteKey(1, "a"), "a"]]));
  });
});

describe("applyItem", () => {
  it("restores a user note as an agent note by `you`, at its saved line", () => {
    const planned = { record: record("u", { source: "user", author: "me", rationale: "because", markup: "<b>" }), target: { side: "old" as const, line: 5 } };
    expect(applyItem(planned)).toEqual({
      filePath: "a.ts",
      oldLine: 5,
      summary: "note u",
      author: "you",
      rationale: "because",
    });
  });

  it("keeps an agent note's author and names the parent for a reply", () => {
    expect(applyItem({ record: record("r", { author: "Pi" }) }, "mcp:1:0")).toEqual({
      replyTo: "mcp:1:0",
      summary: "note r",
      author: "Pi",
    });
  });

  it("never sends an empty summary, which hunk rejects the whole batch for", () => {
    expect(applyItem({ record: record("e", { summary: "" }), target: { side: "new", line: 1 } }).summary).toBe("(empty note)");
  });
});

describe("savedNoteLabel", () => {
  it("shows status, place, author, and the first line of the body", () => {
    const label = savedNoteLabel("outdated", record("a", { author: "Pi", line: 7, summary: "first\nsecond" }));
    expect(label).toBe("outdated  a.ts:7  Pi  first");
  });

  it("strips control characters from the body", () => {
    expect(savedNoteLabel("pending", record("a", { summary: "hi\u001b[31m there" }))).not.toContain("\u001b");
  });
});
