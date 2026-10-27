// Vendored from hunk v0.23.0 (7991d3034af1d2116e9c77db31265e409a73bd9f)
// upstream: packages/hunk/src/ui/components/panes/FileListItem.tsx
// Local changes are marked with "mark-read:". Compare with `bun run vendor:diff hunk`.

import { MouseButton, type MouseEvent as TuiMouseEvent } from "@opentui/core";
import { memo } from "react";
import type { ExtensionSidebarTheme } from "hunkdiff/extension";
import {
  sidebarEntryStats,
  type FileDirectoryEntry,
  type FileGroupEntry,
  type FileListEntry,
} from "./files";
// mark-read: import paths point at local copies.
import { diffRailMarker, fileRowId, fitText, padText } from "./helpers";

/**
 * Rows render from the public sidebar theme tokens rather than the full
 * internal theme: the built-in sidebar is a bundled extension consuming the
 * published props, and these rows are what it draws. `AppTheme` satisfies the
 * token slice structurally, so internal callers pass their theme unchanged.
 */

/** Get icon and color for file state using standard git status codes. */
function getFileStateIcon(
  entry: FileListEntry,
  theme: ExtensionSidebarTheme,
): { icon: string; color: string } {
  if (entry.isUntracked) {
    return { icon: "?", color: theme.fileUntracked };
  }

  switch (entry.changeType) {
    case "new":
      return { icon: "A", color: theme.fileNew };
    case "deleted":
      return { icon: "D", color: theme.fileDeleted };
    case "rename-pure":
    case "rename-changed":
      return { icon: "R", color: theme.fileRenamed };
    case "change":
      return { icon: "M", color: theme.fileModified };
    default:
      return { icon: "", color: theme.text };
  }
}

/** Render one folder header in the navigation sidebar. */
export function FileGroupHeader({
  entry,
  paddingLeft = 1,
  textWidth,
  theme,
}: {
  entry: FileGroupEntry;
  paddingLeft?: number;
  textWidth: number;
  theme: ExtensionSidebarTheme;
}) {
  return (
    <box
      style={{
        width: "100%",
        height: 1,
        paddingLeft,
        backgroundColor: theme.panel,
      }}
    >
      <text fg={theme.muted}>{fitText(entry.label, Math.max(1, textWidth))}</text>
    </box>
  );
}

/** Clamp hierarchy indentation so a row always retains space for its visible label. */
export function fileSidebarIndentWidth(depth: number, textWidth: number, reservedWidth: number) {
  return Math.min(Math.max(0, depth) * 2, Math.max(0, textWidth - reservedWidth - 1));
}

// mark-read: the read marker column. Clicking it toggles read state without
// selecting the row or collapsing the directory.
export const READ_MARKER_WIDTH = 2;

/** Render the "✓ " read marker cell, clickable to toggle read state. */
function ReadMarker({
  background,
  onToggleRead,
  read,
  theme,
}: {
  background: string;
  onToggleRead?: () => void;
  read: boolean;
  theme: ExtensionSidebarTheme;
}) {
  return (
    <box
      style={{ width: READ_MARKER_WIDTH, height: 1, backgroundColor: background }}
      onMouseUp={(event: TuiMouseEvent) => {
        if (event.button !== MouseButton.LEFT || !onToggleRead) {
          return;
        }
        event.stopPropagation();
        onToggleRead();
      }}
    >
      <text fg={theme.badgeAdded}>{read ? "✓ " : "  "}</text>
    </box>
  );
}

/** Render one mouse-toggleable directory row in the navigation sidebar. */
export function FileDirectoryRow({
  collapsed,
  entry,
  onToggleDirectory,
  onToggleRead,
  paddingLeft = 1,
  read = false,
  statsWidth = 0,
  textWidth,
  theme,
}: {
  collapsed: boolean;
  entry: FileDirectoryEntry;
  onToggleDirectory: (path: string) => void;
  // mark-read: read state and toggle for the whole directory.
  onToggleRead?: () => void;
  paddingLeft?: number;
  read?: boolean;
  statsWidth?: number;
  textWidth: number;
  theme: ExtensionSidebarTheme;
}) {
  const statsSectionWidth = statsWidth > 0 ? statsWidth + 1 : 0;
  const countText = collapsed
    ? `${entry.descendantFileCount} ${entry.descendantFileCount === 1 ? "file" : "files"}`
    : null;
  const trailingWidth = countText ? Math.max(statsSectionWidth, countText.length + 1) : 0;
  // mark-read: the read marker takes two columns ahead of the disclosure arrow.
  const disclosureWidth = 2 + READ_MARKER_WIDTH;
  const indentWidth = fileSidebarIndentWidth(
    entry.depth,
    textWidth,
    disclosureWidth + trailingWidth + 1,
  );
  const labelWidth = Math.max(1, textWidth - 1 - disclosureWidth - trailingWidth - indentWidth);

  return (
    <box
      style={{
        width: "100%",
        height: 1,
        flexDirection: "row",
        backgroundColor: theme.panel,
      }}
      onMouseUp={(event: TuiMouseEvent) => {
        if (event.button === MouseButton.LEFT) {
          onToggleDirectory(entry.path);
        }
      }}
    >
      <box style={{ width: 1, height: 1, backgroundColor: theme.panel }} />
      <box
        style={{
          flexGrow: 1,
          height: 1,
          paddingLeft: paddingLeft + indentWidth,
          flexDirection: "row",
          backgroundColor: theme.panel,
        }}
      >
        <ReadMarker
          background={theme.panel}
          onToggleRead={onToggleRead}
          read={read}
          theme={theme}
        />
        <text fg={theme.muted}>{collapsed ? "› " : "⌄ "}</text>
        <text fg={read ? theme.badgeAdded : theme.muted}>
          {padText(fitText(entry.label, labelWidth), labelWidth)}
        </text>
        {countText && (
          <box
            style={{
              width: trailingWidth,
              height: 1,
              flexDirection: "row",
              justifyContent: "flex-end",
              backgroundColor: theme.panel,
            }}
          >
            <text fg={theme.muted}>{countText}</text>
          </box>
        )}
      </box>
    </box>
  );
}

/** Render one file row in the navigation sidebar. */
export const FileListItem = memo(function FileListItem({
  entry,
  paddingLeft = 1,
  read = false,
  selected,
  statsWidth,
  textWidth,
  theme,
  onSelectFile,
  onToggleRead,
}: {
  entry: FileListEntry;
  paddingLeft?: number;
  // mark-read: read state and toggle for this file.
  read?: boolean;
  selected: boolean;
  statsWidth: number;
  textWidth: number;
  theme: ExtensionSidebarTheme;
  onSelectFile: (fileId: string) => void;
  onToggleRead?: (fileId: string) => void;
}) {
  const rowBackground = selected ? theme.panelAlt : theme.panel;
  const stats = sidebarEntryStats(entry);
  const { icon, color } = getFileStateIcon(entry, theme);
  // mark-read: the read marker takes two columns ahead of the icon.
  const iconWidth = (icon ? 2 : 0) + READ_MARKER_WIDTH; // marker + icon + space
  const statsSectionWidth = statsWidth > 0 ? statsWidth + 1 : 0;
  const indentWidth = fileSidebarIndentWidth(
    entry.depth,
    textWidth,
    iconWidth + statsSectionWidth + 1,
  );
  const nameWidth = Math.max(1, textWidth - 1 - iconWidth - statsSectionWidth - indentWidth);

  return (
    <box
      id={fileRowId(entry.id)}
      style={{
        width: "100%",
        height: 1,
        backgroundColor: rowBackground,
        flexDirection: "row",
      }}
      onMouseUp={() => onSelectFile(entry.id)}
    >
      <text fg={selected ? theme.accent : rowBackground} bg={rowBackground}>
        {selected ? diffRailMarker() : " "}
      </text>
      <box
        style={{
          flexGrow: 1,
          height: 1,
          paddingLeft: paddingLeft + indentWidth,
          flexDirection: "row",
          backgroundColor: rowBackground,
        }}
      >
        <ReadMarker
          background={rowBackground}
          onToggleRead={onToggleRead ? () => onToggleRead(entry.id) : undefined}
          read={read}
          theme={theme}
        />
        {icon && <text fg={color}>{icon} </text>}
        <text fg={read ? theme.badgeAdded : theme.text}>
          {padText(fitText(entry.name, nameWidth, "…"), nameWidth)}
        </text>
        {statsSectionWidth > 0 && (
          <box
            style={{
              width: statsSectionWidth,
              height: 1,
              flexDirection: "row",
              justifyContent: "flex-end",
              backgroundColor: rowBackground,
            }}
          >
            {stats.map((stat, index) => (
              <box
                key={`${entry.id}:${stat.kind}`}
                style={{ height: 1, flexDirection: "row", backgroundColor: rowBackground }}
              >
                {index > 0 && <text fg={selected ? theme.text : theme.muted}> </text>}
                <text
                  fg={
                    stat.kind === "agent-comment"
                      ? theme.noteBorder
                      : stat.kind === "addition"
                        ? theme.badgeAdded
                        : theme.badgeRemoved
                  }
                >
                  {stat.text}
                </text>
              </box>
            ))}
          </box>
        )}
      </box>
    </box>
  );
});
