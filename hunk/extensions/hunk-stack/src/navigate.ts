import type { ExtensionReviewDescriptor } from "hunkdiff/extension";
import type { Changeset, Zoom } from "./stack/stack";
import { COMBINED_ID } from "./stack/stack";
import type { Sys } from "./stack/sys";

/** The paths a changeset touches, newest side. Empty when nothing changed or a sha is unresolved. */
export function changedPaths(sys: Sys, changeset: Changeset): string[] {
  const lines = (stdout: string) => stdout.split("\n").filter((line) => line !== "");
  if (changeset.uncommitted) {
    return [
      ...lines(sys.git(["diff", "--name-only", "HEAD"]).stdout),
      ...lines(sys.git(["ls-files", "--others", "--exclude-standard"]).stdout),
    ];
  }
  if (!changeset.baseSha || !changeset.headSha) {
    return [];
  }
  return lines(sys.git(["diff", "--name-only", changeset.baseSha, changeset.headSha]).stdout);
}

/**
 * The neighbour of `fromId` in list order (base to head), skipping changesets that touch no
 * files, or null at either end. A changeset with no files would load an empty review, which is
 * a dead stop where the reviewer wants the next real one.
 */
export function stepChangeset(
  changesets: readonly Changeset[],
  fromId: string | null,
  direction: 1 | -1,
  hasFiles: (changeset: Changeset) => boolean,
): Changeset | null {
  const from = changesets.findIndex((cs) => cs.id === fromId);
  if (from === -1) {
    // Nothing known to be showing: the first step lands on the changeset the review opens on.
    return changesets.find((cs) => cs.current && hasFiles(cs)) ?? null;
  }
  for (let i = from + direction; i >= 0 && i < changesets.length; i += direction) {
    if (hasFiles(changesets[i]!)) {
      return changesets[i]!;
    }
  }
  return null;
}

/** What the selection was on when the zoom changed, for finding it again in the new slicing. */
export interface Flip {
  from: Zoom;
  to: Zoom;
  prevPath: string;
  /** The branch that owned the commit-zoom changeset the reviewer was on. */
  prevBranch?: string;
}

export interface FlipTarget {
  changeset: Changeset;
  /** Absent when the previous file is not in the target, which then opens on its first file. */
  path?: string;
}

/**
 * Where to land after the zoom changes, so the reviewer stays on the same file. A pinned
 * (path, changeset) pair never survives a flip because branch ids and shas differ, so each
 * direction has its own rule:
 *
 * - commit to branch: the owning branch's changeset, on the same path when it has it.
 * - to combined: the one combined changeset, on the same path when it has it.
 * - otherwise: the newest changeset that touched the path, since the list runs oldest to newest.
 *
 * With no match the changeset marked current on the new list wins, on its first file.
 */
export function flipTarget(
  changesets: readonly Changeset[],
  flip: Flip | null,
  pathsOf: (changeset: Changeset) => readonly string[],
): FlipTarget | null {
  const current = changesets.find((cs) => cs.current);
  const fallback = current ? { changeset: current } : null;
  if (!flip) {
    return fallback;
  }
  const onPath = (changeset: Changeset): FlipTarget => ({
    changeset,
    path: pathsOf(changeset).includes(flip.prevPath) ? flip.prevPath : undefined,
  });

  if (flip.from === "commit" && flip.to === "branch") {
    const owner = flip.prevBranch ? changesets.find((cs) => cs.id === flip.prevBranch) : undefined;
    return owner ? onPath(owner) : fallback;
  }
  if (flip.to === "combined") {
    const combined = changesets.find((cs) => cs.id === COMBINED_ID);
    return combined ? onPath(combined) : fallback;
  }
  for (let i = changesets.length - 1; i >= 0; i--) {
    if (pathsOf(changesets[i]!).includes(flip.prevPath)) {
      return { changeset: changesets[i]!, path: flip.prevPath };
    }
  }
  return fallback;
}

/**
 * Which changeset the review is showing, read from the descriptor hunk attaches to a range
 * review. A daemon reload of `diff <base>..<head>` echoes both shas back as a comparison, a
 * working-tree `hunk diff` (with or without `HEAD`) has no descriptor at all (the uncommitted
 * changeset), and `hunk show <sha>` is a commit. Returns null when nothing matches, such as a clean worktree or a range the stack
 * doesn't list.
 */
export function identifyLoaded(
  review: ExtensionReviewDescriptor | null,
  changesets: readonly Changeset[],
): Changeset | null {
  if (review === null) {
    return changesets.find((cs) => cs.uncommitted) ?? null;
  }
  if (review.kind === "comparison") {
    return (
      changesets.find((cs) => cs.baseSha === review.base && cs.headSha === review.head) ??
      changesets.find((cs) => cs.base === review.base && cs.head === review.head) ??
      null
    );
  }
  if (review.kind === "commit") {
    // A commit's id is its sha in both the commit zoom and the git-log fallback.
    return changesets.find((cs) => cs.id === review.revision) ?? null;
  }
  return null;
}
