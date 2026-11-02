import { describe, expect, it } from "bun:test";
import { mkdirSync, mkdtempSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { agentContextOption, carriedArgs } from "./carry";

/** A repo directory under the system temp dir, which on macOS sits behind the /var symlink. */
function dirs() {
  const root = mkdtempSync(join(tmpdir(), "hunk-stack-carry-"));
  const repo = join(root, "repo");
  mkdirSync(join(repo, "sub"), { recursive: true });
  return { root, repo };
}

describe("agentContextOption", () => {
  it("takes the last value in either spelling, and nothing after --", () => {
    expect(agentContextOption(["--agent-context", "a.json", "--agent-context=b.json"])).toBe("b.json");
    expect(agentContextOption(["--mode", "split"])).toBeUndefined();
    expect(agentContextOption(["--", "--agent-context", "a.json"])).toBeUndefined();
  });
});

describe("carriedArgs", () => {
  it("carries --watch and nothing else without a sidecar", () => {
    const { repo } = dirs();
    expect(carriedArgs(["--watch", "--mode", "split"], repo, repo)).toEqual({ args: ["--watch"] });
    expect(carriedArgs(["--", "--watch"], repo, repo)).toEqual({ args: [] });
  });

  it("carries a sidecar inside the repository as an absolute path", () => {
    const { repo } = dirs();
    expect(carriedArgs(["--agent-context", "../tour.json"], join(repo, "sub"), repo)).toEqual({
      args: ["--agent-context", join(repo, "tour.json")],
    });
  });

  it("drops a sidecar outside the repository, including through a symlink, with a notice", () => {
    const { root, repo } = dirs();
    symlinkSync(root, join(repo, "escape"));
    for (const sidecar of [join(root, "tour.json"), "escape/tour.json"]) {
      const carried = carriedArgs(["--watch", "--agent-context", sidecar], repo, repo);
      expect(carried.args).toEqual(["--watch"]);
      expect(carried.notice).toContain("inside the repository");
    }
    expect(carriedArgs(["--agent-context", "tour.json"], repo, null).notice).toContain("inside the repository");
  });

  it("drops a stdin sidecar with a notice", () => {
    const { repo } = dirs();
    const carried = carriedArgs(["--agent-context", "-"], repo, repo);
    expect(carried.args).toEqual([]);
    expect(carried.notice).toContain("stdin");
  });
});
