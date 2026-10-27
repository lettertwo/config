import type { ExtensionReviewDescriptor } from "hunkdiff/extension";
import type { Landing, SwitcherSnapshot } from "./daemon";
import { changedPaths, flipTarget, identifyLoaded, stepChangeset, type Flip } from "./navigate";
import { commonDir } from "./stack/git";
import { createStackSource, type Changeset, type StackSource, type Zoom } from "./stack/stack";
import type { Sys } from "./stack/sys";

/** The slice of `Switcher` that the stack state drives, so tests can stand in for the daemon. */
export interface ChangesetSwitcher {
  request(changeset: Changeset, landing?: Landing): void;
  pendingTarget(): Changeset | null;
  loaded(): string | null;
  setLoaded(id: string | null): void;
  getSnapshot(): SwitcherSnapshot;
  subscribe(listener: () => void): () => void;
}

export interface StackSnapshot {
  /** False until `hunk stack` opens the review; the stack commands then say so. */
  enabled: boolean;
  zoom: Zoom;
  zooms: readonly Zoom[];
  changesets: readonly Changeset[];
  loadedId: string | null;
  pendingId: string | null;
}

/** What the stack commands say in a review that `hunk stack` did not open. */
export const NOT_A_STACK = "Not a stack review; open one with `hunk stack`";

const EMPTY: StackSnapshot = {
  enabled: false,
  zoom: "branch",
  zooms: [],
  changesets: [],
  loadedId: null,
  pendingId: null,
};

/**
 * The stack as the review sees it: the changesets for the current zoom, which one is
 * loaded, and the commands that move between them.
 *
 * The stack is re-read from git on every command, so a branch that moved since the last
 * keypress doesn't send a reload to a stale range.
 */
export class StackState {
  private source: StackSource | null = null;
  private zoom: Zoom = "branch";
  private changesets: readonly Changeset[] = [];
  private paths = new Map<string, readonly string[]>();
  private snapshot: StackSnapshot = EMPTY;
  private listeners = new Set<() => void>();

  constructor(
    private readonly makeSys: (cwd: string) => Sys,
    private readonly switcher: ChangesetSwitcher,
  ) {
    switcher.subscribe(() => this.publish());
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  getSnapshot = (): StackSnapshot => this.snapshot;

  /**
   * Read the stack for `hunk stack` and return the changeset the review opens on, as the
   * nvim review app does: the uncommitted changes when there are any, else the focus branch.
   * Until this runs the state stays disabled, so other hunk commands get no outline.
   */
  open(cwd: string): Changeset | { error: string } {
    const sys = this.makeSys(cwd);
    if (commonDir(sys) === null) {
      return { error: "not a git repository" };
    }
    try {
      this.source = createStackSource(sys);
    } catch (error) {
      // createStackSource throws on an unknown gh-stack schema or a repo with no trunk branch.
      return { error: `no stack (${error instanceof Error ? error.message : error})` };
    }
    this.zoom = this.source.defaultZoom;
    this.read();
    const current = this.changesets.find((cs) => cs.current);
    if (!current) {
      this.source = null;
      this.publish();
      return { error: "no changesets to review" };
    }
    this.switcher.setLoaded(current.id);
    return current;
  }

  /** The pane reports the descriptor of the review it is showing, which names the loaded changeset exactly. */
  observeReview(review: ExtensionReviewDescriptor | null) {
    const found = identifyLoaded(review, this.changesets);
    if (found) {
      this.switcher.setLoaded(found.id);
    } else if (review === null && this.source) {
      this.switcher.setLoaded(null);
    }
  }

  /** Move toward the head (+1) or the base (-1). Returns what to tell the user. */
  step(direction: 1 | -1): string {
    if (!this.source) {
      return NOT_A_STACK;
    }
    this.read();
    const from = this.switcher.pendingTarget()?.id ?? this.switcher.loaded();
    const next = stepChangeset(this.changesets, from, direction, (cs) => this.pathsOf(cs).length > 0);
    if (!next) {
      return direction === 1 ? "Already on the changeset nearest the head" : "Already on the changeset nearest the base";
    }
    this.switcher.request(next);
    return next.title;
  }

  /**
   * Load a changeset by id, landing on `path` when given, as clicking one of its files does.
   * Returns what to tell the user, if anything.
   */
  select(id: string, path?: string): string | null {
    if (!this.source) {
      return null;
    }
    this.read();
    const target = this.changesets.find((cs) => cs.id === id);
    if (!target) {
      return "That changeset is no longer in the stack";
    }
    this.switcher.request(target, path === undefined ? undefined : { path });
    return null;
  }

  /** Cycle to the next zoom and land on the file the reviewer was on. */
  cycleZoom(selectedPath: string | null): string {
    const source = this.source;
    if (!source) {
      return NOT_A_STACK;
    }
    const from = this.zoom;
    const to = source.zooms[(source.zooms.indexOf(from) + 1) % source.zooms.length]!;
    if (to === from) {
      return `Zoom: ${from} (only zoom for this review)`;
    }
    const loaded = this.changesets.find((cs) => cs.id === this.switcher.loaded());
    this.zoom = to;
    this.read();
    const flip: Flip | null = selectedPath
      ? { from, to, prevPath: selectedPath, prevBranch: loaded?.branch }
      : null;
    const target = flipTarget(this.changesets, flip, (cs) => this.pathsOf(cs));
    if (target) {
      this.switcher.request(target.changeset, { path: target.path });
    }
    return `Zoom: ${to}`;
  }

  private read() {
    if (!this.source) {
      return;
    }
    this.changesets = this.source.load(this.zoom);
    this.paths.clear();
    this.publish();
  }

  /** Memoized per read: stepping probes several changesets and a flip probes them all. */
  private pathsOf(changeset: Changeset): readonly string[] {
    let paths = this.paths.get(changeset.id);
    if (!paths) {
      paths = changedPaths(this.makeSys(this.source!.cwd), changeset);
      this.paths.set(changeset.id, paths);
    }
    return paths;
  }

  private publish() {
    const switcher = this.switcher.getSnapshot();
    this.snapshot = this.source
      ? {
          enabled: true,
          zoom: this.zoom,
          zooms: this.source.zooms,
          changesets: this.changesets,
          loadedId: switcher.loadedId,
          pendingId: switcher.pendingId,
        }
      : EMPTY;
    for (const listener of [...this.listeners]) {
      listener();
    }
  }
}
