; ============================================================================
;  ZoneSnap - Workspaces
;  Workspaces and gaming mode: switching on and off, opening apps, and putting
;  windows back (or into their Normal zones) afterwards.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Workspaces. A workspace is a saved setup switched on with one hotkey: a layout, apps
; to open and snap, and options (auto-hide taskbar, cursor lock, dimming, game zone).
; "Gaming" is the built-in one (sections [GamingMode] + [GamingZones]); it is gaming
; mode, and the one auto gaming mode starts. Others live in [Workspace:<name>] with
; GameZone, AutoHideTaskbar, LockCursor, DimSides, Hotkey and AppN entries, and their layout
; in [WSZones:<name>] (see Zones.ahk). One workspace is active at a time; none = Default.
; ---------------------------------------------------------------------------
; Workspaces in your order ([Workspaces] List, names separated by |). Gaming is always
; there: where you've put it, or first.
WSList() {
    list := [], hasGaming := false
    for nm in StrSplit(IniRead(IniFile, "Workspaces", "List", ""), "|") {
        nm := Trim(nm)
        if nm = "Gaming" && !hasGaming
            list.Push(nm), hasGaming := true
        else if nm != "Gaming" && ValidWSName(nm) && !HasValue(list, nm)
            list.Push(nm)
    }
    if !hasGaming
        list.InsertAt(1, "Gaming")
    return list
}

; Save the workspace list in this order
SaveWSOrder(list) {
    names := ""
    for nm in list
        names .= (names = "" ? "" : "|") nm
    IniWrite names, IniFile, "Workspaces", "List"
}

; Copy a settings section (all its keys) to another, leaving out the keys in skip
CopySection(from, to, skip := []) {
    try text := IniRead(IniFile, from)
    catch
        return
    out := ""
    for line in StrSplit(text, "`n", "`r")
        if (eq := InStr(line, "=")) && !HasValue(skip, Trim(SubStr(line, 1, eq - 1)))
            out .= line "`n"
    if out != ""
        IniWrite RTrim(out, "`n"), IniFile, to
}

; Workspaces page: rename a workspace of your own; its layout goes with it
RenameWorkspace(old, new) {
    global ActiveWS, PrevWS, ActiveLayout
    new := Trim(new)
    if old = "Gaming" || !HasValue(WSList(), old)
        return "Gaming mode's name can't be changed"
    if !ValidWSName(new) || new = "Gaming"
        return "Please use a name up to 40 characters, without [ ] | or =, other than Default or Gaming"
    if new != old && HasValue(WSList(), new)
        return "There's already a workspace called " new
    if new == old
        return ""
    sameName := new = old                       ; only the capitals change: same section
    if !sameName {
        for pair in [[WSSection(old), WSSection(new)], ["WSZones:" old, "WSZones:" new]] {
            CopySection(pair[1], pair[2])
            try IniDelete IniFile, pair[1]
        }
    }
    list := WSList()                    ; (the old name has no section now, but is still listed)
    for i, nm in list
        if nm = old
            list[i] := new
    SaveWSOrder(list)
    if ActiveWS = old {
        ActiveWS := new
        ActiveLayout := WSLayoutSection(new)        ; its layout section was renamed too
    }
    if PrevWS = old
        PrevWS := new
    RegisterWSHotkeys()
    UpdateTray()
    return ""
}

; Workspaces page: a new workspace that starts as a copy of another (its options, its app
; places and its own copy of the layout; not its hotkey). Copying Gaming copies its
; layout and options, not the gaming-mode-only settings.
DuplicateWorkspace(src, new) {
    new := Trim(new)
    if !HasValue(WSList(), src)
        return "That workspace doesn't exist"
    if !ValidWSName(new) || new = "Gaming"
        return "Please use a name up to 40 characters, without [ ] | or =, other than Default or Gaming"
    if HasValue(WSList(), new)
        return "There's already a workspace called " new
    sec := WSSection(new)
    if src = "Gaming" {
        for key in ["GameZone", "AutoHideTaskbar", "LockCursor", "DimSides"]
            IniWrite WSOpt("Gaming", key), IniFile, sec, key
        Loop 30
            if (v := IniRead(IniFile, WSSection(src), "App" A_Index, "")) != ""
                IniWrite v, IniFile, sec, "App" A_Index
        layout := "GamingZones"
    } else {
        CopySection(WSSection(src), sec, ["Hotkey"])
        layout := WSLayoutSection(src)
    }
    if (copied := ReadZones(layout)).Length
        SaveZones(copied, "WSZones:" new)
    list := WSList()
    for i, nm in list
        if nm = src {
            list.InsertAt(i + 1, new)
            break
        }
    SaveWSOrder(list)
    UpdateTray()
    return ""
}

; Workspaces page: put the workspaces in this order (names not given keep their place at the end)
OrderWorkspaces(names) {
    have := WSList(), list := []
    for nm in names
        if HasValue(have, nm) && !HasValue(list, nm)
            list.Push(nm)
    for nm in have
        if !HasValue(list, nm)
            list.Push(nm)
    SaveWSOrder(list)
    UpdateTray()
}

ValidWSName(nm) => nm != "" && StrLen(nm) <= 40 && !(nm ~= "[\[\]|=\r\n]") && nm != "Normal" && nm != "Default"   ; (the built-in names)

WSSection(ws) => ws = "Gaming" ? "GamingMode" : "Workspace:" ws

; Layout section a workspace uses (one of your own uses Default's until it has its own)
WSLayoutSection(ws) {
    if ws = "Gaming"
        return "GamingZones"
    if ws = ""
        return "Zones"
    return ReadZones("WSZones:" ws).Length ? "WSZones:" ws : "Zones"
}

; A workspace option as a number. Gaming keeps its old defaults (all on, game zone 2);
; other workspaces start with everything off and no game zone.
WSOpt(ws, key) {
    def := ws = "Gaming" ? (key = "GameZone" ? 2 : 1) : 0
    v := IniRead(IniFile, WSSection(ws), key, def)
    return IsInteger(v) ? Integer(v) : def
}

ToggleGaming() => SwitchWorkspace(ActiveWS = "Gaming" ? "" : "Gaming")

ToggleWorkspace(ws, *) => SwitchWorkspace(ActiveWS = ws ? "" : ws)

; Switch to workspace ws ("" = none: back to the Normal layout)
SwitchWorkspace(ws) {
    global GamingOn, ActiveLayout, PrevAutoHide, AutoStarted, GamingOverride, ActiveWS
    if ws != "" && !HasValue(WSList(), ws)
        return
    old := ActiveWS
    if ws = old
        return
    Critical            ; finish the whole switch before any timer runs
    AutoStarted := false        ; AutoTick sets it again if it was the one switching on
    newHide := ws != "" && WSOpt(ws, "AutoHideTaskbar") && !TaskbarOnSide()
    if old = "Gaming"
        RestoreGameFrames()
    if old != "" {
        if ws != ""
            ApplySwitchPolicy(old, ws)
        Pending.Length := 0
        SetLock(false)
        SetDim(false)
        if !newHide
            ApplyAutoHide(false)        ; your own taskbar setting back
    }
    LitZones.Clear()        ; pinned panes are by zone number, which means something else in another layout
    if old = "" && ws != ""
        RememberPlaces(ws)      ; leaving Normal: note where the workspace's apps are now
    ActiveWS := ws
    GamingOn := ws = "Gaming"
    GamingOverride := GamingOn ? RunningGameLayout() : ""      ; the running game's own layout, if it has one
    ActiveLayout := ws = "" ? "Zones" : WSLayoutSection(ws)
    LoadConfig()
    BuildOverlays()
    if ws != "" {
        if newHide
            ApplyAutoHide(true)
        for app in ReadApps(ws) {
            if GamingOn
                app.zone := MapAppZone(app.zone)        ; same spot in the game's own layout
            LaunchApp(app)
        }
        if WSOpt(ws, "LockCursor") && GameZoneN
            SetLock(true)
        if WSOpt(ws, "DimSides")
            SetDim(true)
        else if DimOn
            BuildDim()
        Notify((GamingOn ? "Gaming mode ON" : ws " workspace ON") (GamingOverride != "" ? " - " GameName(GamingOverride) "'s layout" : ""))
    } else {
        ActiveLayout := "Zones"
        RestorePlaces(old)      ; back to Normal: windows go back where they were
        Notify((old = "Gaming" ? "Gaming mode OFF" : old " workspace OFF") " - back to Default")
    }
    UpdateTray()
}

; ---------------------------------------------------------------------------
; Putting windows back. When a workspace switches on from Normal, ZoneSnap notes where each
; of its apps' windows is (its zone, or its exact spot if it wasn't in one; maximised or
; minimised). When you go back to Normal, apps with a Normal zone (Apps page, Normal view)
; go there and the rest return to where they were. Apps the workspace opened itself move to
; the Normal zone covering their spot. Games and Don't move apps are left alone.
; ---------------------------------------------------------------------------
RememberPlaces(ws) {
    global Before := Map()
    gz := WSOpt(ws, "GameZone")
    for app in ReadApps(ws) {
        if app.zone < 1 || IsGameApp(gz, app.zone, app.win) || !(hwnd := FindWin(app.win)) || Before.Has(hwnd)
            continue
        r := VisibleRect(hwnd)
        if !IsObject(r)
            continue
        try mm := WinGetMinMax(hwnd)
        catch
            continue
        Before[hwnd] := {rect: r, mm: mm, raw: Snapped.Has(hwnd) ? CopyZones([Snapped[hwnd]])[1] : ""}
    }
}

RestorePlaces(oldWS) {
    global Before
    places := Before
    Before := Map()
    ; apps you've given a Normal zone (Apps page, Normal view) go there; the rest go back
    placed := ApplyNormalZones()
    for hwnd in placed
        if places.Has(hwnd)
            places.Delete(hwnd)
    PutBack(places, true)
    ; apps the workspace opened (not open before): into the Normal zone covering their spot
    gz := WSOpt(oldWS, "GameZone")
    for app in ReadApps(oldWS) {
        if app.zone < 1 || IsGameApp(gz, app.zone, app.win) || !(hwnd := FindWin(app.win)) || places.Has(hwnd) || placed.Has(hwnd) || !Snapped.Has(hwnd)
            continue
        r := VisibleRect(hwnd)
        if IsObject(r) && (z := ZoneAt(r.x + r.w // 2, r.y + r.h // 2))
            SnapTo(hwnd, z)
    }
    ; windows (Edge especially) can shuffle again as the taskbar comes back - check once more
    SetTimer () => PutBack(places, false), -900
}

; ---------------------------------------------------------------------------
; Normal zones: where an app goes on the Normal layout, set on the Apps page (Normal).
; [NormalZones] <window match>=<zone>, e.g. "ahk_exe Discord.exe=1". Used when a workspace
; switches off, and straight away if you change one while no workspace is on.
; ---------------------------------------------------------------------------
NormalZones() {
    out := Map()
    try sec := IniRead(IniFile, "NormalZones")
    catch
        return out
    for line in StrSplit(sec, "`n", "`r") {
        eq := InStr(line, "=", , -1)          ; the last "=" (matches never contain one)
        if !eq
            continue
        z := Trim(SubStr(line, eq + 1))
        if IsInteger(z) && Integer(z) >= 0          ; 0 = Don't move
            out[Trim(SubStr(line, 1, eq - 1))] := Integer(z)
    }
    return out
}

; Back on Default: snap every open app that has a Default zone into it (the Default layout
; must be loaded). Apps set to Don't move (0) are left where they are. Returns the windows
; it dealt with, so they aren't also put back. Apps with no entry are "not used in Default":
; they go back where they were before the workspace switched on.
ApplyNormalZones() {
    placed := Map()
    for match, z in NormalZones() {
        if z > Zones.Length || !(hwnd := FindWin(match))
            continue
        if z = 0 {
            placed[hwnd] := 1
            continue
        }
        try {
            if WinGetMinMax(hwnd) = -1
                continue
        }
        SnapTo(hwnd, z)
        placed[hwnd] := 1
    }
    return placed
}

PutBack(places, first) {
    for hwnd, b in places {
        if !WinExist(hwnd)
            continue
        try {
            if b.raw != "" {
                Snapped[hwnd] := b.raw
                target := FitZones([b.raw])[1]
            } else {
                if Snapped.Has(hwnd)
                    Snapped.Delete(hwnd)
                target := b.rect
            }
            if b.mm = 1 {
                if first {
                    MoveToRect(hwnd, target)        ; maximise on the monitor it was on
                    WinMaximize hwnd
                }
                continue
            }
            if !FitsRect(hwnd, target)
                MoveToRect(hwnd, target)
            if b.mm = -1 && first
                WinMinimize hwnd
        }
    }
}

; The window's visible rectangle {x, y, w, h} (without Windows' invisible borders), or ""
VisibleRect(hwnd) {
    rect := Buffer(16, 0)
    try {
        if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", rect, "uint", 16) {
            WinGetPos &x, &y, &w, &h, hwnd
            return {x: x, y: y, w: w, h: h}
        }
    } catch
        return ""
    l := NumGet(rect, 0, "int"), t := NumGet(rect, 4, "int")
    return {x: l, y: t, w: NumGet(rect, 8, "int") - l, h: NumGet(rect, 12, "int") - t}
}

; Leaving one workspace for another: leave, minimise or close the apps the old one opened
; ([Settings] WorkspaceSwitch=leave|minimise|close). Only apps it launches (ones with a
; command) are touched, never ones the new workspace also uses, and never games.
ApplySwitchPolicy(oldWS, newWS) {
    policy := IniRead(IniFile, "Settings", "WorkspaceSwitch", "leave")
    if policy != "minimise" && policy != "close"
        return
    keep := Map()
    for app in ReadApps(newWS)
        keep[app.win] := 1
    for app in ReadApps(oldWS) {
        if app.cmd = "" || keep.Has(app.win)
            continue
        for hwnd in AppWindows(app.win) {
            if policy = "close" {
                try WinClose hwnd
            } else {
                try WinMinimize hwnd
            }
        }
    }
}

; Every top-level window matching an app entry (ahk_exe ... or appid:...)
AppWindows(match) {
    out := []
    if SubStr(match, 1, 6) = "appid:" {
        want := SubStr(match, 7)
        for hwnd in WinGetList() {
            id := GetAppId(hwnd)
            if id != "" && InStr(id, want)
                out.Push(hwnd)
        }
        return out
    }
    try {
        for hwnd in WinGetList(match)
            if !IsOwnWindow(hwnd)
                out.Push(hwnd)
    }
    return out
}

; Zone 0 = "Don't move": opened if it isn't running, but never snapped
LaunchApp(app) {
    if app.zone < 0 || app.zone > Zones.Length
        return
    if !FindWin(app.win) && app.cmd != "" {
        cmd := ExpandEnv(app.cmd)
        dir := ""
        if RegExMatch(cmd, '^"([^"]+)"', &m)
            SplitPath m[1], , &dir
        try Run cmd, dir
        catch {
            Notify("Couldn't launch: " app.cmd)
            return
        }
    }
    ; Watch for the window for up to 3 minutes (slow launchers); snap it, and follow any
    ; splash -> main window switch. Once found, it's held in its zone for 12 seconds.
    if app.zone >= 1
        Pending.Push({win: app.win, zone: app.zone, last: 0, found: 0, until: A_TickCount + 180000})
}

; Hide the taskbar for the running workspace (remembering your own setting), or give your
; setting back
ApplyAutoHide(hide) {
    global PrevAutoHide
    if hide && PrevAutoHide = -1 {
        PrevAutoHide := GetTaskbarAutoHide()
        SetTaskbarAutoHide(true)
    } else if !hide && PrevAutoHide != -1 {
        SetTaskbarAutoHide(PrevAutoHide)
        PrevAutoHide := -1
    }
}
