import { spawn } from "node:child_process";
import type { Changeset } from "./stack/stack";

export interface RunResult {
  code: number;
  stdout: string;
  stderr: string;
}

/** Runs the hunk binary that hosts this extension with the given arguments. */
export type Run = (args: readonly string[]) => Promise<RunResult>;

const RUN_TIMEOUT_MS = 15_000;

/**
 * `process.execPath` is the hunk binary itself, so the extension talks to its own daemon
 * with the same version. The child's stdout is piped and never forwarded: the renderer owns
 * this process's stdout.
 */
export function hunkRunner(): Run {
  return (args) =>
    new Promise((resolve) => {
      const child = spawn(process.execPath, [...args], { stdio: ["ignore", "pipe", "pipe"] });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => (stdout += chunk));
      child.stderr.on("data", (chunk) => (stderr += chunk));
      const timer = setTimeout(() => child.kill("SIGKILL"), RUN_TIMEOUT_MS);
      child.on("error", (error) => {
        clearTimeout(timer);
        resolve({ code: 127, stdout, stderr: stderr || error.message });
      });
      child.on("close", (code) => {
        clearTimeout(timer);
        resolve({ code: code ?? 1, stdout, stderr });
      });
    });
}

/** Where to put the selection once a requested changeset has loaded. */
export interface Landing {
  /** The file to select; the first file when it is absent from the loaded changeset. */
  path?: string;
}

export interface SwitcherSnapshot {
  /** The changeset the review is showing, when the extension knows. */
  loadedId: string | null;
  /** The changeset the extension is loading or has queued. */
  pendingId: string | null;
}

interface Request {
  changeset: Changeset;
  landing?: Landing;
}

/**
 * The `hunk diff` arguments that show one changeset, or the reason it cannot be shown.
 * Reloads take shas rather than the graph's refs: the daemon refuses revisions that start
 * with `-`, and a sha is also immune to a branch moving while the request waits.
 */
export function reloadArgs(changeset: Changeset): string[] | { error: string } {
  if (changeset.uncommitted) {
    // Plain `hunk diff` compares the worktree to the index and drops staged changes; against
    // HEAD it shows staged, unstaged, and untracked files, matching what the outline lists.
    return ["diff", "HEAD"];
  }
  if (!changeset.baseSha || !changeset.headSha) {
    const missing = !changeset.baseSha ? changeset.base : changeset.head;
    return { error: `Cannot resolve ${missing} for ${changeset.title}` };
  }
  return ["diff", `${changeset.baseSha}..${changeset.headSha}`];
}

/**
 * Switches the loaded changeset through hunk's session daemon, because the extension API can
 * navigate inside the loaded diff but cannot load another one.
 *
 * One reload runs at a time. A request that arrives mid-reload replaces any request already
 * waiting, so a burst of keypresses loads only the changeset the reviewer stopped on (two
 * reloads in flight would land in an order nothing guarantees).
 */
export class Switcher {
  private sessionIdCache: string | null = null;
  private inFlight: Request | null = null;
  private queued: Request | null = null;
  private loadedId: string | null = null;
  /** Launch options every reload repeats (`carriedArgs`). */
  private carried: readonly string[] = [];
  private snapshot: SwitcherSnapshot = { loadedId: null, pendingId: null };
  private listeners = new Set<() => void>();

  constructor(
    private readonly run: Run,
    private readonly onError: (message: string) => void,
    private readonly pid: number = process.pid,
  ) {}

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  getSnapshot = (): SwitcherSnapshot => this.snapshot;

  /** The changeset stepping should count from: the newest request, else what is showing. */
  pendingTarget(): Changeset | null {
    return (this.queued ?? this.inFlight)?.changeset ?? null;
  }

  carry(args: readonly string[]) {
    this.carried = args;
  }

  loaded(): string | null {
    return this.loadedId;
  }

  /** Record what is showing without a reload: the initial load, or the pane's own reading of it. */
  setLoaded(id: string | null) {
    if (id !== this.loadedId) {
      this.loadedId = id;
      this.publish();
    }
  }

  /**
   * The landing of the reload now running, handed out once. The `session_reload` event for
   * that reload carries the controls that can select a file in the new generation, and it
   * fires before the daemon answers the request.
   */
  takeLanding(): Landing | null {
    const landing = this.inFlight?.landing ?? null;
    if (this.inFlight) {
      this.inFlight.landing = undefined;
    }
    return landing;
  }

  request(changeset: Changeset, landing?: Landing) {
    const next = { changeset, landing };
    if (this.inFlight) {
      this.queued = next;
      this.publish();
      return;
    }
    void this.start(next);
  }

  private async start(request: Request) {
    this.inFlight = request;
    this.publish();
    let error: string | null = null;
    try {
      error = await this.reload(request.changeset);
    } catch (thrown) {
      // run() resolves on process failure, so a throw here is a bug in parsing the daemon's reply.
      error = String(thrown);
    }
    this.inFlight = null;
    if (error) {
      this.onError(error);
    } else {
      this.loadedId = request.changeset.id;
    }
    const queued = this.queued;
    this.queued = null;
    this.publish();
    if (queued) {
      void this.start(queued);
    }
  }

  /** `process.pid` identifies this window exactly, where `--repo` could match several on one checkout. */
  private async sessionId(): Promise<string | null> {
    if (this.sessionIdCache) {
      return this.sessionIdCache;
    }
    const result = await this.run(["session", "list", "--json"]);
    if (result.code !== 0) {
      return null;
    }
    const sessions = (JSON.parse(result.stdout) as { sessions?: { sessionId: string; pid: number }[] }).sessions;
    this.sessionIdCache = sessions?.find((session) => session.pid === this.pid)?.sessionId ?? null;
    return this.sessionIdCache;
  }

  private async reload(changeset: Changeset): Promise<string | null> {
    const args = reloadArgs(changeset);
    if ("error" in args) {
      return args.error;
    }
    const id = await this.sessionId();
    if (!id) {
      return "Cannot find this review's session in the hunk daemon";
    }
    const result = await this.run(["session", "reload", id, "--json", "--", ...args, ...this.carried]);
    if (result.code !== 0) {
      // A cached id goes stale if the daemon restarted, so look it up again next time.
      this.sessionIdCache = null;
      return `Loading ${changeset.title} failed: ${result.stderr.trim() || `exit ${result.code}`}`;
    }
    return null;
  }

  private publish() {
    this.snapshot = {
      loadedId: this.loadedId,
      pendingId: this.pendingTarget()?.id ?? null,
    };
    for (const listener of [...this.listeners]) {
      listener();
    }
  }
}
