# Changelog

ZoneSnap is in beta: 0.x versions may still change in any way. 1.0.0 will be the first stable release.

Every build gets its own version: a new minor version (0.x.0) for new features or removals, a patch version (0.x.y) for fixes. Not every version is published on GitHub. The whole history was renumbered this way at 0.23.1; the GitHub releases v0.6.0 and v0.6.1 are 0.18.1 and 0.18.2 below.

Each version lists what was **Added**, **Changed**, **Fixed** and **Removed**.

## 0.39.2

### Fixed
- With a custom or Windows accent colour in light mode, the highlight colour (the selected page's bar, links, focus rings) and hotkey badges could be slightly too pale to read on the sidebar and page background with some colours, such as green. The highlight is now measured against the darkest surface it sits on, and key badges get their own check, so every colour reads at 4.5:1 in both themes.

## 0.39.1

### Changed
- After Update now, the notification and the note on the General page say which version you updated from: "Updated from 0.39.0 to 0.39.1".

## 0.39.0

### Added
- **Update now.** When a new version is out, ZoneSnap.exe can update itself: Update now (in the banner on the General page, or the tray menu) downloads the release's ZoneSnap.exe, checks it's the release's own file (its SHA-256 must match the one GitHub publishes, and its version must be the release's), replaces itself and restarts. If anything doesn't match, the download is deleted and nothing changes. Your settings carry over, Start with Windows keeps working, and afterwards ZoneSnap says it was updated, with a link to what's new.
- The script version, or a ZoneSnap.exe in a folder it can't save files in (like Program Files without administrator rights), still opens the release page to download it by hand.

## 0.38.1

### Changed
- **Other…** under Accent colour now opens a colour editor in the window instead of Windows' colour pop-up, which only saved once you clicked away or pressed Enter. Pick a colour on the square, the hue slider or by typing its hex code: the whole window, title bar included, previews it as you go. **Apply colour** (or Enter) keeps it, and Cancel, Esc or leaving the General page puts your colour back. If ZoneSnap deepens a colour to keep text readable, the editor says what it will be shown as.

## 0.38.0

### Added
- **Accent colour** on the General page: ZoneSnap teal (the default), your Windows accent colour, or Custom, with nine ready-made colours (teal, blue, purple, pink, red, orange, gold, green and slate) and Other… for any colour. It colours the buttons, switches, highlights, selected zones and tips, the drag highlight and dimming pin buttons on screen, and now the title bar too. ZoneSnap works out every shade from the one colour, and deepens or lightens it where needed so text stays readable in light and dark mode. Each profile has its own. Saved as `[Settings] AccentMode` (teal, windows or custom) and `AccentCustom`.

### Changed
- Accent colour replaces the **Use my Windows accent colour** switch; if it was on, Accent colour starts on Windows. A Windows accent too pale or too dark to read on is now adjusted instead of being ignored.

## 0.37.7

### Fixed
- Destiny 2 (and games like it) still went past the bottom of the screen and into the right-hand zone until you pressed Ctrl+Alt+B or switched gaming mode off and on. The game sizes its window as if its old frame were still there, so moving it back didn't last. When a game drifts out of its spot, gaming mode now does what Ctrl+Alt+B does: it gives the frame back for a moment and takes it off again, so the game notices, then puts it back in its zone.

## 0.37.6

### Changed
- While gaming mode is on, ZoneSnap now keeps each game where it put it for as long as the game runs, not just for the first 5 seconds. A game that resizes itself whenever it gets round to it (Destiny 2 after its slow start, a splash screen, a resolution change) is put back in its zone within half a second. Snapping a game to another zone, a game layout, or dropping it somewhere with Alt-drag moves its spot, so it doesn't jump back. A minimised or maximised game is left alone.
- A game that undoes this 5 times in 10 seconds is left alone until gaming mode starts again, with a notification saying so, so a game that insists on its own size doesn't flicker.

## 0.37.5

### Fixed
- The first time gaming mode took a game's title bar and frame off, the game could end up shifted down by the height of its old title bar, with its bottom edge past the bottom of the screen (Destiny 2's bottom buttons were cut off) until gaming mode was switched off and on again. ZoneSnap was placing the game before Windows had finished removing the frame, so it allowed for a border that was no longer there. Windows without a frame now go to the exact zone, Windows applies the frame change straight away, and for the first few seconds ZoneSnap puts the game back if it resizes itself. Ctrl+Alt+B applies the frame change straight away too.

## 0.37.4

### Fixed
- With the taskbar on the left or right of the screen, the game zone shrank a little along with every other zone (a 2560-wide game zone became 2528, so games opened at 2528 × 1080). The game zone now keeps its exact size and place, and only the panes between it and the taskbar get narrower: with a 48-pixel taskbar on the left, 640 | 2560 | 640 becomes 592 | 2560 | 640. Layouts without a game zone still share the space evenly.

## 0.37.3

### Changed
- The copyright holder in the licence and the .exe's file details is carson0va4. Screenshots, examples and the window's demo data use a generic "User" profile instead of real names.
- New tagline, "Window zones for ultrawide monitors, for work and play", in the README, the user guide, the .exe's file details and the social preview: ZoneSnap's workspaces suit work and streaming as much as gaming.

## 0.37.2

### Changed
- ZoneSnap's licence is now the standard MIT licence, with no restriction on selling. The parts written by others keep their own licences (see the README).

## 0.37.1

### Added
- A licence: ZoneSnap is free to use, change and share, but not to sell (MIT licence with the Commons Clause). See `LICENSE`; it's also in the script zip and the .exe's file details. The parts written by others keep their own licences.

## 0.37.0

### Added
- **Profiles:** separate setups on one Windows account, for when two people share a PC. Each profile is complete on its own, as if ZoneSnap had been installed fresh: **New profile…** runs the first-run setup, and nothing carries over. Switch from the tray's new **Profile** submenu or the new Profiles card on the General page (it switches off any workspace, puts windows back and restarts ZoneSnap on the other profile); rename or delete profiles there.
- **Whose profile is on**, shown on every page: at the top of the sidebar, under the ZoneSnap logo (click it to switch, add or manage profiles), and in the window's title bar ("ZoneSnap – User"), so it shows on the taskbar and in Alt+Tab too. With more than one profile, the tray tooltip says so as well.
- An **Undo** in the message that appears when you change a setting on the General page.

### Changed
- **Settings live in your Windows user folder:** `%APPDATA%\ZoneSnap\profiles\<profile>\ZoneSnap.ini`, so each Windows account has its own, and ZoneSnap can be installed anywhere, Program Files included. The first start moves your old `ZoneSnap.ini` into a profile named after your Windows user name and keeps the old file as `ZoneSnap.ini.old`. Import backups go in the profile's folder.
- **Every workspace is its own layout.** Your workspaces' layouts are kept with them (they use the Default layout until you save one), and a game's own layout is kept with the game: under Game layouts, choose **Its own layout**, then **Edit**. The Zones page's menu is now **Layout of**, and lists games with their own layout as *Gaming · the game*. Existing workspace and game layouts carry over.
- The General page saves each change straight away; the Save and Revert bar is gone.
- Clearer names for where an app goes: **Open, don't move** and **Don't open** in a workspace (were Don't move and Not used here); **Leave where it is** and **Put back** in the Default view.
- Slimmer workspace cards: Edit layout, Edit apps, Rename and Duplicate sit together at the bottom, Gaming's game options are grouped under Games, and rows that only pointed elsewhere are gone.
- An **Advanced** section on the General page holds the taskbar-edge margin, Open settings file and Restart as administrator.
- **Export layouts only** / **Layouts only** replace "zones only" and "zones and profiles only".
- The update check knows ZoneSnap's own repository.

### Removed
- Saved layouts (the Zones page's Profile menu with Load, Save as and Delete). Layouts a workspace or game used carry over to it; saved layouts nothing used are dropped (your settings from before the update are kept as `ZoneSnap.ini.old`).
- The GitHub repository box on the General page. (A `[Settings] UpdateRepo=owner/name` line still points the update check at a fork.)
- The choice of layout when creating a workspace: a new one starts with the Default layout.

### Fixed
- Renaming the workspace that's on no longer leaves it using the Default layout until the next switch.

## 0.36.1

### Fixed
- Installed Edge apps (Discord, Spotify) still weren't found, because Edge registers them with Windows instead of making ordinary shortcut files. ZoneSnap now finds the app in Windows' app list by its app ID and opens it the way the Start menu does (`explorer.exe shell:AppsFolder\<app ID>`). Commands with `--app=https://…` are switched over when ZoneSnap starts, and Ctrl+Alt+A no longer asks.
- If an app still can't be found, Ctrl+Alt+A shows its app ID, to help work out why.

## 0.36.0

### Fixed
- Installed web apps (Discord or Spotify installed from Edge) now open as the installed app, in their zone. A command like `msedge.exe --app=https://discord.com/app` opens the website in a new Edge window, which Windows sees as a different app, so it was never snapped. When ZoneSnap starts it swaps such commands for the installed app's own shortcut (from the Start menu, the taskbar or the desktop) when it can find it.
- Renaming a game now shows the new name under Game layouts too.

### Changed
- **Ctrl+Alt+A** on an installed web app uses the app's own shortcut, without asking. If the shortcut can't be found, it asks for the shortcut's Target instead of starting you off with `--app=https://`.

### Added
- On the Apps page, a web app that opens its website instead of the installed app says so, with a **Use the installed app** button.
- A rename button for each game under Game layouts.

## 0.35.0

### Changed
- New look, from the house style shared across the developer's apps: slate greys a shade lighter, a darker sidebar, a teal title bar (Windows 11), a muted teal for buttons and switches with a brighter teal for focus rings, the selected page and drop targets, filled secondary buttons, larger page titles and row titles, 38 px buttons and inputs, green "On" badges, teal key badges, and slim scroll bars. The user guide, the quick switcher and the drag overlays match.
- ZoneSnap's teal is now the default accent instead of your Windows accent colour.
- On a narrow page (the guide panel open), a setting's control moves under its text instead of squeezing it.

### Added
- **Use my Windows accent colour** on the General page, for buttons, switches and the drag highlight. If text on your colour wouldn't be readable, ZoneSnap keeps its teal. Saved as `[Settings] AccentFromWindows`.

### Fixed
- Text on the pin button over a dimmed pane is now dark on light accent colours, so it stays readable.

## 0.34.0

### Changed
- The Default view on the Apps page works like every other workspace: each app's menu, and the strips under the map, offer **Don't move** and **Not used in Default**. Don't move leaves the app where the other workspace left it when you come back to Default; Not used in Default (where apps start, and what "Back where it was" did) sends it back to where it was before. Existing settings keep working unchanged.
- Ctrl+Alt+A with Default on, on a window that isn't in a zone, sets it to Don't move in Default, as it does for other workspaces.

## 0.33.0

### Added
- **Rename** a workspace from its card. Its hotkey, apps and layout go with it, and a layout profile named after the workspace is renamed too (along with anything that uses it). Gaming mode keeps its name.
- **Duplicate** a workspace: a new workspace with the same options and app places and its own copy of the layout, placed just after the original. Gaming mode can be duplicated too (its layout and options, not the gaming-mode-only settings). The copy has no hotkey.
- Reorder workspaces: drag a card by the grip on its left, or focus the grip and press Up or Down. The Zones page, the Apps page, the tray's Workspaces submenu and the quick switcher use the same order. Default stays first. Saved in `[Workspaces] List`.
- **Quick switcher** (Ctrl+Alt+Space, changeable on the Hotkeys page): a small list of your workspaces at the mouse, with the active one marked. Press a number, or use the arrow keys and Enter, or click; Esc or clicking elsewhere closes it. It doesn't count as a pop-up stealing the game's focus.

## 0.32.0

### Added
- Every workspace's layout can be edited on the Zones page: the layout picker is now a **Workspace** menu listing Default, Gaming and each workspace of your own, so it works however many workspaces you have. A workspace without a layout of its own starts as a copy of Default; the first save gives it its own (a profile named after it), and Default isn't changed. Each workspace card's Layout row has an **Edit** button that opens it there.
- A **Default** card on the Workspaces page, with Switch on, its layout and its apps.

### Changed
- The Normal layout is now called **Default**, and it's treated as a workspace: the one that's on when no other is. "(no workspace)" is gone from the Zones page, the Apps page, the tray menu and the messages. (Settings keep their old section names, such as `[Zones]` and `[NormalZones]`, so nothing needs converting.)
- Workspace cards on the Workspaces page start closed, showing each workspace's name, whether it's on, and a one-line summary. Click a card to open or close it; ZoneSnap remembers which are open. A new workspace opens straight away.
- "Default" can't be used as a workspace name.

## 0.31.0

### Added
- **Add a game** on the Game layouts list (Apps page, Gaming): type a game's `.exe` name or pick a program that's running, and ZoneSnap watches for it without putting it in a zone.

### Changed
- The code is split into modules: `ZoneSnap.ahk` keeps the start-up code and the files bundled into the .exe, and the rest lives in the new `src` folder (one file per area: zones, snapping, workspaces, apps, games, cursor lock, dimming, taskbar, hotkeys, tray, theme, the ZoneSnap window, import/export, updates). Keep `src` next to `ZoneSnap.ahk` for the script version and when compiling. The compiled .exe is unchanged.
- If the ZoneSnap window can't open (WebView2 missing, or a file left out), ZoneSnap says why in a message and keeps running from the tray and its shortcuts.
- Windows always go back where they were when a workspace switches off, unless they have a Normal zone or are set to Don't move. These per-app choices replace the old switch.

### Removed
- The classic windows: the native settings window and zone editor that stood in for the ZoneSnap window, and the tray item **Use classic windows**. They no longer matched the app (no shared app list, Normal zones, Don't move or renaming).
- **Put windows back when a workspace switches off** (Workspaces page). The Apps page's Normal view and Don't move now decide this for each app.
- **Extra games to detect** (Gaming card). Use **Add a game** on the Game layouts list.
- The per-game **Borderless** switch. Gaming mode makes every game borderless; Ctrl+Alt+B does it by hand for any window.
- **Keep lit** in the tray menu. Keep a pane lit with the pin button, Ctrl+Alt+U or Ctrl+Alt+Shift+1–9.
- ZoneSnap removes the settings these used (`[Settings] Interface` and `RestorePlaces`, the `[Borderless]` section) when it starts. Games listed under Extra games stay games.

## 0.30.0

### Added
- One app list for every workspace. Every app you add appears in every workspace's list on the Apps page. For each workspace, choose a zone, **Don't move** or **Not used here**, from the zone menu or by dragging the app onto a zone or one of the strips under the map. Names and commands are shared, and Remove takes an app off the list everywhere. Saved under `[Apps]` in ZoneSnap.ini.

### Changed
- Ctrl+Alt+A puts an app on the shared list and, with a workspace on, places it in that workspace; with none on, it gets its Normal zone.
- Existing apps, and 0.29.0's `[NormalApps]`, are moved onto the shared list when ZoneSnap starts.

### Fixed
- Adding Steam saved the command of its web helper (`steamwebhelper.exe`), which doesn't open Steam. ZoneSnap now saves `steam.exe`, names the app Steam, and repairs commands saved before.

## 0.29.0

### Changed
- Ctrl+Alt+A with no workspace on adds the app to the Normal layout only (into the Normal zone it's in) instead of to gaming mode. To add an app to gaming mode, press Ctrl+Alt+A with gaming mode on. Saved under `[NormalApps]` (replaced by `[Apps]` in 0.30.0).
- The Apps page opens on the Normal view instead of Gaming.

### Fixed
- After saving a name or command, or confirming a remove, on the Apps page, the edit box could stay open.

## 0.28.0

### Added
- **Don't move**: set an app's zone on the Apps page to Don't move (or drag it into the dashed strip under the map). The workspace opens the app if it isn't running but never moves its window, and doesn't put it back afterwards.

### Changed
- Ctrl+Alt+A on a window that isn't in a zone adds it as Don't move, instead of refusing.

### Fixed
- An app added with Ctrl+Alt+A didn't appear on the Apps page until ZoneSnap was restarted.

## 0.27.1

### Added
- **Not a game?** / **Treat as a game** next to an app in the game zone, and on the Game layouts list, to decide for any program. Saved as `NotGames=` under `[GamingMode]`; a launcher you mark as a game goes into `Games=`.

### Fixed
- A game launcher added in the game zone (Steam, for example) was treated as a game, so auto gaming mode started whenever it was open and gaming mode made it borderless. Launchers and stores (Steam, Epic Games Launcher, Battle.net, GOG Galaxy, EA app, Ubisoft Connect, Riot Client, Xbox app and others) are now ordinary apps wherever they are.

## 0.27.0

### Added
- Rename apps: the Rename button on an app's row gives it your own name, shown wherever ZoneSnap lists it. **Reset** goes back to the automatic name. Saved under `[AppNames]`.
- The Normal view on the Apps page can edit how an app opens and remove it. Both apply to every workspace that has the app, and each row shows which workspaces those are.

### Changed
- A browser web app whose app ID doesn't name its site (a Firefox web app showing as "5e79188c", say) is named after its window title when you add it with Ctrl+Alt+A.

## 0.26.0

### Added
- Choose where apps go on the Normal layout: pick **Normal (no workspace)** on the Apps page and drag each app into a Normal zone, or pick it from the list. When a workspace such as gaming mode switches off, those apps go to their Normal zone and the rest go back where they were. Drag an app into the "Back where it was" strip to unplace it. With no workspace on, a change moves the window straight away. Saved under `[NormalZones]`.

## 0.25.0

### Added
- Back up and share settings (General page): export everything, or only the zones and profiles to share a layout. Import shows what a file holds before anything changes, saves your current settings as "ZoneSnap backup <date>.ini" first, and brings in everything (ZoneSnap restarts) or only the zones and profiles. A full import warns about app commands in the file, since they run when a workspace switches on; a zones-only import never brings in apps.

## 0.24.0

### Added
- 70 / 30 preset: a big zone (the game zone) on the left and a pane on the right, sized to the monitor (2688 | 1152 on a 3840-wide screen).
- Theme setting on the General page: System (follow Windows, as before), Light or Dark. It covers the ZoneSnap window, the user guide panel and the tray menu.

## 0.23.1

### Changed
- The update check says when a repository can't be found (for example because it's private).
- Tidied the code, the README and the user guide.

### Fixed
- The Zones page didn't show which zone is the Gaming layout's game zone (since 0.18.0).
- Turning a running workspace's Auto-hide the taskbar switch on or off didn't take effect until the workspace was switched off and on again.
- Reset shortcuts to defaults could leave a workspace and a default shortcut on the same key. A workspace using a default key now loses it, and ZoneSnap says so.
- The startup tip and the welcome message always said "Alt+drag", even with a different drag key.
- In a maximised window, opening the guide panel left the Zones and Apps pages' monitor pictures too wide.

## 0.23.0

### Added
- Gaming mode makes games borderless: while it's on, every game you've added loses its title bar and frame and fills the game zone, and gets its frame back when gaming mode switches off. **Make games borderless** on the Gaming card turns this off.

### Changed
- The per-game Borderless switch (Apps → Game layouts) means borderless all the time, even outside gaming mode. (Removed in 0.31.0.)

## 0.22.0

### Added
- Windows go back where they were: when a workspace (such as gaming mode) switches off and you're back on the Normal layout, its apps return to the zone or spot they were in before it switched on. Apps it opened move to the Normal zone covering their spot.
- Apps page map: the workspace's zones with each app in its zone. Drag an app onto another zone to move it there; if the workspace is on, its window moves too.

## 0.21.0

### Added
- The user guide opens in a panel beside the ZoneSnap window (F1, the sidebar's User guide button, or the tray menu), so you can read it while you use the app. It follows the page you're on, and **Show in app** opens the page a section describes. It can still open in your web browser.

## 0.20.0

### Added
- User guide: a full guide to every feature, with screenshots, shipped with ZoneSnap (`guide.html`, bundled into the .exe).
- A Help and advanced section on the General page that opens the guide.

### Changed
- The cursor margin setting is now called "Keep the cursor off the taskbar edge".

## 0.19.0

### Added
- Rebindable shortcuts: the Hotkeys page changes any keyboard shortcut (click Change and press the keys), clears one, or goes back to the defaults. ZoneSnap warns about keys already in use and keys Windows keeps for itself. Workspaces can have any key, not just Ctrl+Alt+F1–F9.
- Taskbar edge detection. A taskbar on the left or right is left showing (no auto-hide) and needs no cursor margin; one at the top gets its margin at the top.

## 0.18.4

### Fixed
- A pop-up taking focus mid-game (a Steam message, a notification, Windows handing focus to the taskbar) freed the cursor and could bring the taskbar up under your next click. With the cursor locked, ZoneSnap gives focus straight back to the game unless you left it yourself (Windows key, Alt+Tab, Ctrl+Esc, Ctrl+Alt+F). The game's own dialogs are let through, and so is a window that keeps taking focus.
- A game that replaces its launcher window in the game zone now takes over the cursor lock.

## 0.18.3

### Fixed
- An app flashing for attention (a Steam message, say) brought the auto-hidden taskbar up mid-game. While a workspace auto-hides the taskbar, ZoneSnap stops those flashes so the taskbar stays down.

## 0.18.2

*Published on GitHub as v0.6.1.*

### Changed
- If ZoneSnap has to fall back to its classic windows, it says why.

### Fixed
- The compiled ZoneSnap.exe only showed the classic windows: its interface files weren't bundled into the .exe.

## 0.18.1

*Published on GitHub as v0.6.0, the first public beta.*

### Fixed
- The update check skipped GitHub pre-releases, so it couldn't find beta versions.

## 0.18.0

### Added
- Workspaces: saved setups (layout, apps, taskbar auto-hide, cursor lock, dimming, game zone, hotkey) switched on from the Workspaces page, a Ctrl+Alt+F1–F9 hotkey or the tray. Gaming mode is the built-in Gaming workspace; auto gaming returns to the previous workspace when the game closes.
- A setting for what happens to the previous workspace's apps when switching: leave open, minimise or close.
- Update check: a daily check of the GitHub repository's latest release, with a tray item, a banner in the ZoneSnap window, Check now and Skip this version.

### Changed
- The Apps page edits any workspace's apps; Ctrl+Alt+A adds to the active workspace.
- Cursor and dimming settings moved to the General page.

## 0.17.0

### Added
- Force borderless: a per-game switch (Apps → Game layouts) that removes a windowed game's title bar and frame and snaps it into the game zone whenever it opens, re-applying it if the game restores its borders.

## 0.16.1

### Fixed
- ZoneSnap failed to start with "Unexpected Else" (per-game layout code).

## 0.16.0

### Added
- Multi-monitor support: zones are saved per monitor, follow a monitor that moves, scale with resolution changes and survive unplugging.
- Plugging, unplugging and rearranging monitors is detected and zones refit.
- The zone editor shows your monitor arrangement, and presets fit the selected monitor.
- Halves preset.
- First run gives each extra monitor one zone.

### Changed
- The freed cursor is kept off every monitor's bottom edge.

## 0.15.0

### Added
- Per-game layouts: give a game its own profile, used when gaming mode starts with that game running.
- Profiles remember their game zone.

## 0.14.0

### Added
- The ZoneSnap window (WebView2): a visual drag-to-resize zone editor plus settings, apps and hotkeys pages, falling back to the classic windows when it can't run.

### Changed
- Friendlier names for web app windows.

## 0.13.1

### Fixed
- Windows didn't refit when the taskbar came back on leaving gaming mode (a regression from 0.11.1). Snapped windows now follow their own zone in either layout.

## 0.13.0

### Added
- First run builds a starting layout from the primary monitor's shape (side | game | side on an ultrawide, halves otherwise) and opens the settings window with a welcome.

## 0.12.0

### Added
- ZoneSnap icon, and version details for the compiled .exe.
- Settings window (General, Gaming mode, Apps, Hotkeys), replacing the Hotkeys window.

### Changed
- Follows Windows light or dark mode and your accent colour; rounded, inset drag overlays.

## 0.11.1

### Fixed
- Tooltips vanished early.
- Alt+drag and Ctrl+Alt+F acted on ZoneSnap's own windows.
- Switching gaming mode kept per-zone state from the other layout, and could be interrupted halfway.

## 0.11.0

### Added
- A pin button on a dimmed pane when you hover over it, to keep that pane lit.
- Keep lit submenu in the tray (removed in 0.31.0), and a Hotkeys window listing every shortcut.

## 0.10.0

### Added
- Keep-lit panes: Ctrl+Alt+U keeps the pane under the mouse lit; Ctrl+Alt+Shift+1–9 keeps a zone lit.

## 0.9.2

### Fixed
- The Equal thirds preset set every zone's Y to the zone width, placing windows off-screen.

## 0.9.1

### Fixed
- It wasn't clear which layout was active. The zone editor, tray menu and tooltip now show it, the editor warns about unsaved changes, the Save button names its layout, and Ctrl+Alt+number explains a missing zone.

## 0.9.0

### Added
- Side | 4:3 | Side preset for classic and retro games.

## 0.8.0

### Added
- Zone profiles (save, load, delete), aspect ratios on the preset buttons, a Revert button, and a prompt before unsaved edits are replaced.

## 0.7.0

### Added
- Zone editor presets sized from the primary monitor's resolution: ultrawide (21:9) and 16:9 game in the middle, plus equal thirds.

## 0.6.0

### Added
- Start with Windows (tray toggle).

## 0.5.0

### Added
- Auto gaming mode: on when a game starts, off when it closes.

## 0.4.0

### Added
- Taskbar-aware zones: zones fit above a showing taskbar and use the full screen when it's hidden, and snapped windows refit when it shows or hides.

## 0.3.0

### Added
- Cursor lock: once the game loses focus (Windows key, Alt+Tab) the cursor stays free until you click back into the game.
- Ctrl+Alt+F frees the cursor and moves to a side pane; press again to return.

### Changed
- Faster lock against games that confine the cursor themselves.

## 0.2.2

### Fixed
- Gaming mode didn't put browser app windows (Discord, Spotify as Edge apps) into their zones. They're now identified by their Windows app ID, and launched apps are held in their zones while they open.

## 0.2.1

### Fixed
- With cursor lock on, moving the mouse to the bottom of the screen brought up the auto-hidden taskbar. The cursor is now kept a couple of pixels off the bottom edge.

## 0.2.0

### Added
- Gaming mode (Ctrl+Alt+G): Gaming layout, taskbar auto-hide, opens and snaps side apps.
- Cursor lock (Ctrl+Alt+L) and side-pane dimming (Ctrl+Alt+D).
- Ctrl+Alt+A adds the active window to gaming mode's app list.

## 0.1.0

### Added
- First version: zones, Alt+drag snapping (including borderless games), Ctrl+Alt+1–9, zone editor, borderless toggle (Ctrl+Alt+B).
