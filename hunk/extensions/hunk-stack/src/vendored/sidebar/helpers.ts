// Vendored from hunk v0.23.0 (7991d3034af1d2116e9c77db31265e409a73bd9f)
// Small leaf helpers the sidebar files import from deeper inside hunk, collected
// here so the copied files need only import-path changes. Each block names its
// upstream source. Compare with `bun run vendor:diff hunk`.

import type { ExtensionVcsFileChangeType } from "hunkdiff/extension";

// upstream: packages/hunk/src/core/changeset/diffPaths.ts
/** Remove parser-added CR/LF suffixes from diff paths without touching meaningful spaces. */
export function normalizeDiffPath(path: string | undefined) {
  return path?.replace(/[\r\n]+$/u, "");
}

// upstream: packages/hunk/src/lib/terminalText.ts
/** Render an exact filesystem path safely without letting controls alter terminal geometry. */
export function formatTerminalPath(path: string) {
  let formatted = "";
  for (const character of path) {
    const codePoint = character.codePointAt(0)!;
    if (character === "\\") {
      formatted += "\\\\";
    } else if (character === "\t") {
      formatted += "\\t";
    } else if (character === "\n") {
      formatted += "\\n";
    } else if (character === "\r") {
      formatted += "\\r";
    } else if (codePoint <= 0x1f || (codePoint >= 0x7f && codePoint <= 0x9f)) {
      formatted += `\\x${codePoint.toString(16).padStart(2, "0")}`;
    } else {
      formatted += character;
    }
  }
  return formatted;
}

// upstream: packages/hunk/src/extensions/events.ts
export function readMetadataChangeType(metadata: unknown): ExtensionVcsFileChangeType | undefined {
  const type = (metadata as { type?: unknown } | null | undefined)?.type;
  return type === "change" ||
    type === "rename-pure" ||
    type === "rename-changed" ||
    type === "new" ||
    type === "deleted"
    ? type
    : undefined;
}

// upstream: packages/hunk/src/ui/lib/ids.ts
export function fileRowId(fileId: string) {
  return `file-row:${fileId}`;
}

// upstream: packages/hunk/src/ui/diff/rowStyle.ts
export function diffRailMarker() {
  return "▌";
}

// mark-read: upstream packages/hunk/src/ui/lib/text.ts measures and slices by
// grapheme with its own width tables (~600 lines). Sidebar labels are already
// sanitized by formatTerminalPath, so Bun's width measurement is enough here.
function measureTextWidth(text: string) {
  return Bun.stringWidth(text);
}

/** Take the longest prefix of `text` that fits in `width` terminal cells. */
function sliceTextByWidth(text: string, width: number) {
  let result = "";
  let used = 0;
  for (const character of text) {
    const characterWidth = measureTextWidth(character);
    if (used + characterWidth > width) {
      break;
    }
    result += character;
    used += characterWidth;
  }
  return { text: result, width: used };
}

export function fitText(text: string, width: number, overflowMarker = ".") {
  if (width <= 0) {
    return "";
  }

  if (measureTextWidth(text) <= width) {
    return text;
  }

  const marker = sliceTextByWidth(overflowMarker, width);
  const textWidth = Math.max(0, width - marker.width);
  return `${sliceTextByWidth(text, textWidth).text}${marker.text}`;
}

export function padText(text: string, width: number) {
  const trimmed = fitText(text, width);
  return `${trimmed}${" ".repeat(Math.max(0, width - measureTextWidth(trimmed)))}`;
}
