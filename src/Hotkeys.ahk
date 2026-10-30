; ============================================================================
;  ZoneSnap - Hotkeys
;  Keyboard shortcuts: the actions, your own keys ([Hotkeys]), clash checks, and
;  workspace hotkeys.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

RegisterHotkeys() {
    try Hotkey DragKey, DragWindow
    catch
        MsgBox "Invalid DragHotkey in ZoneSnap.ini: " DragKey, "ZoneSnap", "Icon!"
    RegisterActionHotkeys()
}

; ---------------------------------------------------------------------------
; Rebindable shortcuts. [Hotkeys] in ZoneSnap.ini holds your own keys (AutoHotkey
; notation: ^ Ctrl, ! Alt, + Shift, # Win); a missing entry means the default, an
; empty one means no shortcut. SendToZone and KeepZoneLit are modifiers only - the
; number keys 1-9 are added to them. Changed on the Hotkeys page of the ZoneSnap window.
; ---------------------------------------------------------------------------
HotkeyActions() => [
    {id: "Gaming",        def: "^!g",  mods: 0, what: "Gaming mode on/off"},
    {id: "EditZones",     def: "^!z",  mods: 0, what: "Open ZoneSnap on the Zones page"},
    {id: "SendToZone",    def: "^!",   mods: 1, what: "Send the active window to zone 1 to 9"},
    {id: "KeepZoneLit",   def: "^!+",  mods: 1, what: "Keep zone 1 to 9 lit (toggle), works mid-game"},
    {id: "Lock",          def: "^!l",  mods: 0, what: "Cursor lock on/off"},
    {id: "Free",          def: "^!f",  mods: 0, what: "Free the cursor from the game (press again to go back)"},
    {id: "Dim",           def: "^!d",  mods: 0, what: "Dim side panes on/off"},
    {id: "LitUnderMouse", def: "^!u",  mods: 0, what: "Keep the pane under the mouse lit (toggle)"},
    {id: "AddApp",        def: "^!a",  mods: 0, what: "Add the active window to your app list and the active workspace (in the game zone: a game to detect)"},
    {id: "Borderless",    def: "^!b",  mods: 0, what: "Remove or restore the active window's borders"},
    {id: "Switcher",      def: "^!space", mods: 0, what: "Quick switcher: pick a workspace from a list at the mouse"}
]

HotkeyAction(id) {
    for a in HotkeyActions()
        if a.id = id
            return a
    return ""
}

ActionFn(id) {
    switch id {
        case "Gaming":        return (*) => ToggleGaming()
        case "EditZones":     return (*) => OpenUI("zones")
        case "Lock":          return (*) => SetLock(!LockOn)
        case "Free":          return (*) => ToggleFree()
        case "Dim":           return (*) => SetDim(!DimOn)
        case "LitUnderMouse": return (*) => ToggleLitUnderMouse()
        case "AddApp":        return (*) => AddActiveApp()
        case "Borderless":    return (*) => ToggleBorderless(WinExist("A"))
        case "Switcher":      return (*) => ShowSwitcher()
    }
}

; The key bound to an action, normalised ("" = none)
HotkeyFor(id) {
    a := HotkeyAction(id)
    return IsObject(a) ? NormHK(IniRead(IniFile, "Hotkeys", id, a.def)) : ""
}

; Ctrl/Alt/Shift/Win in a fixed order, key in lower case: "!^G" -> "^!g"
NormHK(hk) {
    hk := Trim(String(hk))
    mods := ""
    while hk != "" && InStr("^!+#", SubStr(hk, 1, 1)) {
        mods .= SubStr(hk, 1, 1)
        hk := SubStr(hk, 2)
    }
    out := ""
    for c in ["^", "!", "+", "#"]
        if InStr(mods, c)
            out .= c
    return out StrLower(hk)
}

SplitHK(hk, &mods, &key) {
    hk := NormHK(hk)
    RegExMatch(hk, "^([\^!+#]*)(.*)$", &m)
    mods := m[1], key := m[2]
}

; "^!+g" -> "Ctrl+Alt+Shift+G"; modifiers only -> "Ctrl+Alt+1 to 9"
HotkeyLabel(hk, isMods := false) {
    if hk = ""
        return ""
    SplitHK(hk, &mods, &key)
    out := ModsLabel(mods)
    out .= out != "" ? "+" : ""
    if isMods
        return out "1 to 9"
    names := Map("pgup", "PgUp", "pgdn", "PgDn", "ins", "Insert", "del", "Delete", "esc", "Esc",
        "numpadadd", "Num +", "numpadsub", "Num -", "numpadmult", "Num *", "numpaddiv", "Num /",
        "numpaddot", "Num .", "numpadenter", "Num Enter", "printscreen", "PrtSc", "scrolllock", "ScrollLock")
    if names.Has(key)
        k := names[key]
    else if key ~= "^numpad\d$"
        k := "Num " SubStr(key, 7)
    else
        k := StrUpper(SubStr(key, 1, 1)) SubStr(key, 2)
    return out k
}

; "^!" -> "Ctrl+Alt"
ModsLabel(mods) {
    out := ""
    for pair in [["^", "Ctrl"], ["!", "Alt"], ["+", "Shift"], ["#", "Win"]]
        if InStr(mods, pair[1])
            out .= (out = "" ? "" : "+") pair[2]
    return out
}

; "Alt + left-drag" for the window-drag key ("!LButton")
DragLabel() => ModsLabel(SubStr(DragKey, 1, -7)) " + left-drag"

; Label of an action's key for messages ("Ctrl+Alt+A", or "its hotkey" when it has none)
KeyText(id) {
    a := HotkeyAction(id)
    hk := HotkeyFor(id)
    return hk = "" ? "its hotkey" : HotkeyLabel(hk, a.mods)
}

; Every key ZoneSnap's shortcuts use: normalised key -> what it does (skip = an action
; id or "ws:<name>" to leave out, for checking a new binding against the rest)
BoundKeys(skip := "") {
    used := Map()
    for a in HotkeyActions() {
        if a.id = skip || (hk := HotkeyFor(a.id)) = ""
            continue
        if a.mods {
            Loop 9
                used[hk A_Index] := a.what
        } else
            used[hk] := a.what
    }
    for ws in WSList() {
        if ws = "Gaming" || "ws:" ws = skip
            continue
        hk := NormHK(IniRead(IniFile, WSSection(ws), "Hotkey", ""))
        if hk != ""
            used[hk] := "the " ws " workspace"
    }
    return used
}

; Why a key can't be used for this action ("" = fine)
HotkeyProblem(target, hk) {
    if hk = ""
        return ""
    isMods := false
    if SubStr(target, 1, 3) != "ws:" {
        a := HotkeyAction(target)
        if !IsObject(a)
            return "Unknown shortcut"
        isMods := a.mods
    }
    SplitHK(hk, &mods, &key)
    if isMods {
        if key != ""
            return "Hold the modifier keys and press a number"
        if !(mods ~= "[\^!#]")
            return "Use Ctrl, Alt or Win with the number keys, or they'd stop typing numbers"
    } else {
        if key = ""
            return "Press a key as well as the modifiers"
        if !(mods ~= "[\^!#]") && !(key ~= "^(f\d{1,2}|pause|scrolllock|printscreen)$")
            return "Use Ctrl, Alt or Win with that key, or it would stop working for typing"
        if HasValue(["!tab", "^esc", "#l", "^!del", "!esc", "!f4"], mods key)
            return HotkeyLabel(hk) " belongs to Windows"
    }
    used := BoundKeys(target)
    keys := isMods ? [] : [mods key]
    if isMods
        Loop 9
            keys.Push(mods A_Index)
    for k in keys
        if used.Has(k)
            return HotkeyLabel(k) " is already used for: " used[k]
    try {
        for k in keys {
            Hotkey k, (*) => 0, "Off"        ; is it a key AutoHotkey can register?
        }
    } catch
        return "Windows or AutoHotkey can't use " HotkeyLabel(keys[1]) " as a shortcut"
    return ""
}

RegisterActionHotkeys() {
    static active := []
    for k in active
        try Hotkey k, "Off"
    active := []
    global ActionKeys := Map()
    taken := ActionKeys
    for a in HotkeyActions() {
        hk := HotkeyFor(a.id)
        if hk = ""
            continue
        keys := []
        if a.mods {
            Loop 9
                keys.Push(hk A_Index)
        } else
            keys.Push(hk)
        for k in keys {
            if taken.Has(k)
                continue
            fn := a.mods ? (a.id = "SendToZone" ? SendToZoneKey : LitZoneKey) : ActionFn(a.id)
            try {
                Hotkey k, fn, "On"
                active.Push(k), taken[k] := 1
            }
        }
    }
    global M_GAME := "Gaming mode" TrayKey("Gaming"), M_LOCK := "Cursor lock" TrayKey("Lock")
    global M_DIM := "Dim side panes" TrayKey("Dim"), M_EDIT := "Edit zones" TrayKey("EditZones")
}

TrayKey(id) => (hk := HotkeyFor(id)) = "" ? "" : "`t" HotkeyLabel(hk)

; Set (or clear, hk = "") the key for an action or "ws:<name>". Returns "" or the problem.
SetHotkey(target, hk) {
    hk := NormHK(hk)
    if (why := HotkeyProblem(target, hk)) != ""
        return why
    if SubStr(target, 1, 3) = "ws:" {
        ws := SubStr(target, 4)
        if !HasValue(WSList(), ws) || ws = "Gaming"
            return "Unknown workspace"
        IniWrite hk, IniFile, WSSection(ws), "Hotkey"
        RegisterWSHotkeys()
    } else {
        IniWrite hk, IniFile, "Hotkeys", target
        RegisterActionHotkeys()
        BuildTray()
    }
    UpdateWSMenu()
    return ""
}

; Every shortcut back to its default. A workspace whose key is now a default loses it
; (returns their names, comma separated, so the caller can say so).
ResetHotkeys() {
    try IniDelete IniFile, "Hotkeys"
    RegisterActionHotkeys()
    cleared := ""
    for ws in WSList()
        if ws != "Gaming" && ActionKeys.Has(NormHK(IniRead(IniFile, WSSection(ws), "Hotkey", ""))) {
            IniWrite "", IniFile, WSSection(ws), "Hotkey"
            cleared .= (cleared = "" ? "" : ", ") ws
        }
    RegisterWSHotkeys()
    BuildTray()
    return cleared
}

; While the ZoneSnap window records a new shortcut, its keys must reach the window
; instead of triggering ZoneSnap's own hotkeys.
CaptureHotkeys(on) {
    Suspend on ? true : false
    SetTimer EndHotkeyCapture, on ? -30000 : 0       ; safety: never stay suspended
}
EndHotkeyCapture() => CaptureHotkeys(false)

SendToZoneKey(hk) {
    n := Integer(SubStr(hk, -1))
    layout := ActiveLayoutLabel()
    if n > Zones.Length {
        Notify("The " layout " layout has no zone " n " (it has " Zones.Length ")")
        return
    }
    if hwnd := WinExist("A")
        SnapTo(hwnd, n)
}

; Workspace hotkeys: any key (Ctrl+Alt+F1-F9 offered on the Workspaces page, anything on
; the Hotkeys page). Gaming uses the Gaming mode shortcut instead.
RegisterWSHotkeys() {
    global WSHotkeys
    for hk in WSHotkeys
        if !ActionKeys.Has(hk)              ; (now one of ZoneSnap's own shortcuts - leave it on)
            try Hotkey hk, "Off"
    WSHotkeys := Map()
    for ws in WSList() {
        if ws = "Gaming"
            continue
        hk := NormHK(IniRead(IniFile, WSSection(ws), "Hotkey", ""))
        if hk = "" || WSHotkeys.Has(hk) || ActionKeys.Has(hk)      ; a shortcut already has it
            continue
        try {
            Hotkey hk, ToggleWorkspace.Bind(ws), "On"
            WSHotkeys[hk] := ws
        }
    }
}
