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


def apply(tab):
    """Rebuild the splits Pair tree into the work layout.

    Top row (62% height): first two windows, 62/38 width split.
    Bottom row (38% height): remaining windows in equal columns.
    Edge cases: 1 window → no-op, 2 windows → side-by-side 62/38.
    Only acts when the active layout is 'splits'.
    """
    if tab is None or tab.current_layout.name != "splits":
        return
    layout = tab.current_layout
    group_ids = [g.id for g in tab.windows.iter_all_layoutable_groups()]
    n = len(group_ids)
    if n <= 1:
        return
    if n == 2:
        root = _pair(True, 0.62, group_ids[0], group_ids[1])
    else:
        top = _pair(True, 0.62, group_ids[0], group_ids[1])
        root = _pair(False, 0.62, top, _equal_row(group_ids[2:]))
    layout.pairs_root = root
    tab.relayout()


def main():
    pass


def handle_result(args, __, ___, boss):  # pyright: ignore
    tab = boss.active_tab
    if tab is not None:
        tab.goto_layout("splits")
        apply(tab)


handle_result.no_ui = True
