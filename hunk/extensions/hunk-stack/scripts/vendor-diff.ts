// Show what changed upstream in the files src/vendored copies, between the
// pinned version and a newer upstream ref. Port those changes by hand, keeping
// the "mark-read:" and "stack:" edits, then bump the source's `from`.
//
//   bun run vendor:diff [hunk|mark-read] [checkout] [ref]
//   defaults: hunk  ../<source>  HEAD

import { resolve } from "node:path";

const SOURCES = {
  // src/vendored/sidebar
  hunk: {
    from: "v0.23.0",
    files: [
      "packages/hunk/src/extensions/default/ui/sidebar/FileSidebars.tsx",
      "packages/hunk/src/ui/components/panes/FileListItem.tsx",
      "packages/hunk/src/ui/lib/files.ts",
      "packages/hunk/src/ui/lib/sidebarRenderWindow.ts",
      // Leaf helpers collected in src/vendored/sidebar/helpers.ts.
      "packages/hunk/src/core/changeset/diffPaths.ts",
      "packages/hunk/src/lib/terminalText.ts",
      "packages/hunk/src/extensions/events.ts",
      "packages/hunk/src/ui/lib/ids.ts",
      "packages/hunk/src/ui/diff/rowStyle.ts",
      "packages/hunk/src/ui/lib/text.ts",
    ],
  },
  // src/vendored/mark-read; upstream src/mark-read.tsx is merged into src/extension.tsx.
  "mark-read": {
    from: "1a76ae85bbd26753314d29db3a89796f1fc63580",
    files: [
      "src/core.ts",
      "src/core.test.ts",
      "src/store.ts",
      "src/store.test.ts",
      "src/sessionLog.ts",
      "src/sessionLog.test.ts",
      "src/mark-read.tsx",
    ],
  },
};

const name = process.argv[2] ?? "hunk";
if (!(name in SOURCES)) {
  console.error(`unknown source ${name}; expected one of ${Object.keys(SOURCES).join(", ")}`);
  process.exit(2);
}
const source = SOURCES[name as keyof typeof SOURCES];
const defaultCheckout = name === "hunk" ? "../../hunk" : "../../hunk-mark-read";
const checkout = resolve(process.argv[3] ?? resolve(import.meta.dir, defaultCheckout));
const ref = process.argv[4] ?? "HEAD";

const result = Bun.spawnSync(
  ["git", "-C", checkout, "diff", "--stat", "-p", source.from, ref, "--", ...source.files],
  { stdout: "inherit", stderr: "inherit" },
);

if (result.exitCode !== 0) {
  process.exit(result.exitCode ?? 1);
}
