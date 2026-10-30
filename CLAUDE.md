# Working on ZoneSnap

Notes for Claude sessions working in this repository (people: see README.md).

## Git

- **Never commit to `main`.** Each change gets its own branch from an up-to-date `main`
  (`feature/<name>`, `fix/<name>` or `docs/<name>`) with its version bump, CHANGELOG section and
  docs, then a pull request into `main`. Merge it yourself with **squash and merge** once Checks
  and Build pass, then delete the branch; if the owner asks to hold a change for review, leave
  the pull request for them. The owner's house style (section 9) is the full rule.
- **Don't sign commits or tags.** Before the first commit in a session run
  `git config commit.gpgsign false && git config tag.gpgsign false`. Commits are authored as the
  repo owner, and a signature from a session key shows as "Unverified" on GitHub.
- **Author commits with the owner's private GitHub email**, never a personal address (the repo is
  public): `git config user.name carson0va4 && git config user.email 217738864+carson0va4@users.noreply.github.com`.
- Dependabot opens pull requests for updates to the workflow's actions and `tools/requirements.txt`;
  the owner merges them.
- Releases are drafted by running the Build workflow on `main` with **Draft a release** ticked,
  only when the owner asks. The owner decides which versions are published.

## Every change

- Every build gets the next version: minor (0.x.0) for features or removals, patch (0.x.y)
  for fixes. No beta suffixes. Bump `ZS_VERSION` and `;@Ahk2Exe-SetVersion` in `ZoneSnap.ahk`
  and `version:` in `ui.html`'s demo data.
- Licence: the standard MIT licence (`LICENSE`, kept as the exact standard text so GitHub
  recognises it). Keep it in the script zip, and keep the third-party licences in `Lib`.
- Keep the docs current with every change: `CHANGELOG.md` (`## [X.Y.Z] - YYYY-MM-DD`, then Added / Changed / Fixed / Removed),
  `README.md`, the user guide (`docs/guide/guide.src.html`), then `python tools/screenshots.py`
  to retake the pictures and rebuild `guide.html`. Don't edit `guide.html` by hand.
- Run `python tests/static_check.py` and `python -m pytest tests` before pushing the branch
  (setup: `tests/README.md`), so CI isn't spent on mistakes found locally.
- No real names in anything public: screenshots, demo data, examples and tests use generic names
  ("User", "User 2"); the copyright holder is carson0va4.
- The window's look follows the owner's house style (teal title bar, slate greys, two teals:
  `--accent` for fills, `--guide-accent` for focus rings and indicators), with the house token names.
  The accent rules (`accent.js`), the picker (`colour-editor.js`) and its CSS are pasted into
  `ui.html` unchanged from the house style: change them there first, then paste them in again.

## AutoHotkey v2 gotchas

- Names are case-insensitive: a local named like a global (`zones` vs `Zones`) hides it.
- A one-line `try`/`for`/`loop`/`while` straight before `else` takes the else.
- `FileInstall` lines must start the line and stay in `ZoneSnap.ahk`, or Ahk2Exe leaves the
  file out of the .exe.
