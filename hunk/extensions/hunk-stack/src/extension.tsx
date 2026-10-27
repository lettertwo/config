import { useMemo, useSyncExternalStore, type ReactNode } from "react";
import type {
  ExtensionDiffFile,
  ExtensionLineHighlightControls,
  ExtensionNotifyType,
  ExtensionPaneProps,
  ExtensionReviewReloadControls,
  ExtensionStatusLineControls,
  HunkExtensionAPI,
} from "hunkdiff/extension";
import { dimHighlights, hiddenNotice, isUnderDirectory, nextUnread, progressSpans } from "./vendored/mark-read/core";
import { defaultSessionDir, SessionLog } from "./vendored/mark-read/sessionLog";
import { MarkReadStore } from "./vendored/mark-read/store";
import { FlexFileSidebar, type SidebarReadState } from "./vendored/sidebar/FileSidebars";
import { fitText, formatTerminalPath } from "./vendored/sidebar/helpers";

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

export interface StackOptions {
  /** Where session files live; defaults to `defaultSessionDir()`. */
  sessionDir?: string;
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
  let reviewTitle = "review";
  let persistFailed = false;

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
    const { files } = props;

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

  // Same geometry as Hunk's bundled files pane, which this replaces.
  hunk.registerPane({
    id: "files",
    title: "Files",
    placement: "left",
    width: { preferred: 34, min: 22, max: 56, fraction: 0.16 },
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

  hunk.on("startup", (_payload, ctx) => {
    host.notify = ctx.notify;
  });
  hunk.on("changeset_loaded", (_payload, ctx) => {
    host.review = ctx.review;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    renderProgress();
  });
  hunk.on("session_reload", (_payload, ctx) => {
    host.review = ctx.review;
    host.statusLine = ctx.statusLine;
    host.notify = ctx.notify;
    renderProgress();
  });
}

export default function registerDefault(hunk: HunkExtensionAPI) {
  registerStack(hunk);
}
