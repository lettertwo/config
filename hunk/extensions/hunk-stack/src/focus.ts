import type {
  ExtensionDiffFile,
  ExtensionKeyEvent,
  ExtensionKeyboardModeKeyResult,
  ExtensionPaneActions,
} from "hunkdiff/extension";

/** One row the cursor can rest on: a changeset header (`path` null) or a file. */
export interface NavRow {
  /** The sidebar entry id, for painting and scrolling to the row. */
  entryId: string;
  /** The loaded changeset's id on its own files; null when nothing listed is loaded. */
  changesetId: string | null;
  path: string | null;
  /** The review's file id, present only for files of the loaded changeset. */
  fileId: string | null;
}

/** Where the cursor is, by names that survive a reload renumbering file ids. */
export interface Cursor {
  changesetId: string | null;
  path: string | null;
}

export interface FocusSnapshot {
  active: boolean;
  /** The row to paint the cursor on, or null while the mode is off. */
  cursorEntryId: string | null;
}

/** What the pane hands over on each render, since a keyboard mode sees no review controls of its own. */
export interface PaneLink {
  actions: Pick<ExtensionPaneActions, "selectFile">;
  files: readonly ExtensionDiffFile[];
  selectedFileId: string | null;
  /** The loaded changeset's id as the rows carry it. */
  loadedId: string | null;
  /** The changeset a reload is on its way to, which the review does not show yet. */
  pendingId: string | null;
}

/** The effects a key can have beyond moving the cursor. */
export interface FocusHost {
  toggleRead(file: ExtensionDiffFile): void;
  isExpanded(changesetId: string): boolean;
  setExpanded(changesetId: string, to: boolean): void;
  /** Load another changeset and land on `path`. */
  openFile(changesetId: string, path: string): void;
}

/** Runs `run` later; the returned function cancels it if it has not run. */
export type Defer = (run: () => void) => () => void;

/** Long enough that walking past a changeset does not start a reload for it. */
const FOLLOW_DELAY_MS = 150;

const deferBy =
  (ms: number): Defer =>
  (run) => {
    const timer = setTimeout(run, ms);
    return () => clearTimeout(timer);
  };

const sameRow = (row: NavRow, cursor: Cursor) =>
  row.changesetId === cursor.changesetId && row.path === cursor.path;

/**
 * The outline's keyboard cursor. The pane publishes the rows it draws, so the cursor walks
 * what is on screen (collapsed directories and headers included) without recomputing the
 * layout here.
 */
export class OutlineFocus {
  private rows: readonly NavRow[] = [];
  private cursor: Cursor | null = null;
  private active = false;
  private pane: PaneLink | null = null;
  private snapshot: FocusSnapshot = { active: false, cursorEntryId: null };
  private listeners = new Set<() => void>();
  private cancelFollow: (() => void) | null = null;

  constructor(
    private readonly host: FocusHost,
    private readonly defer: Defer = deferBy(FOLLOW_DELAY_MS),
  ) {}

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  getSnapshot = (): FocusSnapshot => this.snapshot;

  /** Returns the detach function, for the pane's effect cleanup. */
  attach(pane: PaneLink): () => void {
    this.pane = pane;
    return () => {
      if (this.pane === pane) {
        this.pane = null;
      }
    };
  }

  hasPane(): boolean {
    return this.pane !== null && this.rows.length > 0;
  }

  /** The rows changed (a reload, a toggle, a list arriving): find the cursor again by name. */
  publishRows = (rows: readonly NavRow[]) => {
    this.rows = rows;
    if (this.active && !this.cursor) {
      // Entered before the pane had drawn (it was opening); start once its rows arrive.
      this.cursor = this.startCursor();
    } else if (this.cursor) {
      const cursor = this.cursor;
      const found =
        rows.find((row) => sameRow(row, cursor)) ??
        // A vanished file leaves the cursor on its changeset's header.
        rows.find((row) => row.path === null && row.changesetId === cursor.changesetId) ??
        rows[0];
      this.cursor = found ? { changesetId: found.changesetId, path: found.path } : null;
    }
    this.publish();
  };

  /** Start on the selected file, or the first row when it isn't listed. */
  enter() {
    this.active = true;
    this.cursor = this.startCursor();
    this.publish();
  }

  private startCursor(): Cursor | null {
    const pane = this.pane;
    const selected = pane?.files.find((file) => file.id === pane.selectedFileId);
    const onFile = selected && this.rows.find((row) => row.fileId === selected.id);
    const start = onFile ?? this.rows[0];
    return start ? { changesetId: start.changesetId, path: start.path } : null;
  }

  leave() {
    this.active = false;
    this.cursor = null;
    this.publish();
  }

  /** Decide one key. Returns synchronously; reloads it starts finish later. */
  handleKey(key: ExtensionKeyEvent): ExtensionKeyboardModeKeyResult {
    if (key.ctrl || key.meta || key.option) {
      return "pass";
    }
    const name = key.name;
    const upper = key.sequence === "G" || (name === "g" && key.shift === true);
    if (key.shift && !upper) {
      return "pass";
    }
    if (upper) {
      this.moveTo(this.rows.length - 1);
      return "handled";
    }
    switch (name) {
      case "j":
      case "down":
        this.moveTo(this.index() + 1);
        return "handled";
      case "k":
      case "up":
        this.moveTo(this.index() - 1);
        return "handled";
      case "g":
        this.moveTo(0);
        return "handled";
      case "return":
      case "enter":
        this.activate();
        return "handled";
      case "l":
        this.expand(true);
        return "handled";
      case "h":
        this.collapse();
        return "handled";
      case "space":
        this.toggleRead();
        return "handled";
      case "escape":
      case "q":
      case "tab":
        return "exit";
      default:
        return "pass";
    }
  }

  private index(): number {
    const cursor = this.cursor;
    return cursor ? this.rows.findIndex((row) => sameRow(row, cursor)) : -1;
  }

  private current(): NavRow | undefined {
    return this.rows[this.index()];
  }

  private moveTo(index: number) {
    const row = this.rows[Math.min(this.rows.length - 1, Math.max(0, index))];
    if (!row) {
      return;
    }
    this.cursor = { changesetId: row.changesetId, path: row.path };
    this.publish();
    this.follow(row);
  }

  /**
   * Make the diff show the cursor's file. A loaded file selects at once; a file of another
   * changeset loads it once the cursor rests, so only the file the reviewer stops on costs a
   * reload. Headers load nothing, since a load expands the changeset it opens.
   */
  private follow(row: NavRow) {
    this.cancelFollow?.();
    this.cancelFollow = null;
    const pane = this.pane;
    const changesetId = row.changesetId;
    if (!pane || changesetId === null || row.path === null) {
      return;
    }
    // While a reload is on its way elsewhere, selecting in the loaded changeset would be
    // undone when it lands, so coming back has to load it again.
    const showing = changesetId === pane.loadedId && (pane.pendingId === null || pane.pendingId === changesetId);
    if (showing) {
      if (row.fileId) {
        pane.actions.selectFile(row.fileId);
      }
      return;
    }
    const path = row.path;
    this.cancelFollow = this.defer(() => {
      this.cancelFollow = null;
      this.host.openFile(changesetId, path);
    });
  }

  private activate() {
    const row = this.current();
    if (!row) {
      return;
    }
    if (row.path === null) {
      if (row.changesetId !== null) {
        this.host.setExpanded(row.changesetId, !this.host.isExpanded(row.changesetId));
      }
    } else if (row.fileId) {
      this.pane?.actions.selectFile(row.fileId);
    } else if (row.changesetId !== null) {
      this.cancelFollow?.();
      this.cancelFollow = null;
      this.host.openFile(row.changesetId, row.path);
    }
  }

  private expand(to: boolean) {
    const row = this.current();
    if (row?.path === null && row.changesetId !== null) {
      this.host.setExpanded(row.changesetId, to);
    }
  }

  private collapse() {
    const row = this.current();
    if (!row) {
      return;
    }
    if (row.path === null) {
      this.expand(false);
      return;
    }
    const header = this.rows.find((other) => other.path === null && other.changesetId === row.changesetId);
    if (header) {
      this.cursor = { changesetId: header.changesetId, path: null };
      this.publish();
    }
  }

  private toggleRead() {
    const fileId = this.current()?.fileId;
    const file = fileId ? this.pane?.files.find((candidate) => candidate.id === fileId) : undefined;
    if (file) {
      this.host.toggleRead(file);
    }
  }

  private publish() {
    const cursor = this.cursor;
    const entryId = this.active && cursor ? (this.rows.find((row) => sameRow(row, cursor))?.entryId ?? null) : null;
    if (this.snapshot.active === this.active && this.snapshot.cursorEntryId === entryId) {
      return;
    }
    this.snapshot = { active: this.active, cursorEntryId: entryId };
    for (const listener of [...this.listeners]) {
      listener();
    }
  }
}
