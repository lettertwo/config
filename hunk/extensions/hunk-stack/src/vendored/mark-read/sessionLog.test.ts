// Vendored from hunk-mark-read (1a76ae85bbd26753314d29db3a89796f1fc63580)
// upstream: src/sessionLog.test.ts
// Local changes are marked with "stack:". Compare with `bun run vendor:diff mark-read`.

import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import {
  appendFileSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  utimesSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { defaultSessionDir, replay, SessionLog, sessionFileName, sessionLabel } from "./sessionLog";

let dir: string;

beforeEach(() => {
  dir = join(mkdtempSync(join(tmpdir(), "mark-read-")), "sessions");
});

afterEach(() => {
  rmSync(join(dir, ".."), { recursive: true, force: true });
});

const started = new Date("2026-10-09T10:12:03.456Z");

describe("naming", () => {
  test("labels a session by start time, review, and process", () => {
    expect(sessionFileName(started, "partner-service-resolver HEAD~1..HEAD", 41233)).toBe(
      "2026-10-09T10-12-03_partner-service-resolver_HEAD~1..HEAD_41233.jsonl",
    );
  });

  test("keeps labels file-name safe", () => {
    expect(sessionLabel("Patch review: /tmp/x/repo-pr-12.diff")).toBe(
      "Patch_review_tmp_x_repo-pr-12.diff",
    );
    expect(sessionLabel("///")).toBe("review");
    expect(sessionLabel("x".repeat(200))).toHaveLength(80);
  });

  test("follows XDG_STATE_HOME", () => {
    expect(defaultSessionDir({ XDG_STATE_HOME: "/state" })).toBe("/state/hunk-mark-read/sessions");
  });
});

describe("replay", () => {
  test("the latest event per key wins, whatever order events arrive in", () => {
    expect(
      replay([
        { t: 3, key: "a", read: false },
        { t: 1, key: "a", read: true },
        { t: 2, key: "b", read: true },
      ]),
    ).toEqual(new Set(["b"]));
  });
});

describe("SessionLog", () => {
  test("writes nothing until the first mark, then one file per session", () => {
    const log = new SessionLog(dir, started, 1);
    expect(log.load()).toEqual(new Set());
    log.append([], "repo HEAD");
    expect(() => readdirSync(dir)).toThrow();

    log.append([{ t: 1, key: "a", read: true }], "repo HEAD");
    log.append([{ t: 2, key: "b", read: true }], "repo HEAD");
    expect(readdirSync(dir)).toEqual(["2026-10-09T10-12-03_repo_HEAD_1.jsonl"]);
    expect(log.load()).toEqual(new Set(["a", "b"]));
  });

  test("two sessions write their own files and see each other's marks", () => {
    const first = new SessionLog(dir, started, 1);
    const second = new SessionLog(dir, started, 2);

    // Interleaved writes, as two open Hunk sessions would do.
    first.append([{ t: 1, key: "a", read: true }], "repo-a HEAD~1..HEAD");
    second.append([{ t: 2, key: "b", read: true }], "repo-a HEAD~1..HEAD");
    first.append([{ t: 3, key: "c", read: true }], "repo-a HEAD~1..HEAD");
    second.append([{ t: 4, key: "a", read: false }], "repo-a HEAD~1..HEAD");

    expect(readdirSync(dir)).toHaveLength(2);
    expect(first.load()).toEqual(new Set(["b", "c"]));
    expect(second.load()).toEqual(new Set(["b", "c"]));
  });

  test("a half-written or garbled line is skipped", () => {
    const log = new SessionLog(dir, started, 1);
    log.append([{ t: 1, key: "a", read: true }], "repo");
    const [name] = readdirSync(dir);
    appendFileSync(join(dir, name!), '{"t":2,"key":"b","re');
    appendFileSync(join(dir, `other.jsonl`), 'not json\n{"t":3,"key":"c","read":true}\n');
    expect(log.load()).toEqual(new Set(["a", "c"]));
  });

  test("appends one JSON object per line", () => {
    const log = new SessionLog(dir, started, 1);
    log.append(
      [
        { t: 1, key: "a\0b", read: true },
        { t: 1, key: "c", read: false },
      ],
      "repo",
    );
    const [name] = readdirSync(dir);
    expect(readFileSync(join(dir, name!), "utf8")).toBe(
      '{"t":1,"key":"a\\u0000b","read":true}\n{"t":1,"key":"c","read":false}\n',
    );
  });

  test("prunes session files untouched for 30 days and keeps the rest", () => {
    const old = new SessionLog(dir, new Date("2026-08-01T00:00:00Z"), 1);
    const recent = new SessionLog(dir, new Date("2026-10-01T00:00:00Z"), 2);
    old.append([{ t: 1, key: "a", read: true }], "old");
    recent.append([{ t: 2, key: "b", read: true }], "recent");

    const now = new Date("2026-10-09T00:00:00Z");
    const [oldName] = readdirSync(dir).filter((name) => name.includes("_old_"));
    const day = 24 * 60 * 60;
    utimesSync(
      join(dir, oldName!),
      now.getTime() / 1000 - 31 * day,
      now.getTime() / 1000 - 31 * day,
    );

    expect(recent.prune(now)).toBe(1);
    expect(recent.load()).toEqual(new Set(["b"]));
  });

  test("a missing folder loads empty and prunes nothing", () => {
    const log = new SessionLog(join(dir, "missing"));
    expect(log.load()).toEqual(new Set());
    expect(log.prune()).toBe(0);
  });
});
