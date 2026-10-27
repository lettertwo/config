import { MouseButton, type MouseEvent as TuiMouseEvent } from "@opentui/core";
import type { ExtensionPaneTheme } from "hunkdiff/extension";
import { headerSegments, type HeaderTone } from "./outline";
import type { ChangesetEntry } from "./vendored/sidebar/files";
import { fileRowId } from "./vendored/sidebar/helpers";

function toneColor(tone: HeaderTone, theme: ExtensionPaneTheme): string {
  switch (tone) {
    case "marker":
      return theme.accent;
    case "title":
      return theme.text;
    case "readDone":
      return theme.badgeAdded;
    default:
      return theme.muted;
  }
}

/** One changeset header row; clicking it collapses or expands that changeset's files. */
export function ChangesetHeader({
  entry,
  textWidth,
  theme,
  cursor,
  onToggleChangeset,
}: {
  entry: ChangesetEntry;
  textWidth: number;
  theme: ExtensionPaneTheme;
  /** The outline's keyboard cursor is on this row. */
  cursor: boolean;
  onToggleChangeset: (changesetId: string) => void;
}) {
  const background = cursor ? theme.accentMuted : theme.panel;
  const { left, right } = headerSegments(entry, Math.max(1, textWidth));
  const rightWidth = right.reduce((sum, seg) => sum + Bun.stringWidth(seg.text), 0);
  return (
    <box
      id={fileRowId(entry.id)}
      style={{ width: "100%", height: 1, flexDirection: "row", backgroundColor: background }}
      onMouseUp={(event: TuiMouseEvent) => {
        if (event.button === MouseButton.LEFT) {
          onToggleChangeset(entry.changesetId);
        }
      }}
    >
      <box style={{ width: 1, height: 1, backgroundColor: background }} />
      <box style={{ flexGrow: 1, height: 1, flexDirection: "row", backgroundColor: background }}>
        {left.map((seg, i) => (
          <text key={i} fg={toneColor(seg.tone, theme)}>
            {seg.text}
          </text>
        ))}
        {rightWidth > 0 && (
          <box
            style={{
              flexGrow: 1,
              height: 1,
              flexDirection: "row",
              justifyContent: "flex-end",
              backgroundColor: background,
            }}
          >
            {right.map((seg, i) => (
              <text key={i} fg={toneColor(seg.tone, theme)}>
                {seg.text}
              </text>
            ))}
          </box>
        )}
      </box>
    </box>
  );
}
