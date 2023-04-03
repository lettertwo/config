def main():
    pass


def handle_result(args, __, ___, boss):  # pyright: ignore
    new = True if "new" in args else False
    cwd = True if "cwd" in args else False
    tab = boss.active_tab
    if tab is not None:
        new = new or len(tab) == 1
        if new:
            if cwd:
                tab.new_window(cwd=tab.get_cwd_of_active_window())
            else:
                tab.new_window()
        if tab.current_layout.name == "stack":
            tab.last_used_layout()
            tab.windows.make_previous_group_active()
        elif not new:
            tab.first_window()
            tab.goto_layout("stack")


handle_result.no_ui = True
