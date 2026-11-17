import { useEffect, useMemo, useSyncExternalStore, type ReactNode } from "react";
import type {
  ExtensionCommandContext,
  ExtensionDiffFile,
  ExtensionPaneSize,
  ExtensionLineHighlightControls,
  ExtensionNotifyType,
  ExtensionPaneProps,
  ExtensionReviewDescriptor,
  ExtensionReviewReloadControls,
  ExtensionReviewSnapshotNote,
  ExtensionNoteChangeKind,
  ExtensionPaneControls,
  ExtensionReviewControls,
  ExtensionStatusLineControls,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { carriedArgs } from "./carry";
import { Switcher, hunkRunner, reloadArgs, type Run } from "./daemon";
import { OutlineFocus } from "./focus";
import { kittyMoveWindow, type MoveWindow } from "./kitty";
import { NoteTally } from "./notes";
import {
  addTarget,
  editorHeading,
  noteChoices,
  ownNotesOnLine,
  replantItem,
  rootNoteOf,
  threadByDepth,
  threadsOnLine,
  type EditorRequest,
} from "./noteEditor";
import { runNotes } from "./notesCli";
import { CommitIndex, type NoteOrigin, type Scope } from "./origin";
import {
  NoteJournal,
  anchorInFile,
  anchorOf,
  applyItem,
  contextAt,
  deepestFirst,
  defaultNotesDir,
  groupSaved,
  liveHostIds,
  noteKey,
  parsePatch,
  planRestore,
  recordFromNote,
  rehomeTarget,
  rootOf,
  savedNoteRows,
  USER_AUTHOR,
  type JournalEntry,
  type JournalState,
  type LoadedFile,
  type NoteRecord,
  type NoteSide,
  type Remap,
  type RestoreView,
} from "./persist";
import { StackState, reviewKey } from "./state";
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

Usage: hunk stack notes (list [--json] | resolve <key> [--commit <sha>] | reopen <key>)

Read and change the saved review notes of this worktree, with no Hunk session running.
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
  /** Where saved review notes live; defaults to `defaultNotesDir()`. */
  notesDir?: string;
  /** Waits in ms between lookups of this window's session before giving up; see `sessionCall`. */
  registrationWaits?: readonly number[];
}

/**
 * Register the extension.
 *
 * `[extension.hunk-stack] persist = false` keeps marks and review notes for the session only.
 * The mark and note folders are deliberately not configurable from config, because a
 * repository's `.hunk/config.toml` layers into that table. The mark folder keeps the
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
  const run = options.run ?? hunkRunner();
  const pid = options.pid ?? process.pid;
  const registrationWaits = options.registrationWaits ?? [250, 500, 1000, 2000];
  const switcher = new Switcher(run, (message) => host.notify?.(message, "warning"), options.pid);
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

  // Saved review notes. Hunk keeps notes in memory only, so each change is journaled as it
  // happens (never on shutdown, which is bounded to 250 ms and skipped on a crash) and the notes
  // are applied again to this review's own session whenever a changeset loads.

  /** `undefined` until the first event says which worktree this is; `null` when notes are not saved. */
  let journal: NoteJournal | null | undefined;
  /** The loaded changeset's files, the only place the anchored line's text can be read. */
  let loadedFiles: LoadedFile[] | null = null;
  /** `fileKey` hashes the repository root, so it only names a file within this review. */
  const fileKeys = new Map<string, string>();
  /** Paths that `note_created` and `note_edited` reported, which `note_changed` does not carry. */
  const notePaths = new Map<string, string>();
  /** Notes this process restored, by the id Hunk gave them, to the journal key they keep. */
  const restoredKeys = new Map<string, string>();
  let remaps: Remap[] = [];
  /** Above zero while this extension is applying notes; their `created` events are held back, not journaled as the user's. */
  let applying = 0;
  /** Host ids of notes the editor made and journaled itself, whose `created` events must not be journaled again. */
  const authored = new Set<string>();
  /** Resolved threads the reviewer opened from the saved-notes dialog, by root key; shown for this process only. */
  const forced = new Set<string>();
  /** Host ids this extension is removing to hide a resolved thread; their removal events are not the user's. */
  const hiding = new Set<string>();
  /** The changeset id the latest restore judged notes against, so a late-identified reload is judged again. */
  let restoredFor: string | null = null;
  /** The worktree the review runs in, learned from the first event; a review with no stack reads its commits from it. */
  let reviewCwd: string | undefined;
  let plainIndex: CommitIndex | null = null;
  let buffered: {
    kind: ExtensionNoteChangeKind;
    note: ExtensionReviewSnapshotNote;
    files: readonly LoadedFile[] | null;
    origin: NoteOrigin | null;
  }[] = [];
  let journalQueue: Promise<void> = Promise.resolve();
  let notesFailed = false;
  let restoreFailed = false;
  let restoring = false;
  let restoreAgain = false;
  /** The restore passes running now, which an edit waits out before it touches the host. */
  let restoreRun: Promise<void> = Promise.resolve();
  /** True while an edit is replacing its thread in the host; restores wait until it is done. */
  let editing = false;

  function openJournal(cwd: string): NoteJournal | null {
    if (journal !== undefined) {
      return journal;
    }
    journal = null;
    if (hunk.config.persist === false) {
      return null;
    }
    // Hunk allows one session per worktree and several per repository, so the worktree names the journal.
    const top = (options.makeSys ?? createSys)(cwd).git(["rev-parse", "--show-toplevel"]);
    if (top.code !== 0) {
      return null;
    }
    reviewCwd = cwd;
    journal = new NoteJournal(options.notesDir ?? defaultNotesDir(), top.stdout.trim());
    journal.prune();
    remaps = readJournal()?.remaps ?? [];
    for (const remap of remaps) {
      if (remap.pid === pid) {
        restoredKeys.set(remap.to, remap.key);
      }
    }
    return journal;
  }

  function reportNotesError(error: unknown) {
    if (!notesFailed) {
      notesFailed = true;
      host.notify?.(`stack: cannot use saved notes (${formatTerminalPath(String(error))})`, "warning");
    }
  }

  function readJournal(): JournalState | null {
    try {
      return journal?.load() ?? null;
    } catch (error) {
      reportNotesError(error);
      return null;
    }
  }

  function saveEntries(entries: JournalEntry[]) {
    try {
      journal?.append(entries);
    } catch (error) {
      reportNotesError(error);
    }
  }

  type SessionReply = { kind: "none" } | { kind: "error"; message: string } | { kind: "ok"; value: unknown };

  /** Run `hunk session ...` against this review's own session. */
  async function sessionCall(args: (sessionId: string) => string[], stdin?: string): Promise<SessionReply> {
    let id: string | null = null;
    // Hunk registers the session with its daemon without waiting for it, and emits `startup` and
    // the first `changeset_loaded` meanwhile. No event follows registration, so look again.
    for (const wait of [0, ...registrationWaits]) {
      if (wait > 0) {
        await new Promise((resolve) => setTimeout(resolve, wait));
      }
      try {
        id = await switcher.sessionId();
      } catch (error) {
        // `session list` printed something that is not JSON.
        return { kind: "error", message: String(error) };
      }
      if (id) {
        break;
      }
    }
    if (!id) {
      // Unregistered still (or `HUNK_MCP_DISABLE` is set); a later load tries again.
      return { kind: "none" };
    }
    const result = await run(args(id), stdin);
    if (result.code !== 0) {
      switcher.forgetSession();
      return { kind: "error", message: result.stderr.trim() || `exit ${result.code}` };
    }
    try {
      return { kind: "ok", value: JSON.parse(result.stdout) };
    } catch {
      return { kind: "error", message: "unreadable reply from hunk session" };
    }
  }

  async function listNotes(): Promise<{ notes: { noteId: string; filePath: string }[] } | SessionReply> {
    const reply = await sessionCall((id) => ["session", "comment", "list", id, "--type", "all", "--json"]);
    if (reply.kind !== "ok") {
      return reply;
    }
    const comments = (reply.value as { comments?: { noteId?: string; filePath?: string }[] }).comments ?? [];
    return {
      notes: comments.flatMap((comment) =>
        typeof comment.noteId === "string" && typeof comment.filePath === "string"
          ? [{ noteId: comment.noteId, filePath: comment.filePath }]
          : [],
      ),
    };
  }

  /** The path of a note, which `note_changed` names only by `fileKey`. */
  async function pathOf(note: ExtensionReviewSnapshotNote): Promise<string | null> {
    const known = fileKeys.get(note.fileKey) ?? notePaths.get(note.id);
    if (known) {
      fileKeys.set(note.fileKey, known);
      return known;
    }
    const listed = await listNotes();
    const path = "notes" in listed ? listed.notes.find((entry) => entry.noteId === note.id)?.filePath : undefined;
    if (path) {
      fileKeys.set(note.fileKey, path);
    }
    return path ?? null;
  }

  /**
   * What the review shows, as commits, and the index that read them. In a `hunk stack` review that
   * is the stack's changeset. Otherwise it comes from the descriptor the pane reported: a
   * working-tree review is the uncommitted changes, `show <sha>` is that commit, and a range is
   * the commits in `base..head`. Null until the pane has reported, or for a review of another kind.
   */
  function loadedScope(): { scope: Scope; index: CommitIndex; id: string } | null {
    const changeset = stack.showing();
    const stackScope = changeset ? stack.scopeOf(changeset) : null;
    if (changeset && stackScope && stack.commitIndex) {
      return { scope: stackScope, index: stack.commitIndex, id: changeset.id };
    }
    const review = stack.reviewDescriptor();
    if (review === undefined || reviewCwd === undefined) {
      return null;
    }
    plainIndex ??= new CommitIndex((options.makeSys ?? createSys)(reviewCwd), null);
    const id = `review:${reviewKey(review)}`;
    if (review === null) {
      return { scope: plainIndex.uncommittedScope(), index: plainIndex, id };
    }
    if (review.kind === "commit") {
      return { scope: plainIndex.scopeOfCommit(review.revision), index: plainIndex, id };
    }
    if (review.kind === "comparison") {
      return { scope: plainIndex.scopeOfRange(review.base, review.head), index: plainIndex, id };
    }
    return null;
  }

  /** Names what the review shows, so a change in it is noticed without reading git. */
  function loadedIdentity(): string | null {
    const review = stack.reviewDescriptor();
    return stack.showing()?.id ?? (review === undefined ? null : `review:${reviewKey(review)}`);
  }

  /** The origin a note written now gets, or null when the review's commits cannot be read. */
  function currentOrigin(): NoteOrigin | null {
    const loaded = loadedScope();
    if (!loaded || (loaded.scope.commits.length === 0 && !loaded.scope.uncommitted)) {
      return null;
    }
    return loaded.index.originOf(loaded.scope);
  }

  async function journalNote(
    kind: ExtensionNoteChangeKind,
    note: ExtensionReviewSnapshotNote,
    files: readonly LoadedFile[] | null,
    origin: NoteOrigin | null,
  ) {
    if (!journal) {
      return;
    }
    const restoredKey = restoredKeys.get(note.id);
    const key = restoredKey ?? noteKey(pid, note.id);
    const t = Date.now();
    if (kind === "removed") {
      restoredKeys.delete(note.id);
      remaps = remaps.filter((remap) => remap.key !== key);
      saveEntries([{ op: "remove", t, key }]);
      return;
    }
    if (restoredKey !== undefined) {
      // `created` is the restore's own doing. An edit keeps the note's saved anchor and source.
      const saved = kind === "updated" ? readJournal()?.notes.get(key) : undefined;
      if (saved) {
        // Fields a note no longer has come out as undefined, which the journal's JSON drops.
        const edited: NoteRecord = {
          ...saved,
          summary: note.summary,
          rationale: note.rationale,
          markup: note.markup,
          updatedAt: note.updatedAt ?? saved.updatedAt,
        };
        saveEntries([{ op: "put", t, note: edited }]);
      }
      return;
    }
    const path = await pathOf(note);
    if (!path) {
      return;
    }
    const parentKey = note.parentId === undefined ? undefined : (restoredKeys.get(note.parentId) ?? noteKey(pid, note.parentId));
    // An edit keeps what the note was written against; only its text changed.
    const saved = kind === "updated" ? readJournal()?.notes.get(key) : undefined;
    if (saved) {
      saveEntries([
        {
          op: "put",
          t,
          note: recordFromNote(note, { pid, path, parentKey, origin: saved.origin, lineText: saved.lineText, lineContext: saved.context }),
        },
      ]);
      return;
    }
    if (!origin) {
      // The review's commits could not be read, so there is nothing to place the note by later.
      return;
    }
    const anchor = anchorOf(note.anchor);
    const file = files?.find((candidate) => candidate.path === path);
    const lines = file ? parsePatch(file.patch) : null;
    saveEntries([
      {
        op: "put",
        t,
        note: recordFromNote(note, {
          pid,
          path,
          origin,
          lineText: lines && anchor ? lines[anchor.side].get(anchor.line) : undefined,
          lineContext: lines && anchor && lines[anchor.side].has(anchor.line) ? contextAt(lines, anchor.side, anchor.line) : undefined,
          parentKey,
        }),
      },
    ]);
  }

  /** One at a time and in event order, since resolving a path can wait on the daemon. */
  function enqueueJournal(work: () => Promise<void>) {
    // Reaching here means a bug, since the work reports its own fs and daemon failures; the
    // catch keeps one throw from stalling every later entry.
    journalQueue = journalQueue.then(work).catch(reportNotesError);
  }

  function reportRestoreFailure(message: string) {
    if (!restoreFailed) {
      restoreFailed = true;
      host.notify?.(`stack: cannot restore saved notes (${formatTerminalPath(message)})`, "warning");
    }
  }

  /**
   * What saved notes are judged against: the loaded files, and the commits the review shows. Null
   * when the extension cannot yet say what that is.
   */
  function restoreView(state: JournalState): { view: RestoreView; changesetId: string } | null {
    const loaded = loadedScope();
    if (!loaded || !loadedFiles) {
      return null;
    }
    const { index } = loaded;
    return {
      changesetId: loaded.id,
      view: {
        files: loadedFiles,
        scope: loaded.scope,
        patchIdOf: index.patchId,
        statuses: state.statuses,
        forced,
        rehome: (record, branch) => {
          const commit = rehomeTarget(record, index.branchCommits(branch), index.commitPatch);
          return commit ? { ...commit, patchId: index.patchId(commit.sha) } : null;
        },
      },
    };
  }

  /**
   * Take notes out of the host in the order given, which must put replies before the notes they
   * answer. Their removal events are not journaled. Returns the ids removed, and the reply that
   * stopped it when it stopped early.
   */
  async function removeHostIds(ids: readonly string[]): Promise<{ removed: string[]; stopped: SessionReply | null }> {
    const removed: string[] = [];
    for (const id of ids) {
      hiding.add(id);
      const reply = await sessionCall((session) => ["session", "comment", "rm", session, id, "--json"]);
      if (reply.kind !== "ok") {
        hiding.delete(id);
        return { removed, stopped: reply };
      }
      removed.push(id);
    }
    return { removed, stopped: null };
  }

  /**
   * Take the host's copies of notes out, replies first. Their removal events are not journaled.
   * Returns the journal keys of the notes that are out.
   */
  async function removeFromHost(
    records: readonly NoteRecord[],
    hostIds: ReadonlyMap<string, string>,
    all: ReadonlyMap<string, NoteRecord>,
  ): Promise<Set<string>> {
    const ordered = deepestFirst(records, all).filter((record) => hostIds.has(record.key));
    const { removed, stopped } = await removeHostIds(ordered.map((record) => hostIds.get(record.key)!));
    if (stopped?.kind === "error") {
      reportRestoreFailure(stopped.message);
    }
    return new Set(ordered.slice(0, removed.length).map((record) => record.key));
  }

  /** Journal the events held back while notes were applied, except for notes the editor journaled itself. */
  function drainBuffered() {
    for (const event of buffered.splice(0)) {
      if (event.kind === "created" && authored.has(event.note.id)) {
        continue;
      }
      enqueueJournal(() => journalNote(event.kind, event.note, event.files, event.origin));
    }
  }

  async function restoreOnce() {
    const state = journal && loadedFiles ? readJournal() : null;
    if (!state || !loadedFiles) {
      return;
    }
    if (state.notes.size === 0) {
      return;
    }
    const listed = await listNotes();
    if (!("notes" in listed)) {
      if (listed.kind === "error") {
        reportRestoreFailure(listed.message);
      }
      return;
    }
    // Read after the daemon answered: a reload from outside is identified by the pane meanwhile.
    const judged = restoreView(state);
    if (!judged) {
      return;
    }
    restoredFor = judged.changesetId;
    const liveIds = new Set(listed.notes.map((entry) => entry.noteId));
    const records = [...state.notes.values()];
    const hostIds = liveHostIds(state, remaps, pid, liveIds);
    const plan = planRestore(records, judged.view, new Set(hostIds.keys()));
    if (plan.rehomed.length > 0) {
      const t = Date.now();
      saveEntries(plan.rehomed.map(({ record, origin }) => ({ op: "put" as const, t, note: { ...record, origin } })));
    }
    if (plan.hide.length > 0) {
      await removeFromHost(plan.hide, hostIds, state.notes);
    }

    /** The id a saved note has in the host now, for a reply to name. */
    const hostId = (key: string, fresh: ReadonlyMap<string, string>): string | undefined => fresh.get(key) ?? hostIds.get(key);

    const fresh = new Map<string, string>();
    applying += 1;
    try {
      for (const batch of plan.batches) {
        const sendable = batch.flatMap((planned) => {
          const parentKey = planned.record.parentKey;
          const parent = parentKey === undefined ? undefined : hostId(parentKey, fresh);
          return parentKey !== undefined && parent === undefined ? [] : [{ planned, item: applyItem(planned, parent) }];
        });
        if (sendable.length === 0) {
          break;
        }
        const reply = await sessionCall(
          (id) => ["session", "comment", "apply", id, "--stdin", "--json"],
          JSON.stringify({ comments: sendable.map((entry) => entry.item) }),
        );
        if (reply.kind !== "ok") {
          if (reply.kind === "error") {
            reportRestoreFailure(reply.message);
          }
          break;
        }
        const body = reply.value as { result?: { applied?: unknown }; applied?: unknown };
        const applied = (body.result?.applied ?? body.applied ?? []) as { commentId: string; filePath?: string }[];
        const entries: JournalEntry[] = [];
        applied.slice(0, sendable.length).forEach((made, index) => {
          const { record } = sendable[index]!.planned;
          fresh.set(record.key, made.commentId);
          restoredKeys.set(made.commentId, record.key);
          notePaths.set(made.commentId, made.filePath ?? record.path);
          remaps.push({ pid, key: record.key, to: made.commentId });
          entries.push({ op: "remap", t: Date.now(), pid, key: record.key, to: made.commentId });
        });
        saveEntries(entries);
        if (applied.length !== sendable.length) {
          reportRestoreFailure("hunk applied fewer notes than sent");
          break;
        }
      }
    } finally {
      applying -= 1;
      // Events held back during the apply are judged now that the restored ids are known.
      if (applying === 0) {
        drainBuffered();
      }
    }
    if (fresh.size > 0) {
      restoreFailed = false;
      const counts = [
        plan.pending.length > 0 ? `${plan.pending.length} pending` : "",
        plan.outdated.length > 0 ? `${plan.outdated.length} outdated` : "",
      ].filter(Boolean);
      host.notify?.(
        `stack: restored ${fresh.size} saved note${fresh.size === 1 ? "" : "s"}${counts.length > 0 ? ` (${counts.join(", ")})` : ""}`,
      );
    }
  }

  /** Restore after a load, folding loads that arrive mid-restore into one more pass. */
  function requestRestore() {
    if (!journal) {
      return;
    }
    // An edit takes its thread out of the host before putting it back, and a restore in that gap
    // would put the thread back as well; the edit asks for the pass once it is done.
    if (restoring || editing) {
      restoreAgain = true;
      return;
    }
    restoring = true;
    restoreRun = (async () => {
      try {
        do {
          restoreAgain = false;
          await restoreOnce();
        } while (restoreAgain && !editing);
      } finally {
        restoring = false;
      }
      // Detached from the event that started it, so nothing else would report a throw here.
    })().catch((error) => host.notify?.(`stack: restoring saved notes failed (${formatTerminalPath(String(error))})`, "warning"));
  }

  // A reload from outside the extension is identified by the pane after `changeset_loaded` has
  // already restored against the changeset that was showing, so judge again once it is known.
  stack.subscribe(() => {
    const identity = loadedIdentity();
    if (identity !== null && identity !== restoredFor) {
      requestRestore();
    }
  });

  function loadChangeset(files: readonly ExtensionDiffFile[]) {
    loadedFiles = files.map((file) => ({ path: file.path, patch: file.patch, hunks: file.hunks ?? [] }));
    // Noted now, so the subscription above only reacts to the pane naming a different changeset.
    restoredFor = loadedIdentity();
    requestRestore();
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

  // The note editor. Hunk's own editor makes notes only Hunk can move, so notes are written in a
  // docked textarea instead and created through `comment apply`, like an agent's. The journal
  // still records them as the user's.

  const EDITOR_PANE = "note-editor";
  type EditorSession = {
    id: number;
    request: EditorRequest;
    initial: string;
    panes: ExtensionPaneControls;
    review: ExtensionReviewControls;
    error?: string;
    busy: boolean;
  };
  let editor: EditorSession | null = null;
  let editorCount = 0;
  const editorListeners = new Set<() => void>();
  let textarea: { plainText: string; gotoBufferEnd?: () => void } | null = null;

  function setEditor(next: EditorSession | null) {
    editor = next;
    editorListeners.forEach((listener) => listener());
  }

  function subscribeEditor(listener: () => void) {
    editorListeners.add(listener);
    return () => void editorListeners.delete(listener);
  }

  function cancelEditor() {
    const session = editor;
    // Unmounting the textarea first hands the keys back to Hunk.
    setEditor(null);
    session?.panes.close(EDITOR_PANE);
  }

  /** The journal key of a note Hunk holds: the one it was restored under, else one made in this process. */
  function keyOfHost(id: string): string {
    return restoredKeys.get(id) ?? noteKey(pid, id);
  }

  async function applyNotes(items: Record<string, unknown>[]): Promise<{ made: { commentId: string; filePath?: string }[] } | { error: string }> {
    const reply = await sessionCall(
      (id) => ["session", "comment", "apply", id, "--stdin", "--json"],
      JSON.stringify({ comments: items }),
    );
    if (reply.kind === "none") {
      return { error: "No Hunk session found for this review" };
    }
    if (reply.kind === "error") {
      return { error: reply.message };
    }
    const body = reply.value as { result?: { applied?: unknown }; applied?: unknown };
    const made = (body.result?.applied ?? body.applied ?? []) as { commentId: string; filePath?: string }[];
    return made.length === items.length ? { made } : { error: "hunk applied fewer notes than sent" };
  }

  /** The text of a line and its surroundings in the loaded changeset, which the journal finds the line by later. */
  function lineFacts(path: string, side: NoteSide, line: number) {
    const file = loadedFiles?.find((candidate) => candidate.path === path);
    const lines = file ? parsePatch(file.patch) : null;
    return {
      lineText: lines?.[side].get(line),
      context: lines?.[side].has(line) ? contextAt(lines, side, line) : undefined,
    };
  }

  /** Create one note or reply through the host and journal it as the user's. */
  async function saveNew(request: Extract<EditorRequest, { kind: "add" | "reply" }>, summary: string): Promise<string | null> {
    const parent = request.kind === "reply" ? request.root : undefined;
    const target = request.kind === "add" ? request : anchorOf(request.root.anchor);
    if (!target) {
      return "That note has no line to reply under";
    }
    const item: Record<string, unknown> = parent
      ? { replyTo: parent.id, summary, author: USER_AUTHOR }
      : { filePath: request.path, [target.side === "old" ? "oldLine" : "newLine"]: target.line, summary, author: USER_AUTHOR };
    applying += 1;
    try {
      const applied = await applyNotes([item]);
      if ("error" in applied) {
        return applied.error;
      }
      const id = applied.made[0]!.commentId;
      authored.add(id);
      notePaths.set(id, request.path);
      const origin = currentOrigin();
      if (journal && origin) {
        const facts = lineFacts(request.path, target.side, target.line);
        const record = recordFromNote(
          {
            id,
            parentId: parent?.id,
            source: "user",
            author: USER_AUTHOR,
            anchor: { preferred: { side: target.side, line: target.line } },
            summary,
            createdAt: new Date().toISOString(),
          },
          { pid, path: request.path, origin, lineText: facts.lineText, lineContext: facts.context, parentKey: parent ? keyOfHost(parent.id) : undefined },
        );
        saveEntries([{ op: "put", t: Date.now(), note: record }]);
      }
      return null;
    } finally {
      applying -= 1;
      if (applying === 0) {
        drainBuffered();
      }
    }
  }

  /**
   * Change a note's text. Hunk cannot edit a note made through `comment apply`, so the whole thread
   * is removed and put back, replies last, with the new text on the edited note. Each note keeps
   * its journal key and gains a remap to its new host id.
   */
  async function saveEdit(session: EditorSession, request: Extract<EditorRequest, { kind: "edit" }>, summary: string): Promise<string | null> {
    editing = true;
    try {
      // A restore already running may move this thread, so the snapshot is read after it.
      await restoreRun;
      return await replaceThread(session, request, summary);
    } finally {
      editing = false;
      if (restoreAgain) {
        requestRestore();
      }
    }
  }

  async function replaceThread(session: EditorSession, request: Extract<EditorRequest, { kind: "edit" }>, summary: string): Promise<string | null> {
    const snapshot = session.review.snapshot();
    const root = snapshot ? rootNoteOf(snapshot.notes, request.note.id) : undefined;
    if (!snapshot || !root) {
      return "The review changed under the editor; try again";
    }
    if (!anchorOf(root.anchor)) {
      // Checked before anything is removed, since the thread could not be put back.
      return "This thread has no line to put it back on";
    }
    const depths = threadByDepth(snapshot.notes, root.id);
    const keys = new Map(depths.flat().map((note) => [note.id, keyOfHost(note.id)]));
    const record = journal ? readJournal()?.notes.get(keys.get(request.note.id)!) : undefined;
    if (record) {
      // Saved before the thread is touched, so a failure partway through restores the new text.
      saveEntries([{ op: "put", t: Date.now(), note: { ...record, summary, updatedAt: new Date().toISOString() } }]);
    }
    applying += 1;
    try {
      const { stopped } = await removeHostIds(depths.flat().reverse().map((note) => note.id));
      if (stopped) {
        return stopped.kind === "error" ? stopped.message : "No Hunk session found for this review";
      }
      const fresh = new Map<string, string>();
      for (const depth of depths) {
        const items = depth.map((note) =>
          replantItem(note, { path: request.path, parentId: note.parentId === undefined ? undefined : fresh.get(note.parentId) }, note.id === request.note.id ? summary : note.summary),
        );
        const applied = await applyNotes(items);
        if ("error" in applied) {
          return `${applied.error}; the thread comes back on the next load`;
        }
        const entries: JournalEntry[] = [];
        applied.made.forEach((made, index) => {
          const oldId = depth[index]!.id;
          const key = keys.get(oldId)!;
          fresh.set(oldId, made.commentId);
          restoredKeys.set(made.commentId, key);
          notePaths.set(made.commentId, made.filePath ?? request.path);
          remaps.push({ pid, key, to: made.commentId });
          entries.push({ op: "remap", t: Date.now(), pid, key, to: made.commentId });
        });
        if (journal) {
          saveEntries(entries);
        }
      }
      return null;
    } finally {
      applying -= 1;
      if (applying === 0) {
        drainBuffered();
      }
    }
  }

  /** Save the editor's text; returns why it could not, else null once the note is made and the editor closed. */
  async function saveEditor(text: string): Promise<string | null> {
    const session = editor;
    if (!session || session.busy) {
      return null;
    }
    const summary = text.trim();
    const fail = (error: string) => {
      // The editor may have been cancelled or replaced while the save ran.
      if (editor?.id === session.id) {
        setEditor({ ...session, busy: false, error });
      }
      return error;
    };
    if (summary === "") {
      // `comment apply` rejects a batch with an empty summary.
      return fail("The note is empty");
    }
    setEditor({ ...session, busy: true, error: undefined });
    const { request } = session;
    const error = request.kind === "edit" ? await saveEdit(session, request, summary) : await saveNew(request, summary);
    if (error) {
      return fail(error);
    }
    cancelEditor();
    return null;
  }

  function NoteEditorPane({ width, height }: ExtensionPaneProps): ReactNode {
    const session = useSyncExternalStore(subscribeEditor, () => editor);
    if (!session) {
      return null;
    }
    return (
      <box width={width} height={height} flexDirection="column" border>
        <text>{editorHeading(session.request)}</text>
        <text>{session.error ?? (session.busy ? "Saving..." : "ctrl+s saves, escape cancels")}</text>
        <textarea
          key={session.id}
          focused
          width={Math.max(1, width - 2)}
          height={Math.max(1, height - 4)}
          initialValue={session.initial}
          keyBindings={[{ name: "s", ctrl: true, action: "submit" }]}
          onSubmit={() => void saveEditor(textarea?.plainText ?? "")}
          onKeyDown={(key: { name: string }) => {
            if (key.name === "escape") {
              cancelEditor();
            }
          }}
          ref={(node: typeof textarea) => {
            if (node && textarea !== node) {
              node.gotoBufferEnd?.();
            }
            textarea = node;
          }}
        />
      </box>
    );
  }

  hunk.registerPane({
    id: EDITOR_PANE,
    title: "Note",
    placement: "bottom",
    height: { preferred: 12, min: 6 },
    component: NoteEditorPane,
  });

  function openEditor(ctx: ExtensionCommandContext, request: EditorRequest, initial = "") {
    setEditor({ id: ++editorCount, request, initial, panes: ctx.panes, review: ctx.review, busy: false });
    ctx.panes.open(EDITOR_PANE);
  }

  /** The selection a note command works from, or why there is none. */
  function noteSite(ctx: ExtensionCommandContext) {
    host.notify = ctx.notify;
    const snapshot = ctx.review.snapshot();
    const { file, currentLine } = ctx.selection;
    if (!snapshot || !file || !currentLine) {
      ctx.notify(!file ? "Select a file before writing a note" : "Move to a line of the diff before writing a note", "warning");
      return null;
    }
    for (const entry of snapshot.files) {
      fileKeys.set(entry.fileKey, entry.path);
    }
    const fileKey = snapshot.files.find((entry) => entry.path === file.path)?.fileKey;
    return { snapshot, file, currentLine, fileKey };
  }

  async function chooseNote(ctx: ExtensionCommandContext, title: string, notes: readonly ExtensionReviewSnapshotNote[]) {
    if (notes.length <= 1) {
      return notes[0];
    }
    const choices = noteChoices(notes);
    const chosen = await ctx.dialogs.select({ title, options: choices.map((choice) => choice.label) });
    return choices.find((choice) => choice.label === chosen)?.note;
  }

  hunk.registerCommand({ id: "note-add", title: "Write a note on the current line", key: "c" }, (ctx) => {
    host.notify = ctx.notify;
    const { file, currentLine } = ctx.selection;
    const target = addTarget(file ? { path: file.path, patch: file.patch, hunks: file.hunks ?? [] } : null, currentLine);
    if ("error" in target) {
      ctx.notify(target.error, "warning");
      return;
    }
    openJournal(ctx.cwd);
    openEditor(ctx, { kind: "add", ...target });
  });

  hunk.registerCommand({ id: "note-reply", title: "Reply to the note on the current line", key: "R" }, async (ctx) => {
    const site = noteSite(ctx);
    if (!site) {
      return;
    }
    const threads = site.fileKey === undefined ? [] : threadsOnLine(site.snapshot.notes, site.fileKey, site.currentLine);
    if (threads.length === 0) {
      ctx.notify("No note on this line to reply to", "warning");
      return;
    }
    const root = await chooseNote(ctx, "Reply to which thread?", threads);
    if (root) {
      openJournal(ctx.cwd);
      openEditor(ctx, { kind: "reply", root, path: site.file.path });
    }
  });

  hunk.registerCommand({ id: "note-edit", title: "Edit your note on the current line", key: "E" }, async (ctx) => {
    const site = noteSite(ctx);
    if (!site) {
      return;
    }
    const state = openJournal(ctx.cwd) ? readJournal() : null;
    // Without a journal (`persist = false`) the author line is all that says who wrote a note.
    const mine = (note: ExtensionReviewSnapshotNote) =>
      note.source === "user" || state?.notes.get(keyOfHost(note.id))?.source === "user" || /^you( \(outdated\))?$/u.test(note.author ?? "");
    const own = site.fileKey === undefined ? [] : ownNotesOnLine(site.snapshot.notes, site.fileKey, site.currentLine, mine);
    if (own.length === 0) {
      ctx.notify("No note of yours on this line", "warning");
      return;
    }
    const note = await chooseNote(ctx, "Edit which note?", own);
    if (note) {
      openEditor(ctx, { kind: "edit", note, path: site.file.path }, note.summary);
    }
  });

  /** Drop saved notes for good, along with every reply under them, and out of the host where it has them. */
  async function forgetSaved(chosen: readonly NoteRecord[], all: ReadonlyMap<string, NoteRecord>, hostIds: ReadonlyMap<string, string>) {
    const keys = new Set(chosen.map((record) => record.key));
    for (let size = -1; size !== keys.size; ) {
      size = keys.size;
      for (const record of all.values()) {
        if (record.parentKey !== undefined && keys.has(record.parentKey)) {
          keys.add(record.key);
        }
      }
    }
    const records = [...all.values()].filter((record) => keys.has(record.key));
    remaps = remaps.filter((remap) => !keys.has(remap.key));
    saveEntries(records.map((record) => ({ op: "remove" as const, t: Date.now(), key: record.key })));
    // An outdated thread is shown beside its old line, so deleting it has to take that copy away too.
    await removeFromHost(records, hostIds, all);
  }

  /** Load the narrowest other changeset of the stack that holds a thread's origin, landing on its file. */
  function goToOrigin(root: NoteRecord, origin: NoteOrigin, notify: (message: string, type?: ExtensionNotifyType) => void) {
    const found = stack.changesetWith(origin, root.path);
    if (!found) {
      notify(`No other changeset in the stack holds what this note was written on (${formatTerminalPath(root.path)})`, "warning");
      return;
    }
    const message = stack.select(found.changeset.id, root.path, found.zoom);
    if (message) {
      notify(message, "warning");
    }
  }

  hunk.registerCommand(
    { id: "show-saved-notes", title: "Saved notes: jump to one, load a pending or resolved one, delete an outdated one", key: "S" },
    async (ctx) => {
      host.notify = ctx.notify;
      const snapshot = ctx.review.snapshot();
      for (const file of snapshot?.files ?? []) {
        fileKeys.set(file.fileKey, file.path);
      }
      const state = openJournal(ctx.cwd) ? readJournal() : null;
      if (!state || state.notes.size === 0) {
        ctx.notify("No saved notes");
        return;
      }
      // Judged afresh, since notes come and go between loads without a restore running.
      const listed = await listNotes();
      const liveIds = new Set("notes" in listed ? listed.notes.map((entry) => entry.noteId) : []);
      const hostIds = liveHostIds(state, remaps, pid, liveIds);
      const liveKeys = new Set(hostIds.keys());
      const records = [...state.notes.values()];
      const files = loadedFiles ?? [];
      // Until the review is known nothing is placed, so every open thread waits.
      const view: RestoreView = restoreView(state)?.view ?? { files, scope: { commits: [] } satisfies Scope, patchIdOf: () => undefined, statuses: state.statuses, forced };
      const plan = planRestore(records, view, liveKeys);
      const groups = groupSaved(records, plan, liveKeys, state.statuses);
      const allRows = savedNoteRows(groups);
      // The dialog lists the first 200; the title counts every one.
      const rows = allRows.slice(0, 200);
      const tally = (kind: string) => allRows.filter((row) => row.kind === kind).length;
      const chosen = await ctx.dialogs.select({
        title: `Saved notes: ${tally("shown")} shown, ${tally("pending")} pending, ${tally("outdated")} outdated, ${tally("resolved")} resolved`,
        options: rows.map((row) => row.label),
      });
      const row = rows.find((candidate) => candidate.label === chosen);
      if (!row) {
        return;
      }
      if (row.kind === "delete-outdated") {
        const count = groups.outdated.length;
        if (await ctx.dialogs.confirm({ title: `Delete ${count} outdated saved note${count === 1 ? "" : "s"}?`, confirmLabel: "delete" })) {
          await forgetSaved(groups.outdated, state.notes, hostIds);
          ctx.notify(`Deleted ${count} saved note${count === 1 ? "" : "s"}`);
        }
        return;
      }
      const { record } = row;
      if (row.kind === "outdated") {
        if (await ctx.dialogs.confirm({ title: "Delete this saved note?", body: row.label, confirmLabel: "delete" })) {
          await forgetSaved([record], state.notes, hostIds);
          ctx.notify("Deleted 1 saved note");
        }
        return;
      }
      // A reply sits under its thread's first note, so that note decides where to look.
      const root = rootOf(record, state.notes);
      const originNow = plan.rehomed.find((entry) => entry.record.key === root.key)?.origin ?? root.origin;
      if (row.kind === "pending") {
        if (plan.verdicts.get(record.key)?.kind === "shown") {
          requestRestore();
          return;
        }
        goToOrigin(root, originNow, ctx.notify);
        return;
      }
      if (row.kind === "resolved" && !liveKeys.has(record.key)) {
        // Shown for this process only; the thread stays resolved in the journal.
        forced.add(record.key);
        const shown = planRestore(records, { ...view, forced }, liveKeys).verdicts.get(record.key)?.kind === "shown";
        if (shown) {
          requestRestore();
        } else {
          goToOrigin(root, originNow, ctx.notify);
        }
        return;
      }
      const loaded = files.find((file) => file.path === root.path);
      const runtimeId = snapshot?.files.find((file) => file.path === root.path)?.runtimeId;
      if (!runtimeId) {
        ctx.notify(`${formatTerminalPath(root.path)} is not in the loaded changeset`, "warning");
        return;
      }
      const target = loaded ? anchorInFile(root, loaded, parsePatch(loaded.patch)) : null;
      if (target) {
        ctx.navigation.revealLine(runtimeId, target.side, target.line);
      } else {
        ctx.navigation.selectFile(runtimeId);
      }
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
      if (args[0] === "notes") {
        if (hunk.config.persist === false) {
          await ctx.stderr.write("hunk stack notes: notes are not saved while `persist = false`\n");
          return { kind: "exit", code: 1 };
        }
        const result = runNotes(args.slice(1), {
          sys: (options.makeSys ?? createSys)(ctx.cwd),
          notesDir: options.notesDir ?? defaultNotesDir(),
        });
        if (result.stdout) {
          await ctx.stdout.write(result.stdout);
        }
        if (result.stderr) {
          await ctx.stderr.write(result.stderr);
        }
        return result.code === 0 ? { kind: "exit" } : { kind: "exit", code: result.code };
      }
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
    openJournal(ctx.cwd);
    requestRestore();
    if (width.error) {
      ctx.notify(width.error, "warning");
    }
    if (launchNotice) {
      ctx.notify(launchNotice, "warning");
    }
  });
  hunk.on("changeset_loaded", (payload, ctx) => {
    host.review = ctx.review;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    renderProgress();
    openJournal(ctx.cwd);
    loadChangeset(payload.changeset.files);
  });
  hunk.on("filter_changed", ({ filter }) => stack.setFilter(filter));

  // A note removed through `hunk session comment` may sit on a path that is not loaded.
  hunk.on("note_changed", ({ kind, note }, ctx) => {
    if (kind === "removed") {
      notes.forget(note.id);
    }
    if (!openJournal(ctx.cwd)) {
      return;
    }
    if (kind === "removed" && hiding.delete(note.id)) {
      // The extension took this note out of the host itself, to hide a resolved thread or to
      // delete a saved note it had already dropped; the journal keeps what it has.
      const key = restoredKeys.get(note.id) ?? noteKey(pid, note.id);
      restoredKeys.delete(note.id);
      remaps = remaps.filter((remap) => remap.key !== key);
      return;
    }
    // The line's text and the origin come from the changeset loaded now; a reload may land
    // before the job runs.
    const files = loadedFiles;
    const origin = kind === "created" ? currentOrigin() : null;
    if (applying > 0) {
      buffered.push({ kind, note, files, origin });
      return;
    }
    if (kind === "created" && authored.has(note.id)) {
      return;
    }
    enqueueJournal(() => journalNote(kind, note, files, origin));
  });
  hunk.on("note_created", ({ note }) => void notePaths.set(note.id, note.filePath));
  hunk.on("note_edited", ({ note }) => void notePaths.set(note.id, note.filePath));

  hunk.on("session_reload", (payload, ctx) => {
    host.review = ctx.review;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    renderProgress();
    // `changeset_loaded` comes first on every reload, so the notes are restored there.
    // The daemon answers a reload request after this event, so the request is still the one running.
    if (payload.reason === "daemon" && !switcher.requesting()) {
      stack.noteOutsideReload();
    }
    const landing = payload.reason === "daemon" ? switcher.takeLanding() : null;
    const file = landing?.path ? payload.changeset.files.find((f) => f.path === landing.path) : undefined;
    if (file) {
      ctx.navigation.selectFile(file.id);
    }
  });

  return {
    /** The note editor's state and its save and cancel paths, which the pane calls; exposed so tests can stand in for it. */
    editor: { current: () => editor, save: saveEditor, cancel: cancelEditor },
    /** What the files pane does when Hunk gives it a review; exposed so tests can stand in for the pane. */
    reportReview: (review: ExtensionReviewDescriptor | null) => stack.observeReview(review),
  };
}

export default function registerDefault(hunk: HunkExtensionAPI) {
  registerStack(hunk);
}
