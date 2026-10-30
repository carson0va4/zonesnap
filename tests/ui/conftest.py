"""Shared set-up for the window tests.

ui.html opened in a browser (not inside ZoneSnap) runs on built-in demo data, and its messages
to the script are answered by a small fake in the page, so these tests drive the real page
without Windows. Demo options in the address: ?page=, ?appsws=, ?wsopen=all|Name,
?theme=light, ?layout=, ?taskbar=left, ?welcome=1, ?update=1 (?update=script: the script version), ?updated=1.

Every test fails if the page logs an error or throws.
"""
import pytest
from playwright.sync_api import sync_playwright

from helpers import UI


@pytest.fixture(scope="session")
def browser():
    with sync_playwright() as p:
        # file access lets the guide panel load guide.html next to ui.html
        b = p.chromium.launch(args=["--allow-file-access-from-files"])
        yield b
        b.close()


@pytest.fixture
def open_ui(browser):
    """open_ui("?page=apps", width=1100, height=900) -> a page showing ui.html"""
    pages, errors = [], []

    def _open(query="", width=1100, height=900):
        pg = browser.new_page(viewport={"width": width, "height": height})
        pg.on("pageerror", lambda e: errors.append(str(e)))
        pg.on("console", lambda m: m.type == "error" and errors.append(m.text))
        pg.on("dialog", lambda d: d.accept())
        pg.goto(UI + query)
        pg.wait_for_function("typeof S !== 'undefined' && S && S.workspaces")
        pages.append(pg)
        return pg

    yield _open
    for pg in pages:
        pg.close()
    assert not errors, "The page logged errors: " + " | ".join(errors)
