import { describe, expect, it } from "bun:test";
import { createGraph } from "./graph";
import { createSys } from "./sys";
import { GRAPHITE_SCHEMA, hasSqlite, makeRepo, type TestRepo } from "./testRepo";

function ghStackDoc(branches: string[]) {
  return { schemaVersion: 1, stacks: [{ trunk: { branch: "main" }, branches: branches.map((branch) => ({ branch })) }] };
}
function graphite(repo: TestRepo, rows: string) {
  repo.sqlite(".graphite_metadata.db", GRAPHITE_SCHEMA + rows);
}

// A graphite db can exist while telling us nothing about the focus branch, and a gh-stack
// walk can come back empty. Each must fall through rather than yield an empty stack.
describe("createGraph", () => {
  it("uses the git graph when there is no graphite db or gh-stack file", () => {
    const repo = makeRepo();
    expect(createGraph(createSys(repo.cwd), "main").kind).toBe("git");
  });

  it.skipIf(!hasSqlite)("falls back to the git graph when the graphite walk is empty", () => {
    const repo = makeRepo();
    graphite(repo, "");
    expect(createGraph(createSys(repo.cwd), "main").kind).toBe("git");
  });

  it.skipIf(!hasSqlite)("uses graphite when the walk yields nodes for the focus branch", () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feat");
    graphite(repo, " INSERT INTO branch_metadata VALUES ('feat','main','','');");
    const g = createGraph(createSys(repo.cwd), "feat");
    expect(g.kind).toBe("graphite");
    expect(g.nodes).toHaveLength(1);
  });

  it("uses gh-stack when a gh-stack file tracks the focus branch", () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feat");
    repo.writeGhStack(ghStackDoc(["feat"]));
    const g = createGraph(createSys(repo.cwd), "feat");
    expect(g.kind).toBe("gh-stack");
    expect(g.nodes).toHaveLength(1);
  });

  it.skipIf(!hasSqlite)("prefers gh-stack over graphite when both track the focus branch", () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feat");
    repo.writeGhStack(ghStackDoc(["feat"]));
    graphite(repo, " INSERT INTO branch_metadata VALUES ('feat','main','ggg111','000aaa');");
    const g = createGraph(createSys(repo.cwd), "feat");
    expect(g.kind).toBe("gh-stack");
    expect(g.headRef(g.nodes[0]!)).toBe("refs/heads/feat");
  });

  it.skipIf(!hasSqlite)("falls through to graphite for a branch gh-stack doesn't track", () => {
    const repo = makeRepo();
    repo.git("checkout", "-qb", "feat");
    repo.writeGhStack(ghStackDoc(["other"]));
    graphite(repo, " INSERT INTO branch_metadata VALUES ('feat','main','','');");
    const g = createGraph(createSys(repo.cwd), "feat");
    expect(g.kind).toBe("graphite");
    expect(g.nodes[0]!.branch).toBe("feat");
  });
});
