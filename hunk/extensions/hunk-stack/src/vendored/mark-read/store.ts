// Vendored from hunk-mark-read (1a76ae85bbd26753314d29db3a89796f1fc63580)
// upstream: src/store.ts
// Local changes are marked with "stack:". Compare with `bun run vendor:diff mark-read`.

import { readKey, type KeyedFile } from "./core";

/** One reviewed file as the last changeset transform saw it, before hiding. */
export interface ReviewEntry {
  path: string;
  /** `null` for a file whose patch cannot reveal changes; it is never read. */
  key: string | null;
}

export interface MarkReadSnapshot {
  /** Read keys (`readKey`). Keyed by content, so a diff that changes back reads as read again. */
  readonly marks: ReadonlySet<string>;
  /** Hide read files from the review. */
  readonly hidden: boolean;
  /** Every file in the current review, including hidden ones, in review order. */
  readonly review: readonly ReviewEntry[];
}

/** One key whose read state a `setRead` call changed. */
export interface MarkChange {
  key: string;
  read: boolean;
}

/**
 * Session-local mark state shared by the commands, the transform, the line
 * highlighter, and the sidebar pane.
 *
 * Snapshots are immutable so the pane can read them through
 * `useSyncExternalStore`.
 */
export class MarkReadStore {
  private snapshot: MarkReadSnapshot = { marks: new Set(), hidden: false, review: [] };
  private readonly listeners = new Set<() => void>();
  private keyCache = new Map<string, string | null>();

  getSnapshot = (): MarkReadSnapshot => this.snapshot;

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  /** Look up (and cache) the read key for one file's current diff. */
  keyOf(file: KeyedFile): string | null {
    const cacheKey = `${file.path}\0${file.previousPath ?? ""}\0${file.patch}`;
    let key = this.keyCache.get(cacheKey);
    if (key === undefined) {
      key = readKey(file);
      this.keyCache.set(cacheKey, key);
    }
    return key;
  }

  isTrackable(file: KeyedFile): boolean {
    return this.keyOf(file) !== null;
  }

  isRead(file: KeyedFile): boolean {
    const key = this.keyOf(file);
    return key !== null && this.snapshot.marks.has(key);
  }

  /** Files that can be read at all; untrackable files are left out of progress. */
  trackableCount(): number {
    return this.snapshot.review.filter((entry) => entry.key !== null).length;
  }

  readCount(): number {
    return this.snapshot.review.filter(
      (entry) => entry.key !== null && this.snapshot.marks.has(entry.key),
    ).length;
  }

  /**
   * Record the full review a changeset transform received, optionally
   * replacing the marks with ones loaded from disk.
   */
  setReview(files: readonly KeyedFile[], marks?: ReadonlySet<string>): void {
    // Rebuild the cache from the files under review, so it cannot grow without bound.
    const previousCache = this.keyCache;
    this.keyCache = new Map();
    const review = files.map((file) => {
      const cacheKey = `${file.path}\0${file.previousPath ?? ""}\0${file.patch}`;
      const cached = previousCache.get(cacheKey);
      const key = cached === undefined ? readKey(file) : cached;
      this.keyCache.set(cacheKey, key);
      return { path: file.path, key };
    });
    this.update({ ...this.snapshot, marks: marks ?? this.snapshot.marks, review });
  }

  /** Mark or unmark files by their diff; returns the keys that actually changed. */
  setRead(files: readonly KeyedFile[], read: boolean): MarkChange[] {
    const marks = new Set(this.snapshot.marks);
    const changes: MarkChange[] = [];
    for (const file of files) {
      const key = this.keyOf(file);
      if (key === null) {
        continue;
      }
      if (read && !marks.has(key)) {
        marks.add(key);
        changes.push({ key, read });
      } else if (!read && marks.delete(key)) {
        changes.push({ key, read });
      }
    }
    if (changes.length > 0) {
      this.update({ ...this.snapshot, marks });
    }
    return changes;
  }

  setHidden(hidden: boolean): void {
    if (hidden !== this.snapshot.hidden) {
      this.update({ ...this.snapshot, hidden });
    }
  }

  private update(next: MarkReadSnapshot) {
    this.snapshot = next;
    for (const listener of this.listeners) {
      listener();
    }
  }
}
