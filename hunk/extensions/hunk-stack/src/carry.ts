import { realpathSync } from "node:fs";
import { isAbsolute, relative, resolve } from "node:path";

/**
 * The `hunk stack` options every changeset reload repeats. A daemon reload of an ordinary
 * review reads only its own arguments, so without these the sidecar's notes vanish and
 * `--watch` stops at the first switch. View options stay behind: the review keeps its view
 * across a reload, and repeating them would undo a toggle made since launch.
 */
export interface Carried {
  args: string[];
  /** Why the sidecar shows on the first changeset only. */
  notice?: string;
}

/** The last `--agent-context` value, as hunk's option parser keeps it. */
export function agentContextOption(args: readonly string[]): string | undefined {
  let value: string | undefined;
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!;
    if (arg === "--") {
      break;
    }
    if (arg === "--agent-context") {
      value = args[i + 1];
      i += 1;
    } else if (arg.startsWith("--agent-context=")) {
      value = arg.slice("--agent-context=".length);
    }
  }
  return value;
}

/** Resolve symlinks through the deepest existing ancestor, as hunk's reload bounds do. */
function canonical(path: string): string {
  try {
    return realpathSync(path);
  } catch {
    const parent = resolve(path, "..");
    return parent === path ? path : resolve(canonical(parent), relative(parent, path));
  }
}

/**
 * Work out what reloads repeat from the launch arguments. `repoRoot` is the repository the
 * stack is in; hunk refuses a reload's sidecar outside it, and that refusal would fail every
 * switch rather than just drop the notes.
 */
export function carriedArgs(args: readonly string[], cwd: string, repoRoot: string | null): Carried {
  const carried: string[] = [];
  const beforeSeparator = args.includes("--") ? args.slice(0, args.indexOf("--")) : args;
  if (beforeSeparator.includes("--watch")) {
    carried.push("--watch");
  }

  const sidecar = agentContextOption(args);
  if (sidecar === undefined) {
    return { args: carried };
  }
  if (sidecar === "-") {
    return {
      args: carried,
      notice: "stack: a sidecar read from stdin cannot be read again, so its notes show on the first changeset only",
    };
  }
  const path = resolve(cwd, sidecar);
  const offset = repoRoot ? relative(canonical(repoRoot), canonical(path)) : "..";
  if (offset.startsWith("..") || isAbsolute(offset)) {
    return {
      args: carried,
      notice: "stack: hunk reloads only a sidecar inside the repository, so its notes show on the first changeset only",
    };
  }
  return { args: [...carried, "--agent-context", path] };
}
