; ============================================================================
;  ZoneSnap - Cursor
;  Cursor lock, freeing the cursor, the focus guard, and the main 100 ms timer (Tick).
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Cursor lock
; ---------------------------------------------------------------------------
SetLock(on) {
    global LockOn, FreeMode, GameHwnd
    LockOn := on
    FreeMode := false
    GameHwnd := 0
    SetTimer LockTick, on ? 10 : 0
    if !on
        ReleaseClip()
    if on && !GameZoneN
        Notify("Cursor lock needs a game zone - pick one on the Workspaces page")
    UpdateTray()
}

ToggleFree() {
    global FreeMode, FreeFrom, GameHwnd
    if !LockOn {
        Notify("Cursor lock is off")
        return
    }
    FreeMode := !FreeMode
    NoteSwitchKey()
    if FreeMode {
        ; A focused game hides the cursor and keeps grabbing the mouse, so releasing our
        ; lock isn't enough - move focus to a side pane so the game lets go.
        FreeFrom := WinExist("A")
        ReleaseClip()
        FocusSidePane(FreeFrom)
        Notify("Cursor free")
    } else {
        GameHwnd := 0
        if FreeFrom && WinExist(FreeFrom)
            try WinActivate FreeFrom
        FreeFrom := 0
        Notify("Cursor locked to game")
    }
    LockTick()
}

; Activate the topmost normal window sitting in a non-game zone (e.g. your guide);
; falls back to the desktop if the side panes are empty.
FocusSidePane(skip) {
    for hwnd in WinGetList() {          ; top of the z-order first
        if hwnd = skip || IsOwnWindow(hwnd)
            continue
        try {
            if WinGetExStyle(hwnd) & 0x80           ; tool windows (popups and the like)
                continue
            if WinGetMinMax(hwnd) = -1
                continue
            if WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
                continue
            if WinGetTitle(hwnd) = ""
                continue
            WinGetPos &x, &y, &w, &h, hwnd
        } catch
            continue
        z := ZoneAt(x + w // 2, y + h // 2)
        if z && z != GameZoneN {
            try WinActivate hwnd
            return
        }
    }
    try WinActivate "ahk_class Progman"
}

; Clip the cursor, keeping LockMargin px clear of the taskbar's edge when it's at the top
; or bottom (where an auto-hidden taskbar pops up). A side taskbar needs no margin.
EdgeClip(l, t, r, b, respectTighter) {
    e := TaskbarEdge()
    if e = "bottom"
        b -= LockMargin
    else if e = "top"
        t += LockMargin
    ApplyClip(l, t, r, b, respectTighter)
}

; Clip the cursor to a rectangle. If respectTighter, leave alone a clip that's already inside
; it (e.g. one the game set itself).
ApplyClip(l, t, r, b, respectTighter) {
    global Clipped
    cur := Buffer(16, 0)
    DllCall("GetClipCursor", "ptr", cur)
    cl := NumGet(cur, 0, "int"), ct := NumGet(cur, 4, "int")
    cr := NumGet(cur, 8, "int"), cb := NumGet(cur, 12, "int")
    if cl = l && ct = t && cr = r && cb = b
        return
    if respectTighter && cl >= l && ct >= t && cr <= r && cb <= b
        return
    rc := Buffer(16, 0)
    NumPut("int", l, "int", t, "int", r, "int", b, rc)
    DllCall("ClipCursor", "ptr", rc)
    Clipped := true
}

ReleaseClip() {
    global Clipped
    if Clipped {
        DllCall("ClipCursor", "ptr", 0)
        Clipped := false
    }
}

ActiveZone() {
    try {
        hwnd := WinExist("A")
        if !hwnd
            return 0
        if WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
            return 0
        WinGetPos &x, &y, &w, &h, hwnd
        return ZoneAt(x + w // 2, y + h // 2)
    }
    return 0
}

; --- cursor lock
;   game focused + not freed -> cursor kept inside the game zone
;   otherwise (freed, or another window focused) -> whole screen
;   Either way the LockMargin px at the taskbar's edge (top or bottom) are off-limits so an
;   auto-hidden taskbar can't pop up. Runs on its own fast timer (~10 ms) while the lock is
;   on, so games that keep re-confining the cursor to their window can't get round it.
LockTick(az := -1) {
    global FreeMode, GameHwnd
    if LockOn && !Dragging && GameZoneN {
        if az = -1
            az := ActiveZone()
        fg := WinExist("A")
        if GameHwnd && !WinExist(GameHwnd)       ; game closed
            GameHwnd := 0
        if !FreeMode {
            if !GameHwnd {
                if az = GameZoneN && fg          ; first window focused in the game zone = the game
                    GameHwnd := fg
            } else if fg && fg != GameHwnd {
                ; The game lost focus. If you did it (Windows key, Alt+Tab, a ZoneSnap
                ; window...) stay free until you click back into the game. If something else
                ; took it (a Steam pop-up, the taskbar), give it back to the game.
                if YouLeftGame(fg)
                    FreeMode := true
                else if FillsGameZone(fg)
                    GameHwnd := fg                   ; the real game replacing its launcher
                else if !FocusStolen(fg) || !ReclaimFocus()
                    FreeMode := true
                fg := WinExist("A")
            }
        }
        if !FreeMode && GameHwnd && fg = GameHwnd {
            z := Zones[GameZoneN]
            EdgeClip(z.x, z.y, z.x + z.w, z.y + z.h, true)
        } else {
            vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)  ; virtual screen
            EdgeClip(vx, vy, vx + vw, vy + vh, false)
            KeepOffMonitorBottoms(vy + vh)
        }
    } else if Clipped {
        ReleaseClip()
    }
}

; ---------------------------------------------------------------------------
; Focus guard. While the cursor is locked the mouse can't leave the game, so the only
; ways YOU leave it are the keyboard (Windows key, Alt+Tab, Ctrl+Esc, Alt+Esc,
; Ctrl+Alt+F) or a ZoneSnap window. Any other focus change - a Steam or Discord pop-up,
; a notification, Windows handing focus to the taskbar (which pops an auto-hidden
; taskbar up) - is treated as stolen, and focus goes straight back to the game.
; Dialogs from the game itself, hung games, and a window that keeps taking focus
; (3 times in 10 seconds) are let through. [Settings] FocusGuard=0 turns this off.
; ---------------------------------------------------------------------------
YouLeftGame(fg) {
    if IniRead(IniFile, "Settings", "FocusGuard", "1") != "1"
        return true                              ; guard off: any focus change frees the cursor
    if A_TickCount - LastSwitchKey < 1500        ; you just pressed Win / Alt+Tab / clicked out
        return true
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P") || GetKeyState("Alt", "P")
        return true
    return IsOwnWindow(fg)                       ; ZoneSnap's settings, editor, menus
}

FocusStolen(fg) {
    try {
        if WinGetPID(fg) = WinGetPID(GameHwnd)   ; the game's own dialog (quit, launcher...)
            return false
        if DllCall("IsHungAppWindow", "ptr", GameHwnd)
            return false
        if WinGetClass(fg) ~= "^(#32768|ForegroundStaging|Windows\.UI\.Core\.CoreWindow|MultitaskingViewFrame|XamlExplorerHostIslandWindow|TaskSwitcherWnd)$"
            return false                         ; menus, Start / search, the Alt+Tab switcher
    } catch
        return false
    return true
}

; A window covering most of the game zone is a game, not a pop-up.
FillsGameZone(hwnd) {
    if IsOwnWindow(hwnd)
        return false
    try WinGetPos &x, &y, &w, &h, hwnd
    catch
        return false
    z := Zones[GameZoneN]
    return w >= z.w * 0.8 && h >= z.h * 0.8 && ZoneAt(x + w // 2, y + h // 2) = GameZoneN
}

ReclaimFocus() {
    global StealTimes
    now := A_TickCount
    kept := []
    for t in StealTimes
        if now - t < 10000
            kept.Push(t)
    StealTimes := kept
    if StealTimes.Length >= 3                    ; it keeps coming back - let it have focus
        return false
    StealTimes.Push(now)
    try {
        WinActivate GameHwnd
        return WinWaitActive(GameHwnd, , 0.3) != 0
    }
    return false
}

; Mark the moments you switch away yourself, so the focus guard leaves you alone.
NoteSwitchKey(*) {
    global LastSwitchKey := A_TickCount
}
~*LWin::NoteSwitchKey()
~*RWin::NoteSwitchKey()
~*Tab:: {
    if GetKeyState("Alt", "P")
        NoteSwitchKey()
}
~*Esc:: {
    if GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P")
        NoteSwitchKey()
}

; With several monitors, one rectangle can't keep the cursor off every monitor's bottom edge
; (their bottoms differ), and each can have an auto-hidden taskbar. The clip handles the
; lowest edge; this nudges the cursor up off any higher one.
KeepOffMonitorBottoms(virtualBottom) {
    if MonitorGetCount() < 2 || LockMargin = 0 || TaskbarEdge() != "bottom"
        return
    MouseGetPos &cx, &cy
    Loop MonitorGetCount() {
        MonitorGet A_Index, &ml, &mt, &mr, &mb
        if cx >= ml && cx < mr && cy >= mt && cy < mb {
            ; a monitor directly below means that edge is a way through, not a taskbar edge
            if mb < virtualBottom && cy >= mb - LockMargin && MonitorAt(cx, mb) = 0
                DllCall("SetCursorPos", "int", cx, "int", mb - LockMargin - 1)
            return
        }
    }
}

; Runs every 100 ms: snaps launching apps, keeps the cursor lock, handles dim hover.
Tick() {
    ; --- taskbar shown/hidden (usable screen area changed) -> refit zones, re-snap windows
    if MonitorKey() != LastMonKey
        OnMonitorsChanged()
    else if WorkAreaKey() != LastWA
        OnWorkAreaChange()

    ; --- apps a workspace is opening: snap them, and hold them in place for a moment
    i := Pending.Length
    while i >= 1 {
        p := Pending[i]
        h := 0
        try h := FindWin(p.win)
        if h {
            if h != p.last {
                SnapTo(h, p.zone)
                p.last := h
                if !p.found {
                    p.found := A_TickCount
                    p.until := A_TickCount + 12000
                }
            } else if !FitsZone(h, p.zone) {
                ; apps (Edge app windows especially) often restore their saved size/position
                ; a moment after opening - keep putting them back until the watch ends
                SnapTo(h, p.zone)
            }
        }
        if A_TickCount > p.until
            Pending.RemoveAt(i)
        i--
    }

    az := ActiveZone()

    LockTick(az)

    ; --- dimming: undim the pane under the mouse and the pane you're working in
    if DimOn {
        MouseGetPos &mx, &my
        mz := ZoneAt(mx, my)
        for i, g in DimOverlays {
            if !IsObject(g) || i > Zones.Length
                continue
            show := (i != mz && i != az && !LitZones.Has(i))
            if show != DimVis[i] {
                if show
                    g.Show("NA")
                else
                    g.Hide()
                DimVis[i] := show
            }
            pin := (i = mz)        ; pin button while the mouse is over this pane
            if i <= PinVis.Length && pin != PinVis[i] {
                ShowPin(i, pin)
                PinVis[i] := pin
            }
        }
    }
}
