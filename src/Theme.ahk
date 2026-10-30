; ============================================================================
;  ZoneSnap - Theme
;  Light and dark (house style 2): the theme setting, the teal title bar, the optional
;  Windows accent colour, and the tray menu's look.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Look: follows the Windows light/dark setting and accent colour
; ---------------------------------------------------------------------------
; [Settings] Theme = system (follow Windows, the default), light or dark
ThemePref() {
    v := IniRead(IniFile, "Settings", "Theme", "system")
    return (v = "light" || v = "dark") ? v : "system"
}

; Tray menu look: SetPreferredAppMode 1 = follow Windows, 2 = always dark, 3 = always light
InitTheme() {
    p := ThemePref()
    UxOrdinal(135, p = "dark" ? 2 : p = "light" ? 3 : 1)
    UxOrdinal(136)          ; FlushMenuThemes
}

; The theme or accent setting changed: re-theme the tray menu, the drag overlays and the
; open ZoneSnap window now
ApplyThemeNow() {
    global AccentHex
    InitTheme()
    th := Theme()
    AccentHex := UiAccent()
    if IsObject(UiGui) {
        StyleCaption(UiGui.Hwnd)
        try UiGui.BackColor := th.bg
        try UiCtl.DefaultBackgroundColor := ArgbFor(th.bg)
    }
}

; House style title bar: teal caption with white text on Windows 11; on Windows 10 (which
; ignores caption colours) a dark or light caption to match the theme
StyleCaption(hwnd, preview := "") {
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", Theme().dark ? 1 : 0, "int", 4)
    c := preview != "" ? ShadeFor(StrUpper(preview), "000000", 4.5, "FFFFFF")      ; a colour being previewed
        : AccentMode() = "teal" ? "3D7381" : AccentFill()        ; the house title bar teal, or your accent
    bgr := Integer("0x" SubStr(c, 5, 2) SubStr(c, 3, 2) SubStr(c, 1, 2))     ; COLORREF is 0xBBGGRR
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 35, "uint*", bgr, "int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 36, "uint*", 0xFFFFFF, "int", 4)   ; white text
}

; ---------------------------------------------------------------------------
; Accent colour. [Settings] AccentMode = teal (ZoneSnap's own, the default), windows (your
; Windows accent colour) or custom ([Settings] AccentCustom = RRGGBB). Every accent shade comes
; from that one colour, worked out the same way here and in the house accent.js in ui.html (accentTokens):
;   fill       buttons, switches and the title bar: darkened until white text on it reads (4.5:1)
;   highlight  drag overlays, pin buttons, focus rings: lighter, and readable on the dark panel
; ---------------------------------------------------------------------------
AccentMode() {
    m := IniRead(IniFile, "Settings", "AccentMode", "teal")
    return HasValue(["teal", "windows", "custom"], m) ? m : "teal"
}
AccentCustom() {
    c := IniRead(IniFile, "Settings", "AccentCustom", "7A5AE0")
    return c ~= "^[0-9A-Fa-f]{6}$" ? StrUpper(c) : "7A5AE0"
}
AccentBase() => AccentMode() = "windows" ? AccentColor() : AccentMode() = "custom" ? AccentCustom() : "437784"
AccentFill() => AccentMode() = "teal" ? "437784" : ShadeFor(AccentBase(), "000000", 4.5, "FFFFFF")

; Highlight colour for the drag overlays and pin buttons: the bright house teal, or the
; accent's highlight shade
UiAccent() => AccentMode() = "teal" ? "3CC5B0" : ShadeFor(MixHex(AccentFill(), "FFFFFF", 0.25), "FFFFFF", 4.5, "19202A")

; Relative luminance (WCAG) of RRGGBB, and the contrast ratio between two colours
Luminance(hex) => 0.2126 * LinChannel(SubStr(hex, 1, 2)) + 0.7152 * LinChannel(SubStr(hex, 3, 2)) + 0.0722 * LinChannel(SubStr(hex, 5, 2))
LinChannel(hh) {
    c := Integer("0x" hh) / 255
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
}
Contrast(a, b) {
    x := Luminance(a), y := Luminance(b)
    return (Max(x, y) + 0.05) / (Min(x, y) + 0.05)
}
; a mixed k of the way (0-1) towards b
MixHex(a, b, k) {
    out := ""
    loop 3 {
        p := Integer("0x" SubStr(a, A_Index * 2 - 1, 2)), q := Integer("0x" SubStr(b, A_Index * 2 - 1, 2))
        out .= Format("{:02X}", Max(0, Min(255, Round(p + (q - p) * k))))
    }
    return out
}
; hex moved towards target (black or white) in small steps until it has `need` contrast with `against`
ShadeFor(hex, target, need, against) {
    c := hex, k := 0
    while Contrast(c, against) < need && k < 1 {
        k += 0.04
        c := MixHex(hex, target, k)
    }
    return c
}

; Text colour that reads on a background colour (RRGGBB): near-black on light colours, white
; on dark ones
InkFor(hex) {
    r := Integer("0x" SubStr(hex, 1, 2)), g := Integer("0x" SubStr(hex, 3, 2)), b := Integer("0x" SubStr(hex, 5, 2))
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 > 0.5 ? "0B1F1C" : "FFFFFF"
}

UxOrdinal(n, arg := "") {
    static mod := DllCall("LoadLibrary", "str", "uxtheme", "ptr")
    if !mod || !(fn := DllCall("GetProcAddress", "ptr", mod, "ptr", n, "ptr"))
        return
    if arg = ""
        DllCall(fn)
    else
        DllCall(fn, "int", arg)
}

RoundCorners(hwnd, pref := 2) {     ; Windows 11 rounded corners (2 = round, 3 = small); ignored on 10
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "int*", pref, "int", 4)
}

IsDark() {
    if (p := ThemePref()) != "system"
        return p = "dark"
    try return !RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    return false
}

AccentColor() {             ; Windows accent colour as RRGGBB (stored as ABGR)
    try {
        abgr := RegRead("HKCU\Software\Microsoft\Windows\DWM", "AccentColor")
        return Format("{:02X}{:02X}{:02X}", abgr & 0xFF, (abgr >> 8) & 0xFF, (abgr >> 16) & 0xFF)
    }
    return "38BDA8"
}

; House style 2 colours for ZoneSnap's own native windows (the quick switcher, the window
; behind the page while it loads). Bg, Card, Text, Muted and Danger tokens.
Theme() => IsDark()
    ? {dark: true,  bg: "141A21", panel: "19202A", text: "E6EAEF", sub: "95A0AE", warn: "F2777A"}
    : {dark: false, bg: "F3F5F8", panel: "FFFFFF", text: "141C27", sub: "566273", warn: "B8323A"}
