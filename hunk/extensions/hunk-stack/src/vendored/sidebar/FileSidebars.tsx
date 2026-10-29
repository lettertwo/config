// Vendored from hunk v0.23.0 (7991d3034af1d2116e9c77db31265e409a73bd9f)
// upstream: packages/hunk/src/extensions/default/ui/sidebar/FileSidebars.tsx
// Local changes are marked with "mark-read:" or "stack:". Compare with `bun run vendor:diff hunk`.

import type { ScrollBoxRenderable } from "@opentui/core";
import { useTerminalDimensions } from "@opentui/react";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import type { ExtensionPaneProps } from "hunkdiff/extension";
// mark-read: import paths point at local copies.
import {
  buildDirnameSidebarEntries,
  buildFlatSidebarEntries,
  buildTreeSidebarEntries,
  collapseTreeSidebarEntries,
  expandCollapsedDirectoryPaths,
  resolveFileSidebarMode,
  sidebarDirectoryPaths,
  sidebarEntryStatsWidth,
  toggleCollapsedDirectoryPath,
  type SidebarEntry,
} from "./files";
import { fileRowId } from "./helpers";
import { buildSidebarRenderWindow } from "./sidebarRenderWindow";
import { FileDirectoryRow, FileGroupHeader, FileListItem } from "./FileListItem";
// stack: the outline's changeset headers sit between the file rows.
import { ChangesetHeader } from "../../ChangesetHeader";
import type { NavRow } from "../../focus";
import { navRows, outlineEntries, type FileView, type OutlineModel, type ProjectListed } from "../../outline";

// mark-read: read state the rows render and toggle. Directory paths are the
// logical paths `buildTreeSidebarEntries` assigns to directory rows.
export interface SidebarReadState {
  isFileRead(fileId: string): boolean;
  isDirectoryRead(path: string): boolean;
  toggleFile(fileId: string): void;
  toggleDirectory(path: string): void;
}

// stack: the stack outline and its click handlers. Absent when there is no stack, which
// leaves the plain file list.
export interface SidebarOutline {
  model: OutlineModel;
  onToggleChangeset(changesetId: string): void;
  /** A file of a changeset that is not loaded: load that changeset and land on the file. */
  onOpenFile(changesetId: string, path: string): void;
}

// stack: the keyboard cursor. It works without a stack, over the plain file list.
export interface SidebarFocus {
  /** The row to paint the cursor on; null while the outline mode is off. */
  cursorEntryId: string | null;
  onRows(rows: readonly NavRow[]): void;
}

export type BuiltInSidebarProps = Omit<
  ExtensionPaneProps,
  "placement" | "height" | "currentLine" | "review"
> &
  Partial<Pick<ExtensionPaneProps, "placement" | "height" | "currentLine" | "review">> & {
    readState: SidebarReadState;
    outline?: SidebarOutline;
    focus?: SidebarFocus;
    // stack: forces a file view; null keeps the width-based choice between tree and grouped.
    fileView?: FileView | null;
  };

type FileSidebarVariantProps = Pick<
  BuiltInSidebarProps,
  "actions" | "files" | "selectedFileId" | "theme" | "readState" | "outline" | "focus"
> & {
  estimatedViewportRows: number;
  scrollTop: number;
  textWidth: number;
  viewportHeight: number;
};

/** Ignore directory toggles for projections that cannot contain directory rows. */
function ignoreDirectoryToggle() {}

interface VirtualizedFileSidebarRowsProps extends Omit<FileSidebarVariantProps, "files"> {
  collapsedDirectoryPaths?: ReadonlySet<string>;
  /** The loaded changeset's file rows; headers and the other changesets' rows are woven in from `outline`. */
  entries: SidebarEntry[];
  onToggleDirectory?: (path: string) => void;
  paddingLeft?: number;
  /** Builds rows for a changeset that is not loaded in the same projection as `entries`. */
  project: ProjectListed;
}

/** Render one windowed sidebar projection with shared file selection and stats lanes. */
export function VirtualizedFileSidebarRows({
  actions,
  collapsedDirectoryPaths,
  entries: fileRows,
  outline,
  focus,
  project,
  estimatedViewportRows,
  onToggleDirectory,
  paddingLeft = 1,
  readState,
  scrollTop,
  selectedFileId,
  textWidth,
  theme,
  viewportHeight,
}: VirtualizedFileSidebarRowsProps): ReactNode {
  // stack: headers interleave with the file rows when a stack is known.
  const model = outline?.model;
  const entries = useMemo(
    () => (model ? outlineEntries(model, fileRows, project) : fileRows),
    [fileRows, model, project],
  );
  const rows = useMemo(() => navRows(entries, model?.loadedId ?? null), [entries, model]);
  const onRows = focus?.onRows;
  useEffect(() => onRows?.(rows), [onRows, rows]);
  const cursorEntryId = focus?.cursorEntryId ?? null;
  const fileEntries = entries.filter((entry) => entry.kind === "file");
  const statsWidth = Math.max(0, ...fileEntries.map((entry) => sidebarEntryStatsWidth(entry)));
  const renderWindow = useMemo(
    () =>
      buildSidebarRenderWindow({
        entries,
        estimatedViewportRows,
        overscanRows: 4,
        scrollTop,
        selectedFileId: selectedFileId ?? undefined,
        pinnedEntryId: cursorEntryId ?? undefined,
        viewportHeight,
      }),
    [entries, estimatedViewportRows, scrollTop, selectedFileId, cursorEntryId, viewportHeight],
  );

  return (
    <box style={{ width: "100%", flexDirection: "column" }}>
      {renderWindow.items.map((item) => {
        if (item.kind === "spacer") {
          return (
            <box
              key={item.key}
              style={{ width: "100%", height: item.height, backgroundColor: theme.panel }}
            />
          );
        }

        const { entry } = item;
        if (entry.kind === "changeset") {
          return (
            <ChangesetHeader
              key={entry.id}
              entry={entry}
              textWidth={textWidth}
              theme={theme}
              cursor={entry.id === cursorEntryId}
              onToggleChangeset={outline?.onToggleChangeset ?? ignoreDirectoryToggle}
            />
          );
        }
        if (entry.kind === "group") {
          return (
            <FileGroupHeader
              key={entry.id}
              entry={entry}
              paddingLeft={paddingLeft}
              textWidth={textWidth}
              theme={theme}
            />
          );
        }
        if (entry.kind === "directory") {
          return (
            <FileDirectoryRow
              key={entry.id}
              collapsed={collapsedDirectoryPaths?.has(entry.path) ?? false}
              entry={entry}
              onToggleDirectory={onToggleDirectory ?? ignoreDirectoryToggle}
              onToggleRead={entry.changesetId ? undefined : () => readState.toggleDirectory(entry.path)}
              paddingLeft={paddingLeft}
              read={entry.changesetId ? false : readState.isDirectoryRead(entry.path)}
              statsWidth={statsWidth}
              textWidth={textWidth}
              theme={theme}
            />
          );
        }

        // stack: a row of another changeset has no patch to mark, and selecting it loads its changeset.
        const { changesetId } = entry;
        return (
          <FileListItem
            key={entry.id}
            entry={entry}
            paddingLeft={paddingLeft}
            read={changesetId ? false : readState.isFileRead(entry.id)}
            selected={entry.id === selectedFileId}
            cursor={entry.id === cursorEntryId}
            statsWidth={statsWidth}
            textWidth={textWidth}
            theme={theme}
            onSelectFile={changesetId ? () => outline?.onOpenFile(changesetId, entry.path) : actions.selectFile}
            onToggleRead={changesetId ? undefined : readState.toggleFile}
          />
        );
      })}
    </box>
  );
}

// stack: a stable function, so the woven rows are not rebuilt on every render.
const projectFlat: ProjectListed = (files) => buildFlatSidebarEntries(files);

/** Render the compact directory-group projection for a narrow file sidebar. */
export function FlatFileSidebar({ files, ...props }: FileSidebarVariantProps): ReactNode {
  const entries = useMemo(() => buildFlatSidebarEntries(files), [files]);
  return (
    <VirtualizedFileSidebarRows
      {...props}
      entries={entries}
      paddingLeft={props.outline ? 2 : 1}
      project={projectFlat}
    />
  );
}

// stack: the flat file view, with no group rows to indent under.
const projectDirname: ProjectListed = (files) => buildDirnameSidebarEntries(files);

function DirnameFileSidebar({ files, ...props }: FileSidebarVariantProps): ReactNode {
  const entries = useMemo(() => buildDirnameSidebarEntries(files), [files]);
  return (
    <VirtualizedFileSidebarRows
      {...props}
      entries={entries}
      paddingLeft={props.outline ? 1 : 0}
      project={projectDirname}
    />
  );
}

/** Render the ordered hierarchy after applying the sidebar's collapsed directory paths. */
export function TreeFileSidebar({
  collapsedDirectoryPaths,
  files,
  onToggleDirectory,
  ...props
}: FileSidebarVariantProps & {
  collapsedDirectoryPaths: ReadonlySet<string>;
  onToggleDirectory: (path: string) => void;
}): ReactNode {
  const entries = useMemo(
    () => collapseTreeSidebarEntries(buildTreeSidebarEntries(files), collapsedDirectoryPaths),
    [collapsedDirectoryPaths, files],
  );
  const project = useCallback<ProjectListed>(
    (listed) => collapseTreeSidebarEntries(buildTreeSidebarEntries(listed), collapsedDirectoryPaths),
    [collapsedDirectoryPaths],
  );
  return (
    <VirtualizedFileSidebarRows
      {...props}
      collapsedDirectoryPaths={collapsedDirectoryPaths}
      project={project}
      entries={entries}
      onToggleDirectory={onToggleDirectory}
      paddingLeft={props.outline ? 1 : 0}
    />
  );
}

/**
 * Adapt the built-in file sidebar between compact and hierarchical projections.
 *
 * Resizing only replaces the rows inside one stable scrollbox. The sidebar keeps
 * file navigation and selected-row reveal shared so both projections preserve
 * the same review-stream behavior.
 */
export function FlexFileSidebar({
  files,
  selectedFileId,
  theme,
  width,
  actions,
  readState,
  outline,
  focus,
  fileView = null,
}: BuiltInSidebarProps): ReactNode {
  const scrollRef = useRef<ScrollBoxRenderable | null>(null);
  const previousSelectedFileIdRef = useRef(selectedFileId);
  const skipSelectedFileRevealRef = useRef(false);
  const [collapsedDirectoryPaths, setCollapsedDirectoryPaths] = useState<ReadonlySet<string>>(
    () => new Set(),
  );
  const [scrollViewport, setScrollViewport] = useState({ top: 0, height: 0 });
  const terminal = useTerminalDimensions();
  // Mirrors the host layout: one column of row highlight plus row padding.
  const textWidth = Math.max(8, width - 2);
  // stack: modes are file views, where hunk's "flat" mode is the grouped view.
  const mode: FileView = fileView ?? (resolveFileSidebarMode(textWidth) === "tree" ? "tree" : "grouped");
  const variantProps: FileSidebarVariantProps = {
    actions,
    estimatedViewportRows: terminal.height,
    files,
    outline,
    focus,
    readState,
    scrollTop: scrollViewport.top,
    selectedFileId,
    textWidth,
    theme,
    viewportHeight: scrollViewport.height,
  };

  /** Toggle one logical directory everywhere it appears in the ordered tree projection. */
  const toggleDirectory = (path: string) => {
    skipSelectedFileRevealRef.current = true;
    setCollapsedDirectoryPaths((current) => toggleCollapsedDirectoryPath(current, path));
  };

  useEffect(() => {
    const previousSelectedFileId = previousSelectedFileIdRef.current;
    previousSelectedFileIdRef.current = selectedFileId;
    if (!selectedFileId || selectedFileId === previousSelectedFileId) {
      return;
    }

    const selectedFile = files.find((file) => file.id === selectedFileId);
    if (!selectedFile) {
      return;
    }

    setCollapsedDirectoryPaths((current) =>
      expandCollapsedDirectoryPaths(current, sidebarDirectoryPaths(selectedFile.path)),
    );
  }, [files, selectedFileId]);

  useEffect(() => {
    const scrollBox = scrollRef.current;
    if (!scrollBox) {
      return;
    }

    let cancelled = false;
    let scheduled = false;

    const readViewport = () => {
      const nextTop = scrollBox.scrollTop ?? 0;
      const nextHeight = scrollBox.viewport.height ?? 0;
      setScrollViewport((current) =>
        current.top === nextTop && current.height === nextHeight
          ? current
          : { top: nextTop, height: nextHeight },
      );
    };

    const handleViewportChange = () => {
      if (scheduled) {
        return;
      }
      scheduled = true;
      queueMicrotask(() => {
        if (cancelled) {
          scheduled = false;
          return;
        }

        try {
          readViewport();
        } finally {
          scheduled = false;
        }
      });
    };

    readViewport();
    scrollBox.verticalScrollBar.on("change", handleViewportChange);
    scrollBox.viewport.on("layout-changed", handleViewportChange);
    scrollBox.viewport.on("resized", handleViewportChange);

    return () => {
      cancelled = true;
      scrollBox.verticalScrollBar.off("change", handleViewportChange);
      scrollBox.viewport.off("layout-changed", handleViewportChange);
      scrollBox.viewport.off("resized", handleViewportChange);
    };
  }, [files, mode]);

  // Selection and projection changes can both move the target row, so follow
  // the stable file id after either event instead of only after navigation.
  useEffect(() => {
    if (skipSelectedFileRevealRef.current) {
      skipSelectedFileRevealRef.current = false;
      return;
    }
    if (!selectedFileId) {
      return;
    }

    scrollRef.current?.scrollChildIntoView(fileRowId(selectedFileId));
  }, [collapsedDirectoryPaths, files, mode, selectedFileId]);

  // stack: keep the keyboard cursor in view.
  const cursorEntryId = focus?.cursorEntryId;
  useEffect(() => {
    if (cursorEntryId) {
      scrollRef.current?.scrollChildIntoView(fileRowId(cursorEntryId));
    }
  }, [cursorEntryId]);

  return (
    <scrollbox
      ref={scrollRef}
      width="100%"
      height="100%"
      focused={false}
      scrollY={true}
      viewportCulling={true}
      rootOptions={{ backgroundColor: theme.panel }}
      wrapperOptions={{ backgroundColor: theme.panel }}
      viewportOptions={{ backgroundColor: theme.panel }}
      contentOptions={{ backgroundColor: theme.panel }}
      verticalScrollbarOptions={{ visible: false }}
      horizontalScrollbarOptions={{ visible: false }}
    >
      {mode === "tree" ? (
        <TreeFileSidebar
          {...variantProps}
          collapsedDirectoryPaths={collapsedDirectoryPaths}
          onToggleDirectory={toggleDirectory}
        />
      ) : mode === "grouped" ? (
        <FlatFileSidebar {...variantProps} />
      ) : (
        <DirnameFileSidebar {...variantProps} />
      )}
    </scrollbox>
  );
}
