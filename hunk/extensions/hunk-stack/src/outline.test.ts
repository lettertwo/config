import { describe, expect, it } from "bun:test";
import { headerSegments, isExpanded, matchesFilter, navRows, outlineEntries, type OutlineModel, type ProjectListed } from "./outline";
import type { Changeset } from "./stack/stack";
import {
  buildFlatSidebarEntries,
  buildTreeSidebarEntries,
  type ChangesetEntry,
  type SidebarEntry,
} from "./vendored/sidebar/files";

const flat: ProjectListed = (files) => buildFlatSidebarEntries(files);
const tree: ProjectListed = (files) => buildTreeSidebarEntries(files);

function cs(id: string, extra: Partial<Changeset> = {}): Changeset {
  return { id, title: `title ${id}`, base: "b", head: "h", ...extra };
}

const file = (id: string): SidebarEntry => ({
  kind: "file",
  id,
  name: id,
  depth: 0,
  agentCommentsText: null,
  additionsText: null,
  deletionsText: null,
  changeType: "change",
  isUntracked: false,
  path: id,
});

function model(extra: Partial<OutlineModel> = {}): OutlineModel {
  return {
    changesets: [cs("a"), cs("b"), cs("c")],
    loadedId: "b",
    pendingId: null,
    order: "base-first",
    read: null,
    listings: new Map(),
    notes: new Map(),
    expansion: new Map(),
    filter: "",
    ...extra,
  };
}

const kinds = (entries: SidebarEntry[]) =>
  entries.map((e) => (e.kind === "changeset" ? `H:${e.changesetId}` : e.id));

describe("outlineEntries", () => {
  it("puts the loaded changeset's files under its header, base first", () => {
    expect(kinds(outlineEntries(model(), [file("f1"), file("f2")], flat))).toEqual(["H:a", "H:b", "f1", "f2", "H:c"]);
  });

  it("flips only the display for head first, keeping [i/n] base to head", () => {
    const entries = outlineEntries(model({ order: "head-first" }), [file("f1")], flat);
    expect(kinds(entries)).toEqual(["H:c", "H:b", "f1", "H:a"]);
    const headers = entries.filter((e): e is ChangesetEntry => e.kind === "changeset");
    expect(headers.map((h) => h.index)).toEqual([3, 2, 1]);
    expect(headers.every((h) => h.total === 3)).toBe(true);
  });

  it("leads with the files when no listed changeset is loaded", () => {
    expect(kinds(outlineEntries(model({ loadedId: null }), [file("f1")], flat))).toEqual(["f1", "H:a", "H:b", "H:c"]);
    expect(kinds(outlineEntries(model({ loadedId: "gone" }), [file("f1")], flat))).toEqual(["f1", "H:a", "H:b", "H:c"]);
  });

  it("marks the loaded header and a different pending one", () => {
    const headers = outlineEntries(model({ pendingId: "c" }), [], flat).filter(
      (e): e is ChangesetEntry => e.kind === "changeset",
    );
    expect(headers.map((h) => [h.changesetId, h.loaded, h.pending])).toEqual([
      ["a", false, false],
      ["b", true, false],
      ["c", false, true],
    ]);
  });

  it("does not mark the loaded changeset pending when it is also the target", () => {
    const loaded = outlineEntries(model({ pendingId: "b" }), [], flat).find(
      (e): e is ChangesetEntry => e.kind === "changeset" && e.changesetId === "b",
    )!;
    expect(loaded.pending).toBe(false);
  });

  it("carries the read count on the loaded header only", () => {
    const headers = outlineEntries(model({ read: { read: 1, total: 4 } }), [], flat).filter(
      (e): e is ChangesetEntry => e.kind === "changeset",
    );
    expect(headers.map((h) => h.read)).toEqual([null, { read: 1, total: 4 }, null]);
  });

  it("shows a sha and branch on commit-zoom headers only", () => {
    const entries = outlineEntries(
      model({
        changesets: [cs("a", { branch: "feat", headSha: "0123456789abcdef", prNumber: 7 }), cs("b")],
        loadedId: null,
      }),
      [],
      flat,
    ).filter((e): e is ChangesetEntry => e.kind === "changeset");
    expect(entries.map((h) => [h.sha, h.branch, h.prNumber])).toEqual([
      ["01234567", "feat", 7],
      [undefined, undefined, undefined],
    ]);
  });

  it("lists only the files when there are no changesets", () => {
    expect(kinds(outlineEntries(model({ changesets: [], loadedId: null }), [file("f1")], flat))).toEqual(["f1"]);
  });
});

describe("listed changesets", () => {
  const listings = new Map([
    ["a", [{ status: "A", path: "src/new.ts" }, { status: "?", path: "scratch.txt" }]],
    ["c", [{ status: "R", previousPath: "old.ts", path: "moved.ts" }]],
  ]);

  it("lists an expanded unloaded changeset's files with no stats or read state", () => {
    const entries = outlineEntries(
      model({ listings, expansion: new Map([["a", true]]) }),
      [file("f1")],
      flat,
    );
    expect(kinds(entries)).toEqual(["H:a", "a|group:src:0", "a|listed:src/new.ts", "a|group:.:1", "a|listed:scratch.txt", "H:b", "f1", "H:c"]);
    const listed = entries.filter((e) => e.kind === "file" && e.changesetId === "a");
    expect(listed.map((e) => e.kind === "file" && [e.changeType, e.isUntracked, e.additionsText, e.path])).toEqual([
      ["new", false, null, "src/new.ts"],
      ["change", true, null, "scratch.txt"],
    ]);
  });

  it("leaves collapsed headers bare and waits for a list that has not arrived", () => {
    expect(kinds(outlineEntries(model({ listings }), [file("f1")], flat))).toEqual(["H:a", "H:b", "f1", "H:c"]);
    expect(kinds(outlineEntries(model({ expansion: new Map([["a", true]]) }), [], flat))).toEqual(["H:a", "H:b", "H:c"]);
  });

  it("hides the loaded changeset's files when it is collapsed by hand", () => {
    expect(kinds(outlineEntries(model({ expansion: new Map([["b", false]]) }), [file("f1")], flat))).toEqual([
      "H:a",
      "H:b",
      "H:c",
    ]);
  });

  it("follows the loaded changeset's tree projection and keeps ids unique across changesets", () => {
    const both = new Map([
      ["a", [{ status: "M", path: "src/x.ts" }]],
      ["c", [{ status: "M", path: "src/y.ts" }]],
    ]);
    const entries = outlineEntries(
      model({ listings: both, expansion: new Map([["a", true], ["c", true]]) }),
      [],
      tree,
    );
    expect(entries.filter((e) => e.kind === "directory").map((e) => e.id)).toEqual([
      "a|directory:0:0:src",
      "c|directory:0:0:src",
    ]);
    expect(new Set(entries.map((e) => e.id)).size).toBe(entries.length);
  });

  it("renders a rename as old -> new", () => {
    const entries = outlineEntries(model({ listings, expansion: new Map([["c", true]]) }), [], flat);
    expect(entries.find((e) => e.kind === "file")).toMatchObject({ name: "old.ts -> moved.ts", changeType: "rename-changed" });
  });
});

describe("filtering", () => {
  const listings = new Map([
    ["a", [{ status: "A", path: "src/new.ts" }, { status: "M", path: "docs/readme.md" }]],
    ["c", [{ status: "R", previousPath: "src/old.ts", path: "moved.ts" }]],
  ]);

  it("matches a case-insensitive substring of the path or the path before a rename", () => {
    expect(matchesFilter({ path: "src/New.ts" }, "new")).toBe(true);
    expect(matchesFilter({ path: "moved.ts", previousPath: "src/old.ts" }, " OLD ")).toBe(true);
    expect(matchesFilter({ path: "docs/readme.md" }, "src")).toBe(false);
    expect(matchesFilter({ path: "docs/readme.md" }, "  ")).toBe(true);
  });

  it("expands every changeset with a match, folded or not, showing only its matches", () => {
    const entries = outlineEntries(
      model({ listings, filter: "src", expansion: new Map([["b", false]]) }),
      [file("src/f1")],
      flat,
    );
    expect(kinds(entries)).toEqual(["H:a", "a|group:src:0", "a|listed:src/new.ts", "H:b", "src/f1", "H:c", "c|group:.:0", "c|listed:moved.ts"]);
  });

  it("hides headers with no match, including the loaded one when hunk filtered all its files", () => {
    expect(kinds(outlineEntries(model({ listings, filter: "readme" }), [], flat))).toEqual([
      "H:a",
      "a|group:docs:0",
      "a|listed:docs/readme.md",
    ]);
  });

  it("restores the folds when the filter clears", () => {
    expect(kinds(outlineEntries(model({ listings, filter: "" }), [file("f1")], flat))).toEqual(["H:a", "H:b", "f1", "H:c"]);
  });
});

describe("isExpanded", () => {
  it("defaults to the loaded changeset, and a hand toggle wins", () => {
    expect(isExpanded(new Map(), "b", "b")).toBe(true);
    expect(isExpanded(new Map(), "b", "a")).toBe(false);
    expect(isExpanded(new Map([["b", false], ["a", true]]), "b", "b")).toBe(false);
    expect(isExpanded(new Map([["a", true]]), "b", "a")).toBe(true);
  });
});

describe("listed note counts", () => {
  it("badges a listed file with the notes Hunk keeps for its path", () => {
    const listings = new Map([["a", [{ status: "M", path: "x.ts" }, { status: "M", path: "y.ts" }]]]);
    const entries = outlineEntries(
      model({ listings, expansion: new Map([["a", true]]), notes: new Map([["x.ts", 2]]) }),
      [],
      flat,
    );
    const badges = entries.flatMap((entry) => (entry.kind === "file" ? [[entry.path, entry.agentCommentsText]] : []));
    expect(badges).toEqual([
      ["x.ts", "*2"],
      ["y.ts", null],
    ]);
  });
});

describe("navRows", () => {
  it("keeps headers and files, naming the loaded changeset on its own files", () => {
    const entries = outlineEntries(
      model({ listings: new Map([["a", [{ status: "M", path: "src/x.ts" }]]]), expansion: new Map([["a", true]]) }),
      [file("f1")],
      tree,
    );
    expect(navRows(entries, "b").map((r) => [r.changesetId, r.path, r.fileId])).toEqual([
      ["a", null, null],
      ["a", "src/x.ts", null],
      ["b", null, null],
      ["b", "f1", "f1"],
      ["c", null, null],
    ]);
  });
});

describe("headerSegments", () => {
  const entry = (extra: Partial<ChangesetEntry> = {}): ChangesetEntry => ({
    kind: "changeset",
    id: "changeset:a",
    changesetId: "a",
    index: 2,
    total: 5,
    title: "Add the thing",
    loaded: false,
    pending: false,
    expanded: false,
    read: null,
    ...extra,
  });
  const text = (segs: { text: string }[]) => segs.map((s) => s.text).join("");

  it("lays out marker, counter, title, branch, and PR", () => {
    const { left, right } = headerSegments(
      entry({ loaded: true, sha: "abcd1234", branch: "feat", prNumber: 42 }),
      80,
    );
    expect(text(left)).toBe("● › [2/5] abcd1234 Add the thing  feat  #42");
    expect(right).toEqual([]);
  });

  it("uses a hollow marker while a reload to the header is pending", () => {
    expect(text(headerSegments(entry({ pending: true }), 40).left)).toStartWith("○ ");
    expect(text(headerSegments(entry(), 40).left)).toStartWith("  ");
    expect(text(headerSegments(entry({ expanded: true }), 40).left)).toContain("⌄ ");
  });

  it("keeps the read count on the right and trims the left to fit", () => {
    const { left, right } = headerSegments(entry({ loaded: true, read: { read: 3, total: 4 } }), 20);
    expect(text(right)).toBe("3/4");
    expect(Bun.stringWidth(text(left))).toBeLessThanOrEqual(20 - 3 - 1);
    expect(text(left)).toEndWith("…");
  });

  it("tones a complete read count differently", () => {
    expect(headerSegments(entry({ read: { read: 4, total: 4 } }), 40).right[0]!.tone).toBe("readDone");
    expect(headerSegments(entry({ read: { read: 1, total: 4 } }), 40).right[0]!.tone).toBe("read");
  });

  it("omits a read count with nothing to read", () => {
    expect(headerSegments(entry({ read: { read: 0, total: 0 } }), 40).right).toEqual([]);
  });
});
