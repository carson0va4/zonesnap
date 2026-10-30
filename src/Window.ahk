; ============================================================================
;  ZoneSnap - The ZoneSnap window
;  The ZoneSnap window (WebView2 + ui.html): opening it, the guide panel, and every
;  message between the page and the script (HandleUiMessage, UiState).
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; The ZoneSnap window (WebView2): Zones (visual editor), Workspaces, Apps, General and
; Hotkeys pages and the user guide panel, drawn by ui.html. It talks to this script
; through JSON messages (HandleUiMessage). If it can't start, ZoneSnap says why and
; keeps running from the tray and its shortcuts.
; ---------------------------------------------------------------------------
OpenUI(page := "general", welcome := "") {
    global UiGui, UiCtl, UiView, UiToken, UiStarting, UiPendingPage, UiWelcome
    if (why := UiProblem()) != ""
        return UiCantOpen(why)
    if welcome != ""
        UiWelcome := welcome
    if IsObject(UiGui) {
        UiGui.Show()
        PushUiState(page)
        return
    }
    if UiStarting
        return
    UiStarting := true
    UiPendingPage := page
    th := Theme()
    UiGui := w := Gui("+Resize +MinSize820x560", UiTitle())
    w.BackColor := th.bg
    w.OnEvent("Close", (*) => CloseUI())
    w.OnEvent("Size", UiSize)
    StyleCaption(w.Hwnd)
    w.Show("w1100 h760")
    try {
        dataDir := EnvGet("LOCALAPPDATA") "\ZoneSnap\WebView2"     ; ZoneSnap's own, not Edge's profile
        DirCreate dataDir
        UiCtl := WebView2.CreateControllerAsync(w.Hwnd, 0, dataDir, "", LoaderPath()).await2(20000)
        try UiCtl.DefaultBackgroundColor := ArgbFor(th.bg)          ; no white flash while loading
        UiView := UiCtl.CoreWebView2
        cfg := UiView.Settings
        cfg.AreDefaultContextMenusEnabled := 0
        cfg.IsStatusBarEnabled := 0
        cfg.AreDevToolsEnabled := IniRead(IniFile, "Settings", "UiDebug", 0) = "1"
        UiToken := UiView.add_WebMessageReceived(OnUiMessage)
        UiView.Navigate(FileUrl(UIDir() "\ui.html"))
    } catch as err {
        UiStarting := false
        try w.Destroy()
        UiGui := "", UiCtl := "", UiView := ""
        return UiCantOpen("WebView2 couldn't start: " err.Message)
    }
    UiStarting := false
}

; Why the ZoneSnap window can't open ("" if it can)
UiProblem() {
    try {
        if !(WebView2 is Class) || !(JSON is Class)
            return "the Lib folder wasn't included"
    } catch
        return "the Lib folder wasn't included"
    if !FileExist(UIDir() "\ui.html")
        return "ui.html is missing" (A_IsCompiled ? " (it wasn't bundled into the .exe)" : "")
    if !FileExist(LoaderPath())
        return "WebView2Loader.dll is missing" (A_IsCompiled ? " (it wasn't bundled into the .exe)" : "")
    return ""
}

UiCantOpen(why) {
    MsgBox "The ZoneSnap window can't open: " why ".`n`n"
        . "Zones, gaming mode and your shortcuts still work from the tray icon. If WebView2 is "
        . "missing, install the Microsoft Edge WebView2 Runtime from Microsoft's website and "
        . "start ZoneSnap again.", "ZoneSnap", "Icon!"
}

UIDir() => A_IsCompiled ? EnvGet("LOCALAPPDATA") "\ZoneSnap" : A_ScriptDir
LoaderPath() => A_IsCompiled ? UIDir() "\WebView2Loader.dll"
    : A_ScriptDir "\Lib\WebView2\" (A_PtrSize * 8) "bit\WebView2Loader.dll"

; The user guide (guide.html) opens in a side panel of the ZoneSnap window, so you can
; read it and use ZoneSnap at the same time. If the window can't open, it opens in your
; web browser instead.
OpenGuide(page := "") {
    global UiGuidePending
    if UiProblem() != "" || !FileExist(UIDir() "\guide.html")
        return OpenGuideFile()
    UiGuidePending := true
    OpenUI(page != "" ? page : IsObject(UiGui) ? "" : "general")
}

; The guide in your web browser. The script version reads it from beside the script;
; a compiled .exe unpacks its bundled copy with ui.html.
OpenGuideFile() {
    path := UIDir() "\guide.html"
    if !FileExist(path) {
        Notify("The user guide (guide.html) is missing" (A_IsCompiled ? "" : " - keep it next to ZoneSnap.ahk"))
        return
    }
    try Run path
    catch
        Notify("Couldn't open the user guide")
}

; Widen the ZoneSnap window by the guide panel's width when it opens (staying on its
; monitor), and give the width back when it closes. A maximised window is left as is.
ResizeForGuide(open, width) {
    global UiGuideW
    if !IsObject(UiGui)
        return
    hwnd := UiGui.Hwnd
    if WinGetMinMax(hwnd) != 0 {
        UiGuideW := 0
        return
    }
    WinGetPos &x, &y, &w, &h, hwnd
    scale := A_ScreenDPI / 96
    if open {
        if UiGuideW
            return
        add := Round(width * scale)
        ; the work area of the monitor the window is on
        mon := MonitorAt(x + w // 2, y + h // 2) || MonitorGetPrimary()
        MonitorGetWorkArea mon, &ml, &mt, &mr, &mb
        nw := Min(w + add, mr - ml)
        nx := x + nw > mr ? Max(ml, mr - nw) : x
        UiGuideW := nw - w
        if UiGuideW > 0
            WinMove nx, y, nw, h, hwnd
    } else if UiGuideW {
        WinMove x, y, Max(w - UiGuideW, 820 * scale), h, hwnd
        UiGuideW := 0
    }
}

FileUrl(path) {
    buf := Buffer(4096 * 2, 0), len := 4096
    if DllCall("shlwapi\UrlCreateFromPathW", "str", path, "ptr", buf, "uint*", &len, "uint", 0) >= 0
        return StrGet(buf)
    return "file:///" StrReplace(path, "\", "/")
}

ArgbFor(hex) {      ; COREWEBVIEW2_COLOR {A, R, G, B} as one uint
    r := Integer("0x" SubStr(hex, 1, 2)), g := Integer("0x" SubStr(hex, 3, 2)), b := Integer("0x" SubStr(hex, 5, 2))
    return 0xFF | (r << 8) | (g << 16) | (b << 24)
}

UiSize(w, minMax, *) {
    if minMax != -1 && IsObject(UiCtl)
        try UiCtl.Fill()
}

CloseUI() {
    global UiGui, UiCtl, UiView, UiToken, UiWelcome
    CaptureHotkeys(false)
    try UiView.remove_WebMessageReceived(UiToken)
    try UiCtl.Close()
    UiView := "", UiCtl := "", UiToken := 0, UiWelcome := ""
    global UiGuideW := 0
    if IsObject(UiGui)
        try UiGui.Destroy()
    UiGui := ""
}

; Messages arrive on a WebView2 callback - handle them on ZoneSnap's own thread
OnUiMessage(sender, args) {
    try raw := args.WebMessageAsJson
    catch
        return
    SetTimer(HandleUiMessage.Bind(raw), -1)
}

; (never name a variable "json" here: AutoHotkey names ignore case, so it would hide the JSON class)
HandleUiMessage(raw) {
    global ActiveLayout, UiPendingToast, ImportFile
    try msg := JSON.parse(raw, false, false)
    catch
        return
    if !IsObject(msg) || !msg.HasOwnProp("type")
        return
    switch msg.type {
        case "ready":
            PushUiState(UiPendingPage, UiPendingToast)
            UiPendingToast := ""
        case "saveLayout":
            ; layout: "Normal" (Default), "Gaming", "ws:<workspace>" or "game:<game.exe>"
            list := ZonesFromUi(msg.HasOwnProp("zones") ? msg.zones : "")
            if !list.Length
                return PushUiState(, "A layout needs at least one zone")
            target := msg.HasOwnProp("layout") ? String(msg.layout) : "Normal"
            gz := msg.HasOwnProp("gameZone") && IsInteger(msg.gameZone) && msg.gameZone >= 1
                && msg.gameZone <= list.Length ? Integer(msg.gameZone) : 0
            if target = "Gaming" {
                SaveZones(list, "GamingZones")
                if gz
                    IniWrite gz, IniFile, "GamingMode", "GameZone"
                what := "the Gaming layout"
            } else if SubStr(target, 1, 3) = "ws:" && HasValue(WSList(), SubStr(target, 4)) && SubStr(target, 4) != "Gaming" {
                ws := SubStr(target, 4)
                SaveZones(list, "WSZones:" ws)
                IniWrite gz, IniFile, WSSection(ws), "GameZone"
                what := ws "'s layout"
            } else if SubStr(target, 1, 5) = "game:" && HasValue(GameExes(), SubStr(target, 6)) {
                exe := SubStr(target, 6)
                SaveZones(list, GameLayoutSection(exe))
                IniWrite gz ? gz : LayoutGameZone(GameLayoutSection(exe), list), IniFile, GameLayoutSection(exe), "GameZone"
                what := GameName(exe) "'s layout"
            } else {
                SaveZones(list, "Zones")
                what := "the Default layout"
            }
            ActiveLayout := WSLayoutSection(ActiveWS)
            if GamingOn
                RefreshGameLayout()
            else
                ReloadZonesLive()
            PushUiState(, "Saved to " what)
        case "gameLayout":
            exe := msg.HasOwnProp("exe") ? Trim(String(msg.exe)) : ""
            own := msg.HasOwnProp("own") && msg.own
            SetGameOwnLayout(exe, own)
            PushUiState(, own ? GameName(exe) " has its own layout - edit it on the Zones page" : GameName(exe) " uses the Gaming layout")
        case "preview":
            list := ZonesFromUi(msg.HasOwnProp("zones") ? msg.zones : "")
            if list.Length
                PreviewZones(list)
        case "saveSettings":
            if msg.HasOwnProp("settings")
                ApplyUiSettings(msg.settings)
            PushUiState()                       ; (the page says Saved, with Undo)
        case "appZone", "appCommand", "appRemove":
            UpdateAppFromUi(msg)
            PushUiState()
        case "wsCreate":
            nm := msg.HasOwnProp("name") ? Trim(String(msg.name)) : ""
            if !ValidWSName(nm)
                return PushUiState(, "Please use a name up to 40 characters, without [ ] | or =, other than Default or Gaming")
            if HasValue(WSList(), nm)
                return PushUiState(, "There's already a workspace called " nm)
            list := WSList(), list.Push(nm)
            SaveWSOrder(list)
            IniWrite 0, IniFile, WSSection(nm), "GameZone"      ; (makes its section)
            UpdateTray()
            PushUiState(, nm " workspace created")
        case "wsDelete":
            nm := msg.HasOwnProp("name") ? String(msg.name) : ""
            if nm = "Gaming" || !HasValue(WSList(), nm)
                return
            if ActiveWS = nm
                SwitchWorkspace("")
            try IniDelete IniFile, WSSection(nm)
            try IniDelete IniFile, "WSZones:" nm
            list := []
            for ws in WSList()
                if ws != nm
                    list.Push(ws)
            SaveWSOrder(list)
            RegisterWSHotkeys()
            UpdateTray()
            PushUiState(, nm " workspace deleted")
        case "wsRename":
            old := msg.HasOwnProp("name") ? String(msg.name) : "", new := msg.HasOwnProp("to") ? Trim(String(msg.to)) : ""
            why := RenameWorkspace(old, new)
            PushUiState(, why != "" ? why : old " is now called " new)
        case "wsDuplicate":
            src := msg.HasOwnProp("name") ? String(msg.name) : "", new := msg.HasOwnProp("to") ? Trim(String(msg.to)) : ""
            why := DuplicateWorkspace(src, new)
            PushUiState(, why != "" ? why : new " created as a copy of " src)
        case "wsOrder":
            names := []
            if msg.HasOwnProp("names") && IsObject(msg.names)
                for nm in msg.names
                    names.Push(String(nm))
            OrderWorkspaces(names)
            PushUiState()
        case "wsUpdate":
            nm := msg.HasOwnProp("name") ? String(msg.name) : ""
            if !HasValue(WSList(), nm) || !msg.HasOwnProp("opts") || !IsObject(msg.opts)
                return
            UpdateWorkspace(nm, msg.opts)
            PushUiState()
        case "wsActivate":
            nm := msg.HasOwnProp("name") ? String(msg.name) : ""
            if nm = "" || HasValue(WSList(), nm)
                SwitchWorkspace(nm)
            PushUiState()
        case "setHotkey":
            target := msg.HasOwnProp("id") ? String(msg.id) : ""
            hk := msg.HasOwnProp("key") ? String(msg.key) : ""
            why := SetHotkey(target, hk)
            if why != ""
                return PushUiState(, why)
            a := HotkeyAction(target)
            PushUiState(, hk = "" ? "Shortcut removed" : "Set to " HotkeyLabel(NormHK(hk), IsObject(a) && a.mods))
        case "resetHotkeys":
            cleared := ResetHotkeys()
            PushUiState(, "Shortcuts back to their defaults" (cleared = "" ? "" : " (" cleared " lost its key, which is a default again)"))
        case "hotkeyCapture":
            CaptureHotkeys(msg.HasOwnProp("on") && msg.on)
        case "normalZone":
            if msg.HasOwnProp("win") && msg.HasOwnProp("zone") && IsInteger(msg.zone)
                SetNormalZone(String(msg.win), Integer(msg.zone))
            PushUiState()
        case "appGameKind":
            if msg.HasOwnProp("exe")
                SetGameKind(String(msg.exe), msg.HasOwnProp("game") && msg.game ? true : false)
            PushUiState()
        case "gameAdd":
            why := AddGame(msg.HasOwnProp("exe") ? String(msg.exe) : "")
            PushUiState(, why != "" ? why : Trim(String(msg.exe)) " added as a game - auto gaming mode will watch for it")
        case "runningPrograms":
            try UiView.PostWebMessageAsJson(ToJson({type: "running", list: RunningPrograms()}))
        case "appPlace":
            if msg.HasOwnProp("ws") && msg.HasOwnProp("win") && msg.HasOwnProp("zone") && IsInteger(msg.zone)
                PlaceApp(String(msg.ws), String(msg.win), Integer(msg.zone))
            PushUiState()
        case "appFindShortcut":
            why := FindAppShortcut(msg.HasOwnProp("win") ? String(msg.win) : "")
            PushUiState(, why != "" ? why : "Now opens the installed app")
        case "appRename":
            if msg.HasOwnProp("win")
                SetAppLabel(String(msg.win), msg.HasOwnProp("name") ? String(msg.name) : "")
            PushUiState()
        case "normalAppCommand":
            if msg.HasOwnProp("win")
                SetAppCommandAll(String(msg.win), msg.HasOwnProp("cmd") ? String(msg.cmd) : "")
            PushUiState()
        case "normalAppRemove":
            if msg.HasOwnProp("win")
                RemoveAppAll(String(msg.win))
            PushUiState()
        case "wsPolicy":
            pol := msg.HasOwnProp("policy") ? String(msg.policy) : ""
            if pol = "leave" || pol = "minimise" || pol = "close"
                IniWrite pol, IniFile, "Settings", "WorkspaceSwitch"
            PushUiState()
        case "checkUpdates":
            CheckForUpdates(true)
        case "skipUpdate":
            SkipUpdate()
            PushUiState(, "Update skipped - you'll hear about the next one")
        case "openRelease":
            OpenReleasePage()
        case "installUpdate":
            InstallUpdate()
        case "openWhatsNew":
            OpenWhatsNew()
        case "dismissUpdated":
            DismissUpdated()
        case "exportSettings":
            ExportSettings(msg.HasOwnProp("what") && msg.what = "zones" ? "zones" : "all")
        case "importPick":
            ImportPick()
        case "importApply":
            ImportApply(msg.HasOwnProp("mode") && msg.mode = "all" ? "all" : "zones")
        case "importCancel":
            ImportFile := ""
        case "openGuide":
            OpenGuideFile()
        case "guidePanel":
            ResizeForGuide(msg.HasOwnProp("open") && msg.open, msg.HasOwnProp("width") && IsNumber(msg.width) ? Integer(msg.width) : 420)
        case "openFile":
            Run IniFile
        case "restartAdmin":
            RunAsAdmin()
        case "accentPreview":           ; the colour being chosen: title bar only, nothing saved ("" puts it back)
            if IsObject(UiGui)
                StyleCaption(UiGui.Hwnd, msg.HasOwnProp("hex") && String(msg.hex) ~= "^[0-9A-Fa-f]{6}$" ? String(msg.hex) : "")
        case "profileSwitch":
            SwitchProfile(msg.HasOwnProp("name") ? String(msg.name) : "")
        case "profileCreate":
            why := CreateProfile(msg.HasOwnProp("name") ? String(msg.name) : "")
            PushUiState(, why)                  ; (on success ZoneSnap has restarted)
        case "profileRename":
            old := msg.HasOwnProp("name") ? String(msg.name) : "", new := msg.HasOwnProp("to") ? Trim(String(msg.to)) : ""
            why := RenameProfile(old, new)
            PushUiState(, why != "" ? why : "Profile renamed to " new)
        case "profileDelete":
            nm := msg.HasOwnProp("name") ? String(msg.name) : ""
            why := DeleteProfile(nm)
            PushUiState(, why != "" ? why : "Profile " nm " deleted")
    }
}

ZonesFromUi(arr) {
    list := []
    if !(arr is Array)
        return list
    for z in arr {
        try {
            zx := Integer(z.x), zy := Integer(z.y), zw := Integer(z.w), zh := Integer(z.h)
            if zw > 0 && zh > 0
                list.Push({x: zx, y: zy, w: zw, h: zh})
        }
    }
    return list
}

ReloadZonesLive() {
    LoadConfig()
    BuildOverlays()
    if DimOn
        BuildDim()
    UpdateTray()
}

PreviewZones(list) {
    global Zones
    saved := Zones
    Zones := FitZones(list)
    BuildOverlays()
    ShowOverlays()
    Zones := saved
    SetTimer EndPreview, -2000
}

EndPreview() {
    HideOverlays()
    BuildOverlays()
}

ApplyUiSettings(st) {
    global AutoOn, DragKey
    if !IsObject(st)
        return
    Has(key) => st.HasOwnProp(key)
    if Has("startWithWindows") && (st.startWithWindows ? 1 : 0) != (FileExist(StartupLink) != "" ? 1 : 0)
        ToggleStartup()
    if Has("autoGaming") {
        AutoOn := st.autoGaming ? true : false
        IniWrite AutoOn ? 1 : 0, IniFile, "GamingMode", "AutoGaming"
    }
    if Has("dragKey") {
        newDrag := String(st.dragKey)
        if newDrag != "" && newDrag != DragKey {
            try {
                Hotkey newDrag, DragWindow, "On"
                try Hotkey DragKey, "Off"
                DragKey := newDrag
                IniWrite newDrag, IniFile, "Settings", "DragHotkey"
            } catch
                Notify("Couldn't set that drag shortcut - keeping the current one")
        }
    }
    if Has("lockBottomMargin") && IsNumber(st.lockBottomMargin)
        IniWrite Max(0, Min(20, Integer(st.lockBottomMargin))), IniFile, "GamingMode", "LockBottomMargin"
    if Has("dimOpacity") && IsNumber(st.dimOpacity)
        IniWrite Max(0, Min(255, Integer(st.dimOpacity))), IniFile, "GamingMode", "DimOpacity"
    if Has("theme") && HasValue(["system", "light", "dark"], String(st.theme)) && String(st.theme) != ThemePref() {
        IniWrite String(st.theme), IniFile, "Settings", "Theme"
        ApplyThemeNow()
    }
    if Has("accentMode") && HasValue(["teal", "windows", "custom"], String(st.accentMode)) && String(st.accentMode) != AccentMode() {
        IniWrite String(st.accentMode), IniFile, "Settings", "AccentMode"
        ApplyThemeNow()
    }
    if Has("accentCustom") && String(st.accentCustom) ~= "^[0-9A-Fa-f]{6}$" && StrUpper(st.accentCustom) != AccentCustom() {
        IniWrite StrUpper(st.accentCustom), IniFile, "Settings", "AccentCustom"
        ApplyThemeNow()
    }
    if Has("updateCheck")
        IniWrite st.updateCheck ? 1 : 0, IniFile, "Settings", "UpdateCheck"
    for key in ["gameZone", "autoHideTaskbar", "lockCursor", "dimSides"]      ; (older pages)
        if Has(key)
            UpdateWorkspace("Gaming", {%key%: st.%key%})
    ReloadZonesLive()
}

; Change a workspace's options; if it's active, apply them straight away
UpdateWorkspace(ws, opts) {
    global ActiveLayout
    sec := WSSection(ws)
    has(key) => opts.HasOwnProp(key)
    if has("gameZone") && IsNumber(opts.gameZone)
        IniWrite Max(0, Integer(opts.gameZone)), IniFile, sec, "GameZone"
    for key in ["autoHideTaskbar", "lockCursor", "dimSides"]
        if has(key)
            IniWrite opts.%key% ? 1 : 0, IniFile, sec, StrUpper(SubStr(key, 1, 1)) SubStr(key, 2)
    if has("hotkey") && ws != "Gaming" {
        if (why := SetHotkey("ws:" ws, String(opts.hotkey))) != ""
            Notify(why)
    }
    if ws = "Gaming" {
        if has("autoGaming")
            ApplyUiSettings({autoGaming: opts.autoGaming})
        if has("autoBorderless") {
            IniWrite opts.autoBorderless ? 1 : 0, IniFile, "GamingMode", "AutoBorderless"
            if !opts.autoBorderless && GamingOn
                RestoreGameFrames()
        }
    }
    if ws = ActiveWS {                      ; apply to the running workspace
        if has("autoHideTaskbar")
            ApplyAutoHide(opts.autoHideTaskbar && !TaskbarOnSide())
        ActiveLayout := WSLayoutSection(ws)
        LoadConfig()
        BuildOverlays()
        SetLock(WSOpt(ws, "LockCursor") && GameZoneN ? true : false)
        SetDim(WSOpt(ws, "DimSides") ? true : false)
    }
    UpdateTray()
}

UpdateAppFromUi(msg) {
    key := msg.HasOwnProp("key") ? String(msg.key) : ""
    ws := msg.HasOwnProp("ws") ? String(msg.ws) : "Gaming"
    if !(key ~= "^App\d{1,2}$") || !HasValue(WSList(), ws)
        return
    sec := WSSection(ws)
    v := IniRead(IniFile, sec, key, "")
    parts := StrSplit(v, "|", " `t", 3)
    if v = "" || parts.Length < 2
        return
    zone := parts[1], cmd := parts.Length = 3 ? parts[3] : ""
    switch msg.type {
        case "appRemove":
            try IniDelete IniFile, sec, key
            return
        case "appZone":
            if msg.HasOwnProp("zone") && IsInteger(msg.zone) && msg.zone >= 0
                zone := Integer(msg.zone)
        case "appCommand":
            cmd := msg.HasOwnProp("cmd") ? Trim(String(msg.cmd)) : cmd
    }
    IniWrite zone "|" parts[2] "|" cmd, IniFile, sec, key
    ; moved while its workspace is on: move the open window too
    if msg.type = "appZone" && zone >= 1 && ws = ActiveWS && (hwnd := FindWin(parts[2]))
        SnapTo(hwnd, GamingOn ? MapAppZone(zone) : zone)
    SyncAppList()
}

PushUiQuiet() => PushUiState()

PushUiState(page := "", toastText := "") {
    if !IsObject(UiView)
        return
    global UiGuidePending
    st := UiState()
    st.page := page, st.toast := toastText
    st.openGuide := UiGuidePending ? 1 : 0
    UiGuidePending := false
    try UiView.PostWebMessageAsJson(ToJson(st))
}

UiState() {
    th := Theme()
    MonitorGet MonitorGetPrimary(), &mL, &mT, &mR, &mB
    workspaces := []
    for ws in WSList() {
        lay := WSLayoutSection(ws)
        workspaces.Push({name: ws, builtin: ws = "Gaming" ? 1 : 0, active: ws = ActiveWS ? 1 : 0,
            ownLayout: lay != "Zones" ? 1 : 0, zones: ReadZones(lay), gameZone: WSOpt(ws, "GameZone"),
            autoHideTaskbar: WSOpt(ws, "AutoHideTaskbar"), lockCursor: WSOpt(ws, "LockCursor"),
            dimSides: WSOpt(ws, "DimSides"),
            hotkey: ws = "Gaming" ? HotkeyFor("Gaming") : NormHK(IniRead(IniFile, WSSection(ws), "Hotkey", "")),
            apps: AppsForUi(ws)})
    }
    keys := []
    for row in [[DragLabel(), "Move any window and snap it to a zone (change the key in General)"],
            ["Shift while dragging a title bar", "Show zones and snap on release"],
            ["Windows key / Alt+Tab", "Leave the game: the cursor is free until you click the game"],
            ["Hover a dimmed pane", "Shows a pin button to keep that pane lit"]]
        keys.Push(row)
    bindings := []
    for a in HotkeyActions()
        bindings.Push({id: a.id, what: a.what, mods: a.mods, key: HotkeyFor(a.id), def: a.def})
    games := [], seen := Map()
    for exe in GameExes() {
        if seen.Has(StrLower(exe))
            continue
        seen[StrLower(exe)] := 1
        label := AppLabel("ahk_exe " exe), auto := RegExReplace(exe, "i)\.exe$")
        own := ReadZones(GameLayoutSection(exe))
        games.Push({exe: exe, win: "ahk_exe " exe, name: label != "" ? label : auto, auto: auto, label: label,
            ownLayout: own.Length ? 1 : 0, zones: own, gameZone: own.Length ? LayoutGameZone(GameLayoutSection(exe), own) : 0})
    }
    monitors := []
    for m in MonitorList()
        monitors.Push({n: m.n, name: m.name, x: m.l, y: m.t, w: m.w, h: m.h, primary: m.primary ? 1 : 0})
    return {type: "state", version: ZS_VERSION, override: GamingOverride, games: games,
        profiles: {active: ActiveProfile, list: ProfileList()},
        bindings: bindings, taskbarEdge: TaskbarEdge(),
        monitors: monitors,
        theme: {dark: th.dark ? 1 : 0, accent: AccentColor()},         ; accent: your Windows accent colour
        monitor: {x: mL, y: mT, w: mR - mL, h: mB - mT},
        activeLayout: ActiveLayoutLabel(), activeWS: ActiveWS,
        gamingOn: GamingOn ? 1 : 0,
        workspaces: workspaces, workspaceSwitch: IniRead(IniFile, "Settings", "WorkspaceSwitch", "leave"),
        catalog: CatalogForUi(),
        update: IsObject(UpdateInfo) ? {version: UpdateInfo.version, url: UpdateInfo.url,
            canInstall: CanSelfUpdate() ? 1 : 0, state: UpdateInfo.state} : {version: ""},
        justUpdated: JustUpdated, updatedFrom: UpdatedFrom,
        layouts: {Normal: ReadZones("Zones"), Gaming: ReadZones("GamingZones")},
        settings: {startWithWindows: FileExist(StartupLink) != "" ? 1 : 0,
            dragKey: DragKey, lockBottomMargin: GSInt("LockBottomMargin", 2),
            dimOpacity: GSInt("DimOpacity", 170), theme: ThemePref(),
            accentMode: AccentMode(), accentCustom: AccentCustom(),
            updateCheck: IniRead(IniFile, "Settings", "UpdateCheck", "1") = "1" ? 1 : 0},
        autoGaming: AutoOn ? 1 : 0,
        autoBorderless: GSInt("AutoBorderless", 1) ? 1 : 0,
        hotkeys: keys, welcome: UiWelcome}
}

; Minimal JSON writer (numbers stay numbers, everything else is a string)
ToJson(v) {
    if IsObject(v) {
        out := ""
        if v is Array {
            for item in v
                out .= (out = "" ? "" : ",") ToJson(item)
            return "[" out "]"
        }
        for k, val in (v is Map ? v : v.OwnProps())
            out .= (out = "" ? "" : ",") ToJson(String(k)) ":" ToJson(val)
        return "{" out "}"
    }
    if v is Number
        return String(v)
    s := StrReplace(v, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return '"' s '"'
}
