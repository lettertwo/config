import type { ExtensionReviewDescriptor } from "hunkdiff/extension";
import type { Landing, SwitcherSnapshot } from "./daemon";
import { listChangeset, spawnGit, type GitRunner, type ListedFile } from "./listing";
import { changedPaths, flipTarget, identifyLoaded, stepChangeset, type Flip } from "./navigate";
import { isExpanded, type FileView, type StackOrder } from "./outline";
import { CommitIndex, originInScope, type NoteOrigin, type Scope } from "./origin";
import { commonDir } from "./stack/git";
import { createStackSource, type Changeset, type StackSource, type Zoom } from "./stack/stack";
import type { Sys } from "./stack/sys";

/** The slice of `Switcher` that the stack state drives, so tests can stand in for the daemon. */
export interface ChangesetSwitcher {
  request(changeset: Changeset, landing?: Landing): void;
  pendingTarget(): Changeset | null;
  /** Whether reloads repeat launch options, which a reload from outside the extension drops. */
  carries(): boolean;
  loaded(): string | null;
  /** The changeset whose reload is running, which events during that reload are about. */
  loading(): Changeset | null;
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
  /** Display order of the outline's headers; stepping always walks base to head. */
  order: StackOrder;
  /** Forces the files pane's layout; null picks tree or grouped by pane width. Applies with or without a stack. */
  fileView: FileView | null;
  /** Files of each changeset by id, as they arrive; a changeset git has not answered for is absent. */
  listings: ReadonlyMap<string, readonly ListedFile[]>;
  /** Headers the reviewer expanded or collapsed by hand; the rest follow the loaded changeset. */
  expansion: ReadonlyMap<string, boolean>;
  /** Hunk's file filter query, which the outline applies to every changeset. */
  filter: string;
}

/** A string that is equal for descriptors that show the same revisions. */
export function reviewKey(review: ExtensionReviewDescriptor | null): string {
  if (review === null) {
    return "worktree";
  }
  if (review.kind === "commit") {
    return `commit:${review.revision}`;
  }
  if (review.kind === "comparison") {
    return `range:${review.base}..${review.head}`;
  }
  return `other:${review.kind}`;
}

/** What the stack commands say in a review that `hunk stack` did not open. */
export const NOT_A_STACK = "Not a stack review; open one with `hunk stack`";

/** How many `git diff` probes run at once, so a long stack doesn't fork a process per commit. */
const LISTING_CONCURRENCY = 8;

const EMPTY: StackSnapshot = {
  enabled: false,
  zoom: "branch",
  zooms: [],
  changesets: [],
  loadedId: null,
  pendingId: null,
  order: "head-first",
  fileView: null,
  listings: new Map(),
  expansion: new Map(),
  filter: "",
};

const FILE_VIEW_CYCLE: readonly (FileView | null)[] = [null, "tree", "grouped", "flat"];

/**
 * The stack as the review sees it: the changesets for the current zoom, which one is
 * loaded, and the commands that move between them.
 *
 * The stack is re-read from git on every command, so a branch that moved since the last
 * keypress doesn't send a reload to a stale range.
 */
export class StackState {
  private source: StackSource | null = null;
  private commits: CommitIndex | null = null;
  /** What the pane last reported; undefined until it has, since null is a working-tree review. */
  private review: ExtensionReviewDescriptor | null | undefined = undefined;
  private zoom: Zoom = "branch";
  private order: StackOrder = "head-first";
  private fileView: FileView | null = null;
  private filter = "";
  private changesets: readonly Changeset[] = [];
  /** Set by an outside reload; the next review the pane reports is requested again with the launch options. */
  private carryNext = false;
  private paths = new Map<string, readonly string[]>();
  private listings = new Map<string, { key: string; files: readonly ListedFile[] }>();
  private listing = {
    running: 0,
    queue: [] as (() => void)[],
    inFlight: new Set<string>(),
    idle: [] as (() => void)[],
  };
  private expansion = new Map<string, boolean>();
  private snapshot: StackSnapshot = EMPTY;
  private listeners = new Set<() => void>();

  constructor(
    private readonly makeSys: (cwd: string) => Sys,
    private readonly switcher: ChangesetSwitcher,
    private readonly git: GitRunner = spawnGit,
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
    this.commits = new CommitIndex(sys, this.source);
    this.zoom = this.source.defaultZoom;
    this.order = this.source.defaultStackOrder;
    this.read();
    const current = this.changesets.find((cs) => cs.current);
    if (!current) {
      this.source = null;
      this.commits = null;
      this.publish();
      return { error: "no changesets to review" };
    }
    this.switcher.setLoaded(current.id);
    return current;
  }

  /** The pane reports the descriptor of the review it is showing, which names the loaded changeset exactly. */
  observeReview(review: ExtensionReviewDescriptor | null) {
    // Kept for every review, stack or not, so notes can be tied to what is on screen.
    if (this.review === undefined || reviewKey(this.review) !== reviewKey(review)) {
      this.review = review;
      this.publish();
    }
    const found = identifyLoaded(review, this.changesets) ?? this.adopt(review);
    const carry = this.carryNext;
    this.carryNext = false;
    if (found) {
      this.switcher.setLoaded(found.id);
      if (carry) {
        this.switcher.request(found);
      }
    } else if (review === null && this.source) {
      this.switcher.setLoaded(null);
    }
  }

  /**
   * A `hunk session reload` from outside the extension, such as an agent's, dropped `--watch`
   * and `--agent-context`. When `hunk stack` was launched with either, the next review the pane
   * reports is loaded once more with them, if the stack lists it. Hunk emits `session_reload`
   * from a layout effect, which runs before the pane's effect for the same review.
   */
  noteOutsideReload() {
    if (this.switcher.carries()) {
      this.carryNext = true;
    }
  }

  /**
   * Find the changeset for a review that the changesets in hand do not list. That review came
   * from a `hunk session reload` run outside the extension, such as an agent showing a commit
   * made after the last keypress. The stack is read again and searched at the current zoom
   * first, then at the others, and the zoom follows the match so the outline lists what is on
   * screen.
   */
  private adopt(review: ExtensionReviewDescriptor | null): Changeset | null {
    const source = this.source;
    if (!source || review === null) {
      return null;
    }
    for (const zoom of [this.zoom, ...source.zooms.filter((z) => z !== this.zoom)]) {
      const loaded = source.load(zoom);
      const found = identifyLoaded(review, loaded);
      if (found) {
        this.zoom = zoom;
        this.read(loaded);
        return found;
      }
    }
    return null;
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
  select(id: string, path?: string, zoom?: Zoom): string | null {
    if (!this.source) {
      return null;
    }
    if (zoom !== undefined && zoom !== this.zoom) {
      // The target belongs to another slicing of the stack, which the outline then lists.
      this.zoom = zoom;
    }
    this.read();
    const target = this.changesets.find((cs) => cs.id === id);
    if (!target) {
      return "That changeset is no longer in the stack";
    }
    // A load from the outline leaves its folds as the reviewer sees them. Stepping and zoom
    // don't come through here, so they still fold to follow the loaded changeset.
    const loaded = this.switcher.loaded();
    for (const id of loaded === null ? [target.id] : [loaded, target.id]) {
      if (!this.expansion.has(id)) {
        this.expansion.set(id, this.isExpanded(id));
      }
    }
    this.publish();
    this.switcher.request(target, path === undefined ? undefined : { path });
    return null;
  }

  isExpanded(id: string): boolean {
    return isExpanded(this.expansion, this.switcher.loaded(), id);
  }

  /**
   * The changeset the review is showing, or null when the extension cannot say. While a reload
   * of ours runs, that is the changeset being loaded, since Hunk emits its events before the
   * switcher records the load as done.
   */
  showing(): Changeset | null {
    if (!this.source) {
      return null;
    }
    const id = this.switcher.loading()?.id ?? this.switcher.loaded();
    return this.changesets.find((cs) => cs.id === id) ?? null;
  }

  /** The review the pane last reported: null for a working-tree review, undefined before any report. */
  reviewDescriptor(): ExtensionReviewDescriptor | null | undefined {
    return this.review;
  }

  /** The commits a changeset holds, as notes are matched against them; null outside a stack review. */
  scopeOf(changeset: Changeset): Scope | null {
    return this.commits?.scopeOf(changeset) ?? null;
  }

  /** The commit facts behind `scopeOf`: origins, patch ids, and which branch owns a commit. */
  get commitIndex(): CommitIndex | null {
    return this.commits;
  }

  /**
   * The narrowest changeset, other than the loaded one, that holds a note's origin and changes
   * `path`: a commit's own changeset before its branch's, and that before the combined one.
   * Null when the stack has none.
   */
  changesetWith(origin: NoteOrigin, path: string): { changeset: Changeset; zoom: Zoom } | null {
    const source = this.source;
    const commits = this.commits;
    if (!source || !commits) {
      return null;
    }
    this.read();
    const loaded = this.switcher.loaded();
    const sys = this.makeSys(source.cwd);
    for (const zoom of (["commit", "branch", "combined"] as const).filter((candidate) => source.zooms.includes(candidate))) {
      for (const changeset of zoom === this.zoom ? this.changesets : source.load(zoom)) {
        if (changeset.id !== loaded && originInScope(origin, commits.scopeOf(changeset), commits.patchId) && changedPaths(sys, changeset).includes(path)) {
          return { changeset, zoom };
        }
      }
    }
    return null;
  }

  /** Expand or collapse a header; `to` omitted flips it. */
  setExpanded(id: string, to?: boolean) {
    this.expansion.set(id, to ?? !this.isExpanded(id));
    this.publish();
  }

  setFilter(filter: string) {
    if (filter !== this.filter) {
      this.filter = filter;
      this.publish();
    }
  }

  /** Resolves once every file list asked for so far has arrived or failed. */
  settled(): Promise<void> {
    return this.listing.inFlight.size === 0 ? Promise.resolve() : new Promise((done) => this.listing.idle.push(done));
  }

  toggleOrder(): string {
    if (!this.source) {
      return NOT_A_STACK;
    }
    this.order = this.order === "head-first" ? "base-first" : "head-first";
    this.publish();
    return `Stack order: ${this.order}`;
  }

  /** Cycles the files pane's layout: width-based, then tree, grouped, and flat. */
  cycleFileView(): string {
    this.fileView = FILE_VIEW_CYCLE[(FILE_VIEW_CYCLE.indexOf(this.fileView) + 1) % FILE_VIEW_CYCLE.length]!;
    this.publish();
    return `File view: ${this.fileView ?? "auto"}`;
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

  /** Take the stack at the current zoom from git, or from `loaded` when the caller just read it. */
  private read(loaded?: readonly Changeset[]) {
    if (!this.source) {
      return;
    }
    this.changesets = loaded ?? this.source.load(this.zoom);
    this.commits?.refresh();
    this.paths.clear();
    for (const id of this.listings.keys()) {
      if (!this.changesets.some((cs) => cs.id === id)) {
        this.listings.delete(id);
      }
    }
    this.fetchListings();
    this.publish();
  }

  /**
   * Ask git for the file list of every changeset whose range changed since it was last
   * listed. A range of shas never changes, so only the uncommitted changeset is asked again
   * on each read, and it keeps showing the old list until the new one arrives.
   */
  private fetchListings() {
    const source = this.source!;
    for (const changeset of this.changesets) {
      const key = `${changeset.baseSha}..${changeset.headSha}`;
      const have = this.listings.get(changeset.id);
      if (have?.key === key && !changeset.uncommitted) {
        continue;
      }
      const flight = `${changeset.id}:${key}`;
      if (this.listing.inFlight.has(flight)) {
        continue;
      }
      this.listing.inFlight.add(flight);
      this.whenListingSlot(async () => {
        const files = await listChangeset(this.git, source.cwd, changeset);
        // A zoom cycle may have replaced the list while git ran; a stale answer would
        // show another slicing's files under a reused id.
        const now = this.changesets.find((cs) => cs.id === changeset.id);
        const stale = `${now?.baseSha}..${now?.headSha}` !== key;
        if (files && !stale && this.source === source) {
          this.listings.set(changeset.id, { key, files });
          this.publish();
        }
        this.listing.inFlight.delete(flight);
      });
    }
  }

  private whenListingSlot(job: () => Promise<void>) {
    const listing = this.listing;
    const run = () => {
      listing.running += 1;
      void job().finally(() => {
        listing.running -= 1;
        listing.queue.shift()?.();
        if (listing.inFlight.size === 0) {
          listing.idle.splice(0).forEach((done) => done());
        }
      });
    };
    if (listing.running < LISTING_CONCURRENCY) {
      run();
    } else {
      listing.queue.push(run);
    }
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
          order: this.order,
          fileView: this.fileView,
          listings: new Map([...this.listings].map(([id, { files }]) => [id, files])),
          expansion: new Map(this.expansion),
          filter: this.filter,
        }
      : { ...EMPTY, fileView: this.fileView };
    for (const listener of [...this.listeners]) {
      listener();
    }
  }
}
