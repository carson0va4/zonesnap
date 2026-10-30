"""Games on the Apps page (Gaming workspace): adding, naming, launchers, per-game layouts."""
from helpers import app_names

ELDEN = "ahk_exe eldenring.exe"


def test_add_a_game(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    pg.click("[data-act=gameAddOpen]")
    pg.fill("#game-add", "cs2.exe")
    pg.keyboard.press("Enter")
    assert "cs2" in app_names(pg, "#gamelayouts")
    assert "added as a game" in pg.inner_text("#toast")


def test_rename_a_game_in_game_layouts(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    pg.click(f"#gamelayouts [data-act=nameEdit][data-win='{ELDEN}']")
    pg.keyboard.press("Control+A")
    pg.keyboard.type("Elden Ring")
    pg.keyboard.press("Enter")
    assert app_names(pg, "#gamelayouts")[0] == "Elden Ring"
    pg.click(f"#gamelayouts [data-act=nameEdit][data-win='{ELDEN}']")
    pg.click("[data-act=nameAuto]")
    assert app_names(pg, "#gamelayouts")[0] == "eldenring"


def test_launcher_is_not_a_game(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    games = len(app_names(pg, "#gamelayouts"))
    pg.click("#apps [data-act=gameKind]")
    assert len(app_names(pg, "#gamelayouts")) == games - 1


def test_game_gets_its_own_layout(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    pg.select_option("[data-gamelayout='eldenring.exe']", "1")
    assert pg.evaluate("S.games.find(g => g.exe === 'eldenring.exe').ownLayout") == 1
    pg.click("[data-editlayout='game:eldenring.exe']")
    assert pg.locator("#page-zones").is_visible()
    assert pg.input_value("#layoutpick") == "game:eldenring.exe"
    assert "Elden" in pg.inner_text("#ed-title") or "eldenring" in pg.inner_text("#ed-title")


def test_game_back_to_gaming_layout(open_ui):
    pg = open_ui("?page=apps&appsws=Gaming")
    pg.select_option("[data-gamelayout='SF2Turbo.exe']", "0")      # confirm() is accepted
    assert pg.evaluate("S.games.find(g => g.exe === 'SF2Turbo.exe').ownLayout") == 0
