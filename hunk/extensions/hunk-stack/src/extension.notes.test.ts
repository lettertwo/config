import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionReviewSnapshotNote, HunkExtensionAPI } from "hunkdiff/extension";
import type { Run, RunResult } from "./daemon";
import { registerStack } from "./extension";
import { NoteJournal, journalFileName, noteKey, type NoteRecord } from "./persist";
import { makeRepo, type TestRepo } from "./stack/testRepo";

const PID = 4242;
/** The commit the review's changeset holds; notes match it by subject on its branch. */
const FEATURE = { sha: "0".repeat(40), subject: "feature work", branch: "feat" };
const PATCH = ["@@ -1,3 +1,4 @@", " keep", "-gone", "+added one", "+added two", " tail"].join("\n");

const tempDirs: string[] = [];
afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    rmSync(dir, { recursive: true, force: true });
  }
});

const ok = (value: unknown): RunResult => ({ code: 0, stdout: JSON.stringify(value), stderr: "" });
const settle = () => new Promise((resolve) => setTimeout(resolve, 20));

function sourceFile(path: string, patch = PATCH) {
  return { id: `f:${path}`, path, patch, hunks: [{ index: 0, header: "", oldRange: [1, 3], newRange: [1, 4] }] };
}

function snapshotNote(id: string, extra: Partial<ExtensionReviewSnapshotNote> = {}): ExtensionReviewSnapshotNote {
  return {
    id,
    source: "user",
    fileKey: "key-a",
    anchor: { newRange: [2, 2], preferred: { side: "new", line: 2 } },
    summary: `body ${id}`,
    editable: true,
    resolution: "active",
    ...extra,
  } as ExtensionReviewSnapshotNote;
}

function saved(id: string, extra: Partial<NoteRecord> = {}): NoteRecord {
  return {
    key: noteKey(1, id),
    id,
    source: "agent",
    author: "Pi",
    path: "a.ts",
    side: "new",
    line: 2,
    lineText: "added one",
    summary: `saved ${id}`,
    context: { before: ["keep"], after: ["added two", "tail"] },
    origin: { commits: [FEATURE] },
    ...extra,
  };
}

type Handler = (payload: any, ctx: any) => unknown;

function setup({
  config = {} as Record<string, unknown>,
  echoEvents = true,
  dir = undefined as string | undefined,
  repo = undefined as TestRepo | undefined,
  live = [] as { noteId: string; filePath: string; newRange?: [number, number]; oldRange?: [number, number]; author?: string }[],
  openStack = true,
} = {}) {
  if (!dir) {
    dir = mkdtempSync(join(tmpdir(), "stack-notes-ext-"));
    tempDirs.push(dir);
  }
  if (!repo) {
    // One commit on `feat`: the stack the review opens on is that commit's changeset.
    repo = makeRepo();
    tempDirs.push(repo.cwd);
    repo.git("checkout", "-qb", "feat");
    repo.commitFile("a.ts", FEATURE.subject);
  }
  const root = repo.cwd;
  const notesDir = join(dir, "notes");
  const handlers = new Map<string, Handler[]>();
  const commands = new Map<string, (ctx: any) => unknown>();
  let cli: ((args: readonly string[], ctx: any) => Promise<any>) | undefined;
  const notices: string[] = [];
  const calls: { args: string[]; stdin?: string }[] = [];
  const state = {
    sessionUp: true,
    /** `session list` lookups that miss this window before it shows as registered. */
    missedLookups: 0,
    live,
    next: 0,
    failApply: false,
    failRemove: false,
    /** Runs while an apply is in flight, before hunk answers it. */
    duringApply: () => {},
    /** Runs while a removal is in flight, before hunk answers it. */
    duringRemove: () => {},
  };
  const dialogs: { title: string; options: readonly string[] }[] = [];

  const ctx = {
    cwd: root,
    notify: (message: string) => notices.push(message),
    dialogs: { select: async (options: { title: string; options: readonly string[] }) => (dialogs.push(options), null) },
    review: { snapshot: () => ({ files: [{ fileKey: "key-a", path: "a.ts" }] }) },
  };
  const fire = (event: string, payload: unknown) => {
    for (const handler of handlers.get(event) ?? []) {
      void handler(payload, ctx);
    }
  };

  const run: Run = async (args, stdin) => {
    calls.push({ args: [...args], stdin });
    if (args[1] === "list") {
      if (state.missedLookups > 0) {
        state.missedLookups--;
        return ok({ sessions: [] });
      }
      return ok({ sessions: state.sessionUp ? [{ sessionId: "mine", pid: PID }] : [] });
    }
    if (args[2] === "list") {
      return ok({ comments: state.live });
    }
    if (args[2] === "rm") {
      if (state.failRemove) {
        return { code: 1, stdout: "", stderr: "Session comment rm refused." };
      }
      state.duringRemove();
      const at = state.live.findIndex((note) => note.noteId === args[4]);
      if (at >= 0) {
        const [gone] = state.live.splice(at, 1);
        if (echoEvents) {
          fire("note_changed", { kind: "removed", note: snapshotNote(gone!.noteId, { source: "agent" }) });
        }
      }
      return ok({});
    }
    if (args[2] === "apply") {
      if (state.failApply) {
        return { code: 1, stdout: "", stderr: "Session comment apply rejected the batch." };
      }
      const comments = JSON.parse(stdin!).comments as { filePath?: string; replyTo?: string }[];
      const applied = comments.map((comment) => {
        const commentId = `mcp:${++state.next}`;
        const filePath = comment.filePath ?? state.live.find((note) => note.noteId === comment.replyTo)!.filePath;
        state.live.push({ noteId: commentId, filePath });
        return { commentId, filePath };
      });
      if (echoEvents) {
        // Hunk reports each new note before the apply request is answered.
        for (const made of applied) {
          fire("note_changed", { kind: "created", note: snapshotNote(made.commentId, { source: "agent" }) });
        }
      }
      state.duringApply();
      return ok({ result: { applied } });
    }
    return ok({});
  };

  const api = {
    registerCommand: (command: { id: string }, handler: (ctx: any) => unknown) => commands.set(command.id, handler),
    registerPane: () => {},
    registerCliCommand: (_command: unknown, handler: typeof cli) => void (cli = handler),
    registerLineHighlighter: () => {},
    registerKeyboardMode: () => {},
    transformChangeset: () => {},
    on: (event: string, handler: Handler) => handlers.set(event, [...(handlers.get(event) ?? []), handler]),
    config,
  } as unknown as HunkExtensionAPI;
  const registered = registerStack(api, {
    sessionDir: join(dir, "sessions"),
    notesDir,
    run,
    pid: PID,
    registrationWaits: [5, 5],
  });

  const journal = new NoteJournal(notesDir, root);
  const output = { out: "", err: "" };
  /** Run `hunk stack <args>` through the registered CLI command. */
  const runCli = async (args: string[]) => {
    output.out = "";
    output.err = "";
    const result = await cli!(args, {
      cwd: root,
      stdout: { write: async (text: string) => void (output.out += text) },
      stderr: { write: async (text: string) => void (output.err += text) },
    });
    return { result, ...output };
  };
  if (openStack) {
    void runCli([]);
  }
  return {
    /** The review the files pane reports to the extension; a stack review is known without it. */
    report: registered.reportReview,
    editor: registered.editor,
    dir,
    repo,
    root,
    runCli,
    handlers,
    commands,
    notices,
    calls,
    state,
    dialogs,
    journal,
    fire,
    applies: () => calls.filter((call) => call.args[2] === "apply"),
    load: (files = [sourceFile("a.ts")]) => fire("changeset_loaded", { changeset: { files } }),
    /** A reload, as Hunk emits it: `changeset_loaded`, then `session_reload` with the same changeset. */
    reload: (reason: string, files = [sourceFile("a.ts")]) => {
      fire("changeset_loaded", { changeset: { files } });
      fire("session_reload", { changeset: { files }, reason });
    },
    stored: () => [...journal.load().notes.values()],
  };
}

describe("journaling notes", () => {
  test("takes a note's line text from the changeset loaded when the note changed", async () => {
    const ext = setup({ live: [{ noteId: "user:9", filePath: "a.ts" }] });
    ext.load();
    // The path is not known yet, so journaling waits on `comment list` while a reload lands.
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:9") });
    ext.load([sourceFile("a.ts", PATCH.replace("+added one", "+changed since"))]);
    await settle();
    expect(ext.stored()).toEqual([expect.objectContaining({ key: `${PID}:user:9`, lineText: "added one" })]);
  });

  test("saves a user note with its path and the text of its line, then follows edits and removal", async () => {
    const ext = setup();
    ext.load();
    ext.fire("note_created", { note: { id: "user:1", filePath: "a.ts" } });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:1") });
    await settle();
    expect(ext.stored()).toEqual([
      expect.objectContaining({ key: `${PID}:user:1`, source: "user", path: "a.ts", side: "new", line: 2, lineText: "added one", summary: "body user:1" }),
    ]);
    // The note remembers the commits of the changeset it was written on, and the lines around it.
    const origin = { commits: [{ sha: ext.repo.git("rev-parse", "HEAD"), patchId: expect.stringMatching(/^[0-9a-f]{40}$/), subject: "feature work", branch: "feat" }] };
    expect(ext.stored()[0]).toMatchObject({ origin, context: { before: ["keep"], after: ["added two", "tail"] } });

    ext.fire("note_changed", { kind: "updated", note: snapshotNote("user:1", { summary: "revised" }) });
    await settle();
    expect(ext.stored().map((note) => note.summary)).toEqual(["revised"]);
    expect(ext.stored()[0]).toMatchObject({ origin });

    ext.fire("note_changed", { kind: "removed", note: snapshotNote("user:1") });
    await settle();
    expect(ext.stored()).toEqual([]);
  });

  test("resolves an agent note's path from the daemon when only its fileKey is known", async () => {
    const ext = setup();
    ext.load();
    ext.state.live.push({ noteId: "mcp:agent", filePath: "a.ts" });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("mcp:agent", { source: "agent", fileKey: "unmapped" }) });
    await settle();
    expect(ext.stored().map((note) => [note.path, note.source])).toEqual([["a.ts", "agent"]]);
    expect(ext.calls.some((call) => call.args[2] === "list")).toBe(true);
  });

  test("learns a fileKey from a command context's snapshot and skips the daemon", async () => {
    const ext = setup();
    ext.load();
    await ext.commands.get("show-saved-notes")!({
      ...ctxFor(ext),
      review: { snapshot: () => ({ files: [{ fileKey: "key-a", path: "a.ts" }] }) },
    });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:2") });
    await settle();
    expect(ext.stored().map((note) => note.path)).toEqual(["a.ts"]);
    expect(ext.calls.some((call) => call.args[2] === "list")).toBe(false);
  });

  test("keeps a reply's parent by key", async () => {
    const ext = setup();
    ext.load();
    ext.fire("note_created", { note: { id: "user:1", filePath: "a.ts" } });
    ext.fire("note_created", { note: { id: "user:2", filePath: "a.ts" } });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:1") });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:2", { parentId: "user:1" }) });
    await settle();
    expect(ext.stored().find((note) => note.id === "user:2")?.parentKey).toBe(`${PID}:user:1`);
  });

  test("never writes on shutdown", () => {
    const ext = setup();
    expect(ext.handlers.has("shutdown")).toBe(false);
  });

  test("saves nothing when persist is off", async () => {
    const ext = setup({ config: { persist: false } });
    ext.load();
    ext.fire("note_created", { note: { id: "user:1", filePath: "a.ts" } });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:1") });
    await settle();
    expect(ext.stored()).toEqual([]);
    expect(ext.calls).toEqual([]);
  });
});

describe("restoring notes", () => {
  test("applies a saved note on load, as an agent note by `you`, and says so", async () => {
    const ext = setup();
    ext.journal.append([
      { op: "put", t: 1, note: saved("old", { source: "user", author: "me" }) },
    ]);
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(1);
    expect(ext.applies()[0]!.args).toEqual(["session", "comment", "apply", "mine", "--stdin", "--json"]);
    expect(JSON.parse(ext.applies()[0]!.stdin!)).toEqual({
      comments: [{ filePath: "a.ts", newLine: 2, summary: "saved old", author: "you" }],
    });
    expect(ext.notices).toEqual(["stack: restored 1 saved note"]);
  });

  test("does not journal the created events its own restore caused, and remaps the id", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.load();
    await settle();
    expect(ext.stored().map((note) => note.key)).toEqual([noteKey(1, "old")]);
    expect(ext.journal.load().remaps).toEqual([{ pid: PID, key: noteKey(1, "old"), to: "mcp:1" }]);
  });

  test("never applies a note the host already has, across loads", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.load();
    await settle();
    ext.load();
    await settle();
    ext.reload("watch");
    await settle();
    expect(ext.applies()).toHaveLength(1);
  });

  test("holds a note written on another commit pending instead of applying it", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("elsewhere", { origin: { commits: [{ sha: "1".repeat(40), subject: "another commit", branch: "feat" }] } }) }]);
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(0);
  });

  test("ignores records from a journal that predates origins", async () => {
    const ext = setup();
    const { origin: _origin, ...old } = saved("old");
    mkdirSync(join(ext.dir, "notes"), { recursive: true });
    writeFileSync(join(ext.dir, "notes", journalFileName(ext.root)), `${JSON.stringify({ op: "put", t: 1, note: old })}\n`);
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(0);
    expect(ext.stored()).toEqual([]);
  });

  test("restores once per reload, from `changeset_loaded`", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.reload("daemon");
    await settle();
    expect(ext.calls.filter((call) => call.args[2] === "list")).toHaveLength(1);
  });

  test("applies it again when a reload dropped it from the host", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.load();
    await settle();
    ext.state.live.length = 0;
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(2);
  });

  test("journals a user note saved while the restore's apply is in flight", async () => {
    const ext = setup({ echoEvents: false });
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.state.duringApply = () => {
      ext.fire("note_created", { note: { id: "user:9", filePath: "a.ts" } });
      ext.fire("note_changed", { kind: "created", note: snapshotNote("user:9") });
      // The restore's own note, reported in the same window.
      ext.fire("note_changed", { kind: "created", note: snapshotNote("mcp:1", { source: "agent" }) });
    };
    ext.load();
    await settle();
    expect(ext.stored().map((note) => note.key).sort()).toEqual([noteKey(1, "old"), noteKey(PID, "user:9")].sort());
  });

  test("restores replies one depth per call, naming the parent's new id", async () => {
    const ext = setup();
    ext.journal.append([
      { op: "put", t: 1, note: saved("root") },
      { op: "put", t: 2, note: saved("mid", { parentKey: noteKey(1, "root"), parentId: "root" }) },
      { op: "put", t: 3, note: saved("leaf", { parentKey: noteKey(1, "mid"), parentId: "mid", author: "Pi" }) },
    ]);
    ext.load();
    await settle();
    const bodies = ext.applies().map((call) => JSON.parse(call.stdin!).comments);
    expect(bodies).toEqual([
      [expect.objectContaining({ filePath: "a.ts", summary: "saved root" })],
      [{ replyTo: "mcp:1", summary: "saved mid", author: "Pi" }],
      [{ replyTo: "mcp:2", summary: "saved leaf", author: "Pi" }],
    ]);
    expect(ext.notices).toEqual(["stack: restored 3 saved notes"]);
  });

  test("sends what pre-validates, beside its old line when the line is gone, and counts pending and outdated", async () => {
    const ext = setup();
    ext.journal.append([
      { op: "put", t: 1, note: saved("fits") },
      { op: "put", t: 2, note: saved("gone", { lineText: "deleted since" }) },
      { op: "put", t: 3, note: saved("later", { path: "b.ts" }) },
    ]);
    ext.load();
    await settle();
    expect(JSON.parse(ext.applies()[0]!.stdin!).comments).toEqual([
      expect.objectContaining({ summary: "saved fits", author: "Pi" }),
      expect.objectContaining({ summary: "saved gone", newLine: 2, author: "Pi (outdated)" }),
    ]);
    expect(ext.notices).toEqual(["stack: restored 2 saved notes (1 pending, 1 outdated)"]);
  });

  test("retries a pending note when its file loads", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("later", { path: "b.ts" }) }]);
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(0);
    expect(ext.notices).toEqual([]);
    ext.load([sourceFile("a.ts"), sourceFile("b.ts")]);
    await settle();
    expect(ext.applies()).toHaveLength(1);
  });

  test("restores on the first load when the session registers a moment after it", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.state.missedLookups = 2;
    ext.fire("startup", { cwd: ext.root });
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(1);
    expect(ext.notices).toEqual(["stack: restored 1 saved note"]);
  });

  test("gives up quietly when the session never registers, then restores on a later load", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.state.sessionUp = false;
    ext.load();
    await new Promise((resolve) => setTimeout(resolve, 20));
    await settle();
    expect(ext.applies()).toHaveLength(0);
    expect(ext.notices).toEqual([]);
    ext.state.sessionUp = true;
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(1);
  });

  test("reports a refused apply once, and leaves the note for the next load", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.state.failApply = true;
    ext.load();
    await settle();
    ext.load();
    await settle();
    expect(ext.notices).toEqual(["stack: cannot restore saved notes (Session comment apply rejected the batch.)"]);
    ext.state.failApply = false;
    ext.load();
    await settle();
    expect(ext.notices.at(-1)).toBe("stack: restored 1 saved note");
  });

  test("removing a restored note in the host removes the original record", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.load();
    await settle();
    ext.fire("note_changed", { kind: "removed", note: snapshotNote("mcp:1", { source: "agent" }) });
    await settle();
    expect(ext.stored()).toEqual([]);
    expect(ext.journal.load().remaps).toEqual([]);
  });

  test("an edit to a restored note updates the original record and keeps its anchor", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old", { source: "user", author: "me" }) }]);
    ext.load();
    await settle();
    ext.fire("note_changed", { kind: "updated", note: snapshotNote("mcp:1", { source: "agent", summary: "edited" }) });
    await settle();
    expect(ext.stored()).toEqual([
      expect.objectContaining({ key: noteKey(1, "old"), source: "user", author: "me", summary: "edited", lineText: "added one" }),
    ]);
  });

  test("a rebuilt registry still knows which notes this process restored", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("old") }]);
    ext.load();
    await settle();
    // Same pid and journal, fresh factory state, while the host still holds the restored note.
    const rebuilt = setup({ dir: ext.dir, repo: ext.repo, live: [{ noteId: "mcp:1", filePath: "a.ts" }] });
    rebuilt.load();
    await settle();
    expect(rebuilt.applies()).toHaveLength(0);
    // And an edit to it still reaches the original record.
    rebuilt.fire("note_changed", { kind: "updated", note: snapshotNote("mcp:1", { source: "agent", summary: "after rebuild" }) });
    await settle();
    expect(rebuilt.stored().map((note) => [note.key, note.summary])).toEqual([[noteKey(1, "old"), "after rebuild"]]);
  });
})

describe("the note editor", () => {
  const user = (id: string, extra: Partial<ExtensionReviewSnapshotNote> = {}) =>
    snapshotNote(id, { source: "agent", author: "you", ...extra });

  /** A command context on `a.ts`, with the given notes as the host's snapshot and a line selected. */
  function editorCtx(
    ext: ReturnType<typeof setup>,
    { line = 2, side = "new", notes = [] as ExtensionReviewSnapshotNote[], choose }: { line?: number; side?: string; notes?: ExtensionReviewSnapshotNote[]; choose?: string } = {},
  ) {
    const panes = { opened: [] as string[], closed: [] as string[], open: (id: string) => void panes.opened.push(id), close: (id: string) => void panes.closed.push(id) };
    return {
      ...ctxFor(ext, { choose }),
      selection: { file: sourceFile("a.ts"), currentLine: { side, line } },
      panes,
      review: { snapshot: () => ({ files: [{ fileKey: "key-a", path: "a.ts" }], notes }) },
    };
  }

  test("adds a note through comment apply as `you`, and journals it as the user's under the id Hunk returned", async () => {
    const ext = setup();
    ext.load();
    const ctx = editorCtx(ext);
    await ext.commands.get("note-add")!(ctx);
    expect(ctx.panes.opened).toEqual(["note-editor"]);
    expect(ext.editor.current()?.request).toEqual({ kind: "add", path: "a.ts", side: "new", line: 2 });

    expect(await ext.editor.save("  first note\nsecond line \n")).toBeNull();
    await settle();
    expect(JSON.parse(ext.applies().at(-1)!.stdin!)).toEqual({
      comments: [{ filePath: "a.ts", newLine: 2, summary: "first note\nsecond line", author: "you" }],
    });
    // The created event Hunk echoed is the editor's own and is not journaled a second time.
    expect(ext.stored()).toEqual([
      expect.objectContaining({
        key: `${PID}:mcp:1`,
        id: "mcp:1",
        source: "user",
        author: "you",
        path: "a.ts",
        side: "new",
        line: 2,
        lineText: "added one",
        summary: "first note\nsecond line",
        context: { before: ["keep"], after: ["added two", "tail"] },
      }),
    ]);
    expect(ext.stored()[0]!.origin).toEqual({ commits: [expect.objectContaining({ subject: "feature work", branch: "feat" })] });
    expect(ext.editor.current()).toBeNull();
    expect(ctx.panes.closed).toEqual(["note-editor"]);
  });

  test("a note it made is still removed from the journal when Hunk reports its removal", async () => {
    const ext = setup();
    ext.load();
    await ext.commands.get("note-add")!(editorCtx(ext));
    await ext.editor.save("text");
    await settle();
    ext.fire("note_changed", { kind: "removed", note: user("mcp:1") });
    await settle();
    expect(ext.stored()).toEqual([]);
  });

  test("refuses a line outside every hunk and opens no editor", async () => {
    const ext = setup();
    ext.load();
    const ctx = editorCtx(ext, { line: 9 });
    await ext.commands.get("note-add")!(ctx);
    expect(ctx.messages).toEqual(["A note needs a line inside a hunk"]);
    expect(ext.editor.current()).toBeNull();
    expect(ctx.panes.opened).toEqual([]);
  });

  test("refuses to save an empty editor, keeps it open, and sends nothing", async () => {
    const ext = setup();
    ext.load();
    await ext.commands.get("note-add")!(editorCtx(ext));
    expect(await ext.editor.save("  \n ")).toBe("The note is empty");
    expect(ext.applies()).toHaveLength(0);
    expect(ext.editor.current()).toMatchObject({ error: "The note is empty", busy: false });
  });

  test("keeps the editor open with the host's error when the apply is refused", async () => {
    const ext = setup();
    ext.load();
    await ext.commands.get("note-add")!(editorCtx(ext));
    ext.state.failApply = true;
    expect(await ext.editor.save("text")).toBe("Session comment apply rejected the batch.");
    expect(ext.editor.current()).toMatchObject({ busy: false });
    expect(ext.stored()).toEqual([]);
  });

  test("cancelling closes the pane without applying anything", async () => {
    const ext = setup();
    ext.load();
    const ctx = editorCtx(ext);
    await ext.commands.get("note-add")!(ctx);
    ext.editor.cancel();
    expect(ext.editor.current()).toBeNull();
    expect(ctx.panes.closed).toEqual(["note-editor"]);
    expect(ext.applies()).toHaveLength(0);
  });

  test("replies under a thread's root and journals the reply with its parent's key", async () => {
    const ext = setup({ live: [{ noteId: "mcp:r", filePath: "a.ts" }] });
    ext.load();
    const ctx = editorCtx(ext, { notes: [user("mcp:r", { author: "Pi" })] });
    await ext.commands.get("note-reply")!(ctx);
    expect(ext.editor.current()?.request).toMatchObject({ kind: "reply", root: { id: "mcp:r" } });
    await ext.editor.save("agreed");
    await settle();
    expect(JSON.parse(ext.applies().at(-1)!.stdin!)).toEqual({ comments: [{ replyTo: "mcp:r", summary: "agreed", author: "you" }] });
    expect(ext.stored()).toEqual([
      expect.objectContaining({ key: `${PID}:mcp:1`, source: "user", parentKey: `${PID}:mcp:r`, parentId: "mcp:r", side: "new", line: 2 }),
    ]);
  });

  test("asks which thread to reply to when several sit on the line, and says so when none does", async () => {
    const ext = setup();
    ext.load();
    const two = [user("mcp:a", { summary: "alpha" }), user("mcp:b", { summary: "beta" })];
    const picked = editorCtx(ext, { notes: two, choose: "2. you: beta" });
    await ext.commands.get("note-reply")!(picked);
    expect(ext.dialogs.at(-1)!.options).toEqual(["1. you: alpha", "2. you: beta"]);
    expect(ext.editor.current()?.request).toMatchObject({ kind: "reply", root: { id: "mcp:b" } });
    ext.editor.cancel();

    const none = editorCtx(ext, { line: 3, notes: two });
    await ext.commands.get("note-reply")!(none);
    expect(none.messages).toEqual(["No note on this line to reply to"]);
    expect(ext.editor.current()).toBeNull();
  });

  test("edits a note of yours by removing its thread leaf-first and applying it again, replies after", async () => {
    const ext = setup();
    ext.journal.append([
      { op: "put", t: 1, note: saved("root", { source: "user", author: "you", summary: "old text" }) },
      { op: "put", t: 2, note: saved("reply", { parentKey: noteKey(1, "root"), parentId: "root", author: "Pi" }) },
    ]);
    ext.load();
    await settle();
    // Restored as mcp:1 and mcp:2.
    const notes = [user("mcp:1", { summary: "old text" }), snapshotNote("mcp:2", { source: "agent", author: "Pi", parentId: "mcp:1", summary: "saved reply" })];
    const ctx = editorCtx(ext, { notes });
    await ext.commands.get("note-edit")!(ctx);
    expect(ext.editor.current()).toMatchObject({ request: { kind: "edit", note: { id: "mcp:1" } }, initial: "old text" });

    const before = ext.calls.length;
    expect(await ext.editor.save("new text")).toBeNull();
    await settle();
    const calls = ext.calls.slice(before).filter((call) => call.args[2] === "rm" || call.args[2] === "apply");
    expect(calls.map((call) => [call.args[2], call.args[2] === "rm" ? call.args[4] : JSON.parse(call.stdin!).comments.map((c: any) => c.summary)])).toEqual([
      ["rm", "mcp:2"],
      ["rm", "mcp:1"],
      ["apply", ["new text"]],
      ["apply", ["saved reply"]],
    ]);
    expect(JSON.parse(calls[3]!.stdin!).comments).toEqual([{ replyTo: "mcp:3", summary: "saved reply", author: "Pi" }]);

    // Same keys, new text on the edited one, and remaps to the new host ids.
    expect(ext.stored().map((note) => [note.key, note.summary])).toEqual([
      [noteKey(1, "root"), "new text"],
      [noteKey(1, "reply"), "saved reply"],
    ]);
    const remaps = ext.journal.load().remaps.filter((remap) => ["mcp:3", "mcp:4"].includes(remap.to));
    expect(remaps.map((remap) => [remap.key, remap.to])).toEqual([
      [noteKey(1, "root"), "mcp:3"],
      [noteKey(1, "reply"), "mcp:4"],
    ]);
  });

  test("holds a load that lands mid-edit until the thread is back, so the thread is applied once", async () => {
    const ext = setup();
    ext.journal.append([{ op: "put", t: 1, note: saved("root", { source: "user", author: "you", summary: "old text" }) }]);
    ext.load();
    await settle();
    const ctx = editorCtx(ext, { notes: [user("mcp:1", { summary: "old text" })] });
    await ext.commands.get("note-edit")!(ctx);
    ext.state.duringRemove = () => {
      ext.state.duringRemove = () => {};
      ext.load();
    };
    const before = ext.calls.length;
    expect(await ext.editor.save("new text")).toBeNull();
    await settle();
    const applies = ext.calls.slice(before).filter((call) => call.args[2] === "apply");
    expect(applies.map((call) => JSON.parse(call.stdin!).comments.map((c: any) => c.summary))).toEqual([["new text"]]);
    // The held load still ran once the edit was done.
    expect(ext.calls.slice(before).filter((call) => call.args[2] === "list").length).toBeGreaterThan(0);
    expect(ext.state.live.map((note) => note.noteId)).toEqual(["mcp:2"]);
  });

  test("refuses to edit a thread whose root has no line, and removes nothing", async () => {
    const ext = setup();
    ext.load();
    const ctx = editorCtx(ext, { notes: [user("mcp:1", { summary: "old text" })] });
    await ext.commands.get("note-edit")!(ctx);
    ext.state.live.push({ noteId: "mcp:1", filePath: "a.ts" });
    const lineless = user("mcp:1", { summary: "old text", anchor: {} as any });
    ctx.review.snapshot = () => ({ files: [{ fileKey: "key-a", path: "a.ts" }], notes: [lineless] });
    const before = ext.calls.length;
    expect(await ext.editor.save("new text")).toBe("This thread has no line to put it back on");
    expect(ext.calls.slice(before).filter((call) => call.args[2] === "rm")).toEqual([]);
  });

  test("does not offer another author's note for editing", async () => {
    const ext = setup();
    ext.load();
    const ctx = editorCtx(ext, { notes: [snapshotNote("mcp:1", { source: "agent", author: "Pi" })] });
    await ext.commands.get("note-edit")!(ctx);
    expect(ctx.messages).toEqual(["No note of yours on this line"]);
    expect(ext.editor.current()).toBeNull();
  });

  test("offers a legacy Hunk user note for editing", async () => {
    const ext = setup();
    ext.load();
    const ctx = editorCtx(ext, { notes: [snapshotNote("user:1", { source: "user", author: undefined })] });
    await ext.commands.get("note-edit")!(ctx);
    expect(ext.editor.current()?.request).toMatchObject({ kind: "edit", note: { id: "user:1" } });
  });
});

describe("notes outside a `hunk stack` review", () => {
  const comparison = (base: string, head: string) => ({ kind: "comparison" as const, provider: "git", title: "range", base, head });
  const commitReview = (revision: string) => ({ kind: "commit" as const, provider: "git", title: "commit", revision });

  /** `feat` holds `first` then `second`; returns the shas, base first. */
  function twoCommits() {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feat");
    const base = repo.git("rev-parse", "HEAD");
    repo.commitFile("a.ts", "first");
    const first = repo.git("rev-parse", "HEAD");
    repo.commitFile("b.ts", "second");
    return { repo, base, first, second: repo.git("rev-parse", "HEAD") };
  }

  async function writeNote(ext: ReturnType<typeof setup>) {
    ext.fire("note_created", { note: { id: "user:1", filePath: "a.ts" } });
    ext.fire("note_changed", { kind: "created", note: snapshotNote("user:1") });
    await settle();
  }

  test("saves a note from a working-tree review on the branch, and restores it in the next one", async () => {
    const first = setup({ openStack: false });
    first.report(null);
    first.load();
    await writeNote(first);
    expect(first.stored()).toEqual([expect.objectContaining({ origin: { uncommitted: true, branch: "feat" }, lineText: "added one" })]);

    const next = setup({ dir: first.dir, repo: first.repo, openStack: false });
    next.report(null);
    next.load();
    await settle();
    expect(next.applies()).toHaveLength(1);
    expect(next.notices).toEqual(["stack: restored 1 saved note"]);
  });

  test("restores once the pane names the review, when `changeset_loaded` came first", async () => {
    const first = setup({ openStack: false });
    first.journal.append([{ op: "put", t: 1, note: saved("old", { origin: { uncommitted: true, branch: "feat" } }) }]);
    first.load();
    await settle();
    expect(first.applies()).toHaveLength(0);
    first.report(null);
    await settle();
    expect(first.applies()).toHaveLength(1);
  });

  test("a note written under `show <sha>` restores under that commit and under a range holding it, and waits elsewhere", async () => {
    const { repo, base, first, second } = twoCommits();
    const writer = setup({ repo, openStack: false });
    writer.report(commitReview(first));
    writer.load();
    await writeNote(writer);
    expect(writer.stored()[0]!.origin).toEqual({ commits: [{ sha: first, patchId: expect.any(String), subject: "first" }] });

    const restoredUnder = async (review: Parameters<typeof writer.report>[0]) => {
      const ext = setup({ dir: writer.dir, repo, openStack: false });
      ext.report(review);
      ext.load();
      await settle();
      return ext.applies().length;
    };
    expect(await restoredUnder(commitReview(first))).toBe(1);
    expect(await restoredUnder(comparison(base, second))).toBe(1);
    expect(await restoredUnder(comparison(first, second))).toBe(0);
    expect(await restoredUnder(commitReview(second))).toBe(0);
  });

  test("lists notes with no stack source, reporting origin and status without placement", async () => {
    const repo = makeRepo();
    repo.git("branch", "-m", "main", "dev");
    const ext = setup({ repo, openStack: false });
    ext.journal.append([{ op: "put", t: 1, note: saved("n") }]);
    const thread = JSON.parse((await ext.runCli(["notes", "list", "--json"])).out).threads[0];
    expect(thread).toMatchObject({ origin: { commits: [FEATURE] }, status: "open", waitingOn: "user", placement: [] });
  });
});

describe("thread status", () => {
  const root = () => ({ op: "put" as const, t: 1, note: saved("root") });
  const reply = () => ({ op: "put" as const, t: 2, note: saved("reply", { parentKey: noteKey(1, "root"), source: "user", author: "me", summary: "why?" }) });
  const status = (state: "open" | "resolved") => ({ op: "status" as const, t: 9, key: noteKey(1, "root"), status: state });

  test("takes a resolved thread out of the host, replies first, without journaling a removal", async () => {
    const ext = setup();
    ext.journal.append([root(), reply()]);
    ext.load();
    await settle();
    expect(ext.state.live.map((note) => note.noteId)).toEqual(["mcp:1", "mcp:2"]);

    ext.journal.append([status("resolved")]);
    ext.load();
    await settle();
    expect(ext.calls.filter((call) => call.args[2] === "rm").map((call) => call.args.slice(3))).toEqual([
      ["mine", "mcp:2", "--json"],
      ["mine", "mcp:1", "--json"],
    ]);
    expect(ext.state.live).toEqual([]);
    expect(ext.stored().map((note) => note.id)).toEqual(["root", "reply"]);
    expect(readFileSync(join(ext.dir, "notes", journalFileName(ext.root)), "utf8")).not.toContain('"op":"remove"');
    // And it stays out on the next load.
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(2);
  });

  test("does not apply a resolved thread, and applies it again once reopened", async () => {
    const ext = setup();
    ext.journal.append([root(), status("resolved")]);
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(0);
    ext.journal.append([status("open")]);
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(1);
  });

  test("lists a resolved thread under its own status, and loads it for the session when chosen", async () => {
    const ext = setup();
    ext.journal.append([root(), reply(), status("resolved")]);
    ext.load();
    await settle();
    const ctx = ctxFor(ext, { choose: "resolved  a.ts:2  Pi  saved root" });
    await ext.commands.get("show-saved-notes")!(ctx);
    expect(ext.dialogs[0]).toEqual({
      title: "Saved notes: 0 shown, 0 pending, 0 outdated, 1 resolved",
      options: ["resolved  a.ts:2  Pi  saved root"],
    });
    await settle();
    expect(ext.applies()).toHaveLength(2);
    // Journaled status is unchanged, so the next process hides it again.
    expect(ext.journal.load().statuses.get(noteKey(1, "root"))?.status).toBe("resolved");
  });

  test("keeps a thread the reviewer loaded in the diff through later restores", async () => {
    const ext = setup();
    ext.journal.append([root(), status("resolved")]);
    ext.load();
    await settle();
    await ext.commands.get("show-saved-notes")!(ctxFor(ext, { choose: "resolved  a.ts:2  Pi  saved root" }));
    await settle();
    ext.load();
    await settle();
    expect(ext.calls.filter((call) => call.args[2] === "rm")).toEqual([]);
  });
});

describe("hunk stack notes", () => {
  const root = (id = "root") => ({ op: "put" as const, t: 1, note: saved(id) });
  const userReply = () => ({ op: "put" as const, t: 2, note: saved("reply", { parentKey: noteKey(1, "root"), source: "user", author: "me", summary: "why?" }) });

  test("lists threads as JSON with origin, status, who they wait on, placement, and replies", async () => {
    const ext = setup({ openStack: false });
    ext.journal.append([root(), userReply(), { op: "remap", t: 3, pid: 77, key: noteKey(1, "root"), to: "mcp:5" }]);
    const { result, out } = await ext.runCli(["notes", "list", "--json"]);
    expect(result).toEqual({ kind: "exit" });
    const [thread, ...rest] = JSON.parse(out).threads;
    expect(rest).toEqual([]);
    expect(thread).toMatchObject({
      key: noteKey(1, "root"),
      path: "a.ts",
      line: 2,
      origin: { commits: [FEATURE] },
      status: "open",
      waitingOn: "agent",
      hostIds: [{ pid: 1, id: "root" }, { pid: 77, id: "mcp:5" }],
      replies: [{ key: noteKey(1, "reply"), source: "user", summary: "why?" }],
    });
    // Both zooms of the one-commit stack hold the origin; the note's line is not in the commit's diff.
    expect(thread.placement.map((entry: { zoom: string; state: string }) => [entry.zoom, entry.state])).toEqual([
      ["combined", "outdated"],
      ["commit", "outdated"],
    ]);
  });

  test("waits on the user when the last word was the agent's", async () => {
    const ext = setup({ openStack: false });
    ext.journal.append([root()]);
    const { out } = await ext.runCli(["notes", "list", "--json"]);
    expect(JSON.parse(out).threads[0].waitingOn).toBe("user");
  });

  test("resolves a thread with the commit that fixed it, and reopens it", async () => {
    const ext = setup({ openStack: false });
    ext.journal.append([root()]);
    const sha = ext.repo.git("rev-parse", "HEAD");
    const resolved = await ext.runCli(["notes", "resolve", noteKey(1, "root"), "--commit", sha]);
    expect(resolved.result).toEqual({ kind: "exit" });
    expect(resolved.out).toBe(`Resolved ${noteKey(1, "root")} by ${sha.slice(0, 8)} feature work\n`);
    expect(ext.journal.load().statuses.get(noteKey(1, "root"))).toEqual({
      status: "resolved",
      fix: { sha, patchId: expect.any(String), subject: "feature work", branch: "feat" },
    });

    const listed = JSON.parse((await ext.runCli(["notes", "list", "--json"])).out).threads[0];
    expect(listed).toMatchObject({ status: "resolved", waitingOn: null, fix: { sha, subject: "feature work" }, fixNow: sha });

    const reopened = await ext.runCli(["notes", "reopen", noteKey(1, "root")]);
    expect(reopened.out).toBe(`Reopened ${noteKey(1, "root")}\n`);
    expect(ext.journal.load().statuses.get(noteKey(1, "root"))).toEqual({ status: "open" });
  });

  test("refuses a reply's key, an unknown key, and a commit git does not have", async () => {
    const ext = setup({ openStack: false });
    ext.journal.append([root(), userReply()]);
    const reply = await ext.runCli(["notes", "resolve", noteKey(1, "reply")]);
    expect(reply.result).toEqual({ kind: "exit", code: 1 });
    expect(reply.err).toBe(`hunk stack notes: ${noteKey(1, "reply")} is a reply; use its thread's key ${noteKey(1, "root")}\n`);
    expect((await ext.runCli(["notes", "reopen", "9:nope"])).err).toBe("hunk stack notes: no saved note with key 9:nope\n");
    expect((await ext.runCli(["notes", "resolve", noteKey(1, "root"), "--commit", "deadbeef"])).err).toContain("is not a commit");
    expect(ext.journal.load().statuses.size).toBe(0);
  });

  test("prints a readable list and says so when nothing is saved", async () => {
    const ext = setup({ openStack: false });
    expect((await ext.runCli(["notes", "list"])).out).toBe("No saved notes\n");
    ext.journal.append([root(), userReply()]);
    const { out } = await ext.runCli(["notes", "list"]);
    expect(out).toContain(`${noteKey(1, "root")}  open  waiting on agent  a.ts:2  saved root\n`);
    expect(out).toContain("    me: why?\n");
  });

  test("works without a live session, and the live extension picks the change up on its next load", async () => {
    const ext = setup();
    ext.state.sessionUp = false;
    ext.journal.append([root()]);
    await ext.runCli(["notes", "resolve", noteKey(1, "root")]);
    expect(ext.calls).toEqual([]);
    ext.state.sessionUp = true;
    ext.load();
    await settle();
    expect(ext.applies()).toHaveLength(0);
  });

  test("answers to persist = false and to a bad subcommand", async () => {
    const off = setup({ config: { persist: false }, openStack: false });
    expect((await off.runCli(["notes", "list"])).err).toContain("persist = false");
    const ext = setup({ openStack: false });
    expect((await ext.runCli(["notes", "frob"])).result).toEqual({ kind: "exit", code: 1 });
  });
});

describe("show-saved-notes", () => {
  /** A journal with one note of each status once `a.ts` loads: shown, pending, outdated. */
  async function threeNotes() {
    const ext = setup();
    ext.journal.append([
      { op: "put", t: 1, note: saved("here") },
      { op: "put", t: 2, note: saved("later", { path: "b.ts", line: 8 }) },
      { op: "put", t: 3, note: saved("gone", { lineText: "deleted since", line: 3 }) },
      { op: "put", t: 4, note: saved("gone-reply", { parentKey: noteKey(1, "gone"), summary: "under gone" }) },
    ]);
    ext.load();
    await settle();
    return ext;
  }

  test("lists every saved note under its status, with a row that clears the outdated ones", async () => {
    const ext = await threeNotes();
    await ext.commands.get("show-saved-notes")!(ctxFor(ext));
    expect(ext.dialogs).toEqual([
      {
        title: "Saved notes: 1 shown, 1 pending, 2 outdated, 0 resolved",
        options: [
          "Delete all 2 outdated notes",
          "shown     a.ts:2  Pi  saved here",
          "pending   b.ts:8  Pi  saved later",
          "outdated  a.ts:3  Pi  saved gone",
          "outdated  a.ts:2  Pi  under gone",
        ],
      },
    ]);
  });

  test("jumps to a shown note's line", async () => {
    const ext = await threeNotes();
    const ctx = ctxFor(ext, { choose: "shown     a.ts:2  Pi  saved here" });
    await ext.commands.get("show-saved-notes")!(ctx);
    expect(ctx.jumps).toEqual([["rt:a.ts", "new", 2]]);
  });

  test("says so when no other changeset in the stack holds a pending note's origin", async () => {
    const ext = await threeNotes();
    const ctx = ctxFor(ext, { choose: "pending   b.ts:8  Pi  saved later" });
    await ext.commands.get("show-saved-notes")!(ctx);
    expect(ctx.messages).toEqual(["No other changeset in the stack holds what this note was written on (b.ts)"]);
    expect(ext.stored().map((note) => note.id)).toContain("later");
  });

  test("loads the narrowest changeset that holds a pending note's origin, not the first that touches its file", async () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feat");
    repo.commitFile("a.ts", "first");
    repo.write("a.ts", "v2\n");
    repo.git("commit", "-qam", "second");
    repo.commitFile("b.ts", "third");
    const ext = setup({ repo });
    const second = repo.git("rev-parse", "HEAD~1");
    ext.journal.append([{ op: "put", t: 1, note: saved("n", { origin: { commits: [{ sha: second, subject: "second", branch: "feat" }] } }) }]);
    ext.load([sourceFile("b.ts")]);
    await settle();
    const ctx = ctxFor(ext, { choose: "pending   a.ts:2  Pi  saved n" });
    await ext.commands.get("show-saved-notes")!(ctx);
    const reload = ext.calls.find((call) => call.args[1] === "reload")!;
    expect(reload.args.slice(5)).toEqual(["diff", `${repo.git("rev-parse", "HEAD~2")}..${second}`]);
  });

  test("deletes an outdated note and its replies once confirmed", async () => {
    const ext = await threeNotes();
    const choose = "outdated  a.ts:3  Pi  saved gone";
    await ext.commands.get("show-saved-notes")!(ctxFor(ext, { choose, confirm: false }));
    expect(ext.stored().map((note) => note.id)).toEqual(["here", "later", "gone", "gone-reply"]);

    const ctx = ctxFor(ext, { choose, confirm: true });
    await ext.commands.get("show-saved-notes")!(ctx);
    expect(ext.stored().map((note) => note.id)).toEqual(["here", "later"]);
    expect(ctx.messages).toEqual(["Deleted 1 saved note"]);
  });

  test("clears every outdated note from the first row", async () => {
    const ext = await threeNotes();
    const ctx = ctxFor(ext, { choose: "Delete all 2 outdated notes", confirm: true });
    await ext.commands.get("show-saved-notes")!(ctx);
    expect(ext.stored().map((note) => note.id)).toEqual(["here", "later"]);
    expect(ctx.messages).toEqual(["Deleted 2 saved notes"]);
  });

  test("says so when nothing is saved", async () => {
    const ext = setup();
    ext.load();
    const ctx = ctxFor(ext);
    await ext.commands.get("show-saved-notes")!(ctx);
    expect(ctx.messages).toEqual(["No saved notes"]);
    expect(ext.dialogs).toEqual([]);
  });
});

function ctxFor(ext: ReturnType<typeof setup>, answers: { choose?: string; confirm?: boolean } = {}) {
  const messages: string[] = [];
  const jumps: unknown[][] = [];
  return {
    cwd: ext.root,
    messages,
    jumps,
    notify: (message: string) => void messages.push(message),
    review: { snapshot: () => ({ files: [{ fileKey: "key-a", path: "a.ts", runtimeId: "rt:a.ts" }] }) },
    navigation: {
      revealLine: (...args: unknown[]) => void jumps.push(args),
      selectFile: (...args: unknown[]) => void jumps.push(args),
    },
    dialogs: {
      select: async (options: { title: string; options: readonly string[] }) => (ext.dialogs.push(options), answers.choose ?? null),
      confirm: async () => answers.confirm ?? false,
    },
  };
}
