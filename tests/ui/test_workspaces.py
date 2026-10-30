"""The Workspaces page: rename, duplicate, reorder, and the menus that follow the order."""

NAMES = "[...document.querySelectorAll('.ws-card .ws-name')].map(n => n.firstChild.textContent.trim())"


def test_rename_workspace(open_ui):
    pg = open_ui("?page=workspaces&wsopen=Work", height=1600)
    pg.click("[data-wsrename=Work]")
    pg.fill("#modal-in", "Office")
    pg.keyboard.press("Enter")
    assert "Office" in pg.evaluate(NAMES) and "Work" not in pg.evaluate(NAMES)
    assert pg.evaluate("wsOpen.has('Office')")                # stays open
    assert pg.locator("[data-wsrename=Gaming]").count() == 0  # gaming mode keeps its name


def test_duplicate_refuses_a_taken_name(open_ui):
    pg = open_ui("?page=workspaces&wsopen=Work", height=1600)
    pg.click("[data-wsdup=Work]")
    pg.fill("#modal-in", "Gaming")
    pg.keyboard.press("Enter")
    assert pg.inner_text("#modal-err").strip() != ""
    pg.fill("#modal-in", "Streaming")
    pg.keyboard.press("Enter")
    assert "Streaming" in pg.evaluate(NAMES)
    assert pg.evaluate("findWS('Streaming').apps.length") == pg.evaluate("findWS('Work').apps.length")


def test_reorder_by_keyboard_and_menus_follow(open_ui):
    pg = open_ui("?page=workspaces", height=1600)
    names = pg.evaluate(NAMES)
    last = names[-1]
    assert names[0] == "Default" and len(names) >= 3
    pg.focus(f"[data-wsgrip='{last}']")
    pg.keyboard.press("ArrowUp")
    moved = pg.evaluate(NAMES)
    assert moved.index(last) == names.index(last) - 1
    assert pg.evaluate("document.activeElement.dataset.wsgrip") == last
    pg.click("[data-go=apps]")
    menu = pg.evaluate("[...document.querySelectorAll('#appsws option')].map(o => o.textContent)")
    own = [n for n in moved if n != "Default"]               # the Default card always comes first
    assert menu == ["Default"] + own
    pg.click("[data-go=zones]")
    layouts = pg.evaluate("[...document.querySelectorAll('#layoutpick option')].map(o => o.textContent)")
    assert [n for n in layouts if n in own] == own


def test_card_actions_and_layout_of_own_workspace(open_ui):
    pg = open_ui("?page=workspaces&wsopen=Work", height=1600)
    card = pg.locator("[data-wscard=Work]")
    assert "Default layout" in card.inner_text()
    card.locator("[data-editlayout='ws:Work']").click()
    assert pg.input_value("#layoutpick") == "ws:Work"
    assert "until you save one" in pg.inner_text("#ed-title")
    pg.click("[data-preset='1']")
    pg.click("#save-layout")
    assert pg.evaluate("findWS('Work').ownLayout") == 1
    pg.click("[data-go=workspaces]")
    assert "Its own layout" in pg.locator("[data-wscard=Work]").inner_text()


def test_new_workspace_has_no_layout_picker(open_ui):
    pg = open_ui("?page=workspaces", height=1600)
    pg.click("[data-act=newWS]")
    assert pg.locator("#modal-sel").count() == 0
    pg.fill("#modal-in", "Streaming")
    pg.keyboard.press("Enter")
    assert pg.evaluate("findWS('Streaming').ownLayout") == 0
