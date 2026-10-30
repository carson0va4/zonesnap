"""Build guide.html (the user guide that ships with ZoneSnap) from docs/guide/guide.src.html:
inline the WebP screenshots and fill in the version from ZoneSnap.ahk.

Usage (from anywhere):  python tools/build_guide.py [output path]   (default: guide.html)
"""
import base64
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
GUIDE = ROOT / "docs" / "guide"


def version():
    m = re.search(r'ZS_VERSION\s*:=\s*"([^"]+)"', (ROOT / "ZoneSnap.ahk").read_text(encoding="utf-8"))
    return m.group(1)


def build():
    src = (GUIDE / "guide.src.html").read_text(encoding="utf-8")

    def img(m):
        data = (GUIDE / (m.group(1) + ".webp")).read_bytes()
        return "data:image/webp;base64," + base64.b64encode(data).decode()

    out = re.sub(r"\{\{img:([a-z_]+)\}\}", img, src).replace("{{VERSION}}", version())
    assert "{{" not in out, "unfilled placeholder in guide.src.html"
    return out


if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "guide.html"
    html = build()
    dest.write_text(html, encoding="utf-8", newline="\n")
    print(f"wrote {dest} ({len(html):,} bytes, version {version()})")
