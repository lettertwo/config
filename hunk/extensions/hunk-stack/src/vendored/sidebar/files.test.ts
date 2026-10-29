import { describe, expect, it } from "bun:test";
import { buildDirnameSidebarEntries, type SidebarFileSource } from "./files";

function source(path: string, previousPath?: string): SidebarFileSource {
  return { id: path, path, previousPath, stats: { additions: 1, deletions: 0 } };
}

describe("buildDirnameSidebarEntries", () => {
  it("lists files without group rows, each with its directory after its name", () => {
    const entries = buildDirnameSidebarEntries([source("src/a.ts"), source("README.md"), source("src/b.ts")]);
    expect(entries.map((e) => e.kind)).toEqual(["file", "file", "file"]);
    expect(entries).toMatchObject([
      { name: "a.ts", dirname: "src", depth: 0 },
      { name: "README.md" },
      { name: "b.ts", dirname: "src" },
    ]);
    expect(entries[1]).not.toHaveProperty("dirname");
  });

  it("shows a rename by name and the new path's directory", () => {
    const [entry] = buildDirnameSidebarEntries([source("lib/new.ts", "src/old.ts")]);
    expect(entry).toMatchObject({ name: "old.ts -> new.ts", dirname: "lib" });
  });
});
