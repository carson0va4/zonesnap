"""Every page opens cleanly, in both themes, and shows the right version."""
import pytest

from helpers import script_version

PAGES = ["zones", "workspaces", "apps", "general", "hotkeys"]


@pytest.mark.parametrize("theme", ["dark", "light"])
@pytest.mark.parametrize("page", PAGES)
def test_page_opens(open_ui, page, theme):
    pg = open_ui(f"?page={page}&wsopen=all" + ("&theme=light" if theme == "light" else ""))
    assert pg.locator(f"#page-{page}").is_visible()
    assert pg.get_attribute("html", "data-theme") == theme
    # no page wider than the window (the setting rows wrap instead)
    assert pg.evaluate("document.documentElement.scrollWidth <= innerWidth")


def test_nav_switches_pages(open_ui):
    pg = open_ui("?page=zones")
    for page in PAGES:
        pg.click(f"[data-go={page}]")
        assert pg.locator(f"#page-{page}").is_visible()
        assert pg.get_attribute(f"[data-go={page}]", "aria-current") == "page"


def test_version_matches_script(open_ui):
    pg = open_ui()
    assert f"ZoneSnap {script_version()}" in pg.inner_text("#ver")


def test_narrow_window(open_ui):
    pg = open_ui("?page=general", width=760, height=700)
    assert pg.evaluate("document.documentElement.scrollWidth <= innerWidth")


def test_welcome_and_update_banner(open_ui):
    pg = open_ui("?page=general&welcome=1&update=1")
    assert "3840" in pg.inner_text("#page-general")
    assert "is available" in pg.inner_text("#update-banner")
