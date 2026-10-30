"""The Apps page: one shared app list, a zone per workspace, renaming, the Default view."""
from helpers import app_names, map_chips

SPOTIFY = "appid:open.spotify.com-D551!App"
DISCORD = "appid:5e79188c"


def test_every_workspace_lists_every_app(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    gaming = set(app_names(pg)) - {"eldenring.exe"}          # games are only in Gaming
    pg.select_option("#appsws", "Work")
    assert set(app_names(pg)) == gaming
    pg.select_option("#appsws", "__normal")
    assert set(app_names(pg)) == gaming


def test_rename_shows_everywhere_and_resets(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    pg.click(f"[data-act=nameEdit][data-win='{SPOTIFY}']")
    assert pg.evaluate("document.activeElement.dataset.appname") == SPOTIFY
    pg.keyboard.press("Control+A")
    pg.keyboard.type("Music")
    pg.keyboard.press("Enter")
    assert "Music" in app_names(pg)
    assert "Music" in map_chips(pg)["1"]
    pg.select_option("#appsws", "__normal")
    assert "Music" in app_names(pg)
    pg.click(f"[data-act=nameEdit][data-win='{SPOTIFY}']")
    pg.click("[data-act=nameAuto]")
    assert "Spotify" in app_names(pg)


def test_escape_cancels_rename(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    before = app_names(pg)
    pg.click(f"[data-act=nameEdit][data-win='{DISCORD}']")
    pg.keyboard.type("x")
    pg.keyboard.press("Escape")
    assert pg.locator("[data-appname]").count() == 0
    assert app_names(pg) == before


def test_zone_menu_and_dont_move(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    assert "Steam" in map_chips(pg)["0"]                     # demo: Steam is Don't move
    pg.select_option("[data-place='ahk_exe steam.exe']", "1")
    assert "Steam" in map_chips(pg)["1"]
    pg.select_option("[data-place='ahk_exe steam.exe']", "0")
    assert "Steam" in map_chips(pg)["0"]


def test_drag_onto_zone_and_strip(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming", height=1200)
    pg.drag_and_drop(f"#appmap [data-chip='{SPOTIFY}']", "[data-dropzone='0']")
    assert "Spotify" in map_chips(pg)["0"]
    assert pg.input_value(f"[data-place='{SPOTIFY}']") == "0"
    pg.drag_and_drop(f"[data-chip='{SPOTIFY}']", "[data-dropzone='4']")
    assert "Spotify" in map_chips(pg)["4"]


def test_default_view_zones(open_ui):
    pg = open_ui("?page=apps")
    assert pg.input_value("#appsws") == "__normal"            # the Apps page opens on Default
    pg.select_option("[data-normalzone='ahk_exe ms-teams.exe']", "2")
    assert "Teams" in map_chips(pg)["2"]
    pg.select_option("[data-normalzone='ahk_exe steam.exe']", "0")
    assert "Steam" in map_chips(pg)["0"]


def test_remove_app_everywhere(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    pg.click("[data-act=appRemoveAsk][data-key='ahk_exe notepad.exe']")
    pg.click("[data-act=normRemoveYes]")
    assert "notepad.exe" not in app_names(pg)
    pg.select_option("#appsws", "Work")
    assert "notepad.exe" not in app_names(pg)


def test_web_app_opening_its_website_is_flagged(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    notes = pg.locator("#apps .warnline")
    flagged = notes.count()
    assert flagged >= 1
    pg.click(f"#apps [data-act=appFindShortcut][data-win='{SPOTIFY}']")
    assert notes.count() == flagged - 1
    assert "shell:AppsFolder" in pg.evaluate(f"S.catalog.find(a => a.win === '{SPOTIFY}').cmd")
    assert "installed app" in pg.inner_text("#toast")
