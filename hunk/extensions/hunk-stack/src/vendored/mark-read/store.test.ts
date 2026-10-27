// Vendored from hunk-mark-read (1a76ae85bbd26753314d29db3a89796f1fc63580)
// upstream: src/store.test.ts
// Local changes are marked with "stack:". Compare with `bun run vendor:diff mark-read`.

import { describe, expect, test } from "bun:test";
import { MarkReadStore } from "./store";

const a = { path: "src/a.ts", patch: "@@ -1 +1 @@\n-a\n+A\n" };
const b = { path: "src/b.ts", patch: "@@ -1 +1 @@\n-b\n+B\n" };
const big = { path: "big.bin", patch: "" };

describe("MarkReadStore", () => {
  test("marks and unmarks files and reports only real changes", () => {
    const store = new MarkReadStore();
    store.setReview([a, b]);

    expect(store.setRead([a], true)).toHaveLength(1);
    expect(store.isRead(a)).toBe(true);
    expect(store.isRead(b)).toBe(false);
    expect(store.readCount()).toBe(1);

    expect(store.setRead([a], true)).toEqual([]);
    expect(store.setRead([a], false)).toEqual([{ key: store.keyOf(a)!, read: false }]);
    expect(store.readCount()).toBe(0);
  });

  test("a changed diff reads as unread; the identical diff reads as read again", () => {
    const store = new MarkReadStore();
    store.setReview([a, b]);
    store.setRead([a], true);

    const aChanged = { ...a, patch: `${a.patch}+more\n` };
    store.setReview([aChanged, b]);
    expect(store.isRead(aChanged)).toBe(false);

    store.setReview([a, b]);
    expect(store.isRead(a)).toBe(true);
  });

  test("untrackable files are never read and are left out of progress", () => {
    const store = new MarkReadStore();
    store.setReview([a, big]);
    expect(store.isTrackable(big)).toBe(false);
    expect(store.setRead([big], true)).toEqual([]);
    store.setRead([a], true);
    expect(store.readCount()).toBe(1);
    expect(store.trackableCount()).toBe(1);
  });

  test("setReview can replace the marks with ones loaded from disk", () => {
    const store = new MarkReadStore();
    store.setReview([a, b], new Set([store.keyOf(b)!]));
    expect(store.isRead(a)).toBe(false);
    expect(store.isRead(b)).toBe(true);
  });

  test("notifies subscribers with a fresh snapshot", () => {
    const store = new MarkReadStore();
    store.setReview([a]);
    const before = store.getSnapshot();
    let calls = 0;
    const unsubscribe = store.subscribe(() => {
      calls += 1;
    });

    store.setRead([a], true);
    store.setHidden(true);
    store.setHidden(true);
    unsubscribe();
    store.setHidden(false);

    expect(calls).toBe(2);
    expect(store.getSnapshot()).not.toBe(before);
  });
});
