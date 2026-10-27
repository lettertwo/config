import { describe, expect, it } from "bun:test";
import { parseMetadata } from "./graphite";

describe("parseMetadata", () => {
  it("parses |-separated sqlite output into a by-branch map", () => {
    const by = parseMetadata(["feat-a|main|aaa111|000aaa", "feat-b|feat-a|bbb222|aaa111"].join("\n"));
    expect(by.get("feat-a")).toEqual({
      branch: "feat-a",
      parent: "main",
      headRev: "aaa111",
      parentRev: "000aaa",
    });
    expect(by.get("feat-b")!.parent).toBe("feat-a");
  });

  it("skips malformed lines", () => {
    const by = parseMetadata("just-one-field\nok|main||\n");
    expect(by.has("just-one-field")).toBe(false);
    expect(by.has("ok")).toBe(true);
  });

  it("returns empty for empty output", () => {
    expect(parseMetadata("").size).toBe(0);
  });
});
