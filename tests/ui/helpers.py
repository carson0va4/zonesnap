"""Helpers for the window tests."""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
UI = (ROOT / "ui.html").as_uri()


def script_version():
    """ZS_VERSION from ZoneSnap.ahk"""
    m = re.search(r'ZS_VERSION\s*:=\s*"([^"]+)"', (ROOT / "ZoneSnap.ahk").read_text(encoding="utf-8"))
    return m.group(1)


def app_names(pg, scope="#apps"):
    """Names in the Apps page list (or another list), in order"""
    return pg.evaluate("s => [...document.querySelectorAll(s + ' .nm')].map(n => n.firstChild.textContent.trim())", scope)


def map_chips(pg):
    """{zone: [app names]} on the Apps page map; zone "0" is Don't move, "-1" Not used here"""
    return pg.evaluate("""() => {
        const out = {};
        for (const c of document.querySelectorAll('#appmap-card [data-chip]')) {
            const z = c.closest('[data-dropzone]').dataset.dropzone;
            (out[z] = out[z] || []).push(c.querySelector('.nm').textContent.trim());
        }
        return out;
    }""")
