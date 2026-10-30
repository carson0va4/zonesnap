; ============================================================================
;  ZoneSnap - Tray
;  The tray menu, Start with Windows, Restart as administrator, and clean-up on exit.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Tray menu
; ---------------------------------------------------------------------------
BuildTray() {
    A_IconTip := "ZoneSnap"
    global TrayActiveName
    A_TrayMenu.Delete()
    TrayActiveName := ActiveTrayLabel()
    A_TrayMenu.Add(TrayActiveName, (*) => 0)
    A_TrayMenu.Disable(TrayActiveName)
    A_TrayMenu.Add()
    A_TrayMenu.Add(M_GAME, (*) => ToggleGaming())
    A_TrayMenu.Add("Workspaces", WSMenu)
    A_TrayMenu.Add("Profile", ProfileMenu)
    A_TrayMenu.Add(M_LOCK, (*) => SetLock(!LockOn))
    A_TrayMenu.Add(M_DIM,  (*) => SetDim(!DimOn))
    A_TrayMenu.Add(M_AUTO, (*) => ToggleAuto())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Settings...", (*) => OpenUI("general"))
    A_TrayMenu.Add(M_EDIT, (*) => OpenUI("zones"))
    A_TrayMenu.Add("Show zones", (*) => FlashZones())
    A_TrayMenu.Add("Hotkeys...", (*) => OpenUI("hotkeys"))
    A_TrayMenu.Add("User guide", (*) => OpenGuide())
    A_TrayMenu.Add("Check for updates", (*) => CheckForUpdates(true))
    A_TrayMenu.Add(M_BOOT, (*) => ToggleStartup())
    A_TrayMenu.Add("Open settings file", (*) => Run(IniFile))
    A_TrayMenu.Add("Restart as administrator", (*) => RunAsAdmin())
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "Settings..."
    UpdateTray()
}

ActiveTrayLabel() => "Active: " (ActiveWS = "" ? "Default" : ActiveWS)

; "Default", "Gaming" or the active workspace's name
ActiveLayoutLabel() => ActiveWS = "" ? "Default" : ActiveWS

UpdateTray() {
    global TrayActiveName
    if TrayActiveName != "" && (newName := ActiveTrayLabel()) != TrayActiveName {
        try A_TrayMenu.Rename(TrayActiveName, newName)
        TrayActiveName := newName
    }
    SetCheck(M_GAME, GamingOn)
    SetCheck(M_LOCK, LockOn)
    SetCheck(M_DIM, DimOn)
    SetCheck(M_AUTO, AutoOn)
    UpdateWSMenu()
    UpdateProfileMenu()
    UpdateTrayUpdateItem()
    SetCheck(M_BOOT, FileExist(StartupLink) != "")
    if IsObject(UiView)
        SetTimer PushUiQuiet, -250       ; keep an open ZoneSnap window in step
    A_IconTip := "ZoneSnap - " (ActiveWS = "" ? "Default" : ActiveWS)
        . (GamingOverride != "" ? " (" GameName(GamingOverride) ")" : "")
        . (ProfileList().Length > 1 ? " - " ActiveProfile : "")
}

SetCheck(name, on) {
    try {
        if on
            A_TrayMenu.Check(name)
        else
            A_TrayMenu.Uncheck(name)
    }
}

RunAsAdmin() {
    if A_IsAdmin {
        MsgBox "ZoneSnap is already running as administrator.", "ZoneSnap"
        return
    }
    try {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '" /restart'
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        ExitApp
    }
}

Cleanup(*) {
    if Clipped
        DllCall("ClipCursor", "ptr", 0)
    if PrevAutoHide != -1
        SetTaskbarAutoHide(PrevAutoHide)
}

; Tray "Workspaces" submenu: one item per workspace, ticked when active
UpdateWSMenu() {
    try WSMenu.Delete()
    WSMenu.Add("Default", (*) => SwitchWorkspace(""))
    if ActiveWS = ""
        WSMenu.Check("Default")
    WSMenu.Add()
    for ws in WSList() {
        hk := HotkeyLabel(ws = "Gaming" ? HotkeyFor("Gaming") : IniRead(IniFile, WSSection(ws), "Hotkey", ""))
        label := ws (hk != "" ? "`t" hk : "")
        WSMenu.Add(label, ToggleWorkspace.Bind(ws))
        if ws = ActiveWS
            WSMenu.Check(label)
    }
}

; ---------------------------------------------------------------------------
; Start with Windows: a shortcut in your Startup folder (no admin, no registry)
; ---------------------------------------------------------------------------
ToggleStartup() {
    if FileExist(StartupLink) {
        try FileDelete StartupLink
        Notify("ZoneSnap won't start with Windows")
    } else if MakeStartupLink() {
        Notify("ZoneSnap will start with Windows")
    } else {
        Notify("Couldn't create the startup shortcut")
    }
    UpdateTray()
}

MakeStartupLink() {
    try {
        if A_IsCompiled
            FileCreateShortcut A_ScriptFullPath, StartupLink, A_ScriptDir, , "ZoneSnap window zones"
        else
            FileCreateShortcut A_AhkPath, StartupLink, A_ScriptDir, '"' A_ScriptFullPath '"', "ZoneSnap window zones"
        return true
    }
    return false
}
