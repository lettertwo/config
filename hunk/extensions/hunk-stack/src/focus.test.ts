import { describe, expect, it } from "bun:test";
import type { ExtensionDiffFile, ExtensionKeyEvent } from "hunkdiff/extension";
import { OutlineFocus, type FocusHost, type NavRow } from "./focus";

const header = (changesetId: string): NavRow => ({
  entryId: `changeset:${changesetId}`,
  changesetId,
  path: null,
  fileId: null,
});
const loadedFile = (changesetId: string, path: string, fileId: string): NavRow => ({
  entryId: fileId,
  changesetId,
  path,
  fileId,
});
const otherFile = (changesetId: string, path: string): NavRow => ({
  entryId: `${changesetId}|listed:${path}`,
  changesetId,
  path,
  fileId: null,
});

const file = (id: string, path: string) => ({ id, path }) as ExtensionDiffFile;

/** a: unloaded with two files, b: loaded with two files, c: unloaded and collapsed. */
const ROWS: NavRow[] = [
  header("a"),
  otherFile("a", "a1.ts"),
  otherFile("a", "a2.ts"),
  header("b"),
  loadedFile("b", "b1.ts", "f:1"),
  loadedFile("b", "b2.ts", "f:2"),
  header("c"),
];
const FILES = [file("f:1", "b1.ts"), file("f:2", "b2.ts")];

const key = (name: string, extra: Partial<ExtensionKeyEvent> = {}): ExtensionKeyEvent => ({ name, ...extra });

function setup(selectedFileId: string | null = "f:2", pendingId: string | null = null) {
  const log = {
    selected: [] as string[],
    read: [] as string[],
    expanded: [] as [string, boolean][],
    opened: [] as [string, string][],
  };
  const expanded = new Set(["b"]);
  const host: FocusHost = {
    toggleRead: (f) => log.read.push(f.path),
    isExpanded: (id) => expanded.has(id),
    setExpanded: (id, to) => {
      log.expanded.push([id, to]);
    },
    openFile: (id, path) => log.opened.push([id, path]),
  };
  // The deferred load waits until the test says the cursor has rested.
  let deferred: (() => void) | null = null;
  const focus = new OutlineFocus(host, (run) => {
    deferred = run;
    return () => {
      if (deferred === run) {
        deferred = null;
      }
    };
  });
  const rest = () => {
    const run = deferred;
    deferred = null;
    run?.();
  };
  focus.attach({
    actions: { selectFile: (id) => log.selected.push(id) },
    files: FILES,
    selectedFileId,
    loadedId: "b",
    pendingId,
  });
  focus.publishRows(ROWS);
  focus.enter();
  const at = () => focus.getSnapshot().cursorEntryId;
  const press = (name: string, extra?: Partial<ExtensionKeyEvent>) => focus.handleKey(key(name, extra));
  return { focus, log, at, press, rest };
}

describe("OutlineFocus", () => {
  it("places the cursor once a pane opened by the focus command draws its rows", () => {
    const host: FocusHost = { toggleRead: () => {}, isExpanded: () => true, setExpanded: () => {}, openFile: () => {} };
    const focus = new OutlineFocus(host);
    focus.enter();
    expect(focus.getSnapshot()).toEqual({ active: true, cursorEntryId: null });
    focus.attach({ actions: { selectFile: () => {} }, files: FILES, selectedFileId: "f:2", loadedId: "b", pendingId: null });
    focus.publishRows(ROWS);
    expect(focus.getSnapshot().cursorEntryId).toBe("f:2");
  });

  it("enters on the selected file, and on the first row when none is selected", () => {
    expect(setup("f:2").at()).toBe("f:2");
    expect(setup(null).at()).toBe("changeset:a");
    expect(setup().focus.getSnapshot().active).toBe(true);
  });

  it("moves with j/k and arrows, clamps at the ends, and jumps with g and G", () => {
    const { press, at } = setup("f:1");
    expect(press("j")).toBe("handled");
    expect(at()).toBe("f:2");
    press("down");
    expect(at()).toBe("changeset:c");
    press("j");
    expect(at()).toBe("changeset:c");
    press("g");
    expect(at()).toBe("changeset:a");
    press("k");
    expect(at()).toBe("changeset:a");
    expect(press("g", { shift: true, sequence: "G" })).toBe("handled");
    expect(at()).toBe("changeset:c");
    press("up");
    expect(at()).toBe("f:2");
  });

  it("selects loaded files at once and leaves the loaded header alone", () => {
    const { press, log, rest } = setup("f:1");
    press("j");
    press("k");
    press("k");
    rest();
    expect(log.selected).toEqual(["f:2", "f:1"]);
    expect(log.opened).toEqual([]);
  });

  it("loads another changeset once the cursor rests on one of its files", () => {
    const { press, log, rest } = setup("f:1");
    press("k");
    press("k");
    expect(log.opened).toEqual([]);
    rest();
    expect(log.opened).toEqual([["a", "a2.ts"]]);
  });

  it("loads nothing from a header of another changeset", () => {
    const { press, log, rest } = setup("f:2");
    press("j");
    rest();
    press("g");
    rest();
    expect(log.opened).toEqual([]);
  });

  it("loads only the row the cursor stops on when walking past changesets", () => {
    const { press, log, rest } = setup("f:1");
    press("k");
    press("k");
    press("k");
    rest();
    expect(log.opened).toEqual([["a", "a1.ts"]]);
  });

  it("drops a deferred load when the cursor comes back before it runs", () => {
    const { press, log, rest } = setup("f:2");
    press("j");
    press("k");
    rest();
    expect(log.opened).toEqual([]);
    expect(log.selected).toEqual(["f:2"]);
  });

  it("reloads the loaded changeset when coming back while another is on its way", () => {
    const { press, log, rest } = setup("f:2", "c");
    press("k");
    expect(log.selected).toEqual([]);
    rest();
    expect(log.opened).toEqual([["b", "b1.ts"]]);
  });

  it("opens a file of another changeset on enter and selects a loaded one", () => {
    const { press, log, rest } = setup("f:1");
    press("g");
    press("j");
    press("enter");
    rest();
    expect(log.opened).toEqual([["a", "a1.ts"]]);
    press("g");
    press("return");
    expect(log.expanded).toEqual([["a", true]]);
    for (let i = 0; i < 4; i++) {
      press("j");
    }
    log.selected.length = 0;
    press("enter");
    expect(log.selected).toEqual(["f:1"]);
    expect(log.opened).toHaveLength(1);
  });

  it("exits to the diff when enter opens a file, and stays on a header", () => {
    const { press } = setup("f:1");
    press("g");
    expect(press("enter")).toBe("handled");
    press("j");
    expect(press("enter")).toBe("exit");
  });

  it("toggles a header on enter, expands on l, collapses on h", () => {
    const { press, log } = setup("f:1");
    press("g");
    press("l");
    press("h");
    press("j");
    press("j");
    press("j");
    press("h");
    expect(log.expanded).toEqual([
      ["a", true],
      ["a", false],
      ["b", false],
    ]);
  });

  it("moves a file row's cursor to its header on h, and ignores l there", () => {
    const { press, at, log } = setup("f:2");
    press("h");
    expect(at()).toBe("changeset:b");
    expect(log.expanded).toEqual([]);
    press("j");
    expect(press("l")).toBe("handled");
    expect(log.expanded).toEqual([]);
    press("h");
    press("h");
    expect(log.expanded).toEqual([["b", false]]);
  });

  it("toggles read on loaded files and swallows space elsewhere", () => {
    const { press, log } = setup("f:2");
    expect(press("space")).toBe("handled");
    expect(log.read).toEqual(["b2.ts"]);
    press("g");
    expect(press("space")).toBe("handled");
    press("j");
    expect(press("space")).toBe("handled");
    expect(log.read).toEqual(["b2.ts"]);
  });

  it("exits on escape, q, and tab; passes everything else", () => {
    const { press } = setup();
    expect(["escape", "q", "tab"].map((name) => press(name))).toEqual(["exit", "exit", "exit"]);
    for (const [name, extra] of [
      ["9", { shift: true, sequence: "(" }],
      ["0", { shift: true, sequence: ")" }],
      ["i", {}],
      ["/", { shift: true, sequence: "?" }],
      ["d", { ctrl: true }],
      ["j", { shift: true, sequence: "J" }],
      ["x", {}],
    ] as const) {
      expect(press(name, extra)).toBe("pass");
    }
  });

  it("keeps the cursor on the same file when rows renumber after a reload", () => {
    const { focus, at } = setup("f:2");
    focus.publishRows([
      header("a"),
      otherFile("a", "a1.ts"),
      header("b"),
      loadedFile("b", "b1.ts", "f:7"),
      loadedFile("b", "b2.ts", "f:8"),
    ]);
    expect(at()).toBe("f:8");
  });

  it("keeps the cursor on a file that moved from another changeset to the loaded one", () => {
    const { focus, press, at } = setup("f:1");
    press("g");
    press("j");
    expect(at()).toBe("a|listed:a1.ts");
    focus.attach({ actions: { selectFile() {} }, files: [file("f:9", "a1.ts")], selectedFileId: "f:9", loadedId: "a", pendingId: null });
    focus.publishRows([header("a"), loadedFile("a", "a1.ts", "f:9"), header("b")]);
    expect(at()).toBe("f:9");
  });

  it("falls back to the header when the file is gone, and to the first row when the changeset is", () => {
    const { focus, at } = setup("f:2");
    focus.publishRows([header("a"), header("b"), header("c")]);
    expect(at()).toBe("changeset:b");
    focus.publishRows([header("a"), header("c")]);
    expect(at()).toBe("changeset:a");
  });

  it("paints no cursor once the mode is left", () => {
    const { focus, at } = setup();
    focus.leave();
    expect(at()).toBeNull();
    expect(focus.getSnapshot().active).toBe(false);
  });

  it("notifies subscribers only when the painted row changes", () => {
    const { focus, press } = setup("f:1");
    let calls = 0;
    focus.subscribe(() => (calls += 1));
    press("j");
    expect(calls).toBe(1);
    focus.publishRows(ROWS);
    expect(calls).toBe(1);
  });

  it("reports whether a pane is attached with rows to walk", () => {
    const focus = new OutlineFocus({} as FocusHost);
    expect(focus.hasPane()).toBe(false);
    focus.attach({ actions: { selectFile() {} }, files: [], selectedFileId: null, loadedId: null, pendingId: null });
    expect(focus.hasPane()).toBe(false);
    focus.publishRows(ROWS);
    expect(focus.hasPane()).toBe(true);
  });
});
