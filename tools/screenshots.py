"""Retake every screenshot from ui.html's demo mode, then rebuild guide.html.

  docs/screenshots/*.png   the README's pictures
  docs/guide/*.webp        the user guide's pictures (inlined into guide.html)
  docs/social-preview.png  the picture GitHub shows when the repository's link is shared
                           (upload it in the repository's Settings -> Social preview)

Usage: python tools/screenshots.py      (needs: pip install -r tools/requirements.txt,
                                          then python -m playwright install chromium)
Run it after any change to how the window looks, so the pictures match the build.
"""
import base64
import io
import pathlib
import re
import subprocess
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[1]
UI = (ROOT / "ui.html").as_uri()
README_SHOTS = ROOT / "docs" / "screenshots"
GUIDE_SHOTS = ROOT / "docs" / "guide"


def page(browser, query, width=1100, height=720):
    pg = browser.new_page(viewport={"width": width, "height": height})
    pg.goto(UI + query)
    pg.wait_for_function("typeof S !== 'undefined' && S && S.workspaces")
    pg.wait_for_timeout(250)
    return pg


def webp(pg, name, **clip):
    png = pg.screenshot(clip=clip) if clip else pg.screenshot()
    Image.open(io.BytesIO(png)).save(GUIDE_SHOTS / f"{name}.webp", quality=82, method=6)


# 1280 x 640, GitHub's social preview size: name, what it does, and the Zones page
SOCIAL = """<!doctype html><html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; margin: 0; }
  body { width: 1280px; height: 640px; overflow: hidden; background: #12171E; color: #E6EAEF;
    font-family: "Segoe UI", "Inter", system-ui, sans-serif; display: flex; align-items: center; gap: 48px; padding: 0 0 0 72px; }
  .txt { width: 440px; flex-shrink: 0; }
  .brand { display: flex; align-items: center; gap: 16px; font-size: 54px; font-weight: 700; letter-spacing: -.01em; }
  .tag { margin-top: 22px; font-size: 27px; line-height: 1.35; color: #C9D1DB; }
  .pills { margin-top: 28px; display: flex; flex-wrap: wrap; gap: 10px; }
  .pills span { padding: 7px 14px; border-radius: 999px; border: 1px solid #29323D; background: #1A212A; font-size: 18px; color: #95A0AE; }
  .shot { flex: 1; height: 520px; border-radius: 18px 0 0 18px; overflow: hidden; border: 1px solid #29323D; border-right: 0;
    box-shadow: 0 24px 60px rgba(0,0,0,.45); background: url(data:image/png;base64,SHOT) left top / auto 100% no-repeat; }
  .bar { height: 6px; background: linear-gradient(90deg, #437784, #3CC5B0); position: fixed; left: 0; right: 0; bottom: 0; }
</style></head><body>
  <div class="txt">
    <div class="brand">LOGO ZoneSnap</div>
    <div class="tag">Window zones for ultrawide monitors, for work and play.</div>
    <div class="pills"><span>Workspaces</span><span>Gaming mode</span><span>Cursor lock</span><span>Game layouts</span></div>
  </div>
  <div class="shot"></div><div class="bar"></div>
</body></html>"""


def social_preview(browser):
    ui = (ROOT / "ui.html").read_text(encoding="utf-8")
    logo = re.search(r'<div class="brand">\s*(<svg.*?</svg>)', ui, re.S).group(1)
    logo = logo.replace('width="28" height="28"', 'width="64" height="64"').replace("var(--accent-ink)", "#FFFFFF").replace("var(--accent)", "#437784")
    shot = base64.b64encode((README_SHOTS / "zone-editor.png").read_bytes()).decode()
    pg = browser.new_page(viewport={"width": 1280, "height": 640})
    pg.set_content(SOCIAL.replace("LOGO", logo).replace("SHOT", shot))
    pg.wait_for_timeout(200)
    pg.screenshot(path=ROOT / "docs" / "social-preview.png")


def main():
    README_SHOTS.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--allow-file-access-from-files"])

        # README
        pg = page(b, "?page=zones")
        pg.select_option("#layoutpick", "Gaming")
        pg.wait_for_timeout(200)
        pg.screenshot(path=README_SHOTS / "zone-editor.png")
        pg = page(b, "?page=workspaces&wsopen=Gaming")
        pg.evaluate("document.querySelector('#page-workspaces .scroll').scrollTop = document.querySelector('.ws-card').offsetTop - 20")
        pg.wait_for_timeout(100)
        pg.screenshot(path=README_SHOTS / "workspaces.png")
        page(b, "?page=general", height=1010).screenshot(path=README_SHOTS / "general.png")
        pg = page(b, "?page=apps&appsws=Gaming", width=1520, height=760)
        pg.keyboard.press("F1")
        pg.wait_for_timeout(1200)
        pg.screenshot(path=README_SHOTS / "guide-panel.png")

        # user guide
        for name, query in [("zones", "?page=zones&layout=Gaming"), ("workspaces", "?page=workspaces&wsopen=Gaming"),
                            ("apps", "?page=apps&appsws=Gaming"), ("general", "?page=general"),
                            ("welcome", "?page=general&welcome=1")]:
            webp(page(b, query), name)
        pg = page(b, "?page=apps")
        pg.select_option("#appsws", "__normal")
        pg.wait_for_timeout(250)
        webp(pg, "apps_normal", x=210, y=0, width=890, height=560)
        pg = page(b, "?page=hotkeys")
        pg.click("[data-hkrec=Lock]")
        pg.wait_for_timeout(100)
        webp(pg, "hotkeys_rec", x=210, y=0, width=890, height=420)
        social_preview(b)
        b.close()

    subprocess.run([sys.executable, str(ROOT / "tools" / "build_guide.py")], check=True)


if __name__ == "__main__":
    main()
