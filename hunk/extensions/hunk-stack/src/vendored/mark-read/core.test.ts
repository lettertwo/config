// Vendored from hunk-mark-read (1a76ae85bbd26753314d29db3a89796f1fc63580)
// upstream: src/core.test.ts
// Local changes are marked with "stack:". Compare with `bun run vendor:diff mark-read`.

import { describe, expect, test } from "bun:test";
import {
  dimHighlights,
  hiddenNotice,
  isUnderDirectory,
  nextUnread,
  progressSpans,
  readKey,
} from "./core";

const PATCH = [
  "diff --git a/src/a.ts b/src/a.ts",
  "--- a/src/a.ts",
  "+++ b/src/a.ts",
  "@@ -10,3 +10,3 @@ function a() {",
  " keep",
  "-old",
  "+new",
  " ",
  "\\ No newline at end of file",
  "@@ -40,1 +40,2 @@",
  " ctx",
  "+added",
  "",
].join("\n");

/** Build a git-style patch for one hunk of `src/a.ts`. */
function gitPatch({
  index = "index 3f2a1b0..9c1d4e2 100644",
  header = "@@ -10,3 +10,3 @@ function a() {",
  body = [" keep", "-old", "+new", " tail"],
} = {}) {
  return [
    "diff --git a/src/a.ts b/src/a.ts",
    index,
    "--- a/src/a.ts",
    "+++ b/src/a.ts",
    header,
    ...body,
    "",
  ].join("\n");
}

const key = (patch: string, path = "src/a.ts", previousPath?: string) =>
  readKey({ path, previousPath, patch });

describe("readKey", () => {
  test("is stable for the same file and patch", () => {
    expect(key(gitPatch())).toBe(key(gitPatch()));
  });

  test("ignores line numbers and function context (rebase shifting the hunk)", () => {
    expect(key(gitPatch({ header: "@@ -42,3 +55,3 @@ other context" }))).toBe(key(gitPatch()));
  });

  test("ignores the index line and git vs GitHub header details", () => {
    expect(key(gitPatch({ index: "index 0000000..1111111" }))).toBe(key(gitPatch()));
  });

  test("an untracked file keeps its key after git add", () => {
    const untracked = [
      "diff --git a/n.ts b/n.ts",
      "new file mode 100644",
      "--- /dev/null\t",
      "+++ b/n.ts",
      "@@ -0,0 +1,2 @@",
      "+one",
      "+two",
      "",
    ].join("\n");
    const staged = [
      "diff --git a/n.ts b/n.ts",
      "new file mode 100644",
      "index 0000000..5f1e2c3",
      "--- /dev/null",
      "+++ b/n.ts",
      "@@ -0,0 +1,2 @@",
      "+one",
      "+two",
      "",
    ].join("\n");
    expect(key(staged, "n.ts")).toBe(key(untracked, "n.ts"));
  });

  test("any changed added, removed, or context line changes the key", () => {
    const base = key(gitPatch());
    expect(key(gitPatch({ body: [" keep", "-old", "+new!", " tail"] }))).not.toBe(base);
    expect(key(gitPatch({ body: [" keep", "-old2", "+new", " tail"] }))).not.toBe(base);
    expect(key(gitPatch({ body: [" keep!", "-old", "+new", " tail"] }))).not.toBe(base);
    expect(
      key(gitPatch({ body: [" keep", "-old", "+new", " tail", "\\ No newline at end of file"] })),
    ).not.toBe(base);
  });

  test("a different hunk split changes the key", () => {
    const split = gitPatch({ body: [" keep", "-old", "@@ -20,1 +20,1 @@", "+new", " tail"] });
    expect(key(split)).not.toBe(key(gitPatch()));
  });

  test("path, previous path, and mode changes count", () => {
    const base = key(gitPatch());
    expect(key(gitPatch(), "src/b.ts")).not.toBe(base);
    expect(key(gitPatch(), "src/a.ts", "src/old.ts")).not.toBe(base);
    const modeChange = gitPatch().replace("index ", "old mode 100644\nnew mode 100755\nindex ");
    expect(key(modeChange)).not.toBe(base);
  });

  test("binary changes are detected through the blob ids", () => {
    const binary = (index: string) =>
      ["diff --git a/i.png b/i.png", index, "Binary files a/i.png and b/i.png differ", ""].join(
        "\n",
      );
    expect(key(binary("index 1111111..2222222 100644"), "i.png")).not.toBeNull();
    expect(key(binary("index 1111111..2222222 100644"), "i.png")).not.toBe(
      key(binary("index 1111111..3333333 100644"), "i.png"),
    );
  });

  test("pure renames and mode-only changes are trackable", () => {
    const rename = [
      "diff --git a/x b/y",
      "similarity index 100%",
      "rename from x",
      "rename to y",
      "",
    ].join("\n");
    expect(key(rename, "y", "x")).not.toBeNull();
    const mode = ["diff --git a/x b/x", "old mode 100644", "new mode 100755", ""].join("\n");
    expect(key(mode, "x")).not.toBeNull();
  });

  test("a bare empty context line does not hide the lines below it", () => {
    const v1 = gitPatch({ body: [" keep", "", "-old", "+new"] });
    const v2 = gitPatch({ body: [" keep", "", "-old", "+changed"] });
    expect(key(v1)).not.toBe(key(v2));
    // And the bare line itself counts.
    expect(key(v1)).not.toBe(key(gitPatch({ body: [" keep", "-old", "+new"] })));
  });

  test("unexpected prefixes and lines after the declared counts still count", () => {
    const base = key(gitPatch());
    expect(key(gitPatch({ body: [" keep", "-old", "+new", " tail", "?odd"] }))).not.toBe(base);
    expect(
      key(gitPatch({ body: [" keep", "-old", "+new", " tail", "+extra beyond count"] })),
    ).not.toBe(base);
  });

  test("header lookalikes inside the body are hashed, not excluded", () => {
    const withBody = (line: string) => key(gitPatch({ body: [" keep", line, "-old", "+new"] }));
    const lookalikes = [
      "index 1234567..89abcde 100644",
      "index on semantics",
      "diff --git a/x b/x",
      "similarity index 90%",
      "--- a/src/a.ts",
      "+++ b/src/a.ts",
      "@@ not a real header",
      "@@@ neither",
    ];
    const keys = lookalikes.map(withBody);
    for (const lookalikeKey of keys) {
      expect(lookalikeKey).not.toBe(key(gitPatch({ body: [" keep", "-old", "+new"] })));
    }
    // Two lookalikes differing in text give different keys, so their text is hashed.
    expect(withBody("@@ not a real header")).not.toBe(withBody("@@ another fake"));
  });

  test("before the first hunk, only strictly shaped noise lines are excluded", () => {
    const base = key(gitPatch());
    expect(key(gitPatch({ index: "index on semantics" }))).not.toBe(base);
    expect(key(gitPatch({ index: "index 0123abc..4567def" }))).toBe(base);
    const similarity = gitPatch().replace("index ", "similarity index 87%\nindex ");
    expect(key(similarity)).toBe(base);
    const notSimilarity = gitPatch().replace("index ", "similarity index high\nindex ");
    expect(key(notSimilarity)).not.toBe(base);
  });

  test("real hunk headers of any range and combined diffs reduce to a bare marker", () => {
    const combined = (header: string) =>
      key(
        ["diff --cc m.ts", "index 1,2..3", "--- a/m.ts", "+++ b/m.ts", header, "++merged", ""].join(
          "\n",
        ),
        "m.ts",
      );
    expect(combined("@@@ -1,2 -1,3 +1,4 @@@")).toBe(combined("@@@ -9,2 -7,3 +5,4 @@@ ctx"));
    expect(key(gitPatch({ header: "@@ -10 +10 @@" }))).toBe(key(gitPatch()));
  });

  test("files whose patch cannot reveal changes have no key", () => {
    expect(key("", "big.bin")).toBeNull();
    expect(key("Binary file skipped: logo.png\n", "logo.png")).toBeNull();
  });
});

describe("nextUnread", () => {
  const files = [{ id: "a" }, { id: "b" }, { id: "c" }];

  test("finds the next unread file after the current one", () => {
    const read = new Set(["b"]);
    expect(nextUnread(files, "a", (file) => read.has(file.id))?.id).toBe("c");
  });

  test("wraps around to the start", () => {
    const read = new Set(["c"]);
    expect(nextUnread(files, "c", (file) => read.has(file.id))?.id).toBe("a");
  });

  test("returns the current file when it is the only unread one", () => {
    const read = new Set(["a", "c"]);
    expect(nextUnread(files, "b", (file) => read.has(file.id))?.id).toBe("b");
  });

  test("starts at the first file without a selection", () => {
    expect(nextUnread(files, null, () => false)?.id).toBe("a");
  });

  test("returns null when everything is read", () => {
    expect(nextUnread(files, "a", () => true)).toBeNull();
    expect(nextUnread([], null, () => false)).toBeNull();
  });
});

describe("isUnderDirectory", () => {
  test("matches files at any depth below the directory", () => {
    expect(isUnderDirectory("src/a.ts", "src")).toBe(true);
    expect(isUnderDirectory("src/deep/a.ts", "src")).toBe(true);
    expect(isUnderDirectory("src/deep/a.ts", "src/deep")).toBe(true);
  });

  test("does not match siblings sharing a prefix", () => {
    expect(isUnderDirectory("srcx/a.ts", "src")).toBe(false);
    expect(isUnderDirectory("src.ts", "src")).toBe(false);
  });
});

describe("dimHighlights", () => {
  test("covers every non-empty patch line on the side Hunk numbers it", () => {
    expect(dimHighlights(PATCH)).toEqual([
      { side: "new", line: 10, range: [0, 4], tone: "dim" },
      { side: "old", line: 11, range: [0, 3], tone: "dim" },
      { side: "new", line: 11, range: [0, 3], tone: "dim" },
      { side: "new", line: 40, range: [0, 3], tone: "dim" },
      { side: "new", line: 41, range: [0, 5], tone: "dim" },
    ]);
  });

  test("treats a bare empty line as context and keeps counting below it", () => {
    const patch = ["@@ -1,4 +1,4 @@", " a", "", "-b", "+B", " c", ""].join("\n");
    expect(dimHighlights(patch)).toEqual([
      { side: "new", line: 1, range: [0, 1], tone: "dim" },
      { side: "old", line: 3, range: [0, 1], tone: "dim" },
      { side: "new", line: 3, range: [0, 1], tone: "dim" },
      { side: "new", line: 4, range: [0, 1], tone: "dim" },
    ]);
  });

  test("ignores everything before the first hunk", () => {
    expect(dimHighlights("diff --git a/x b/x\nBinary files differ\n")).toEqual([]);
  });
});

describe("progressSpans", () => {
  test("shows read over total", () => {
    expect(progressSpans(7, 12)).toEqual([{ text: "7/12 read", tone: "muted" }]);
  });

  test("celebrates when everything is read", () => {
    expect(progressSpans(12, 12)).toEqual([{ text: "✓ all 12 read", tone: "added" }]);
  });

  test("does not claim an empty review is read", () => {
    expect(progressSpans(0, 0)).toEqual([{ text: "0/0 read", tone: "muted" }]);
  });
});

describe("hiddenNotice", () => {
  test("says nothing when no read file is hidden", () => {
    expect(hiddenNotice(0, 3, ["H"])).toEqual([]);
  });

  test("counts hidden files and names the current key", () => {
    expect(hiddenNotice(3, 2, ["H"])).toEqual(["3 read files hidden", "H to show"]);
    expect(hiddenNotice(1, 2, ["space", "H"])).toEqual(["1 read file hidden", "space to show"]);
  });

  test("says all when nothing is left to list", () => {
    expect(hiddenNotice(4, 0, ["H"])).toEqual(["All 4 read files hidden", "H to show"]);
    expect(hiddenNotice(1, 0, ["H"])).toEqual(["1 read file hidden", "H to show"]);
  });

  test("leaves the key out when the command is unbound", () => {
    expect(hiddenNotice(2, 0, [])).toEqual(["All 2 read files hidden"]);
  });
});
