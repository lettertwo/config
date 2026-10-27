import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, realpathSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export const hasSqlite = spawnSync("sqlite3", ["-version"]).status === 0;

export interface TestRepo {
  cwd: string;
  /** Run git in the repo and return trimmed stdout; throws on failure. */
  git(...args: string[]): string;
  write(name: string, content: string): void;
  commitFile(name: string, subject: string): void;
  /** Run sqlite3 against a path under `.git`. */
  sqlite(file: string, query: string): void;
  writeGhStack(doc: unknown): void;
}

/** A repo on `main` with one commit, in a fresh temp dir. */
export function makeRepo(): TestRepo {
  const cwd = realpathSync(mkdtempSync(join(tmpdir(), "stack-repo-")));
  const git = (...args: string[]) => {
    const r = spawnSync("git", args, { cwd, encoding: "utf8" });
    if (r.status !== 0) {
      throw new Error(`git ${args.join(" ")}: ${r.stderr}`);
    }
    return r.stdout.trim();
  };
  const write = (name: string, content: string) => {
    mkdirSync(join(cwd, name, ".."), { recursive: true });
    writeFileSync(join(cwd, name), content);
  };
  git("init", "-q");
  git("branch", "-M", "main");
  git("config", "user.email", "t@t");
  git("config", "user.name", "t");
  write("base.txt", "base\n");
  git("add", ".");
  git("commit", "-qm", "init");
  return {
    cwd,
    git,
    write,
    commitFile(name, subject) {
      write(name, name + "\n");
      git("add", ".");
      git("commit", "-qm", subject);
    },
    sqlite(file, query) {
      const r = spawnSync("sqlite3", [join(cwd, ".git", file), query], { encoding: "utf8" });
      if (r.status !== 0) {
        throw new Error(`sqlite3: ${r.stderr}`);
      }
    },
    writeGhStack(doc) {
      writeFileSync(join(cwd, ".git", "gh-stack"), JSON.stringify(doc));
    },
  };
}

export const GRAPHITE_SCHEMA =
  "CREATE TABLE branch_metadata (branch_name TEXT, parent_branch_name TEXT," +
  " branch_revision TEXT, parent_branch_revision TEXT);";
