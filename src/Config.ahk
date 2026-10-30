; ============================================================================
;  ZoneSnap - Config
;  Settings file basics: first-run defaults, the Gaming section, and small helpers
;  used everywhere (Notify, HasValue, comma lists, safe ini keys).
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; First run: build a starting layout from the primary monitor's shape and return a
; one-line description of it for the welcome message.
;   super ultrawide (32:9-ish)  -> side | 21:9 game | side
;   ultrawide (21:9-ish)        -> side | 16:9 game | side
;   anything narrower           -> two halves
WriteDefaults() {
    FileAppend "[Settings]`r`n", IniFile, "UTF-16"
    IniWrite "!LButton", IniFile, "Settings", "DragHotkey"
    MonitorGet MonitorGetPrimary(), &mL, &mT, &mR, &mB
    mW := mR - mL, mH := mB - mT
    ratio := mW / mH
    zl := []
    if ratio >= 2.2 {
        mid := Min(ratio >= 2.9 ? UltraWidth(mH) : WideWidth(mH), mW)
        side := (mW - mid) // 2
        zl.Push({x: mL, y: mT, w: side, h: mH}
              , {x: mL + side, y: mT, w: mid, h: mH}
              , {x: mL + side + mid, y: mT, w: mW - side - mid, h: mH})
        desc := "I've set up zones for your " mW " x " mH " monitor: a " mid "-wide game zone ("
            . (ratio >= 2.9 ? "21:9" : "16:9") ") in the middle with a " side "-wide pane either side."
    } else {
        half := mW // 2
        zl.Push({x: mL, y: mT, w: half, h: mH}, {x: mL + half, y: mT, w: mW - half, h: mH})
        desc := "Your " mW " x " mH " monitor isn't an ultrawide, so I've started you with two halves."
    }
    extra := 0
    for m in MonitorList() {                ; each other monitor starts as one zone
        if m.primary
            continue
        zl.Push({x: m.l, y: m.t, w: m.w, h: m.h})
        extra++
    }
    if extra
        desc .= " Your other " (extra = 1 ? "monitor is" : extra " monitors are") " one zone each to start."
    SaveZones(zl, "Zones")
    return desc
}

EnsureGamingSection() {
    if IniRead(IniFile, "GamingMode", "GameZone", "") = "" {
        gameZone := ReadZones("Zones").Length = 3 ? 2 : 1
        lines := [
            "[GamingMode]",
            "; Gaming mode (Ctrl+Alt+G by default). These settings apply while it is on.",
            "; Zone number the game sits in (cursor lock target, never dimmed).",
            "GameZone=" gameZone,
            "; 1 = auto-hide the taskbar during gaming mode (your setting is restored after).",
            "AutoHideTaskbar=1",
            "; 1 = keep the cursor inside the game zone while the game is focused.",
            "LockCursor=1",
            "; Pixels kept clear of the taskbar's edge while the cursor is locked (stops the auto-hide taskbar).",
            "LockBottomMargin=2",
            "; 1 = dim the other zones. DimOpacity 0-255, higher = darker.",
            "DimSides=1",
            "DimOpacity=170",
            "; 1 = turn gaming mode on when a game starts and off when it closes.",
            "; Games = anything added with Ctrl+Alt+A (default key) while in the game zone, plus this list:",
            "AutoGaming=1",
            ";Games=eldenring.exe, cs2.exe",
            "; Apps to launch and snap:  AppN=zone|window match|command   (command optional)",
            "; Easiest: put a window in its zone and press Ctrl+Alt+A (default key) to add it here.",
            "; With no command, an already-open window (e.g. your game) is just snapped.",
            ';App1=1|ahk_exe Discord.exe|"%LOCALAPPDATA%\Discord\Update.exe" --processStart Discord.exe',
            ";App2=3|ahk_exe chrome.exe|chrome.exe",
            ";App3=2|ahk_exe MyGame.exe|"
        ]
        text := ""
        for line in lines
            text .= line "`r`n"
        enc := "UTF-8"
        try {
            f := FileOpen(IniFile, "r")
            enc := f.Encoding
            f.Close()
        }
        FileAppend "`r`n" text, IniFile, enc
    }
    if IniRead(IniFile, "GamingZones", "Count", "") = ""
        SaveZones(ReadZones("Zones"), "GamingZones")
}

GSInt(key, def) {
    v := IniRead(IniFile, "GamingMode", key, def)
    return IsInteger(v) ? Integer(v) : def
}

Notify(msg) {
    ToolTip msg
    SetTimer HideTip, -1800     ; same timer each time, so a newer tooltip gets its full time
}

HideTip() => ToolTip()

; Settings for features removed in 0.31.0: the classic windows ([Settings] Interface), the
; Put windows back switch ([Settings] RestorePlaces) and per-game Borderless ([Borderless])
TidyOldSettings() {
    try IniDelete IniFile, "Settings", "Interface"
    try IniDelete IniFile, "Settings", "RestorePlaces"
    try IniDelete IniFile, "Borderless"
    ; 0.38.0: the Windows accent switch became Accent colour (teal, Windows or custom)
    old := IniRead(IniFile, "Settings", "AccentFromWindows", "")
    if old != "" {
        if old = "1" && IniRead(IniFile, "Settings", "AccentMode", "") = ""
            IniWrite "windows", IniFile, "Settings", "AccentMode"
        try IniDelete IniFile, "Settings", "AccentFromWindows"
    }
}

; A window match that's safe as a key in ZoneSnap.ini (keys can't hold = [ ] or line breaks)
SafeIniKey(match) => match != "" && !(match ~= "[=\r\n\[\]]")

HasValue(arr, v) {
    for x in arr
        if x = v
            return true
    return false
}

CsvList(csv) {
    out := []
    for s in StrSplit(csv, ",", " `t")
        if s != ""
            out.Push(s)
    return out
}
CsvJoin(arr) {
    out := ""
    for s in arr
        out .= (out = "" ? "" : ",") s
    return out
}

ExpandEnv(s) {
    buf := Buffer(32767 * 2, 0)
    DllCall("ExpandEnvironmentStringsW", "str", s, "ptr", buf, "uint", 32767)
    return StrGet(buf)
}
