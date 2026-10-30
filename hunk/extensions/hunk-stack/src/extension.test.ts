import { afterEach, describe, expect, test } from "bun:test";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type {
  ChangesetTransform,
  ExtensionChangeset,
  ExtensionCommandContext,
  ExtensionCliCommandHandler,
  ExtensionCommandHandler,
  ExtensionDiffFile,
  ExtensionKeyboardMode,
  ExtensionLineHighlighter,
  ExtensionPane,
  ExtensionStatusItem,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { paneWidth, registerStack } from "./extension";
import { NOT_A_STACK } from "./state";
import { makeRepo } from "./stack/testRepo";

const tempDirs: string[] = [];
afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    rmSync(dir, { recursive: true, force: true });
  }
});

/** A fresh session folder that the test cleans up. */
function tempSessionDir() {
  const dir = mkdtempSync(join(tmpdir(), "mark-read-ext-"));
  tempDirs.push(dir);
  return join(dir, "sessions");
}

/** Build a reviewed file whose patch changes one line. */
function diffFile(index: number, path: string): ExtensionDiffFile {
  return {
    id: `file:${index}:${path}`,
    path,
    patch: `@@ -1 +1 @@\n-old ${path}\n+new ${path}\n`,
    stats: { additions: 1, deletions: 1 },
    metadata: { type: "change" },
    agent: null,
  };
}

/** Load the extension against a recording fake of the Hunk API. */
function loadExtension({
  sessionDir = tempSessionDir(),
  config = {} as Record<string, unknown>,
  extraFiles = [] as ExtensionDiffFile[],
  moveWindow = async (_direction: "left" | "right") => null as string | null,
} = {}) {
  const commands = new Map<
    string,
    { key?: string | readonly string[]; handler: ExtensionCommandHandler }
  >();
  const panes: ExtensionPane[] = [];
  const cliCommands = new Map<string, ExtensionCliCommandHandler>();
  const modes = new Map<string, ExtensionKeyboardMode>();
  const highlighters: ExtensionLineHighlighter[] = [];
  const transforms: ChangesetTransform[] = [];
  const status = new Map<string, ExtensionStatusItem>();
  const api = {
    registerCommand: (command, handler) => commands.set(command.id, { key: command.key, handler }),
    registerPane: (pane) => panes.push(pane),
    registerCliCommand: (command, handler) => cliCommands.set(command.name, handler),
    registerLineHighlighter: (highlighter) => highlighters.push(highlighter),
    registerKeyboardMode: (mode) => modes.set(mode.id, mode),
    transformChangeset: (fn) => transforms.push(fn),
    on: () => {},
    config,
  } as Partial<HunkExtensionAPI> as HunkExtensionAPI;
  registerStack(api, { sessionDir, moveWindow });

  const files = [
    ...["src/a.ts", "src/b.ts", "src/lib/c.ts", "docs/readme.md"].map((path, index) =>
      diffFile(index, path),
    ),
    ...extraFiles,
  ];
  let visible = files;

  /** Run the transform the way a (re)load does. */
  const load = async () => {
    const changeset: ExtensionChangeset = { id: "cs", sourceLabel: "repo", title: "t", files };
    visible = (await transforms[0]!(changeset, { cwd: "/", notify: () => {} })).files;
  };

  /** Fire one command with the given file selected; returns what the command did. */
  const run = (commandId: string, selectedPath: string | null, activeMode: string | null = null) => {
    const effects = {
      selected: null as string | null,
      refreshed: 0,
      reloaded: 0,
      notes: [] as string[],
    };
    const ctx = {
      cwd: "/",
      notify: (message: string) => effects.notes.push(message),
      selection: {
        file: visible.find((file) => file.path === selectedPath) ?? null,
        hunkIndex: 0,
        currentLine: null,
        files: visible,
      },
      navigation: { selectFile: (id: string) => (effects.selected = id) },
      keyboardModes: {
        enterMode: (id: string) => ((activeMode = id), true),
        exitMode: () => ((activeMode = null), true),
        isActive: (id?: string) => activeMode !== null && (id === undefined || id === activeMode),
      },
      highlights: { refresh: () => (effects.refreshed += 1) },
      statusLine: {
        set: (item: ExtensionStatusItem) => status.set(item.id, item),
        clear: () => {},
      },
      commands: {
        execute: (id: string) => {
          if (id === "hunk.app.refresh") {
            effects.reloaded += 1;
            return true;
          }
          return false;
        },
      },
    } as unknown as ExtensionCommandContext;
    const done = commands.get(commandId)!.handler(ctx);
    return Object.assign(effects, { done, mode: () => activeMode });
  };

  const isDimmed = async (path: string) => {
    const file = files.find((candidate) => candidate.path === path)!;
    const marks = await highlighters[0]!.highlight({
      file,
      signal: new AbortController().signal,
      readDocument: async () => null,
    });
    return (marks?.length ?? 0) > 0;
  };

  return {
    cliCommands,
    commands,
    modes,
    panes,
    status,
    files,
    load,
    run,
    isDimmed,
    sessionDir,
    visible: () => visible,
  };
}

/** Run the `hunk stack` CLI handler the way hunk does before any review starts. */
async function runCli(ext: ReturnType<typeof loadExtension>, cwd: string, args: string[]) {
  let stderr = "";
  const writer = (sink: (chunk: string) => void) => ({
    write: async (chunk: string | Uint8Array) => sink(String(chunk)),
  });
  const result = await ext.cliCommands.get("stack")!(args, {
    cwd,
    signal: new AbortController().signal,
    stdin: (async function* () {})(),
    stdout: writer(() => {}),
    stderr: writer((chunk) => (stderr += chunk)),
  });
  return { result, stderr };
}

describe("stack extension", () => {
  test("registers the agreed keys and replaces the files pane", () => {
    const ext = loadExtension();
    expect(ext.commands.get("toggle")?.key).toBe("x");
    expect(ext.commands.get("next-unread")?.key).toBe("X");
    expect(ext.commands.get("toggle-hidden")?.key).toBe("H");
    expect(ext.panes[0]?.replaces).toBe("hunk:files");
  });

  test("sizes the pane from the width setting", () => {
    expect(loadExtension({ config: { width: 40 } }).panes[0]?.width).toEqual({ preferred: 40, min: 22, max: 56 });
    expect(loadExtension().panes[0]?.width).toEqual(paneWidth(undefined).size);
  });

  test("reads width as whole columns from 1 up and a fraction below 1", () => {
    expect(paneWidth(0.25).size).toEqual({ preferred: 34, min: 22, max: 56, fraction: 0.25 });
    expect(paneWidth(80).size).toEqual({ preferred: 80, min: 22, max: 80 });
    expect(paneWidth(12).size).toEqual({ preferred: 12, min: 12, max: 56 });
    for (const bad of [0, -3, 1.5, "40", null]) {
      const width = paneWidth(bad);
      expect(width.size).toEqual(paneWidth(undefined).size);
      expect(width.error).toContain("using the default");
    }
  });

  test("hunk stack delegates to the changeset the review opens on", async () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "a1");
    repo.commitFile("a1x.txt", "a1: add x");
    repo.writeGhStack({ schemaVersion: 1, stacks: [{ trunk: { branch: "main" }, branches: [{ branch: "a1" }] }] });
    const base = repo.git("rev-parse", "main").trim();
    const head = repo.git("rev-parse", "a1").trim();

    const result = await runCli(loadExtension(), repo.cwd, ["--mode", "split"]);
    expect(result).toEqual({ result: { kind: "delegate", argv: ["diff", `${base}..${head}`, "--mode", "split"] }, stderr: "" });
  });

  test("hunk stack exits with the reason outside a git repo", async () => {
    const result = await runCli(loadExtension(), "/", []);
    expect(result).toEqual({ result: { kind: "exit", code: 1 }, stderr: "hunk stack: not a git repository\n" });
  });

  test("other hunk commands get no stack", () => {
    const ext = loadExtension();
    expect(ext.run("next-changeset", "src/a.ts").notes).toEqual([NOT_A_STACK]);
  });

  test("focus-outline is bound to tab and enters the outline mode", () => {
    const ext = loadExtension();
    expect(ext.commands.get("focus-outline")?.key).toBe("tab");
    expect(ext.modes.get("outline")?.title).toContain("Outline");
  });

  test("ctrl+h and ctrl+l leave hunk when there is no outline to move to or from", async () => {
    const moves: string[] = [];
    const ext = loadExtension({ moveWindow: async (direction) => (moves.push(direction), null) });
    expect(ext.commands.get("focus-outline-or-left")?.key).toBe("ctrl+h");
    expect(ext.commands.get("focus-diff-or-right")?.key).toBe("ctrl+l");
    const left = ext.run("focus-outline-or-left", "src/a.ts");
    await left.done;
    expect(left.mode()).toBeNull();
    await ext.run("focus-diff-or-right", "src/a.ts").done;
    expect(moves).toEqual(["left", "right"]);
  });

  test("ctrl+l from the outline focuses the diff", async () => {
    const moves: string[] = [];
    const ext = loadExtension({ moveWindow: async (direction) => (moves.push(direction), null) });
    const effects = ext.run("focus-diff-or-right", "src/a.ts", "outline");
    await effects.done;
    expect(effects.mode()).toBeNull();
    expect(moves).toEqual([]);
  });

  test("a failed move says why", async () => {
    const ext = loadExtension({ moveWindow: async () => "stack: kitten @ action failed: nope" });
    const effects = ext.run("focus-diff-or-right", "src/a.ts");
    await effects.done;
    expect(effects.notes).toEqual(["stack: kitten @ action failed: nope"]);
  });

  test("x marks, dims, and jumps to the next unread file; x again unmarks in place", async () => {
    const ext = loadExtension();
    await ext.load();

    const marked = ext.run("toggle", "src/a.ts");
    expect(marked.selected).toBe("file:1:src/b.ts");
    expect(marked.refreshed).toBe(1);
    expect(await ext.isDimmed("src/a.ts")).toBe(true);
    expect(await ext.isDimmed("src/b.ts")).toBe(false);
    expect(ext.status.get("progress")?.spans[0]?.text).toBe("1/4 read");

    const unmarked = ext.run("toggle", "src/a.ts");
    expect(unmarked.selected).toBeNull();
    expect(await ext.isDimmed("src/a.ts")).toBe(false);
    expect(ext.status.get("progress")?.spans[0]?.text).toBe("0/4 read");
  });

  test("X skips read files and wraps; everything read stays put", async () => {
    const ext = loadExtension();
    await ext.load();
    ext.run("toggle", "src/b.ts");

    expect(ext.run("next-unread", "src/a.ts").selected).toBe("file:2:src/lib/c.ts");
    expect(ext.run("next-unread", "docs/readme.md").selected).toBe("file:0:src/a.ts");

    ext.run("toggle", "src/a.ts");
    ext.run("toggle", "src/lib/c.ts");
    const last = ext.run("toggle", "docs/readme.md");
    expect(last.selected).toBeNull();
    expect(last.notes).toContain("✓ all 4 read");
    expect(ext.status.get("progress")?.spans[0]?.text).toBe("✓ all 4 read");
    expect(ext.run("next-unread", "src/a.ts").selected).toBeNull();
  });

  test("H hides read files through a refresh and shows them again", async () => {
    const ext = loadExtension();
    await ext.load();
    ext.run("toggle", "src/a.ts");

    expect(ext.run("toggle-hidden", "src/b.ts").reloaded).toBe(1);
    await ext.load();
    expect(ext.visible().map((file) => file.path)).toEqual([
      "src/b.ts",
      "src/lib/c.ts",
      "docs/readme.md",
    ]);
    // Progress still counts the hidden file.
    expect(ext.status.get("progress")?.spans[0]?.text).toBe("1/4 read");

    // Marking while hidden reloads so the file drops out.
    expect(ext.run("toggle", "src/b.ts").reloaded).toBe(1);
    await ext.load();
    expect(ext.visible().map((file) => file.path)).toEqual(["src/lib/c.ts", "docs/readme.md"]);

    ext.run("toggle-hidden", "src/lib/c.ts");
    await ext.load();
    expect(ext.visible()).toHaveLength(4);
  });

  test("hiding when everything is read says so", async () => {
    const ext = loadExtension();
    await ext.load();
    for (const file of ext.files) {
      ext.run("toggle", file.path);
    }
    expect(ext.run("toggle-hidden", "src/a.ts").notes).toContain(
      "All files read, read files are hidden",
    );
  });
});

describe("saving marks", () => {
  test("marks survive into the next Hunk session for the same diffs", async () => {
    const first = loadExtension();
    await first.load();
    first.run("toggle", "src/a.ts");
    first.run("toggle", "src/lib/c.ts");
    expect(existsSync(first.sessionDir)).toBe(true);

    const second = loadExtension({ sessionDir: first.sessionDir });
    await second.load();
    expect(await second.isDimmed("src/a.ts")).toBe(true);
    expect(await second.isDimmed("src/b.ts")).toBe(false);
    expect(second.run("next-unread", "src/a.ts").selected).toBe("file:1:src/b.ts");
  });

  test("a reload picks up marks another open session saved", async () => {
    const first = loadExtension();
    const second = loadExtension({ sessionDir: first.sessionDir });
    await first.load();
    await second.load();

    first.run("toggle", "src/b.ts");
    expect(await second.isDimmed("src/b.ts")).toBe(false);
    await second.load();
    expect(await second.isDimmed("src/b.ts")).toBe(true);

    // An unmark in the second session wins over the earlier mark.
    second.run("toggle", "src/b.ts");
    await first.load();
    expect(await first.isDimmed("src/b.ts")).toBe(false);
  });

  test("persist = false keeps marks for the session only", async () => {
    const ext = loadExtension({ config: { persist: false } });
    await ext.load();
    ext.run("toggle", "src/a.ts");
    expect(existsSync(ext.sessionDir)).toBe(false);
    await ext.load();
    expect(await ext.isDimmed("src/a.ts")).toBe(true);
  });
});

describe("files whose changes cannot be detected", () => {
  test("escape control characters from the path in the refusal message", async () => {
    const hostile = { ...diffFile(8, "evil\u001b]0;pwned\u0007.bin"), patch: "" };
    const ext = loadExtension({ extraFiles: [hostile] });
    await ext.load();
    const [note] = ext.run("toggle", hostile.path).notes;
    expect(note).toBe("Can't detect changes to evil\\x1b]0;pwned\\x07.bin, not marked");
    expect(note).not.toContain("\u001b");
  });

  const tooLarge = { ...diffFile(9, "assets/huge.bin"), patch: "", isTooLarge: true };

  test("refuse a mark, are skipped by navigation, and stay out of progress", async () => {
    const ext = loadExtension({ extraFiles: [tooLarge] });
    await ext.load();

    const refused = ext.run("toggle", "assets/huge.bin");
    expect(refused.notes).toContain("Can't detect changes to assets/huge.bin, not marked");

    for (const path of ["src/a.ts", "src/b.ts", "src/lib/c.ts"]) {
      ext.run("toggle", path);
    }
    const last = ext.run("toggle", "docs/readme.md");
    expect(last.selected).toBeNull();
    expect(last.notes).toContain("✓ all 4 read");
    expect(ext.status.get("progress")?.spans[0]?.text).toBe("✓ all 4 read");
  });
});
