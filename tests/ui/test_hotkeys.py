"""The Hotkeys page: recording a shortcut, clashes, clearing, cancelling, resetting."""

KEY = "id => S.bindings.find(b => b.id === id).key"


def press(pg, *mods, key):
    for m in mods:
        pg.keyboard.down(m)
    pg.keyboard.press(key)
    for m in reversed(mods):
        pg.keyboard.up(m)


def test_record_a_shortcut(open_ui):
    pg = open_ui("?page=hotkeys")
    pg.click("[data-hkrec=Lock]")
    press(pg, "Control", "Shift", key="KeyK")
    assert pg.evaluate(KEY, "Lock") == "^+k"


def test_clash_is_refused(open_ui):
    pg = open_ui("?page=hotkeys")
    before = pg.evaluate(KEY, "Dim")
    pg.click("[data-hkrec=Dim]")
    press(pg, "Control", "Alt", key="KeyG")                   # gaming mode's key
    assert pg.evaluate(KEY, "Dim") == before


def test_backspace_clears_and_escape_cancels(open_ui):
    pg = open_ui("?page=hotkeys")
    pg.click("[data-hkrec=Free]")
    pg.keyboard.press("Backspace")
    assert pg.evaluate(KEY, "Free") == ""
    before = pg.evaluate(KEY, "Borderless")
    pg.click("[data-hkrec=Borderless]")
    pg.keyboard.press("Escape")
    assert not pg.evaluate("!!recording")
    assert pg.evaluate(KEY, "Borderless") == before


def test_reset_to_defaults(open_ui):
    pg = open_ui("?page=hotkeys")
    pg.click("[data-hkrec=Lock]")
    press(pg, "Control", "Shift", key="KeyK")
    pg.click("[data-act=resetHotkeys]")
    assert pg.evaluate("S.bindings.filter(b => b.key !== b.def).length") == 0
