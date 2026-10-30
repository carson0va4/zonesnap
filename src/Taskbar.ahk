; ============================================================================
;  ZoneSnap - Taskbar
;  The taskbar: which edge it's on, auto-hide, and the flash guard that keeps it
;  down mid-game.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Flash guard. When an app wants attention (a Steam or Discord message, a finished
; download) its taskbar button flashes, and Windows brings an auto-hidden taskbar up to
; show it - interrupting a game. While the active workspace auto-hides the taskbar,
; ZoneSnap stops those flashes as they start, so the taskbar stays down. The app's own
; pop-ups and unread badges are unaffected. [Settings] FlashGuard=0 turns this off.
; ---------------------------------------------------------------------------
StartFlashGuard() {
    if !DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd)
        return
    OnMessage(DllCall("RegisterWindowMessage", "str", "SHELLHOOK", "uint"), OnShellHook)
}

OnShellHook(wParam, lParam, *) {
    ; HSHELL_FLASH = HSHELL_REDRAW (6) with HSHELL_HIGHBIT (0x8000) set
    if wParam != 0x8006 || ActiveWS = "" || !WSOpt(ActiveWS, "AutoHideTaskbar") || TaskbarOnSide()
        return
    if IniRead(IniFile, "Settings", "FlashGuard", "1") != "1"
        return
    SetTimer(StopFlash.Bind(lParam), -30)       ; after Windows has started the flash
}

StopFlash(hwnd) {
    if !hwnd || !WinExist(hwnd)
        return
    ; FLASHWINFO {cbSize, hwnd, dwFlags = FLASHW_STOP (0), uCount, dwTimeout}
    fi := Buffer(A_PtrSize = 8 ? 32 : 20, 0)
    NumPut("uint", fi.Size, fi, 0)
    NumPut("ptr", hwnd, fi, A_PtrSize = 8 ? 8 : 4)
    DllCall("FlashWindowEx", "ptr", fi)
}

; Which screen edge the taskbar is on: "left", "top", "right" or "bottom" (ABM_GETTASKBARPOS;
; Windows uses one setting for every monitor's taskbar). Cached for a second.
TaskbarEdge() {
    static last := -10000, edge := "bottom"
    if A_TickCount - last < 1000
        return edge
    last := A_TickCount
    abd := Buffer(A_PtrSize = 8 ? 48 : 36, 0)
    NumPut("uint", abd.Size, abd, 0)
    if DllCall("shell32\SHAppBarMessage", "uint", 0x5, "ptr", abd, "uptr") {
        e := NumGet(abd, A_PtrSize = 8 ? 20 : 12, "uint")
        if e <= 3
            edge := ["left", "top", "right", "bottom"][e + 1]
    }
    return edge
}

; A taskbar on the left or right sits beside a side pane, so ZoneSnap leaves it alone:
; no auto-hide, and no cursor margin needed.
TaskbarOnSide() => TaskbarEdge() = "left" || TaskbarEdge() = "right"

; Taskbar auto-hide via SHAppBarMessage (ABM_GETSTATE / ABM_SETSTATE)
GetTaskbarAutoHide() {
    abd := Buffer(A_PtrSize = 8 ? 48 : 36, 0)
    NumPut("uint", abd.Size, abd, 0)
    return DllCall("shell32\SHAppBarMessage", "uint", 0x4, "ptr", abd, "uptr") & 1
}

SetTaskbarAutoHide(on) {
    abd := Buffer(A_PtrSize = 8 ? 48 : 36, 0)
    NumPut("uint", abd.Size, abd, 0)
    NumPut("ptr", WinExist("ahk_class Shell_TrayWnd"), abd, A_PtrSize)
    NumPut("ptr", on ? 1 : 2, abd, A_PtrSize = 8 ? 40 : 32)   ; ABS_AUTOHIDE : ABS_ALWAYSONTOP
    DllCall("shell32\SHAppBarMessage", "uint", 0xA, "ptr", abd, "uptr")
}
