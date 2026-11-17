import { appendFileSync, mkdirSync, readFileSync, readdirSync, statSync, unlinkSync } from "node:fs";
import { createHash } from "node:crypto";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { findCommit, originInScope, parseCommit, parseOrigin, type NoteOrigin, type OriginCommit, type PatchIdOf, type Scope } from "./origin";
import { RETENTION_DAYS } from "./vendored/mark-read/sessionLog";

export type { NoteOrigin, OriginCommit };

export type NoteSide = "old" | "new";
export type NoteSource = "ai" | "agent" | "user";

/**
 * One review note as the journal keeps it.
 *
 * A note's id is not quite unique across restarts: Hunk names a user note by the millisecond
 * and a counter that starts at zero in each process (`user:<ms>-<n>`), though agent notes carry
 * a UUID. `key` is the journal's own identity: the pid of the process that created the note,
 * then its id there. A restored note keeps the key it was first saved under, however many times it is
 * restored.
 */
export interface NoteRecord {
  key: string;
  /** The note's id in the process that created it. */
  id: string;
  /** Key of the note this one replies to. */
  parentKey?: string;
  /** The parent's id in the process that created this note, kept for the record's reader. */
  parentId?: string;
  source: NoteSource;
  author?: string;
  /** Repo-relative, as the loaded changeset spells it. */
  path: string;
  side?: NoteSide;
  line?: number;
  oldRange?: readonly [number, number];
  newRange?: readonly [number, number];
  summary: string;
  rationale?: string;
  markup?: string;
  createdAt?: string;
  updatedAt?: string;
  /** The anchored line's text when the note was saved, so the note can find the line again. */
  lineText?: string;
  /** Up to two lines on each side of the anchored line, so a repeated line is not mistaken for it. */
  context?: LineContext;
  /** The changeset the note was written on. A record without one is from an older journal and is dropped on read. */
  origin: NoteOrigin;
}

export interface LineContext {
  before: string[];
  after: string[];
}

/** Whether the reviewer is waiting on an answer in a thread, or it is closed. */
export type ThreadStatus = "open" | "resolved";

/** A thread's status, kept under its root note's key. */
export interface ThreadState {
  status: ThreadStatus;
  /** The commit that closed the thread, found again after a rebase the way an origin commit is. */
  fix?: OriginCommit;
}

export interface Remap {
  /** Process that restored the note. */
  pid: number;
  /** Journal key of the restored note. */
  key: string;
  /** The id Hunk gave the restored note in that process. */
  to: string;
}

export type JournalEntry =
  | { op: "put"; t: number; note: NoteRecord }
  | { op: "remove"; t: number; key: string }
  | { op: "remap"; t: number; pid: number; key: string; to: string }
  | { op: "status"; t: number; key: string; status: ThreadStatus; fix?: OriginCommit };

export interface JournalState {
  /** Live records in the order they were first saved. */
  notes: Map<string, NoteRecord>;
  remaps: Remap[];
  /** The latest status per thread root; a thread with none is open. */
  statuses: Map<string, ThreadState>;
}

export function emptyState(): JournalState {
  return { notes: new Map(), remaps: [], statuses: new Map() };
}

export function noteKey(pid: number, id: string): string {
  return `${pid}:${id}`;
}

/** `$XDG_STATE_HOME/hunk-stack/notes`, defaulting to `~/.local/state`. */
export function defaultNotesDir(env: Record<string, string | undefined> = process.env): string {
  const stateHome = env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return join(stateHome, "hunk-stack", "notes");
}

/** A worktree root's file name: a readable label plus a hash, since two roots can share a basename. */
export function journalFileName(root: string): string {
  const label = basename(root).replace(/[^A-Za-z0-9._~-]+/gu, "_").replace(/^_+|_+$/gu, "").slice(0, 60) || "root";
  const hash = createHash("sha1").update(root).digest("hex").slice(0, 12);
  return `${label}-${hash}.jsonl`;
}

function parseEntry(line: string): JournalEntry | null {
  try {
    const value = JSON.parse(line) as Partial<JournalEntry> & Record<string, unknown>;
    if (typeof value.t !== "number") {
      return null;
    }
    if (value.op === "put" && value.note && typeof value.note.key === "string" && typeof value.note.path === "string") {
      // Notes saved before origins existed cannot be placed on a changeset, so they are dropped.
      return parseOrigin((value.note as { origin?: unknown }).origin) ? (value as JournalEntry) : null;
    }
    if (value.op === "status" && typeof value.key === "string" && (value.status === "open" || value.status === "resolved")) {
      return value.fix === undefined || parseCommit(value.fix) ? (value as JournalEntry) : null;
    }
    if (value.op === "remove" && typeof value.key === "string") {
      return value as JournalEntry;
    }
    if (value.op === "remap" && typeof value.key === "string" && typeof value.to === "string" && typeof value.pid === "number") {
      return value as JournalEntry;
    }
    return null;
  } catch {
    // A line another process is still writing, or a hand edit.
    return null;
  }
}

/**
 * Replay entries in file order: the latest put per key wins, a remove ends the key, and the
 * latest status per key wins. With one writer, file order is write order; `t` is wall-clock time
 * and can step backwards.
 */
export function replay(entries: readonly JournalEntry[]): JournalState {
  const notes = new Map<string, NoteRecord>();
  const remaps: Remap[] = [];
  const statuses = new Map<string, ThreadState>();
  for (const entry of entries) {
    if (entry.op === "put") {
      notes.set(entry.note.key, entry.note);
    } else if (entry.op === "remove") {
      notes.delete(entry.key);
      statuses.delete(entry.key);
    } else if (entry.op === "status") {
      statuses.set(entry.key, entry.fix ? { status: entry.status, fix: entry.fix } : { status: entry.status });
    } else {
      remaps.push({ pid: entry.pid, key: entry.key, to: entry.to });
    }
  }
  // A removed note's remaps would otherwise keep reporting it as live.
  return { notes, remaps: remaps.filter((remap) => notes.has(remap.key)), statuses };
}

/**
 * Append-only note persistence: one JSONL file per worktree root.
 *
 * Hunk allows one session per worktree, so the file has one writer at a time and appends never
 * contend. Nothing is rewritten; files untouched for `RETENTION_DAYS` are deleted whole.
 */
export class NoteJournal {
  private readonly path: string;

  constructor(
    private readonly dir: string,
    root: string,
  ) {
    this.path = join(dir, journalFileName(root));
  }

  load(): JournalState {
    let text: string;
    try {
      text = readFileSync(this.path, "utf8");
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") {
        return emptyState();
      }
      throw error;
    }
    const entries: JournalEntry[] = [];
    for (const line of text.split("\n")) {
      const entry = line ? parseEntry(line) : null;
      if (entry) {
        entries.push(entry);
      }
    }
    return replay(entries);
  }

  append(entries: readonly JournalEntry[]): void {
    if (entries.length === 0) {
      return;
    }
    mkdirSync(this.dir, { recursive: true });
    // The leading newline ends a line that a crash left half written, so it cannot swallow this
    // batch's first entry. Blank lines are skipped on read.
    appendFileSync(this.path, `\n${entries.map((entry) => JSON.stringify(entry)).join("\n")}\n`);
  }

  /** Delete journals last written more than `RETENTION_DAYS` before `now`; returns how many. */
  prune(now: Date = new Date()): number {
    const cutoff = now.getTime() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    let names: string[];
    try {
      names = readdirSync(this.dir).filter((name) => name.endsWith(".jsonl"));
    } catch {
      // No folder yet means nothing has been saved.
      return 0;
    }
    let removed = 0;
    for (const name of names) {
      const path = join(this.dir, name);
      try {
        if (statSync(path).mtimeMs < cutoff) {
          unlinkSync(path);
          removed += 1;
        }
      } catch {
        // Another process may have pruned it first.
      }
    }
    return removed;
  }
}

/** The fields of a Hunk review note the journal reads; Hunk's own note type satisfies it. */
export interface NoteLike {
  id: string;
  parentId?: string;
  source: NoteSource;
  author?: string;
  anchor: {
    oldRange?: readonly [number, number];
    newRange?: readonly [number, number];
    preferred?: { side: NoteSide; line: number };
  };
  summary: string;
  rationale?: string;
  markup?: string;
  createdAt?: string;
  updatedAt?: string;
}

/** The line a note sits on: Hunk's preferred line, else the start of whichever range it has. */
export function anchorOf(anchor: NoteLike["anchor"]): { side: NoteSide; line: number } | null {
  if (anchor.preferred) {
    return anchor.preferred;
  }
  if (anchor.newRange) {
    return { side: "new", line: anchor.newRange[0] };
  }
  if (anchor.oldRange) {
    return { side: "old", line: anchor.oldRange[0] };
  }
  return null;
}

export function recordFromNote(
  note: NoteLike,
  context: { pid: number; path: string; origin: NoteOrigin; lineText?: string; lineContext?: LineContext; parentKey?: string },
): NoteRecord {
  const anchor = anchorOf(note.anchor);
  const record: NoteRecord = {
    key: noteKey(context.pid, note.id),
    id: note.id,
    source: note.source,
    path: context.path,
    summary: note.summary,
    origin: context.origin,
  };
  const optional: Partial<NoteRecord> = {
    parentKey: context.parentKey,
    parentId: note.parentId,
    author: note.author,
    side: anchor?.side,
    line: anchor?.line,
    oldRange: note.anchor.oldRange,
    newRange: note.anchor.newRange,
    rationale: note.rationale,
    markup: note.markup,
    createdAt: note.createdAt,
    updatedAt: note.updatedAt,
    lineText: context.lineText,
    context: context.lineContext,
  };
  // JSON drops undefined anyway; leaving them out keeps records comparable in tests.
  for (const [field, value] of Object.entries(optional)) {
    if (value !== undefined) {
      (record as unknown as Record<string, unknown>)[field] = value;
    }
  }
  return record;
}

/** A file's patch text split by side, so a note's line can be read back and searched for. */
export interface PatchLines {
  old: Map<number, string>;
  new: Map<number, string>;
}

const HUNK_HEADER = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/u;

export function parsePatch(patch: string): PatchLines {
  const lines: PatchLines = { old: new Map(), new: new Map() };
  let oldLine = 0;
  let newLine = 0;
  let oldLeft = 0;
  let newLeft = 0;
  for (const text of patch.split("\n")) {
    const header = oldLeft === 0 && newLeft === 0 ? HUNK_HEADER.exec(text) : null;
    if (header) {
      oldLine = Number(header[1]);
      newLine = Number(header[3]);
      oldLeft = header[2] === undefined ? 1 : Number(header[2]);
      newLeft = header[4] === undefined ? 1 : Number(header[4]);
      continue;
    }
    if (oldLeft === 0 && newLeft === 0) {
      // File headers before the first hunk, or text after the last one.
      continue;
    }
    const marker = text[0];
    if (marker === "\\") {
      continue;
    }
    if (marker === "-") {
      lines.old.set(oldLine++, text.slice(1));
      oldLeft -= 1;
    } else if (marker === "+") {
      lines.new.set(newLine++, text.slice(1));
      newLeft -= 1;
    } else {
      const content = text.slice(1);
      lines.old.set(oldLine++, content);
      lines.new.set(newLine++, content);
      oldLeft -= 1;
      newLeft -= 1;
    }
  }
  return lines;
}

/** The text of `line` on `side` in `patch`, when a hunk covers it. */
export function lineTextAt(patch: string, side: NoteSide, line: number): string | undefined {
  return parsePatch(patch)[side].get(line);
}

export interface LoadedFile {
  path: string;
  patch: string;
  hunks: readonly { oldRange?: readonly [number, number]; newRange?: readonly [number, number] }[];
}

/** The hunks a patch's own `@@` headers describe, for a patch read from git rather than from Hunk. */
export function hunksOfPatch(patch: string): LoadedFile["hunks"] {
  const hunks: { oldRange?: readonly [number, number]; newRange?: readonly [number, number] }[] = [];
  for (const text of patch.split("\n")) {
    const header = HUNK_HEADER.exec(text);
    if (header) {
      const span = (start: string, count: string | undefined): readonly [number, number] | undefined => {
        const length = count === undefined ? 1 : Number(count);
        return length === 0 ? undefined : [Number(start), Number(start) + length - 1];
      };
      hunks.push({ oldRange: span(header[1]!, header[2]), newRange: span(header[3]!, header[4]) });
    }
  }
  return hunks;
}

const CONTEXT_LINES = 2;

/** The lines around `line` on one side of the patch, as many as the patch holds up to two each way. */
export function contextAt(patchLines: PatchLines, side: NoteSide, line: number): LineContext {
  const texts = patchLines[side];
  const before: string[] = [];
  const after: string[] = [];
  for (let step = 1; step <= CONTEXT_LINES && texts.has(line - step); step++) {
    before.unshift(texts.get(line - step)!);
  }
  for (let step = 1; step <= CONTEXT_LINES && texts.has(line + step); step++) {
    after.push(texts.get(line + step)!);
  }
  return { before, after };
}

type Target = { side: NoteSide; line: number };

export interface PlannedNote {
  record: NoteRecord;
  /** Where a root note goes; absent for a reply, which goes under its parent. */
  target?: Target;
  /** The root of an open thread whose line is gone, placed beside where it was. */
  outdated?: boolean;
}

/** What a loaded changeset means for one saved note. */
export type Verdict =
  | { kind: "shown"; depth: number; target?: Target; outdated?: boolean }
  /** The loaded changeset does not hold the note's origin or lacks its file; `held` marks the lack of the file. */
  | { kind: "pending"; held?: boolean }
  /** Its thread is resolved, so it stays out of the diff. */
  | { kind: "resolved" }
  /** A reply whose parent is gone from the journal. */
  | { kind: "orphan" };

export interface RestorePlan {
  /** Notes to apply, one array per call: roots first, then replies one depth per call. */
  batches: PlannedNote[][];
  /** The loaded changeset does not hold their origin or file; tried again on every load. */
  pending: NoteRecord[];
  /** Open threads whose line is gone from a changeset that holds their origin, and replies with no parent. */
  outdated: NoteRecord[];
  /** Notes of resolved threads, which are not applied. */
  resolved: NoteRecord[];
  /** Resolved notes the host has now, replies before the notes they answer, for removal. */
  hide: NoteRecord[];
  /** Uncommitted notes whose line a commit now holds, with the origin to save for each. */
  rehomed: { record: NoteRecord; origin: NoteOrigin }[];
  verdicts: ReadonlyMap<string, Verdict>;
}

/** Whether a hunk of `file` spans `line` on `side`; Hunk accepts a note on no other line. */
export function covers(file: LoadedFile, side: NoteSide, line: number): boolean {
  return file.hunks.some((hunk) => {
    const range = side === "old" ? hunk.oldRange : hunk.newRange;
    return range !== undefined && line >= range[0] && line <= range[1];
  });
}

function sameLines(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((text, index) => text === b[index]);
}

/**
 * Where a note belongs in the loaded file, or null when its line is gone.
 *
 * At the saved line with the saved text the note stays, whatever surrounds it. Moving to another
 * line takes both the text and the surrounding lines, since a line like `}` repeats all over a
 * file and the nearest copy is rarely the one the note was written on. Only lines inside a hunk
 * count, because `hunk session comment apply` rejects a whole batch for one line outside them.
 * `strict` drops the saved-line shortcut, for judging a file the note was not written in.
 */
export function anchorInFile(
  record: NoteRecord,
  file: LoadedFile,
  patchLines: PatchLines,
  options: { strict?: boolean } = {},
): Target | null {
  if (record.side === undefined || record.line === undefined) {
    return null;
  }
  const { side, line } = record;
  if (record.lineText === undefined) {
    return covers(file, side, line) ? { side, line } : null;
  }
  const texts = patchLines[side];
  if (!options.strict && texts.get(line) === record.lineText && covers(file, side, line)) {
    return { side, line };
  }
  const saved = record.context;
  if (saved === undefined) {
    return null;
  }
  let best: number | null = null;
  for (const [candidate, text] of texts) {
    if (text !== record.lineText || !covers(file, side, candidate)) {
      continue;
    }
    const around = contextAt(patchLines, side, candidate);
    if (!sameLines(around.before, saved.before) || !sameLines(around.after, saved.after)) {
      continue;
    }
    if (best === null || Math.abs(candidate - line) < Math.abs(best - line)) {
      best = candidate;
    }
  }
  return best === null ? null : { side, line: best };
}

/**
 * Where an open thread whose line is gone goes instead: its saved line when a hunk still spans
 * it, else the start of the file's first hunk. The saved anchor is left alone, so the thread
 * finds its line again if a later changeset brings it back.
 */
export function reanchorInFile(record: NoteRecord, file: LoadedFile): Target | null {
  if (record.side === undefined || record.line === undefined) {
    return null;
  }
  const { side, line } = record;
  const rangeOf = (hunk: LoadedFile["hunks"][number], on: NoteSide) => (on === "old" ? hunk.oldRange : hunk.newRange);
  if (covers(file, side, line)) {
    return { side, line };
  }
  const other: NoteSide = side === "old" ? "new" : "old";
  for (const on of [side, other]) {
    const first = file.hunks.map((hunk) => rangeOf(hunk, on)).find((range) => range !== undefined);
    if (first) {
      return { side: on, line: first[0] };
    }
  }
  return null;
}

/**
 * The commit of a branch whose own diff holds an uncommitted note's line, with its text and
 * surrounding lines. `patchOf` reads one commit's patch of a path.
 */
export function rehomeTarget(
  record: NoteRecord,
  candidates: readonly OriginCommit[],
  patchOf: (commit: OriginCommit, path: string) => string | undefined,
): OriginCommit | null {
  if (record.lineText === undefined) {
    return null;
  }
  for (const commit of candidates) {
    const patch = patchOf(commit, record.path);
    if (patch && anchorInFile(record, { path: record.path, patch, hunks: hunksOfPatch(patch) }, parsePatch(patch), { strict: true })) {
      return commit;
    }
  }
  return null;
}

/** What `planRestore` judges notes against: the loaded changeset and the journal's thread statuses. */
export interface RestoreView {
  files: readonly LoadedFile[];
  scope: Scope;
  patchIdOf: PatchIdOf;
  statuses?: ReadonlyMap<string, ThreadState>;
  /** Resolved threads the reviewer asked to see this session, by root key. */
  forced?: ReadonlySet<string>;
  /** The commit on `branch` that now holds an uncommitted note's line. */
  rehome?: (record: NoteRecord, branch: string) => OriginCommit | null;
}

/**
 * Sort saved notes into what can be applied now, what waits, and what lost its line.
 *
 * A thread shows on a loaded changeset that holds every commit of its origin and has its line.
 * When the loaded changeset does not hold the origin, or lacks the file, the thread is pending,
 * never outdated. It is outdated only when a changeset that holds the origin has no such line,
 * and an open thread then goes beside where the line was. A resolved thread is not applied.
 *
 * `liveKeys` are the journal keys of notes the host already has (restored earlier, or made in
 * this process); they are never planned again. A reply takes its parent's fate: it waits when the
 * parent waits, is outdated when the parent is, and follows it into a later batch when the
 * parent is being restored in this plan.
 */
export function planRestore(
  records: readonly NoteRecord[],
  view: RestoreView,
  liveKeys: ReadonlySet<string>,
): RestorePlan {
  const byKey = new Map(records.map((record) => [record.key, record]));
  const files = new Map(view.files.map((file) => [file.path, { file, lines: parsePatch(file.patch) }]));
  const verdicts = new Map<string, Verdict>();
  const rehomed: RestorePlan["rehomed"] = [];

  const judgeRoot = (record: NoteRecord): Verdict => {
    if (view.statuses?.get(record.key)?.status === "resolved" && !view.forced?.has(record.key)) {
      return { kind: "resolved" };
    }
    const loaded = files.get(record.path);
    let origin = record.origin;
    if ("uncommitted" in origin) {
      const here = view.scope.uncommitted?.branch === origin.branch;
      if (!(here && loaded && anchorInFile(record, loaded.file, loaded.lines))) {
        const commit = view.rehome?.(record, origin.branch);
        if (commit) {
          origin = { commits: [commit] };
          rehomed.push({ record, origin });
        }
      }
    }
    if (!originInScope(origin, view.scope, view.patchIdOf)) {
      return { kind: "pending" };
    }
    if (!loaded) {
      return { kind: "pending", held: true };
    }
    const target = anchorInFile(record, loaded.file, loaded.lines);
    if (target) {
      return { kind: "shown", depth: 0, target };
    }
    const beside = reanchorInFile(record, loaded.file);
    return beside ? { kind: "shown", depth: 0, target: beside, outdated: true } : { kind: "pending", held: true };
  };

  const judge = (record: NoteRecord, trail: ReadonlySet<string>): Verdict => {
    const known = verdicts.get(record.key);
    if (known) {
      return known;
    }
    let verdict: Verdict;
    if (record.parentKey !== undefined) {
      const parent = byKey.get(record.parentKey);
      if (!parent || trail.has(parent.key)) {
        verdict = liveKeys.has(record.parentKey) ? { kind: "shown", depth: 0 } : { kind: "orphan" };
      } else {
        const parentVerdict = judge(parent, new Set([...trail, record.key]));
        if (parentVerdict.kind !== "shown") {
          verdict = liveKeys.has(parent.key) && parentVerdict.kind === "pending" ? { kind: "shown", depth: 0 } : parentVerdict;
        } else {
          verdict = {
            kind: "shown",
            depth: liveKeys.has(parent.key) ? 0 : parentVerdict.depth + 1,
            ...(parentVerdict.outdated ? { outdated: true } : {}),
          };
        }
      }
    } else {
      verdict = judgeRoot(record);
    }
    verdicts.set(record.key, verdict);
    return verdict;
  };

  const plan: RestorePlan = { batches: [], pending: [], outdated: [], resolved: [], hide: [], rehomed, verdicts };
  for (const record of records) {
    const verdict = judge(record, new Set());
    if (verdict.kind === "resolved") {
      plan.resolved.push(record);
      if (liveKeys.has(record.key)) {
        plan.hide.push(record);
      }
    } else if (verdict.kind === "orphan") {
      plan.outdated.push(record);
    } else if (verdict.kind === "shown" && verdict.outdated) {
      plan.outdated.push(record);
    }
    if (liveKeys.has(record.key)) {
      continue;
    }
    if (verdict.kind === "pending") {
      plan.pending.push(record);
    } else if (verdict.kind === "shown") {
      const planned: PlannedNote = { record, target: verdict.target };
      if (verdict.outdated && record.parentKey === undefined) {
        planned.outdated = true;
      }
      (plan.batches[verdict.depth] ??= []).push(planned);
    }
  }
  plan.hide = deepestFirst(plan.hide, byKey);
  return plan;
}

/** `records` with every reply before the note it answers, which is the order Hunk lets notes be removed in. */
export function deepestFirst(records: readonly NoteRecord[], byKey: ReadonlyMap<string, NoteRecord>): NoteRecord[] {
  const depth = (record: NoteRecord): number => {
    let steps = 0;
    for (let current = record; current.parentKey !== undefined && steps < byKey.size; steps++) {
      const parent = byKey.get(current.parentKey);
      if (!parent) {
        break;
      }
      current = parent;
    }
    return steps;
  };
  return [...records].sort((a, b) => depth(b) - depth(a));
}

/**
 * Where each saved note sits for the saved-notes dialog. A resolved thread is listed by its
 * root alone; every other note goes under the status its verdict and the host's state give it.
 */
export function groupSaved(
  records: readonly NoteRecord[],
  plan: RestorePlan,
  liveKeys: ReadonlySet<string>,
  statuses: ReadonlyMap<string, ThreadState>,
): Record<SavedNoteStatus, NoteRecord[]> {
  const byKey = new Map(records.map((record) => [record.key, record]));
  const groups: Record<SavedNoteStatus, NoteRecord[]> = { shown: [], pending: [], outdated: [], resolved: [] };
  for (const record of records) {
    if (statuses.get(rootOf(record, byKey).key)?.status === "resolved") {
      if (record.parentKey === undefined) {
        groups.resolved.push(record);
      }
      continue;
    }
    const verdict = plan.verdicts.get(record.key);
    if (verdict?.kind === "orphan" || (verdict?.kind === "shown" && verdict.outdated)) {
      groups.outdated.push(record);
    } else if (verdict?.kind === "shown" && liveKeys.has(record.key)) {
      groups.shown.push(record);
    } else {
      groups.pending.push(record);
    }
  }
  return groups;
}

/**
 * The id each saved note has in the host right now, by journal key. Its keys are the notes the
 * host has; a restored note maps to the id its remap names, and a note made in this process to
 * its own id.
 */
export function liveHostIds(
  state: JournalState,
  remaps: readonly Remap[],
  pid: number,
  liveIds: ReadonlySet<string>,
): Map<string, string> {
  const live = new Map<string, string>();
  for (const remap of remaps) {
    if (remap.pid === pid && liveIds.has(remap.to) && !live.has(remap.key)) {
      live.set(remap.key, remap.to);
    }
  }
  for (const record of state.notes.values()) {
    // Only this process's own ids are comparable with what the host lists.
    if (record.key === noteKey(pid, record.id) && liveIds.has(record.id) && !live.has(record.key)) {
      live.set(record.key, record.id);
    }
  }
  return live;
}

/** The author line of a note the reviewer wrote through this extension's editor. */
export const USER_AUTHOR = "you";

/** The author line a restored note carries: who wrote it, and whether it is outdated. */
function restoredAuthor(planned: PlannedNote): string | undefined {
  const { record } = planned;
  if (planned.outdated) {
    return `${record.source === "user" ? USER_AUTHOR : (record.author ?? "agent")} (outdated)`;
  }
  return record.source === "user" ? USER_AUTHOR : record.author;
}

/** One item of a `hunk session comment apply` batch. */
export function applyItem(planned: PlannedNote, parentId?: string): Record<string, unknown> {
  const { record } = planned;
  const body: Record<string, unknown> = {
    // The batch is rejected whole for an empty summary.
    summary: record.summary || "(empty note)",
    author: restoredAuthor(planned),
  };
  if (record.rationale) {
    // `markup` is left out: hunk accepts it only when the session runs with --experimental,
    // and one refused item rejects the batch.
    body.rationale = record.rationale;
  }
  if (parentId !== undefined) {
    return { replyTo: parentId, ...body };
  }
  const target = planned.target!;
  return { filePath: record.path, [target.side === "old" ? "oldLine" : "newLine"]: target.line, ...body };
}

/** A control-free first line of `text`, cut to `max` characters. */
export function firstLine(text: string, max = 60): string {
  // Note bodies are free text and go to the terminal.
  const line = (text.split("\n")[0] ?? "").replace(/[\u0000-\u001f\u007f-\u009f]/gu, " ").trim();
  return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

export type SavedNoteStatus = "shown" | "pending" | "outdated" | "resolved";

export function savedNoteLabel(status: SavedNoteStatus, record: NoteRecord): string {
  const where = record.line === undefined ? record.path : `${record.path}:${record.line}`;
  const author = record.author ?? record.source;
  return `${status.padEnd(8)}  ${where.replace(/[\u0000-\u001f\u007f-\u009f]/gu, "?")}  ${firstLine(author, 20)}  ${firstLine(record.summary)}`;
}

/** The note a thread hangs from: `record` itself, or the root its replies lead back to. */
export function rootOf(record: NoteRecord, byKey: ReadonlyMap<string, NoteRecord>): NoteRecord {
  const seen = new Set<string>();
  let current = record;
  while (current.parentKey !== undefined && !seen.has(current.key)) {
    seen.add(current.key);
    const parent = byKey.get(current.parentKey);
    if (!parent) {
      break;
    }
    current = parent;
  }
  return current;
}

/** One choice in the saved-notes dialog. */
export type SavedNoteRow =
  | { label: string; kind: "delete-outdated" }
  | { label: string; kind: SavedNoteStatus; record: NoteRecord };

/**
 * The dialog's rows: every saved note under its status, led by one row that clears the outdated
 * ones when there are any. The dialog answers with the chosen label alone, so labels are made
 * distinct.
 */
export function savedNoteRows(groups: Record<SavedNoteStatus, readonly NoteRecord[]>): SavedNoteRow[] {
  const rows: SavedNoteRow[] = [];
  const count = groups.outdated.length;
  if (count > 0) {
    rows.push({ kind: "delete-outdated", label: `Delete ${count === 1 ? "the outdated note" : `all ${count} outdated notes`}` });
  }
  const used = new Map<string, number>();
  for (const kind of ["shown", "pending", "outdated", "resolved"] as const) {
    for (const record of groups[kind]) {
      const label = savedNoteLabel(kind, record);
      const repeat = (used.get(label) ?? 0) + 1;
      used.set(label, repeat);
      rows.push({ kind, record, label: repeat === 1 ? label : `${label} (${repeat})` });
    }
  }
  return rows;
}
