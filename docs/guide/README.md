# User guide source

`guide.html` in the repository root is built from these files and ships with ZoneSnap
(bundled into the .exe). ZoneSnap shows it in a side panel as `guide.html?embed=1`: in that
mode it hides the contents sidebar, shows a section picker and Show in app buttons, and talks
to `ui.html` with postMessage (see the script at the end of `guide.src.html` and the user guide
panel section of `ui.html`).

- `guide.src.html`: the guide, with `{{img:name}}` and `{{VERSION}}` placeholders.
- `*.webp`: pictures of the ZoneSnap window, inlined into the built page. `tools/screenshots.py`
  retakes them.

To rebuild after editing (the version comes from `ZoneSnap.ahk`):

    python tools/build_guide.py

The tests fail if `guide.html` doesn't match its source.
