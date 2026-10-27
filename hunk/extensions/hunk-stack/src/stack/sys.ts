import { spawnSync } from "node:child_process";

export interface ExecResult {
  code: number;
  stdout: string;
  stderr: string;
}

/** The process boundary, so tests and callers can swap it. Never writes to this process's stdout. */
export interface Sys {
  cwd: string;
  git(args: string[], input?: string): ExecResult;
  /** Run `sqlite3 <db> <query>`; a missing binary is a nonzero code, not a throw. */
  sqlite(db: string, query: string): ExecResult;
}

function run(cmd: string, args: string[], cwd: string, input?: string): ExecResult {
  const result = spawnSync(cmd, args, {
    cwd,
    input,
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
    stdio: ["pipe", "pipe", "pipe"],
  });
  if (result.error) {
    // spawn failures (ENOENT, EACCES) carry no exit status.
    return { code: 127, stdout: "", stderr: String(result.error.message) };
  }
  return { code: result.status ?? 1, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

export function createSys(cwd: string): Sys {
  return {
    cwd,
    git: (args, input) => run("git", args, cwd, input),
    sqlite: (db, query) => run("sqlite3", [db, query], cwd),
  };
}
