; ============================================================================
;  ZoneSnap - Games
;  Games: what counts as a game (launchers don't), auto gaming mode, per-game
;  layouts, and making games borderless in gaming mode.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Auto gaming mode: Gaming switches on when a game starts and, if it was switched on
; automatically, back to whatever was active before when the game closes.
; Edge-triggered, so toggling by hand while a game runs isn't overridden.
; ---------------------------------------------------------------------------
AutoTick() {
    global AutoStarted, PrevGameRunning, PrevWS
    running := AutoOn && GameRunning()
    if running && !PrevGameRunning && !GamingOn {
        PrevWS := ActiveWS
        SwitchWorkspace("Gaming")
        AutoStarted := true
        Notify("Game detected - gaming mode ON")
    } else if !running && PrevGameRunning && GamingOn && AutoStarted {
        SwitchWorkspace(HasValue(WSList(), PrevWS) ? PrevWS : "")
        Notify(PrevWS = "" ? "Game closed - gaming mode OFF" : "Game closed - back to " PrevWS)
    }
    PrevGameRunning := running
}

GameRunning() {
    for exe in GameExes()
        if ProcessExist(exe)
            return true
    return false
}

; Games = the Games= list, plus any app entry in the game zone that's matched by .exe
; (except game launchers and apps you've said aren't games)
GameExes() {
    list := CsvList(IniRead(IniFile, "GamingMode", "Games", ""))
    gz := GSInt("GameZone", 2)
    for app in ReadApps("Gaming")
        if IsGameApp(gz, app.zone, app.win)
            list.Push(ExeOf(app.win))
    return list
}

; Game launchers and stores. They often sit in the game zone, but they run all the time, so
; treating them as games would start auto gaming mode whenever they're open and make them
; borderless. "Treat as a game" on the Apps page overrides this (it adds them to Games=).
Launchers() {
    static list := ["steam.exe", "steamwebhelper.exe", "epicgameslauncher.exe", "battle.net.exe",
    "galaxyclient.exe", "eadesktop.exe", "origin.exe", "upc.exe", "ubisoftconnect.exe",
    "riotclientservices.exe", "riotclientux.exe", "xboxpcapp.exe", "amazon games ui.exe",
    "heroic.exe", "itch.exe", "playnite.desktopapp.exe", "playnite.fullscreenapp.exe",
    "rockstarlauncher.exe", "battlestate games launcher.exe"]
    return list
}

; The program name in an "ahk_exe name.exe" window match, or "" for any other match
ExeOf(match) => RegExMatch(match, "i)^ahk_exe\s+(.+\.exe)$", &m) ? Trim(m[1]) : ""

; Is this program not a game? Your own word on the Apps page wins, then the launcher list.
NotAGame(exe) {
    if HasValue(CsvList(IniRead(IniFile, "GamingMode", "Games", "")), exe)
        return false
    if HasValue(CsvList(IniRead(IniFile, "GamingMode", "NotGames", "")), exe)
        return true
    return HasValue(Launchers(), exe)
}

; An app entry is a game when it sits in the workspace's game zone (gz), is matched by its
; .exe, and isn't a launcher or something you've said isn't a game
IsGameApp(gz, zone, match) {
    exe := ExeOf(match)
    return gz >= 1 && zone = gz && exe != "" && !NotAGame(exe)
}

; Apps page: "Not a game" / "Treat as a game" for a program
SetGameKind(exe, isGame) {
    exe := Trim(exe)
    if !(exe ~= 'i)^[^\\/:*?"<>|,]+\.exe$')
        return
    games := CsvList(IniRead(IniFile, "GamingMode", "Games", ""))
    notGames := CsvList(IniRead(IniFile, "GamingMode", "NotGames", ""))
    drop(arr) {
        out := []
        for s in arr
            if s != exe                     ; (case-insensitive, like Windows file names)
                out.Push(s)
        return out
    }
    games := drop(games), notGames := drop(notGames)
    if isGame {
        if HasValue(Launchers(), exe)
            games.Push(exe)                 ; a launcher only counts as a game when you say so
    } else {
        notGames.Push(exe)
        if ProcessExist(exe) && GamingOn && GameMainWindow(exe)
            RestoreGameFrames()             ; give it its frame back if gaming mode took it
    }
    IniWrite CsvJoin(games), IniFile, "GamingMode", "Games"
    if notGames.Length
        IniWrite CsvJoin(notGames), IniFile, "GamingMode", "NotGames"
    else
        try IniDelete IniFile, "GamingMode", "NotGames"
    SyncAppList()                   ; a game that's now an app joins the shared list
}

; Apps page, Game layouts -> Add a game: detect this program as a game without snapping it
; anywhere (it goes into [GamingMode] Games=)
AddGame(exe) {
    exe := Trim(exe)
    if !(exe ~= 'i)^[^\\/:*?"<>|,]+\.exe$')
        return "That isn't a program name - it should end in .exe"
    if HasValue(GameExes(), exe)
        return exe " is already a game"
    notGames := CsvList(IniRead(IniFile, "GamingMode", "NotGames", "")), keep := []
    for x in notGames
        if x != exe
            keep.Push(x)
    if keep.Length
        IniWrite CsvJoin(keep), IniFile, "GamingMode", "NotGames"
    else
        try IniDelete IniFile, "GamingMode", "NotGames"
    games := CsvList(IniRead(IniFile, "GamingMode", "Games", ""))
    if !HasValue(games, exe)
        games.Push(exe)
    IniWrite CsvJoin(games), IniFile, "GamingMode", "Games"
    return ""
}

; Programs with a window open now (for Add a game's suggestions), ZoneSnap and Windows' own left out
RunningPrograms() {
    static skip := ["explorer.exe", "applicationframehost.exe", "textinputhost.exe", "shellexperiencehost.exe",
        "searchhost.exe", "startmenuexperiencehost.exe", "systemsettings.exe", "lockapp.exe", "autohotkey64.exe",
        "autohotkey32.exe", "autohotkey.exe", "msedgewebview2.exe"]
    out := [], seen := Map()
    seen.CaseSense := false
    for hwnd in WinGetList() {
        try {
            if !(WinGetStyle(hwnd) & 0x10000000) || WinGetTitle(hwnd) = ""
                continue
            exe := WinGetProcessName(hwnd)
        } catch
            continue
        if seen.Has(exe) || HasValue(skip, exe) || exe = A_ScriptName
            continue
        seen[exe] := 1
        out.Push(exe)
    }
    return out
}

; ---------------------------------------------------------------------------
; Per-game layouts: [GameZones:<game.exe>] (see Zones.ahk)
; ---------------------------------------------------------------------------
; The first running game with its own layout ("" = use the Gaming layout)
RunningGameLayout() {
    for exe in GameExes()
        if ProcessExist(exe) && ReadZones(GameLayoutSection(exe)).Length
            return exe
    return ""
}

; A game's name as you see it: what you renamed it to, else its program without .exe
GameName(exe) {
    label := AppLabel("ahk_exe " exe)
    return label != "" ? label : RegExReplace(exe, "i)\.exe$")
}

; Give a game its own layout (a copy of the Gaming layout to start from), or take it away
SetGameOwnLayout(exe, own) {
    exe := Trim(exe)
    if exe = "" || exe ~= "[\[\]=\r\n]"
        return
    sec := GameLayoutSection(exe)
    if !own {
        try IniDelete IniFile, sec
    } else if !ReadZones(sec).Length {
        SaveZones(ReadZones("GamingZones"), sec)
        IniWrite GSInt("GameZone", 2), IniFile, sec, "GameZone"
    }
    if GamingOn                                 ; gaming mode is on: use (or stop using) it now
        RefreshGameLayout()
}

; Gaming mode is on and a game's layout was added, removed or saved: use the right one now
RefreshGameLayout() {
    global GamingOverride
    GamingOverride := GamingOn ? RunningGameLayout() : ""
    ReloadZonesLive()
}

; Game zone of a layout section: the one saved with it, else its largest zone
LayoutGameZone(sec, list) {
    g := IniRead(IniFile, sec, "GameZone", "")
    if IsInteger(g) && g >= 1 && g <= list.Length
        return Integer(g)
    best := 1, bestArea := 0
    for i, z in list
        if z.w * z.h > bestArea
            best := i, bestArea := z.w * z.h
    return best
}

; An app's zone number refers to the Gaming layout. With a game's own layout active, send the
; game to that layout's game zone and other apps to the zone covering their usual spot.
MapAppZone(n) {
    if GamingOverride = ""
        return n
    if n = GSInt("GameZone", 2)
        return GameZoneN
    usual := ReadZones("GamingZones")
    if n < 1 || n > usual.Length
        return n
    spot := usual[n], best := 0, bestArea := -1
    for i, z in RawZones {
        if i = GameZoneN
            continue
        ow := Min(spot.x + spot.w, z.x + z.w) - Max(spot.x, z.x)
        oh := Min(spot.y + spot.h, z.y + z.h) - Max(spot.y, z.y)
        area := (ow > 0 && oh > 0) ? ow * oh : 0
        if area > bestArea
            best := i, bestArea := area
    }
    return best ? best : n
}

ToggleAuto() {
    global AutoOn
    AutoOn := !AutoOn
    IniWrite AutoOn ? 1 : 0, IniFile, "GamingMode", "AutoGaming"
    Notify("Auto gaming mode " (AutoOn ? "ON" : "OFF"))
    UpdateTray()
}

; ---------------------------------------------------------------------------
; Borderless games (like the Borderless Gaming app). While gaming mode is on (and
; [GamingMode] AutoBorderless=1), every game ZoneSnap knows has its title bar and frame
; removed and is snapped into the game zone. If the game puts its borders back (after a
; resolution change or alt-tab), it is stripped and snapped again, and if it resizes itself
; it is put back where it was (KeepGameHome). Games get their frame
; back when gaming mode switches off. (Ctrl+Alt+B does the same for any window, by hand.) The game itself must be in windowed mode;
; nothing outside a game can change exclusive fullscreen.
; ---------------------------------------------------------------------------
BorderlessTick() {
    if Dragging
        return
    for hwnd in BorderlessDone.Clone()          ; forget closed windows
        if !WinExist(hwnd)
            BorderlessDone.Delete(hwnd)
    for hwnd in GameHomes.Clone()
        if !WinExist(hwnd)
            GameHomes.Delete(hwnd)
    if !GamingOn || !GSInt("AutoBorderless", 1)
        return
    for exe in GameExes() {
        if !ProcessExist(exe)
            continue
        hwnd := GameMainWindow(exe)
        if !hwnd
            continue
        try {
            if WinGetMinMax(hwnd) = -1
                continue
            framed := WinGetStyle(hwnd) & 0xC40000          ; caption or sizing border
        } catch
            continue
        if framed || !BorderlessDone.Has(hwnd) {
            ; remember its frame, to give it back when gaming mode switches off
            ; (not a frame ZoneSnap gave back itself, to remind the game it's gone: ReframeGame)
            if framed && !GamingFrames.Has(hwnd) && !GameHomes.Has(hwnd)
                try GamingFrames[hwnd] := {style: WinGetStyle(hwnd) & 0xC40000, ex: WinGetExStyle(hwnd) & 0x20301}
            MakeBorderless(hwnd, GameHomes.Has(hwnd) ? GameHomes[hwnd].z : GameZoneRect())
            BorderlessDone[hwnd] := true
        }
        KeepGameHome(hwnd, exe)
    }
}

; Games often resize themselves after losing their frame, at a splash screen, after loading or
; after a resolution change, however long that takes. Some (Destiny 2) still size their window
; as if the frame were there - their size plus the old border - so they spill past the bottom
; of the screen and into the next zone, and simply moving them back doesn't last. What works is
; what Ctrl+Alt+B does by hand: give the frame back for a moment, then take it off again, so
; the game notices it has gone (ReframeGame). While gaming mode is on, a game that has moved off
; the spot ZoneSnap gave it is reframed and put back. A game that undoes it 5 times in 10
; seconds is left alone until gaming mode starts again, so one that insists doesn't flicker.
KeepGameHome(hwnd, exe) {
    if !GameHomes.Has(hwnd) {
        GameHomes[hwnd] := {z: GameZoneRect(), fixes: [], gaveUp: false}
        return
    }
    home := GameHomes[hwnd]
    try {
        if home.gaveUp || WinGetMinMax(hwnd) != 0        ; minimised or maximised: left as it is
            return
    } catch
        return
    if AtRect(hwnd, home.z)
        return
    now := A_TickCount, recent := []
    for t in home.fixes
        if now - t < 10000
            recent.Push(t)
    home.fixes := recent
    if recent.Length >= 4 {
        home.gaveUp := true
        TrayTip GameName(exe) " keeps changing its own size, so ZoneSnap has stopped putting it back in the game zone. Switch gaming mode off and on to try again.", "ZoneSnap", 1
        return
    }
    home.fixes.Push(now)
    ReframeGame(hwnd, home.z)
}

; Gives a borderless game its frame back in its spot; on the next tick (half a second later)
; BorderlessTick sees the frame and takes it off again, which the game does notice
ReframeGame(hwnd, z) {
    try WinSetStyle "+0xC40000", hwnd
    catch
        return
    FrameChanged(hwnd)
    MoveToRect(hwnd, z)
}

; A game dragged with Alt (or Shift) and dropped outside a zone stays where you dropped it
KeepGameHere(hwnd) {
    if !GameHomes.Has(hwnd)
        return
    try {
        WinGetPos &x, &y, &w, &h, hwnd
        GameHomes[hwnd].z := {x: x, y: y, w: w, h: h}
    }
}

; Gaming mode switched off: games it made borderless get their title bar and frame back
RestoreGameFrames() {
    for hwnd, f in GamingFrames {
        if !WinExist(hwnd)
            continue
        try {
            WinSetStyle "+" f.style, hwnd
            WinSetExStyle "+" f.ex, hwnd
            WinGetPos &x, &y, &w, &h, hwnd
            WinMove x, y, w, h, hwnd             ; redraw with the frame
        }
        if BorderlessDone.Has(hwnd)
            BorderlessDone.Delete(hwnd)
    }
    GamingFrames.Clear()
    GameHomes.Clear()                            ; a fresh start next time (and for games it gave up on)
}

; The game's main window: its largest visible, top-level, non-tool window
GameMainWindow(exe) {
    best := 0, bestArea := 0
    try ids := WinGetList("ahk_exe " exe)
    catch
        return 0
    for hwnd in ids {
        try {
            if !(WinGetStyle(hwnd) & 0x10000000)                 ; WS_VISIBLE
                continue
            if WinGetExStyle(hwnd) & 0x80                         ; tool window
                continue
            if DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")    ; owned (a dialog or popup)
                continue
            WinGetPos , , &ww, &wh, hwnd
        } catch
            continue
        if ww >= 320 && wh >= 200 && ww * wh > bestArea
            best := hwnd, bestArea := ww * wh
    }
    return best
}

MakeBorderless(hwnd, z := "") {
    try {
        if WinGetMinMax(hwnd) = 1
            WinRestore hwnd
        WinSetStyle "-0xC40000", hwnd               ; caption + sizing frame
        WinSetExStyle "-0x20301", hwnd              ; dialog, window, client and static edges
    } catch
        return
    FrameChanged(hwnd)
    MoveToRect(hwnd, z = "" ? GameZoneRect() : z)
}

; Makes Windows apply a style change to the frame straight away (SWP_FRAMECHANGED, without
; moving, sizing, reordering or activating), so the window's size is worked out without it
FrameChanged(hwnd) {
    try DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x37)
}

; True when the window's rect is the rect z (to a pixel)
AtRect(hwnd, z) {
    try {
        WinGetPos &x, &y, &w, &h, hwnd
        return Abs(x - z.x) <= 1 && Abs(y - z.y) <= 1 && Abs(w - z.w) <= 1 && Abs(h - z.h) <= 1
    } catch
        return true
}

; Where a borderless game goes: the game zone of the active layout while gaming mode is
; on, otherwise the Gaming layout's game zone (so it's ready for when gaming mode starts)
GameZoneRect() {
    if ActiveWS != "" && GameZoneN && GameZoneN <= Zones.Length
        return Zones[GameZoneN]
    list := ReadZones("GamingZones")
    n := GSInt("GameZone", 2)
    if n >= 1 && n <= list.Length
        return FitZones([list[n]], list[n])[1]
    MonitorGetWorkArea MonitorGetPrimary(), &wl, &wt, &wr, &wb
    return {x: wl, y: wt, w: wr - wl, h: wb - wt}
}

ToggleBorderless(hwnd) {
    if !hwnd
        return
    try {
        if WinGetStyle(hwnd) & 0xC00000          ; has caption
            WinSetStyle "-0xC40000", hwnd        ; remove caption + sizing border
        else
            WinSetStyle "+0xC40000", hwnd
        FrameChanged(hwnd)
        WinGetPos &x, &y, &w, &h, hwnd
    } catch
        return
    if z := ZoneAt(x + w // 2, y + h // 2)
        SnapTo(hwnd, z)
}
