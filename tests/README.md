# Tests

Everything here runs on Linux, macOS or Windows, and on every push (the **Checks** job in
`.github/workflows/build.yml`). The **Build** job then compiles ZoneSnap.exe on Windows.

| What | Checks |
| --- | --- |
| `static_check.py` | The AutoHotkey code: brackets, a name spelled two ways in one function, locals hiding globals, an `else` caught by a one-line `try`/`for`/`loop`/`while`, `FileInstall` not at the start of its line, calls to functions that don't exist |
| `test_repo.py` | One version everywhere (script, .exe info, ui.html, changelog), every `src` module included, `guide.html` built from its current source, bundled files and images present |
| `ui/` | The ZoneSnap window (`ui.html`) in a real browser, on its demo data: every page in both themes, the app list, renaming, zones and Don't move, the Default view, games, workspaces, hotkeys and the guide panel. Any error the page logs fails the test |

What they can't check: anything that needs Windows itself (moving windows, the taskbar, the
cursor lock, launching apps). The Windows build checks the script loads and compiles; the rest
is tested by hand.

## Running them

    pip install -r tools/requirements.txt
    python -m playwright install chromium
    python tests/static_check.py
    python -m pytest tests
