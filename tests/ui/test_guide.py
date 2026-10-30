"""The user guide panel beside the window (F1)."""
from helpers import script_version


def guide_frame(pg):
    pg.wait_for_function("[...document.querySelectorAll('iframe')].some(f => f.src.includes('guide.html'))")
    frame = next(f for f in pg.frames if "guide.html" in f.url)
    frame.wait_for_selector("#jump")
    return frame


def test_f1_opens_the_guide_beside_the_window(open_ui):
    pg = open_ui("?page=zones", width=1520, height=760)
    pg.keyboard.press("F1")
    pg.wait_for_function("document.querySelector('.app').classList.contains('with-guide')")
    frame = guide_frame(pg)
    assert "embed" in frame.evaluate("document.documentElement.className")
    assert script_version() in frame.inner_text(".ver")
    pg.click(".guide-head [data-act=toggleGuide]")
    assert not pg.evaluate("document.querySelector('.app').classList.contains('with-guide')")


def test_guide_follows_the_page_and_theme(open_ui):
    pg = open_ui("?page=general&theme=light", width=1520, height=760)
    pg.click(".card [data-act=toggleGuide]")
    frame = guide_frame(pg)
    frame.wait_for_function("document.documentElement.dataset.theme === 'light'")
    pg.click("[data-go=hotkeys]")
    frame.wait_for_function("document.getElementById('jump').value === 'hotkeys'")
