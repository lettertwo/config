import { CommitIndex, findCommit, type OriginCommit } from "./origin";
import { NoteJournal, firstLine, planRestore, rehomeTarget, hunksOfPatch, rootOf, type NoteRecord, type ThreadStatus } from "./persist";
import { createStackSource, type StackSource, type Zoom } from "./stack/stack";
import type { Sys } from "./stack/sys";
import { formatTerminalPath } from "./vendored/sidebar/helpers";

export const NOTES_USAGE = `Usage: hunk stack notes <command>

Commands:
  list [--json]                       Every saved thread: its origin, status, and where it shows
  resolve <key> [--commit <sha>]      Close a thread, naming the commit that fixed it
  reopen <key>                        Open a resolved thread again

Reads and writes the saved-notes journal of the current worktree. No Hunk session is needed.
A key is the thread's first note, as \`list\` prints it.
`;

export interface NotesResult {
  code: number;
  stdout: string;
  stderr: string;
}

export interface NotesDeps {
  sys: Sys;
  notesDir: string;
  /** Epoch milliseconds for journal entries; defaults to the clock. */
  now?: () => number;
}

type Placement = { zoom: Zoom; changeset: string; title: string; state: "shown" | "outdated" | "pending" };

const fail = (message: string, code = 1): NotesResult => ({ code, stdout: "", stderr: `hunk stack notes: ${message}\n` });

/** The `notes` subcommand of `hunk stack`: reads and writes the journal with no live session. */
export function runNotes(args: readonly string[], deps: NotesDeps): NotesResult {
  const [command, ...rest] = args;
  if (command === undefined || command === "-h" || command === "--help") {
    return { code: command === undefined ? 1 : 0, stdout: command === undefined ? "" : NOTES_USAGE, stderr: command === undefined ? NOTES_USAGE : "" };
  }
  if (command !== "list" && command !== "resolve" && command !== "reopen") {
    return fail(`unknown command ${formatTerminalPath(command)}\n${NOTES_USAGE.trimEnd()}`);
  }

  let json = false;
  let commit: string | undefined;
  const positional: string[] = [];
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i]!;
    if (arg === "--json") {
      json = true;
    } else if (arg === "--commit" && command === "resolve") {
      commit = rest[++i];
      if (commit === undefined) {
        return fail("--commit needs a sha");
      }
    } else if (arg.startsWith("-")) {
      return fail(`unknown option ${formatTerminalPath(arg)} for ${command}`);
    } else {
      positional.push(arg);
    }
  }

  const top = deps.sys.git(["rev-parse", "--show-toplevel"]);
  if (top.code !== 0) {
    return fail("not a git repository");
  }
  const journal = new NoteJournal(deps.notesDir, top.stdout.trim());
  let state;
  try {
    state = journal.load();
  } catch (error) {
    return fail(`cannot read the journal (${formatTerminalPath(String(error))})`);
  }
  let source: StackSource | null = null;
  try {
    source = createStackSource(deps.sys);
  } catch {
    // No stack (no trunk branch, or an unknown gh-stack schema): threads list without placement.
  }
  const index = new CommitIndex(deps.sys, source);

  if (command === "list") {
    if (positional.length > 0) {
      return fail("list takes no arguments");
    }
    const threads = listThreads(state, source, index);
    if (json) {
      return { code: 0, stdout: `${JSON.stringify({ threads }, null, 2)}\n`, stderr: "" };
    }
    return { code: 0, stdout: threads.length === 0 ? "No saved notes\n" : threads.map(threadText).join(""), stderr: "" };
  }

  const key = positional[0];
  if (key === undefined || positional.length > 1) {
    return fail(`${command} takes one thread key`);
  }
  const record = state.notes.get(key);
  if (!record) {
    return fail(`no saved note with key ${formatTerminalPath(key)}`);
  }
  if (record.parentKey !== undefined) {
    return fail(`${formatTerminalPath(key)} is a reply; use its thread's key ${formatTerminalPath(rootOf(record, state.notes).key)}`);
  }
  let status: ThreadStatus = "open";
  let fix: OriginCommit | undefined;
  if (command === "resolve") {
    status = "resolved";
    if (commit !== undefined) {
      fix = index.describe(commit) ?? undefined;
      if (!fix) {
        return fail(`${formatTerminalPath(commit)} is not a commit in this repository`);
      }
    }
  }
  try {
    journal.append([{ op: "status", t: (deps.now ?? Date.now)(), key, status, ...(fix ? { fix } : {}) }]);
  } catch (error) {
    return fail(`cannot write the journal (${formatTerminalPath(String(error))})`);
  }
  if (json) {
    return { code: 0, stdout: `${JSON.stringify({ key, status, ...(fix ? { fix } : {}) })}\n`, stderr: "" };
  }
  const by = fix ? ` by ${fix.sha.slice(0, 8)} ${firstLine(fix.subject)}` : "";
  return { code: 0, stdout: `${status === "resolved" ? "Resolved" : "Reopened"} ${key}${by}\n`, stderr: "" };
}

function listThreads(state: ReturnType<NoteJournal["load"]>, source: StackSource | null, index: CommitIndex) {
  const records = [...state.notes.values()];
  const roots = records.filter((record) => record.parentKey === undefined);
  const repliesOf = new Map<string, NoteRecord[]>();
  for (const record of records) {
    if (record.parentKey !== undefined) {
      const root = rootOf(record, state.notes);
      if (root.parentKey === undefined) {
        repliesOf.set(root.key, [...(repliesOf.get(root.key) ?? []), record]);
      }
    }
  }
  const hostIds = (record: NoteRecord) => {
    const ids = state.remaps.filter((remap) => remap.key === record.key).map((remap) => ({ pid: remap.pid, id: remap.to }));
    const own = /^(\d+):/u.exec(record.key);
    return own && record.key === `${own[1]}:${record.id}` ? [{ pid: Number(own[1]), id: record.id }, ...ids] : ids;
  };

  // The stack at every zoom, read once, with each changeset's scope; a note is judged against each.
  const changesets = source ? source.zooms.flatMap((zoom) => source.load(zoom).map((changeset) => ({ zoom, changeset, scope: index.scopeOf(changeset) }))) : [];
  const combined = changesets.find((entry) => entry.zoom === "combined");

  const placementOf = (root: NoteRecord): Placement[] => {
    const placements: Placement[] = [];
    for (const { zoom, changeset, scope } of changesets) {
      const patch = index.changesetPatch(changeset, root.path);
      const files = patch ? [{ path: root.path, patch, hunks: hunksOfPatch(patch) }] : [];
      const verdict = planRestore(
        [root],
        {
          files,
          scope,
          patchIdOf: index.patchId,
          rehome: (record, branch) => rehomeTarget(record, index.branchCommits(branch), index.commitPatch),
        },
        new Set(),
      ).verdicts.get(root.key);
      if (verdict?.kind === "shown") {
        placements.push({ zoom, changeset: changeset.id, title: changeset.title, state: verdict.outdated ? "outdated" : "shown" });
      } else if (verdict?.kind === "pending" && verdict.held) {
        placements.push({ zoom, changeset: changeset.id, title: changeset.title, state: "pending" });
      }
    }
    return placements;
  };

  return roots.map((root) => {
    const replies = repliesOf.get(root.key) ?? [];
    const thread = [root, ...replies];
    const sorted = thread.every((record) => record.createdAt !== undefined)
      ? [...thread].sort((a, b) => Date.parse(a.createdAt!) - Date.parse(b.createdAt!))
      : thread;
    const last = sorted[sorted.length - 1]!;
    const threadState = state.statuses.get(root.key);
    const resolved = threadState?.status === "resolved";
    const fix = threadState?.fix;
    const fixNow = fix && combined ? findCommit(fix, combined.scope.commits, index.patchId) : undefined;
    const note = (record: NoteRecord) => ({
      key: record.key,
      source: record.source,
      ...(record.author === undefined ? {} : { author: record.author }),
      summary: record.summary,
      ...(record.rationale === undefined ? {} : { rationale: record.rationale }),
      ...(record.createdAt === undefined ? {} : { createdAt: record.createdAt }),
      hostIds: hostIds(record),
    });
    return {
      ...note(root),
      path: root.path,
      ...(root.side === undefined ? {} : { side: root.side }),
      ...(root.line === undefined ? {} : { line: root.line }),
      origin: root.origin,
      status: resolved ? "resolved" : "open",
      ...(fix ? { fix, fixNow: fixNow?.sha ?? null } : {}),
      // The last word decides who owes the next one; a closed thread waits on no one.
      waitingOn: resolved ? null : last.source === "user" ? "agent" : "user",
      placement: placementOf(root),
      replies: replies.map(note),
    };
  });
}

function threadText(thread: ReturnType<typeof listThreads>[number]): string {
  const where = thread.line === undefined ? thread.path : `${thread.path}:${thread.line}`;
  const waiting = thread.waitingOn ? `  waiting on ${thread.waitingOn}` : "";
  const lines = [`${thread.key}  ${thread.status}${waiting}  ${formatTerminalPath(where)}  ${firstLine(thread.summary)}`];
  if (thread.fix) {
    lines.push(`    fixed by ${thread.fix.sha.slice(0, 8)} ${firstLine(thread.fix.subject)}${thread.fixNow === null ? " (not in the stack now)" : ""}`);
  }
  if (thread.placement.length > 0) {
    lines.push(`    ${thread.placement.map((entry) => `${entry.zoom} ${firstLine(entry.title, 30)} ${entry.state}`).join(", ")}`);
  }
  for (const reply of thread.replies) {
    lines.push(`    ${firstLine(reply.author ?? reply.source, 20)}: ${firstLine(reply.summary)}`);
  }
  return `${lines.join("\n")}\n`;
}
