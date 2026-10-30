; ============================================================================
;  ZoneSnap - Zones
;  Zones: how they're stored per monitor, fitted to the taskbar and the screen,
;  refitted when monitors change, and which layout section each workspace and game uses.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Zone storage. Each zone is saved relative to its monitor:
;     ZoneN=x,y,w,h,DISPLAYn,monitorWidth,monitorHeight   (x,y from the monitor's corner)
; so zones follow a monitor that moves, scale with a resolution change, and land
; on a same-sized (or the main) monitor while theirs is unplugged - keeping their
; original placement for when it's back. Older lines (x,y,w,h on the desktop) still load.
; Everything else in ZoneSnap works with desktop coordinates, resolved here.
; ---------------------------------------------------------------------------
ReadZones(section) {
    list := []
    count := IniRead(IniFile, section, "Count", 0)
    count := IsInteger(count) ? Integer(count) : 0
    mons := MonitorList()
    Loop count {
        line := IniRead(IniFile, section, "Zone" A_Index, "")
        p := StrSplit(line, ",", " ")
        if p.Length < 4 || !IsInteger(p[1]) || !IsInteger(p[2]) || !IsInteger(p[3]) || !IsInteger(p[4])
            continue
        if p.Length >= 7 && IsInteger(p[6]) && IsInteger(p[7]) && p[6] > 0 && p[7] > 0
            list.Push(ResolveZone(line, p, mons))
        else
            list.Push({x: Integer(p[1]), y: Integer(p[2]), w: Integer(p[3]), h: Integer(p[4])})
    }
    return list
}

ResolveZone(line, p, mons) {
    global ZoneOrigin
    monName := p[5], mw := Integer(p[6]), mh := Integer(p[7])
    m := 0
    for mon in mons                         ; 1. the same monitor
        if mon.name = monName {
            m := mon
            break
        }
    if !m
        for mon in mons                     ; 2. a monitor the same size
            if mon.w = mw && mon.h = mh {
                m := mon
                break
            }
    if !m
        for mon in mons                     ; 3. the main monitor
            if mon.primary {
                m := mon
                break
            }
    if !m
        m := mons[1]
    sx := m.w / mw, sy := m.h / mh
    z := {x: m.l + Round(Integer(p[1]) * sx), y: m.t + Round(Integer(p[2]) * sy),
          w: Round(Integer(p[3]) * sx), h: Round(Integer(p[4]) * sy)}
    if m.name != monName || m.w != mw || m.h != mh
        ZoneOrigin[z.x "," z.y "," z.w "," z.h] := line     ; stand-in placement: keep the original
    return z
}

SaveZones(list, section) {
    try IniDelete IniFile, section
    IniWrite list.Length, IniFile, section, "Count"
    mons := MonitorList()
    for i, z in list
        IniWrite ZoneLine(z, mons), IniFile, section, "Zone" i
}

ZoneLine(z, mons) {
    key := z.x "," z.y "," z.w "," z.h
    if ZoneOrigin.Has(key)                   ; unchanged zone of a monitor that isn't plugged in
        return ZoneOrigin[key]
    m := MonitorForRect(z, mons)
    return (z.x - m.l) "," (z.y - m.t) "," z.w "," z.h "," m.name "," m.w "," m.h
}

; Monitors: name (DISPLAYn), bounds, size, main or not - in Windows' order
MonitorList() {
    mons := [], prim := MonitorGetPrimary()
    Loop MonitorGetCount() {
        MonitorGet A_Index, &ml, &mt, &mr, &mb
        try monName := RegExReplace(MonitorGetName(A_Index), "^\\\\\.\\")
        catch
            monName := "DISPLAY" A_Index
        mons.Push({n: A_Index, name: monName, l: ml, t: mt, r: mr, b: mb, w: mr - ml, h: mb - mt, primary: A_Index = prim})
    }
    return mons
}

; The monitor holding a rectangle's centre, else the one it overlaps most, else the main one
MonitorForRect(z, mons) {
    cx := z.x + z.w // 2, cy := z.y + z.h // 2
    best := 0, bestArea := 0
    for m in mons {
        if cx >= m.l && cx < m.r && cy >= m.t && cy < m.b
            return m
        ow := Min(z.x + z.w, m.r) - Max(z.x, m.l), oh := Min(z.y + z.h, m.b) - Max(z.y, m.t)
        if ow > 0 && oh > 0 && ow * oh > bestArea
            best := m, bestArea := ow * oh
    }
    if best
        return best
    for m in mons
        if m.primary
            return m
    return mons[1]
}

MonitorKey() {
    key := ""
    for m in MonitorList()
        key .= m.name ":" m.l "," m.t "," m.r "," m.b ";"
    return key
}

; Monitors plugged in, unplugged, rearranged or resized: re-read every zone for the new layout
OnMonitorsChanged() {
    global LastMonKey, LastWA
    LastMonKey := MonitorKey()
    LastWA := WorkAreaKey()
    ZoneOrigin.Clear()          ; re-worked out as zones are read for the new arrangement
    Snapped.Clear()             ; old positions mean nothing on the new arrangement
    ReloadZonesLive()
    Notify("Monitors changed - zones updated")
}

LoadConfig() {
    global Zones, RawZones, DragKey, GameZoneN, LockMargin, GameRaw
    ; (GamingOverride: read only)
    DragKey := IniRead(IniFile, "Settings", "DragHotkey", "!LButton")
    RawZones := ReadZones(ActiveLayout)
    if !RawZones.Length && ActiveLayout != "Zones"
        RawZones := ReadZones("Zones")
    gameZones := []
    if ActiveLayout = "GamingZones" && GamingOverride != "" {
        gameZones := ReadZones(GameLayoutSection(GamingOverride))
        if gameZones.Length
            RawZones := gameZones
    }
    n := IniRead(IniFile, "GamingMode", "GameZone", 2)
    if ActiveWS != "" && ActiveWS != "Gaming"
        n := WSOpt(ActiveWS, "GameZone")
    if gameZones.Length
        n := LayoutGameZone(GameLayoutSection(GamingOverride), gameZones)
    GameZoneN := (IsInteger(n) && n >= 1 && n <= RawZones.Length) ? Integer(n) : 0
    GameRaw := GameZoneN ? RawZones[GameZoneN] : ""      ; (before fitting: it keeps its size)
    Zones := FitZones(RawZones)
    LockMargin := Max(0, GSInt("LockBottomMargin", 2))
}

; ---------------------------------------------------------------------------
; Taskbar-aware zones
;   Zones are defined in full-screen pixels (RawZones). The live Zones are those
;   rectangles mapped onto each monitor's usable area (screen minus a visible taskbar).
;   With a game zone on the monitor that the taskbar doesn't cover, the game zone keeps
;   its exact size and place, and only the zones between it and the taskbar give up the
;   taskbar's space (a 48 px taskbar on the left: 640 | 2560 | 640 becomes 592 | 2560 | 640).
;   Otherwise every zone shares the loss proportionally, so a stack of zones stays even.
;   game: the saved game zone to keep ("" = none); by default the active layout's (GameRaw).
; ---------------------------------------------------------------------------
FitZones(list, game := "active") {
    if !IsObject(game) && game = "active"
        game := GameRaw
    out := []
    for z in list {
        m := MonitorAt(z.x + z.w // 2, z.y + z.h // 2)
        if !m {
            out.Push({x: z.x, y: z.y, w: z.w, h: z.h})
            continue
        }
        MonitorGet m, &ml, &mt, &mr, &mb
        MonitorGetWorkArea m, &wl, &wt, &wr, &wb
        g := IsObject(game) && MonitorAt(game.x + game.w // 2, game.y + game.h // 2) = m ? game : ""
        x1 := FitAxis(z.x, ml, mr, wl, wr, g ? g.x : "", g ? g.w : 0)
        x2 := FitAxis(z.x + z.w, ml, mr, wl, wr, g ? g.x : "", g ? g.w : 0)
        y1 := FitAxis(z.y, mt, mb, wt, wb, g ? g.y : "", g ? g.h : 0)
        y2 := FitAxis(z.y + z.h, mt, mb, wt, wb, g ? g.y : "", g ? g.h : 0)
        out.Push({x: x1, y: y1, w: x2 - x1, h: y2 - y1})
    }
    return out
}

; One coordinate from the monitor's span (lo..hi) onto its usable span (ulo..uhi). gs, gl:
; the game zone's start and length on this axis ("" = no game zone). If the game zone fits
; inside the usable span, it stays put and the stretch on each side of it shrinks instead.
FitAxis(v, lo, hi, ulo, uhi, gs, gl) {
    if gs != "" && (ulo > lo || uhi < hi) && gs >= ulo && gs + gl <= uhi {
        ge := gs + gl
        if v <= gs
            return gs = lo ? v : Round(ulo + (v - lo) * (gs - ulo) / (gs - lo))
        if v >= ge
            return ge = hi ? v : Round(ge + (v - ge) * (uhi - ge) / (hi - ge))
        return v
    }
    return Round(ulo + (v - lo) * (uhi - ulo) / (hi - lo))
}

MonitorAt(x, y) {
    Loop MonitorGetCount() {
        MonitorGet A_Index, &l, &t, &r, &b
        if x >= l && x < r && y >= t && y < b
            return A_Index
    }
    return 0
}

WorkAreaKey() {
    key := ""
    Loop MonitorGetCount() {
        MonitorGetWorkArea A_Index, &l, &t, &r, &b
        key .= l "," t "," r "," b ";"
    }
    return key
}

; The usable area changed (taskbar shown/hidden): refit zones and put windows back.
OnWorkAreaChange() {
    global Zones, LastWA
    LastWA := WorkAreaKey()
    old := Zones
    Zones := FitZones(RawZones)
    BuildOverlays()
    if DimOn
        BuildDim()
    moved := []
    for hwnd, rz in Snapped.Clone() {
        if !WinExist(hwnd) {
            Snapped.Delete(hwnd)
            continue
        }
        ; only windows still roughly in their zone - if you moved one elsewhere, leave it
        try WinGetPos &x, &y, &w, &h, hwnd
        catch
            continue
        cx := x + w // 2, cy := y + h // 2
        if cx >= rz.x - 50 && cx < rz.x + rz.w + 50 && cy >= rz.y - 80 && cy < rz.y + rz.h + 80 {
            ; refit to its own zone's rectangle for the new usable area, whichever layout is active
            MoveToRect(hwnd, FitZones([rz])[1])
            moved.Push(hwnd)
        } else
            Snapped.Delete(hwnd)
    }
    ; Windows and apps (Edge windows especially) shuffle windows again a moment after the
    ; taskbar changes - check twice more
    SetTimer () => ReSnapList(moved), -700
    SetTimer () => ReSnapList(moved), -1600
}

ReSnapList(list) {
    for hwnd in list {
        if !WinExist(hwnd) || !Snapped.Has(hwnd)
            continue
        target := FitZones([Snapped[hwnd]])[1]
        if !FitsRect(hwnd, target)
            MoveToRect(hwnd, target)
    }
}

; ---------------------------------------------------------------------------
; Layout sections. Every workspace is its own layout:
;     [Zones]              Default
;     [GamingZones]        Gaming (its game zone: [GamingMode] GameZone)
;     [WSZones:<name>]     a workspace of your own (its game zone: [Workspace:<name>] GameZone).
;                          Until it's saved once, the workspace uses the Default layout.
;     [GameZones:<exe>]    a game's own layout, used instead of Gaming's while that game runs
;                          (its game zone: GameZone in the same section)
; ---------------------------------------------------------------------------
GameLayoutSection(exe) => "GameZones:" exe

; Before 0.37.0, layouts could also be saved under a name ([Profile:<name>]) and picked by a
; workspace ([Workspace:<name>] Layout=) or a game ([GameProfiles] game.exe=). Each workspace
; and game now keeps its own copy; saved layouts nothing used are dropped (the settings file
; from before the update is kept as a backup).
MigrateLayouts() {
    for ws in WSList() {
        if ws = "Gaming"
            continue
        prof := Trim(IniRead(IniFile, WSSection(ws), "Layout", ""))
        if prof != "" && !ReadZones("WSZones:" ws).Length && ReadZones("Profile:" prof).Length
            CopySection("Profile:" prof, "WSZones:" ws, ["GameZone"])
        try IniDelete IniFile, WSSection(ws), "Layout"
    }
    try games := IniRead(IniFile, "GameProfiles")
    catch
        games := ""
    for line in StrSplit(games, "`n", "`r") {
        if !(eq := InStr(line, "="))
            continue
        exe := Trim(SubStr(line, 1, eq - 1)), prof := Trim(SubStr(line, eq + 1))
        if exe = "" || exe ~= "[\[\]=]" || ReadZones(GameLayoutSection(exe)).Length
            continue
        if (list := ReadZones("Profile:" prof)).Length {
            CopySection("Profile:" prof, GameLayoutSection(exe), ["GameZone"])
            IniWrite LayoutGameZone("Profile:" prof, list), IniFile, GameLayoutSection(exe), "GameZone"
        }
    }
    try IniDelete IniFile, "GameProfiles"
    for sec in IniSections(IniFile)
        if SubStr(sec, 1, 8) = "Profile:"
            try IniDelete IniFile, sec
}

SameZones(a, b) {
    if a.Length != b.Length
        return false
    for i, z in a
        if z.x != b[i].x || z.y != b[i].y || z.w != b[i].w || z.h != b[i].h
            return false
    return true
}

CopyZones(list) {
    out := []
    for z in list
        out.Push({x: z.x, y: z.y, w: z.w, h: z.h})
    return out
}

; Standard ultrawide (21:9-class) game width for a screen height, e.g. 1080 -> 2560, 1440 -> 3440
UltraWidth(h) {
    static known := Map(1080, 2560, 1200, 2880, 1440, 3440, 1600, 3840, 2160, 5120)
    return known.Has(h) ? known[h] : Round(h * 64 / 27 / 2) * 2
}

; Standard 16:9 game width for a screen height, e.g. 1080 -> 1920, 1440 -> 2560
WideWidth(h) => Round(h * 16 / 9 / 2) * 2
