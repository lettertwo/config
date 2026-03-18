from worklayout import apply


def on_close(boss, window, data):
    apply(boss.active_tab)
