import { spawn } from "node:child_process";
import type { ExtensionVcsFileChangeType } from "hunkdiff/extension";
import type { Changeset } from "./stack/stack";

/** One file of a changeset that is not loaded: what git says changed, with no patch behind it. */
export interface ListedFile {
  /** A git status letter, or `?` for an untracked file in the uncommitted changeset. */
  status: string;
  path: string;
  previousPath?: string;
}

export interface GitOutput {
  code: number;
  stdout: string;
}

/** Runs git in a directory without blocking the UI thread, which the outline shares. */
export type GitRunner = (cwd: string, args: readonly string[]) => Promise<GitOutput>;

/** Piped and never forwarded: the renderer owns this process's stdout. */
export const spawnGit: GitRunner = (cwd, args) =>
  new Promise((resolve) => {
    const child = spawn("git", [...args], { cwd, stdio: ["ignore", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => (stdout += chunk));
    // A missing git binary or directory is an `error` event with no exit status.
    child.on("error", () => resolve({ code: 127, stdout: "" }));
    child.on("close", (code) => resolve({ code: code ?? 1, stdout }));
  });

/**
 * Parse `git diff --name-status -M -z`: `<status>\0<path>\0`, with a second path for
 * renames and copies. `-z` keeps odd file names unquoted.
 */
export function parseNameStatus(stdout: string): ListedFile[] {
  const fields = stdout.split("\0");
  const files: ListedFile[] = [];
  for (let i = 0; i < fields.length; ) {
    const status = fields[i]!;
    if (status === "") {
      break;
    }
    const letter = status[0]!;
    if (letter === "R" || letter === "C") {
      files.push({ status: letter, previousPath: fields[i + 1]!, path: fields[i + 2]! });
      i += 3;
    } else {
      files.push({ status: letter, path: fields[i + 1]! });
      i += 2;
    }
  }
  return files;
}

/** The files a changeset touches, or null when git could not answer. */
export async function listChangeset(
  git: GitRunner,
  cwd: string,
  changeset: Changeset,
): Promise<ListedFile[] | null> {
  if (changeset.uncommitted) {
    const [tracked, untracked] = await Promise.all([
      git(cwd, ["diff", "--name-status", "-M", "-z", "HEAD"]),
      git(cwd, ["ls-files", "--others", "--exclude-standard", "-z"]),
    ]);
    if (tracked.code !== 0 || untracked.code !== 0) {
      return null;
    }
    return [
      ...parseNameStatus(tracked.stdout),
      ...untracked.stdout
        .split("\0")
        .filter((path) => path !== "")
        .map((path) => ({ status: "?", path })),
    ];
  }
  if (!changeset.baseSha || !changeset.headSha) {
    return null;
  }
  const result = await git(cwd, [
    "diff",
    "--name-status",
    "-M",
    "-z",
    changeset.baseSha,
    changeset.headSha,
  ]);
  return result.code === 0 ? parseNameStatus(result.stdout) : null;
}

/** The change type a listed file's status letter stands for, in the vocabulary the file rows draw. */
export function changeTypeOf(status: string): ExtensionVcsFileChangeType {
  switch (status) {
    case "A":
    case "C":
      return "new";
    case "D":
      return "deleted";
    case "R":
      return "rename-changed";
    default:
      return "change";
  }
}
