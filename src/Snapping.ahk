; ============================================================================
;  ZoneSnap - Snapping
;  Snapping: the drag overlays, Alt+drag, Shift while dragging a title bar, and
;  moving windows into zones.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Zone overlay (shown while dragging)
; ---------------------------------------------------------------------------
BuildOverlays() {
    global Overlays, AccentHex
    AccentHex := UiAccent()
    for g in Overlays
        g.Destroy()
    Overlays := []
    for i, z in Zones {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")  ; E0x20 = click-through
        g.BackColor := "253041"
        RoundCorners(g.Hwnd)
        iw := Max(1, z.w - 2 * OverlayInset), ih := Max(1, z.h - 2 * OverlayInset)
        g.SetFont("s28 bold cWhite", "Segoe UI")
        g.AddText("x0 y" Max(0, ih // 2 - 48) " w" iw " Center BackgroundTrans", i)
        g.SetFont("s11 norm cE2E8F0", "Segoe UI")
        g.AddText("x0 y+2 w" iw " Center BackgroundTrans", z.w " x " z.h)
        Overlays.Push(g)
    }
}

ShowOverlays() {
    for i, g in Overlays {
        if i > Zones.Length
            break
        z := Zones[i]
        g.BackColor := "253041"
        g.Show("NA x" (z.x + OverlayInset) " y" (z.y + OverlayInset)
            . " w" Max(1, z.w - 2 * OverlayInset) " h" Max(1, z.h - 2 * OverlayInset))
        WinSetTransparent 150, g
    }
}

HideOverlays() {
    for g in Overlays
        g.Hide()
}

Highlight(n) {
    for i, g in Overlays {
        g.BackColor := (i = n) ? AccentHex : "253041"
        WinSetTransparent (i = n) ? 200 : 150, g
    }
}

FlashZones() {
    Notify(ActiveLayoutLabel() " layout (active now)")
    ShowOverlays()
    SetTimer HideOverlays, -2000
}

ZoneAt(x, y) {
    for i, z in Zones
        if (x >= z.x && x < z.x + z.w && y >= z.y && y < z.y + z.h)
            return i
    return 0
}

; ---------------------------------------------------------------------------
; Moving / snapping windows
; ---------------------------------------------------------------------------
TopWindowUnderMouse() {
    MouseGetPos , , &hwnd
    if !hwnd
        return 0
    hwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")  ; GA_ROOT
    try cls := WinGetClass(hwnd)
    catch
        return 0
    if cls ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
        return 0
    if IsOwnWindow(hwnd)            ; overlays, pin buttons, editor, help window
        return 0
    return hwnd
}

IsOwnWindow(hwnd) {
    try return WinGetPID(hwnd) = DllCall("GetCurrentProcessId")
    return false
}

; Alt + drag: move a window from anywhere inside it, then snap to a zone.
DragWindow(*) {
    global Dragging
    hwnd := TopWindowUnderMouse()
    if !hwnd
        return
    MouseGetPos &mx, &my
    try {
        if WinGetMinMax(hwnd) = 1 {
            WinRestore hwnd
            WinGetPos , , &ww, , hwnd
            offX := ww // 2, offY := 15
        } else {
            WinGetPos &wx, &wy, , , hwnd
            offX := mx - wx, offY := my - wy
        }
    } catch
        return

    Dragging := true
    ReleaseClip()
    btn := RegExReplace(DragKey, "[\^!+#<>*~$]")   ; e.g. "!LButton" -> "LButton"
    ShowOverlays()
    cur := 0
    try {
        while GetKeyState(btn, "P") {
            MouseGetPos &cx, &cy
            try WinMove cx - offX, cy - offY, , , hwnd
            z := ZoneAt(cx, cy)
            if z != cur {
                Highlight(z)
                cur := z
            }
            Sleep 10
        }
    } finally {
        HideOverlays()
        Dragging := false
    }
    if cur
        SnapTo(hwnd, cur)
    else
        KeepGameHere(hwnd)
}

; True if the window's visible rectangle matches zone n (within a few px).
FitsZone(hwnd, n) => (n < 1 || n > Zones.Length) ? true : FitsRect(hwnd, Zones[n])

FitsRect(hwnd, z) {
    rect := Buffer(16, 0)
    try {
        if WinGetMinMax(hwnd) != 0
            return false
        if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", rect, "uint", 16) {
            WinGetPos &x, &y, &w, &h, hwnd
            NumPut("int", x, "int", y, "int", x + w, "int", y + h, rect)
        }
    } catch
        return true
    l := NumGet(rect, 0, "int"), t := NumGet(rect, 4, "int")
    return Abs(l - z.x) <= 3 && Abs(t - z.y) <= 3
        && Abs(NumGet(rect, 8, "int") - l - z.w) <= 3 && Abs(NumGet(rect, 12, "int") - t - z.h) <= 3
}

; Put a window exactly into zone n, compensating for Windows' invisible borders.
SnapTo(hwnd, n) {
    if n < 1 || n > Zones.Length
        return
    MoveToRect(hwnd, Zones[n])
    ; remember the zone's saved rectangle so the window can follow it when the taskbar
    ; shows or hides - in either layout
    if n <= RawZones.Length
        Snapped[hwnd] := CopyZones([RawZones[n]])[1]
}

; Move a window so its visible area exactly fills rectangle z
MoveToRect(hwnd, z) {
    try {
        mm := WinGetMinMax(hwnd)
        if mm = -1
            return
        if mm = 1
            WinRestore hwnd
        WinGetPos &wx, &wy, &ww, &wh, hwnd
    } catch
        return

    ; a window without a caption or sizing frame has no invisible border, so it goes to the
    ; exact rect (just after its frame is taken away, DWM can still report the old border)
    l := 0, t := 0, r := 0, b := 0
    rect := Buffer(16, 0)
    try framed := WinGetStyle(hwnd) & 0xC40000
    catch
        framed := 1
    if framed && !DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", rect, "uint", 16) {
        l := NumGet(rect, 0, "int") - wx
        t := NumGet(rect, 4, "int") - wy
        r := (wx + ww) - NumGet(rect, 8, "int")
        b := (wy + wh) - NumGet(rect, 12, "int")
    }
    try WinMove z.x - l, z.y - t, z.w + l + r, z.h + t + b, hwnd
    if GameHomes.Has(hwnd)
        GameHomes[hwnd].z := {x: z.x, y: z.y, w: z.w, h: z.h}    ; a game stays where it was put
}

; ---------------------------------------------------------------------------
; Left clicks: cursor lock bookkeeping, and Shift while dragging a normal title bar
; (show zones, snap on release)
; ---------------------------------------------------------------------------
~LButton:: {
    global Dragging, FreeMode, GameHwnd
    if LockOn && GameZoneN {
        MouseGetPos &fx, &fy
        if ZoneAt(fx, fy) != GameZoneN {
            NoteSwitchKey()      ; clicking another window on purpose isn't a stolen focus
        } else if FreeMode {
            FreeMode := false    ; clicking back into the game zone re-locks a freed cursor
            GameHwnd := 0        ; whatever you clicked in the game zone becomes the game
        }
    }
    hwnd := TopWindowUnderMouse()
    if !hwnd
        return
    try WinGetPos &sx, &sy, , , hwnd
    catch
        return
    shown := false, cur := 0
    while GetKeyState("LButton", "P") {
        if GetKeyState("Shift", "P") {
            try WinGetPos &x, &y, , , hwnd
            catch
                break
            if shown || x != sx || y != sy {
                if !shown {
                    Dragging := true
                    ReleaseClip()
                    ShowOverlays()
                    shown := true
                }
                MouseGetPos &cx, &cy
                z := ZoneAt(cx, cy)
                if z != cur {
                    Highlight(z)
                    cur := z
                }
            }
        } else if shown {
            HideOverlays()
            Dragging := false
            shown := false, cur := 0
        }
        Sleep 15
    }
    if shown {
        HideOverlays()
        Dragging := false
        if cur
            SnapTo(hwnd, cur)
        else
            KeepGameHere(hwnd)
    }
}
