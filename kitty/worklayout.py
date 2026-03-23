from kitty.layout.splits import Pair


def _pair(horizontal, bias, one, two):
    p = Pair(horizontal=horizontal)
    p.bias = bias
    p.one = one
    p.two = two
    return p


def _equal_row(group_ids):
    n = len(group_ids)
    if n == 1:
        return group_ids[0]
    return _pair(True, 1.0 / n, group_ids[0], _equal_row(group_ids[1:]))


def _get_leaves(node):
    """Return leaf group IDs from a Pair subtree, left-to-right."""
    if node is None:
        return []
    if isinstance(node, int):
        return [node]
    return _get_leaves(node.one) + _get_leaves(node.two)


def _build(ids):
    """Build a Pair tree for the given ordered window IDs."""
    n = len(ids)
    if n <= 1:
        return
    if n == 2:
        return _pair(True, 0.62, ids[0], ids[1])
    top = _pair(True, 0.62, ids[0], ids[1])
    return _pair(False, 0.62, top, _equal_row(ids[2:]))


def capture(tab):
    """Snapshot the current top/bottom row IDs before a new window is added.

    Returns (top_ids, bottom_ids) if the layout is in a fully-formed work
    layout (vertical root with exactly two windows in the top row), otherwise
    None.  Call this *before* tab.new_window().
    """
    if tab is None or tab.current_layout.name != "splits":
        return None
    root = tab.current_layout.pairs_root
    if root is None or root.horizontal:
        return None
    top_ids = _get_leaves(root.one)
    if len(top_ids) != 2:
        return None
    return (top_ids, _get_leaves(root.two))


def append(tab, state):
    """Add any windows not in *state* to the bottom-right, preserving the top row.

    *state* is the return value of capture().  Falls back to apply() when
    state is None (fresh layout or fewer than 3 windows).
    """
    if tab is None or tab.current_layout.name != "splits":
        return
    if state is None:
        apply(tab)
        return

    layout = tab.current_layout
    top_ids, bottom_ids = state
    known = set(top_ids) | set(bottom_ids)
    new_ids = sorted(
        g.id for g in tab.windows.iter_all_layoutable_groups() if g.id not in known
    )
    layout.pairs_root = _build(top_ids + bottom_ids + new_ids)
    tab.relayout()


def remove(tab, exclude_id):
    """Rebuild from the current tree order, dropping one window.

    If a top-row slot opens up after the removal, the first bottom window is
    promoted to fill it.  Falls back to apply() when there is no existing tree.
    """
    if tab is None or tab.current_layout.name != "splits":
        return
    layout = tab.current_layout
    root = layout.pairs_root
    if root is None:
        apply(tab)
        return

    if root.horizontal:
        ids = [i for i in _get_leaves(root) if i != exclude_id]
    else:
        top_ids = [i for i in _get_leaves(root.one) if i != exclude_id]
        bottom_ids = [i for i in _get_leaves(root.two) if i != exclude_id]
        while len(top_ids) < 2 and bottom_ids:
            top_ids.append(bottom_ids.pop(0))
        ids = top_ids + bottom_ids

    layout.pairs_root = _build(ids)
    tab.relayout()


def apply(tab):
    """Rebuild the work layout from scratch, ordered by group ID (oldest first).

    Only called by the manual opt+cmd+l trigger and as a fallback for fresh
    layouts with fewer than 3 windows.
    """
    if tab is None or tab.current_layout.name != "splits":
        return
    layout = tab.current_layout
    root = layout.pairs_root

    if root is None:
        ids = sorted(g.id for g in tab.windows.iter_all_layoutable_groups())
    elif root.horizontal:
        ids = [i for i in _get_leaves(root)]
    else:
        top_ids = [i for i in _get_leaves(root.one)]
        bottom_ids = [i for i in _get_leaves(root.two)]
        while len(top_ids) < 2 and bottom_ids:
            top_ids.append(bottom_ids.pop(0))
        ids = top_ids + bottom_ids

    layout.pairs_root = _build(ids)
    if layout.pairs_root is not None:
        tab.relayout()


def on_close(boss, window, data):  # pyright: ignore
    tab = boss.active_tab
    if tab is None:
        return
    closing_group_id = next(
        (
            g.id
            for g in tab.windows.iter_all_layoutable_groups()
            if g.has_window_id(window.id)
        ),
        None,
    )
    remove(tab, closing_group_id)


def main():
    pass


def handle_result(args, __, ___, boss):  # pyright: ignore
    tab = boss.active_tab
    if tab is not None:
        tab.goto_layout("splits")
        apply(tab)


handle_result.no_ui = True
