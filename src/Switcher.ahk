; ============================================================================
;  ZoneSnap - Quick switcher
;  A small list of your workspaces that pops up at the mouse (Ctrl+Alt+Space by
;  default): arrow keys or a number to pick, Enter or a click to switch, Esc to close.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; Open the switcher, or close it if it's already open
ShowSwitcher() {
    global Switcher
    if IsObject(Switcher)
        return CloseSwitcher()
    NoteSwitchKey()                     ; choosing a workspace isn't a pop-up stealing the game's focus
    th := Theme()
    names := ["Default"], labels := []
    for ws in WSList()
        names.Push(ws)
    cur := 1
    for i, nm in names {
        if nm = (ActiveWS = "" ? "Default" : ActiveWS)
            cur := i
        hk := nm = "Default" ? "" : nm = "Gaming" ? HotkeyFor("Gaming") : NormHK(IniRead(IniFile, WSSection(nm), "Hotkey", ""))
        labels.Push((i <= 9 ? i "   " : "     ") nm (i = cur ? "   (on)" : "") (hk != "" ? "   -   " HotkeyLabel(hk) : ""))
    }
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "ZoneSnap - switch workspace")
    g.BackColor := th.bg
    g.MarginX := 12, g.MarginY := 10
    g.SetFont("s9 c" th.sub, "Segoe UI")
    g.AddText("w300", "Switch to  (" KeyText("Switcher") " or Esc closes)")
    g.SetFont("s11 c" th.text, "Segoe UI")
    lb := g.AddListBox("w300 r" Min(names.Length, 12) " -E0x200 Background" th.panel " Choose" cur, labels)
    lb.OnEvent("DoubleClick", (*) => PickSwitcher())
    g.OnEvent("Escape", (*) => CloseSwitcher())
    Switcher := {gui: g, lb: lb, names: names}
    StyleCaption(g.Hwnd)        ; (a borderless window: this gives it the theme's edge colours)
    RoundCorners(g.Hwnd)
    ; at the mouse, kept on its monitor
    g.Show("Hide AutoSize")
    g.GetPos(, , &w, &h)
    MouseGetPos &mx, &my
    MonitorGetWorkArea((m := MonitorAt(mx, my)) ? m : MonitorGetPrimary(), &l, &t, &r, &b)
    x := Max(l, Min(mx - w // 2, r - w)), y := Max(t, Min(my - 20, b - h))
    g.Show("x" x " y" y)
    WinActivate g.Hwnd
    lb.Focus()
    SwitcherKeys()
    OnMessage(0x0006, SwitcherActivate)          ; WM_ACTIVATE: close when you click elsewhere
}

; Enter / NumpadEnter switch; 1-9 pick that row, only while the switcher has focus
SwitcherKeys() {
    static made := false
    if !made {
        HotIf (*) => IsObject(Switcher) && WinActive("ahk_id " Switcher.gui.Hwnd)
        for k in ["Enter", "NumpadEnter"]
            Hotkey k, (*) => PickSwitcher()
        Loop 9 {
            Hotkey String(A_Index), SwitcherNumber
            Hotkey "Numpad" A_Index, SwitcherNumber
        }
        HotIf
        made := true
    }
}

SwitcherNumber(hk) {
    n := Integer(SubStr(hk, -1))
    if IsObject(Switcher) && n <= Switcher.names.Length {
        Switcher.lb.Choose(n)
        PickSwitcher()
    }
}

SwitcherActivate(wParam, lParam, msg, hwnd) {
    if IsObject(Switcher) && hwnd = Switcher.gui.Hwnd && (wParam & 0xFFFF) = 0
        SetTimer CloseSwitcher, -10
}

; Switch to the chosen workspace (if it isn't on already)
PickSwitcher() {
    if !IsObject(Switcher)
        return
    i := Switcher.lb.Value, nm := i ? Switcher.names[i] : ""
    CloseSwitcher()
    if nm = ""
        return
    ws := nm = "Default" ? "" : nm
    if ws != ActiveWS
        SwitchWorkspace(ws)
}

CloseSwitcher(*) {
    global Switcher
    OnMessage(0x0006, SwitcherActivate, 0)
    if IsObject(Switcher)
        try Switcher.gui.Destroy()
    Switcher := ""
}
