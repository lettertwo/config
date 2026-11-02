/** One reviewed file as the pane sees it: its path and the notes Hunk shows on it. */
export interface NotedFile {
  path: string;
  agent: { annotations: readonly { id?: string }[] } | null;
}

/**
 * Note counts by path, for the rows of changesets that are not loaded.
 *
 * Hunk keys saved notes by repository and path, not by diff range, and matches a sidecar's
 * annotations by path on every load, so both follow a path into every changeset that touches
 * it. Hunk only hands the pane the loaded changeset's files, so the counts for other paths are
 * the ones seen when they were last loaded.
 */
export class NoteTally {
  /** Each path's notes as last seen: how many, and the ids a removal can name. */
  private byPath = new Map<string, { count: number; ids: ReadonlySet<string> }>();
  private snapshot: ReadonlyMap<string, number> = new Map();
  private readonly listeners = new Set<() => void>();

  getSnapshot = (): ReadonlyMap<string, number> => this.snapshot;

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  /**
   * Take the loaded files' notes as the whole truth for their paths. Paths not in `files`
   * (other changesets, filtered or hidden files) keep their counts.
   */
  observe(files: readonly NotedFile[]): void {
    const next = new Map(this.byPath);
    for (const file of files) {
      const annotations = file.agent?.annotations ?? [];
      const ids = new Set(annotations.flatMap((annotation) => (annotation.id === undefined ? [] : [annotation.id])));
      next.set(file.path, { count: annotations.length, ids });
    }
    this.replace(next);
  }

  /** A note was removed, possibly on a path that is not loaded. */
  forget(id: string): void {
    const found = [...this.byPath].find(([, notes]) => notes.ids.has(id));
    if (found) {
      const [path, { count, ids }] = found;
      const next = new Map(this.byPath);
      next.set(path, { count: count - 1, ids: new Set([...ids].filter((other) => other !== id)) });
      this.replace(next);
    }
  }

  private replace(next: Map<string, { count: number; ids: ReadonlySet<string> }>) {
    const counts = new Map([...next].flatMap(([path, { count }]) => (count > 0 ? [[path, count] as const] : [])));
    this.byPath = next;
    if (sameCounts(counts, this.snapshot)) {
      return;
    }
    this.snapshot = counts;
    for (const listener of this.listeners) {
      listener();
    }
  }
}

function sameCounts(a: ReadonlyMap<string, number>, b: ReadonlyMap<string, number>) {
  return a.size === b.size && [...a].every(([path, count]) => b.get(path) === count);
}
