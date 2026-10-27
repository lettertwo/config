// Vendored from hunk-mark-read (1a76ae85bbd26753314d29db3a89796f1fc63580)
// upstream: src/sessionLog.ts
// Local changes are marked with "stack:". Compare with `bun run vendor:diff mark-read`.

import {
  appendFileSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/** One mark or unmark, as appended to a session file. */
export interface MarkEvent {
  /** Milliseconds since the epoch. */
  t: number;
  key: string;
  read: boolean;
}

export const RETENTION_DAYS = 30;

/** `$XDG_STATE_HOME/hunk-mark-read/sessions`, defaulting to `~/.local/state`. */
export function defaultSessionDir(env: Record<string, string | undefined> = process.env): string {
  const stateHome = env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return join(stateHome, "hunk-mark-read", "sessions");
}

/** Turn a review title like `repo HEAD~1..HEAD` into a file-name-safe label. */
export function sessionLabel(title: string): string {
  const label = title
    .replace(/[^A-Za-z0-9._~-]+/gu, "_")
    .replace(/^_+|_+$/gu, "")
    .slice(0, 80);
  return label || "review";
}

/** Build one session's file name: start time, review label, process id. */
export function sessionFileName(startedAt: Date, title: string, pid: number): string {
  const stamp = startedAt.toISOString().slice(0, 19).replace(/:/gu, "-");
  return `${stamp}_${sessionLabel(title)}_${pid}.jsonl`;
}

/** Parse one JSONL line, ignoring anything malformed (a line another session is still writing). */
function parseEvent(line: string): MarkEvent | null {
  try {
    const value = JSON.parse(line) as Partial<MarkEvent>;
    return typeof value.t === "number" &&
      typeof value.key === "string" &&
      typeof value.read === "boolean"
      ? { t: value.t, key: value.key, read: value.read }
      : null;
  } catch {
    return null;
  }
}

/**
 * Replay events in time order and return the keys whose latest event is a mark.
 *
 * Later events win across sessions, so an unmark in one session overrides an
 * earlier mark from another. The sort is stable, so equal timestamps keep
 * their file order.
 */
export function replay(events: readonly MarkEvent[]): Set<string> {
  const latest = new Map<string, boolean>();
  for (const event of [...events].sort((a, b) => a.t - b.t)) {
    latest.set(event.key, event.read);
  }
  return new Set([...latest].filter(([, read]) => read).map(([key]) => key));
}

/**
 * Append-only mark persistence: one JSONL file per Hunk session in a shared folder.
 *
 * Each session writes only its own file, so concurrent sessions never contend
 * for a write. Reading replays every session file. Files untouched for
 * `RETENTION_DAYS` are deleted whole; nothing is ever rewritten.
 */
export class SessionLog {
  private fileName: string | null = null;

  constructor(
    private readonly dir: string,
    private readonly startedAt: Date = new Date(),
    private readonly pid: number = process.pid,
  ) {}

  /** Read every session file and return the currently read keys. */
  load(): Set<string> {
    const events: MarkEvent[] = [];
    for (const name of this.sessionFiles()) {
      let text: string;
      try {
        text = readFileSync(join(this.dir, name), "utf8");
      } catch {
        continue;
      }
      for (const line of text.split("\n")) {
        const event = line ? parseEvent(line) : null;
        if (event) {
          events.push(event);
        }
      }
    }
    return replay(events);
  }

  /** Append events to this session's file, creating it (named after `title`) on first use. */
  append(events: readonly MarkEvent[], title: string): void {
    if (events.length === 0) {
      return;
    }
    if (!this.fileName) {
      mkdirSync(this.dir, { recursive: true });
      this.fileName = sessionFileName(this.startedAt, title, this.pid);
    }
    const lines = events.map((event) => `${JSON.stringify(event)}\n`).join("");
    appendFileSync(join(this.dir, this.fileName), lines);
  }

  /** Delete session files last written more than `RETENTION_DAYS` before `now`. */
  prune(now: Date = new Date()): number {
    const cutoff = now.getTime() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    let removed = 0;
    for (const name of this.sessionFiles()) {
      const path = join(this.dir, name);
      try {
        if (statSync(path).mtimeMs < cutoff) {
          unlinkSync(path);
          removed += 1;
        }
      } catch {
        // Another session may have pruned it first.
      }
    }
    return removed;
  }

  private sessionFiles(): string[] {
    try {
      return readdirSync(this.dir).filter((name) => name.endsWith(".jsonl"));
    } catch {
      return [];
    }
  }
}
