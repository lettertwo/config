import { useEffect, useMemo, useSyncExternalStore, type ReactNode } from "react";
import type {
  ExtensionCommandContext,
  ExtensionDiffFile,
  ExtensionPaneSize,
  ExtensionLineHighlightControls,
  ExtensionNotifyType,
  ExtensionPaneProps,
  ExtensionReviewReloadControls,
  ExtensionStatusLineControls,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { carriedArgs } from "./carry";
import { Switcher, hunkRunner, reloadArgs, type Run } from "./daemon";
import { OutlineFocus } from "./focus";
import { kittyMoveWindow, type MoveWindow } from "./kitty";
import { NoteTally } from "./notes";
import { StackState } from "./state";
import { createSys, type Sys } from "./stack/sys";
import { dimHighlights, hiddenNotice, isUnderDirectory, nextUnread, progressSpans } from "./vendored/mark-read/core";
import { defaultSessionDir, SessionLog } from "./vendored/mark-read/sessionLog";
import { MarkReadStore } from "./vendored/mark-read/store";
import { FlexFileSidebar, type SidebarReadState } from "./vendored/sidebar/FileSidebars";
import { fitText, formatTerminalPath } from "./vendored/sidebar/helpers";
import type { OutlineModel } from "./outline";

const HIGHLIGHTER_ID = "dim";
const STATUS_ID = "progress";
const ALL_READ_HIDDEN = "All files read, read files are hidden";
/**
 * Full id of the hide/show command, for looking up its current keys.
 *
 * Hunk names the extension after its folder or repository and does not tell the
 * extension that name. Installed under another name, the lookup finds no keys
 * and the sidebar leaves the key out.
 */
const TOGGLE_HIDDEN = "hunk-stack.toggle-hidden";
const TOGGLE_FILES_PANE = "hunk.view.toggleFilesPane";
const STACK_USAGE = `Usage: hunk stack [hunk diff options]

Review the current branch's stack with an outline of its changesets. Opens on the
uncommitted changes when there are any, else on the focus branch. Options such as
--mode or --watch pass through to hunk diff.
`;

/** Same geometry as Hunk's bundled files pane, which this replaces. */
const DEFAULT_WIDTH: ExtensionPaneSize = { preferred: 34, min: 22, max: 56, fraction: 0.16 };

/**
 * The pane width from `[extension.hunk-stack] width`: whole columns from 1 up, or below 1 a
 * fraction of the window. Columns widen the default bounds to fit the request.
 */
export function paneWidth(width: unknown): { size: ExtensionPaneSize; error?: string } {
  if (width === undefined) {
    return { size: DEFAULT_WIDTH };
  }
  if (typeof width === "number" && width > 0 && width < 1) {
    return { size: { ...DEFAULT_WIDTH, fraction: width } };
  }
  if (typeof width === "number" && Number.isInteger(width) && width >= 1) {
    return {
      size: { preferred: width, min: Math.min(DEFAULT_WIDTH.min!, width), max: Math.max(DEFAULT_WIDTH.max!, width) },
    };
  }
  return {
    size: DEFAULT_WIDTH,
    error: `stack: width = ${formatTerminalPath(JSON.stringify(width) ?? String(width))} is neither whole columns nor a fraction below 1; using the default`,
  };
}

export interface StackOptions {
  /** Where session files live; defaults to `defaultSessionDir()`. */
  sessionDir?: string;
  /** Runs the hosting hunk binary for daemon requests; defaults to `process.execPath`. */
  run?: Run;
  /** Builds the process boundary for stack discovery in a directory. */
  makeSys?: (cwd: string) => Sys;
  /** The pid the daemon knows this window by; defaults to `process.pid`. */
  pid?: number;
  /** Leaves hunk for a neighboring terminal window; defaults to kitty's. */
  moveWindow?: MoveWindow;
}

/**
 * Register the extension.
 *
 * `[extension.hunk-stack] persist = false` keeps marks for the session only.
 * The session folder is deliberately not configurable from config, because a
 * repository's `.hunk/config.toml` layers into that table. It keeps the
 * `hunk-mark-read` name so marks made before this extension absorbed that extension
 * still show.
 */
export function registerStack(hunk: HunkExtensionAPI, options: StackOptions = {}) {
  // Per-registration state, so a rebuilt extension registry starts clean.
  const store = new MarkReadStore();
  const log =
    hunk.config.persist === false
      ? null
      : new SessionLog(options.sessionDir ?? defaultSessionDir());
  const width = paneWidth(hunk.config.width);
  let reviewTitle = "review";
  /** Said once the review is up, since the terminal belongs to hunk from then on. */
  let launchNotice: string | undefined;
  let persistFailed = false;
  const switcher = new Switcher(
    options.run ?? hunkRunner(),
    (message) => host.notify?.(message, "warning"),
    options.pid,
  );
  const stack = new StackState(options.makeSys ?? createSys, switcher);
  const notes = new NoteTally();

  const focus = new OutlineFocus({
    toggleRead: (file) => toggleFiles([file]),
    isExpanded: (id) => stack.isExpanded(id),
    setExpanded: (id, to) => stack.setExpanded(id, to),
    openFile: (id, path) => {
      const message = stack.select(id, path);
      if (message) {
        host.notify?.(message, "warning");
      }
    },
  });

  /**
   * Host controls captured from the latest command or lifecycle context.
   *
   * Pane clicks run outside any handler, so they reuse these to repaint the dim
   * highlights, report errors, and, while read files are hidden, reload the review.
   */
  const host: {
    highlights: ExtensionLineHighlightControls | null;
    review: ExtensionReviewReloadControls | null;
    statusLine: ExtensionStatusLineControls | null;
    notify: ((message: string, type?: ExtensionNotifyType) => void) | null;
  } = { highlights: null, review: null, statusLine: null, notify: null };

  function renderProgress() {
    host.statusLine?.set({
      id: STATUS_ID,
      spans: progressSpans(store.readCount(), store.trackableCount()),
      alignment: "right",
    });
  }

  function allRead() {
    return store.readCount() === store.trackableCount();
  }

  /** Read from disk; a broken folder degrades to session-only marks instead of failing the review. */
  function loadPersistedMarks(): Set<string> | undefined {
    // After a failed write the disk is behind memory; keep the session's own marks.
    if (!log || persistFailed) {
      return undefined;
    }
    try {
      return log.load();
    } catch (error) {
      reportPersistError(error);
      return undefined;
    }
  }

  function reportPersistError(error: unknown) {
    if (!persistFailed) {
      persistFailed = true;
      // fs errors embed paths; escape them like file names rather than trusting the host to.
      const reason = formatTerminalPath(String(error));
      host.notify?.(
        `stack: cannot save marks (${reason}); keeping them for this session`,
        "warning",
      );
    }
  }

  /** Change read state in memory and append the change to this session's file. */
  function setRead(files: readonly ExtensionDiffFile[], read: boolean) {
    const changes = store.setRead(files, read);
    if (log && changes.length > 0) {
      const t = Date.now();
      try {
        log.append(
          changes.map((change) => ({ t, ...change })),
          reviewTitle,
        );
      } catch (error) {
        reportPersistError(error);
      }
    }
    return changes.length > 0;
  }

  /** Make a mark change visible: repaint dimming, and drop newly read files when hiding. */
  function afterMarksChanged() {
    if (store.getSnapshot().hidden && host.review) {
      // A reload re-runs the transform and every highlighter.
      void host.review.requestReload();
      return;
    }
    if (host.highlights) {
      host.highlights.refresh(HIGHLIGHTER_ID);
    } else {
      void host.review?.requestReload();
    }
  }

  /** Toggle every trackable file in `files` together: unmark all when all are read, else mark all. */
  function toggleFiles(files: readonly ExtensionDiffFile[]) {
    const trackable = files.filter((file) => store.isTrackable(file));
    if (trackable.length === 0) {
      return;
    }
    const everyRead = trackable.every((file) => store.isRead(file));
    if (setRead(trackable, !everyRead)) {
      afterMarksChanged();
    }
  }

  /** Untrackable files can never be read, so navigation steps over them. */
  const doneWith = (file: ExtensionDiffFile) => store.isRead(file) || !store.isTrackable(file);

  /** The built-in files pane, copied from Hunk, with read markers. */
  function StackSidebar(props: ExtensionPaneProps): ReactNode {
    const snapshot = useSyncExternalStore(store.subscribe, store.getSnapshot);
    const { files, review } = props;
    const stackSnapshot = useSyncExternalStore(stack.subscribe, stack.getSnapshot);
    const focusSnapshot = useSyncExternalStore(focus.subscribe, focus.getSnapshot);

    useEffect(() => stack.observeReview(review), [review]);
    useEffect(() => notes.observe(files), [files]);
    const noteCounts = useSyncExternalStore(notes.subscribe, notes.getSnapshot);

    const readState = useMemo<SidebarReadState>(() => {
      const isRead = (file: ExtensionDiffFile) => {
        const key = store.keyOf(file);
        return key !== null && snapshot.marks.has(key);
      };
      const filesUnder = (path: string) =>
        files.filter((file) => isUnderDirectory(file.path, path));
      return {
        isFileRead: (fileId) => {
          const file = files.find((candidate) => candidate.id === fileId);
          return file ? isRead(file) : false;
        },
        isDirectoryRead: (path) => {
          const trackable = filesUnder(path).filter((file) => store.isTrackable(file));
          return trackable.length > 0 && trackable.every(isRead);
        },
        toggleFile: (fileId) => {
          const file = files.find((candidate) => candidate.id === fileId);
          if (file) {
            toggleFiles([file]);
          }
        },
        toggleDirectory: (path) => toggleFiles(filesUnder(path)),
      };
    }, [files, snapshot]);

    const outline = useMemo(() => {
      if (!stackSnapshot.enabled || stackSnapshot.changesets.length === 0) {
        return undefined;
      }
      const model: OutlineModel = {
        changesets: stackSnapshot.changesets,
        loadedId: stackSnapshot.loadedId,
        pendingId: stackSnapshot.pendingId,
        order: stackSnapshot.order,
        read: { read: store.readCount(), total: store.trackableCount() },
        listings: stackSnapshot.listings,
        expansion: stackSnapshot.expansion,
        filter: stackSnapshot.filter,
        notes: noteCounts,
      };
      return {
        model,
        onToggleChangeset: (id: string) => stack.setExpanded(id),
        onOpenFile: (id: string, path: string) => {
          const message = stack.select(id, path);
          if (message) {
            props.actions.notify(message, "warning");
          }
        },
      };
      // `snapshot` is in the deps because the read count changes with the marks.
    }, [stackSnapshot, snapshot, noteCounts, props.actions]);

    // The rows name the loaded changeset only when the outline is drawn.
    const loadedId = outline ? stackSnapshot.loadedId : null;
    const pendingId = outline ? stackSnapshot.pendingId : null;
    useEffect(
      () =>
        focus.attach({
          actions: props.actions,
          keybindings: props.keybindings,
          files,
          selectedFileId: props.selectedFileId ?? null,
          loadedId,
          pendingId,
        }),
      [props.actions, props.keybindings, files, props.selectedFileId, loadedId, pendingId],
    );
    const paneFocus = useMemo(
      () => ({ cursorEntryId: focusSnapshot.cursorEntryId, onRows: focus.publishRows, onPoint: focus.point }),
      [focusSnapshot.cursorEntryId],
    );

    const { theme, width } = props;
    const notice = snapshot.hidden
      ? hiddenNotice(store.readCount(), files.length, props.keybindings.getKeys(TOGGLE_HIDDEN))
      : [];
    // One column of row highlight on each side, as in the file rows.
    const noticeRows = notice.map((line) => (
      <text key={line} fg={theme.muted} bg={theme.panel}>
        {" " + fitText(line, Math.max(0, width - 2), "…")}
      </text>
    ));

    if (files.length === 0 && notice.length > 0) {
      // Nothing left to list: say why where the list would be.
      return (
        <box
          style={{
            width: "100%",
            height: "100%",
            flexDirection: "column",
            backgroundColor: theme.panel,
          }}
        >
          {noticeRows}
        </box>
      );
    }

    return (
      <box
        style={{
          width: "100%",
          height: "100%",
          flexDirection: "column",
          backgroundColor: theme.panel,
        }}
      >
        <box style={{ width: "100%", flexGrow: 1, flexShrink: 1, minHeight: 0 }}>
          <FlexFileSidebar
            {...props}
            readState={readState}
            outline={outline}
            focus={paneFocus}
            fileView={stackSnapshot.fileView}
          />
        </box>
        {notice.length > 0 ? (
          <text fg={theme.border} bg={theme.panel}>
            {"─".repeat(Math.max(0, width))}
          </text>
        ) : null}
        {noticeRows}
      </box>
    );
  }

  try {
    log?.prune();
  } catch {
    // Cleanup is best effort; a later session retries.
  }
  store.subscribe(renderProgress);

  hunk.transformChangeset((changeset) => {
    reviewTitle = changeset.title;
    // Re-reading on every (re)load picks up marks other sessions saved meanwhile.
    store.setReview(changeset.files, loadPersistedMarks());
    if (!store.getSnapshot().hidden) {
      return changeset;
    }
    return { ...changeset, files: changeset.files.filter((file) => !store.isRead(file)) };
  });

  hunk.registerLineHighlighter({
    id: HIGHLIGHTER_ID,
    highlight: ({ file }) => (store.isRead(file) ? dimHighlights(file.patch) : null),
  });

  hunk.registerPane({
    id: "files",
    title: "Files",
    placement: "left",
    width: width.size,
    defaultOpen: true,
    replaces: "hunk:files",
    component: StackSidebar,
  });

  hunk.registerCommand(
    { id: "toggle", title: "Toggle file read (mark jumps to next unread)", key: "x" },
    (ctx) => {
      host.highlights = ctx.highlights;
      host.statusLine = ctx.statusLine;
      host.notify = ctx.notify;

      const { file, files } = ctx.selection;

      if (!file) {
        ctx.notify("Select a file before marking it read", "warning");
        return;
      }

      if (!store.isTrackable(file)) {
        // Paths come from the diff and may contain control characters.
        ctx.notify(
          `Can't detect changes to ${formatTerminalPath(file.path)}, not marked`,
          "warning",
        );
        return;
      }

      if (store.isRead(file)) {
        setRead([file], false);
        afterMarksChanged();
        return;
      }

      setRead([file], true);
      const next = nextUnread(files, file.id, doneWith);

      if (next) {
        ctx.navigation.selectFile(next.id);
      } else {
        ctx.notify(
          store.getSnapshot().hidden ? ALL_READ_HIDDEN : `✓ all ${store.trackableCount()} read`,
        );
      }

      if (store.getSnapshot().hidden) {
        ctx.commands.execute("hunk.app.refresh");
      } else {
        ctx.highlights.refresh(HIGHLIGHTER_ID);
      }
    },
  );

  hunk.registerCommand({ id: "next-unread", title: "Next unread file", key: "X" }, (ctx) => {
    host.highlights = ctx.highlights;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    const { file, files } = ctx.selection;
    const next = nextUnread(files, file?.id ?? null, doneWith);
    if (!next) {
      ctx.notify(`✓ all ${store.trackableCount()} read`);
      return;
    }
    if (next.id !== file?.id) {
      ctx.navigation.selectFile(next.id);
    }
  });

  hunk.registerCommand({ id: "toggle-hidden", title: "Hide/show read files", key: "H" }, (ctx) => {
    host.highlights = ctx.highlights;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    const hidden = !store.getSnapshot().hidden;
    store.setHidden(hidden);
    if (!ctx.commands.execute("hunk.app.refresh")) {
      store.setHidden(!hidden);
      ctx.notify("This review cannot be refreshed, so read files cannot be hidden", "warning");
      return;
    }
    if (hidden && allRead()) {
      ctx.notify(ALL_READ_HIDDEN);
    } else {
      ctx.notify(hidden ? "Hiding read files" : "Showing read files");
    }
  });

  hunk.registerCommand(
    // The outline lists head first while stepping walks base to head, as in the nvim review app.
    { id: "next-changeset", title: "Next changeset (toward head)", key: ")" },
    (ctx) => {
      host.notify = ctx.notify;
      ctx.notify(stack.step(1));
    },
  );

  hunk.registerCommand(
    { id: "previous-changeset", title: "Previous changeset (toward base)", key: "(" },
    (ctx) => {
      host.notify = ctx.notify;
      ctx.notify(stack.step(-1));
    },
  );

  hunk.registerCommand(
    { id: "cycle-zoom", title: "Cycle changeset zoom (combined, branch, commit)", key: "I" },
    (ctx) => {
      host.notify = ctx.notify;
      ctx.notify(stack.cycleZoom(ctx.selection.file?.path ?? null));
    },
  );

  hunk.registerKeyboardMode({
    id: "outline",
    title: "Outline: j/k move, enter open, h/l fold, space read, / filter, esc exit",
    onEnter: () => focus.enter(),
    onExit: () => focus.leave(),
    onKey: (key, ctx) => {
      host.highlights = ctx.highlights;
      host.statusLine = ctx.statusLine;
      host.notify = ctx.notify;
      // Hunk's filter, and not a key of the mode's own, so `/` keeps its meaning in the diff.
      if ((key.name === "/" || key.sequence === "/") && !key.ctrl && !key.meta && !key.option) {
        ctx.commands.execute("hunk.review.focusFilter");
        return "handled";
      }
      // Hiding the pane would leave the mode holding the keys with no cursor to draw, so the
      // mode runs hunk's toggle itself and hands the keys back to the diff.
      if (focus.bindsTo(key, TOGGLE_FILES_PANE) && ctx.commands.execute(TOGGLE_FILES_PANE)) {
        return "exit";
      }
      return focus.handleKey(key);
    },
  });

  hunk.registerCommand(
    { id: "focus-outline", title: "Focus the outline (keyboard cursor)", key: "tab" },
    (ctx) => {
      host.notify = ctx.notify;
      if (!focus.hasPane()) {
        // Also reveals the pane when hunk hid it for a narrow window. The cursor lands once
        // the pane draws its rows.
        ctx.panes.open("files");
      }
      if (!ctx.keyboardModes.enterMode("outline")) {
        ctx.notify("Cannot focus the outline from here", "warning");
      }
    },
  );

  // The outline sits left of the diff, so ctrl+h and ctrl+l move between them as between
  // nvim splits, and leave hunk from its edges.
  const moveWindow = options.moveWindow ?? kittyMoveWindow();
  async function moveOut(ctx: ExtensionCommandContext, direction: "left" | "right") {
    const error = await moveWindow(direction);
    if (error) {
      ctx.notify(error, "warning");
    }
  }

  hunk.registerCommand(
    { id: "focus-outline-or-left", title: "Focus the outline if open, else the window to the left", key: "ctrl+h" },
    async (ctx) => {
      host.notify = ctx.notify;
      if (focus.hasPane() && !ctx.keyboardModes.isActive("outline") && ctx.keyboardModes.enterMode("outline")) {
        return;
      }
      await moveOut(ctx, "left");
    },
  );

  hunk.registerCommand(
    { id: "focus-diff-or-right", title: "Focus the diff from the outline, else the window to the right", key: "ctrl+l" },
    async (ctx) => {
      host.notify = ctx.notify;
      if (ctx.keyboardModes.isActive("outline") && ctx.keyboardModes.exitMode()) {
        return;
      }
      await moveOut(ctx, "right");
    },
  );

  hunk.registerCommand(
    { id: "toggle-stack-order", title: "Toggle outline order (head first, base first)", key: "O" },
    (ctx) => {
      host.notify = ctx.notify;
      ctx.notify(stack.toggleOrder());
    },
  );

  hunk.registerCommand(
    { id: "cycle-file-view", title: "Cycle file view (auto, tree, grouped, flat)", key: "T" },
    (ctx) => {
      host.notify = ctx.notify;
      ctx.notify(stack.cycleFileView());
    },
  );

  // The handler runs in the process that then hosts the delegated review, so the stack it
  // opens is the one the pane draws. Any other hunk command leaves the stack closed and gets
  // the plain files pane with read marks.
  hunk.registerCliCommand(
    {
      name: "stack",
      summary: "Review the current branch's stack, one changeset at a time",
      usage: "[hunk diff options]",
    },
    async (args, ctx) => {
      if (args.includes("-h") || args.includes("--help")) {
        await ctx.stdout.write(STACK_USAGE);
        return { kind: "exit" };
      }
      const opened = stack.open(ctx.cwd);
      const argv = "error" in opened ? opened : reloadArgs(opened);
      if ("error" in argv) {
        await ctx.stderr.write(`hunk stack: ${formatTerminalPath(argv.error)}\n`);
        return { kind: "exit", code: 1 };
      }
      const toplevel = (options.makeSys ?? createSys)(ctx.cwd).git(["rev-parse", "--show-toplevel"]);
      const carried = carriedArgs(args, ctx.cwd, toplevel.code === 0 ? toplevel.stdout.trim() : null);
      switcher.carry(carried.args);
      launchNotice = carried.notice;
      return { kind: "delegate", argv: [...argv, ...args] };
    },
  );

  hunk.on("startup", (_payload, ctx) => {
    host.notify = ctx.notify;
    if (width.error) {
      ctx.notify(width.error, "warning");
    }
    if (launchNotice) {
      ctx.notify(launchNotice, "warning");
    }
  });
  hunk.on("changeset_loaded", (_payload, ctx) => {
    host.review = ctx.review;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    renderProgress();
  });
  hunk.on("filter_changed", ({ filter }) => stack.setFilter(filter));

  // A note removed through `hunk session comment` may sit on a path that is not loaded.
  hunk.on("note_changed", ({ kind, note }) => {
    if (kind === "removed") {
      notes.forget(note.id);
    }
  });

  hunk.on("session_reload", (payload, ctx) => {
    host.review = ctx.review;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    renderProgress();
    // The daemon answers a reload request after this event, so the request is still the one running.
    const landing = payload.reason === "daemon" ? switcher.takeLanding() : null;
    const file = landing?.path ? payload.changeset.files.find((f) => f.path === landing.path) : undefined;
    if (file) {
      ctx.navigation.selectFile(file.id);
    }
  });
}

export default function registerDefault(hunk: HunkExtensionAPI) {
  registerStack(hunk);
}
