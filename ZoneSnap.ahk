; ============================================================================
;  ZoneSnap - window zones for ultrawide monitors, for work and play
;  AutoHotkey v2. User guide: guide.html (F1 in the ZoneSnap window). Developer
;  notes: README.md and the comments at the top of each section below.
;
;  Files that belong together: ZoneSnap.ahk, ZoneSnap.ico, the src folder (the rest
;  of the code, below), ui.html (the ZoneSnap window), guide.html (the user guide) and
;  the Lib folder (WebView2 and JSON). To compile: keep them all next to this script
;  and use Ahk2Exe with the 64-bit v2 base; the .exe carries everything inside it.
;  Settings: %APPDATA%\ZoneSnap\profiles\<profile>\ZoneSnap.ini (see src\Profiles.ahk).
; ----------------------------------------------------------------------------
;  WHAT IT DOES
;    Zones          Alt+drag any window (even a borderless game) onto a zone, or
;                   Shift while dragging a title bar, or Ctrl+Alt+1..9.
;    Workspaces     Saved setups switched on in one go: a layout, apps to open and
;                   snap, taskbar auto-hide, cursor lock, dimming. Gaming mode is the
;                   built-in Gaming workspace and switches on when a game starts.
;    Games          Made borderless and fitted to the game zone in gaming mode;
;                   per-game layouts; the cursor locked to the game.
;    ZoneSnap window  Zones, Workspaces, Apps, General and Hotkeys pages, plus the
;                   user guide in a side panel. Every keyboard shortcut can be changed.
;  Default shortcuts (rebindable on the Hotkeys page): Ctrl+Alt+G gaming mode,
;  Ctrl+Alt+Z zones, Ctrl+Alt+1..9 send to zone, Ctrl+Alt+A add app, Ctrl+Alt+L
;  cursor lock, Ctrl+Alt+F free the cursor, Ctrl+Alt+D dimming, Ctrl+Alt+U and
;  Ctrl+Alt+Shift+1..9 keep a pane lit, Ctrl+Alt+B borders, Ctrl+Alt+Space the quick
;  switcher.
; ----------------------------------------------------------------------------
;  WHERE THINGS ARE
;    ZoneSnap.ahk         globals, start-up, and the files bundled into the .exe
;    src\Profiles.ahk     where settings live; profiles (separate setups) and switching
;    src\Config.ahk       first-run defaults and shared helpers
;    src\Zones.ahk        zone storage, monitors, taskbar fitting, layout sections
;    src\Snapping.ahk     drag overlays, Alt+drag, snapping windows into zones
;    src\Workspaces.ahk   switching workspaces on/off, putting windows back
;    src\Apps.ahk         the shared app list, Default zones, Ctrl+Alt+A
;    src\Games.ahk        what's a game, auto gaming mode, per-game layouts, borderless
;    src\Cursor.ahk       cursor lock, focus guard, the main timer
;    src\Dimming.ahk      dimmed side panes and keep-lit pins
;    src\Taskbar.ahk      taskbar edge, auto-hide, flash guard
;    src\Hotkeys.ahk      shortcuts and rebinding
;    src\Tray.ahk         tray menu, Start with Windows
;    src\Theme.ahk        light/dark and accent colour
;    src\Switcher.ahk     the quick switcher (Ctrl+Alt+Space)
;    src\Window.ahk       the ZoneSnap window and its messages (ui.html)
;    src\ImportExport.ahk settings export/import
;    src\Updates.ahk      update check
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
;@Ahk2Exe-SetName ZoneSnap
;@Ahk2Exe-SetDescription ZoneSnap - window zones for ultrawide monitors - for work and play
;@Ahk2Exe-SetVersion 0.39.3
;@Ahk2Exe-SetCopyright Copyright (c) 2026 carson0va4 - MIT licence
;@Ahk2Exe-SetMainIcon ZoneSnap.ico

; The ZoneSnap window: WebView2 + JSON from thqby's ahk2_lib (MIT), in the Lib folder next
; to this script. Without them ZoneSnap still runs from the tray, and says why.
#Include *i <WebView2\WebView2>
#Include *i <JSON>

DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")  ; per-monitor DPI aware: real pixels
CoordMode "Mouse", "Screen"
SetWinDelay -1

global IniFile      := ""          ; the active profile's settings file (StartProfile)
global ActiveProfile := ""         ; the profile in use (a folder in %APPDATA%\ZoneSnap\profiles)
global ProfileMenu  := Menu()      ; tray "Profile" submenu
global Zones        := []
global Overlays     := []
global DimOverlays  := []
global DimVis       := []
global LitZones     := Map()       ; zones kept undimmed (Ctrl+Alt+U / Ctrl+Alt+Shift+n)
global PinBtns      := []          ; hover pin button per dimmed zone (0 for the game zone)
global PinVis       := []
global PinTexts     := []
global OverlayInset := 8           ; gap around drag overlays so neighbouring zones read as separate
global AccentHex    := "3CC5B0"       ; drag overlay highlight: house GuideAccent, or your accent's highlight shade
global ZS_VERSION   := "0.39.3"   ; 0.x = beta; 1.0.0 once it is tested and stable
global ZS_REPO      := "carson0va4/zonesnap"   ; where releases are published (update check)
global UiGui := "", UiCtl := "", UiView := "", UiToken := 0, UiStarting := false
global UiPendingPage := "general", UiWelcome := ""
global UiGuidePending := false, UiGuideW := 0   ; open the guide panel on the next state push; px the window grew for it
global UiPendingToast := ""                    ; message for the ZoneSnap window's first state push (after an import)
global ImportFile := ""                        ; settings file picked for import, waiting for you to choose what to bring in
global BorderlessDone := Map()         ; game windows ZoneSnap has made borderless (hwnd -> true)
global GameHomes := Map()              ; in gaming mode, where each game window belongs: hwnd -> {z, fixes, gaveUp}
global GamingFrames := Map()           ; games made borderless only for gaming mode: hwnd -> {style, ex} to put back
global GamingOverride := ""             ; profile used instead of the Gaming layout for this session (per-game)
global DragKey      := "!LButton"
global ActiveLayout := "Zones"      ; "Zones" = normal layout, "GamingZones" = gaming layout
global GameZoneN    := 0
global GameRaw      := ""           ; the active layout's game zone as saved (FitZones keeps its size)
global LockMargin   := 2            ; px kept clear of the taskbar's edge while cursor lock is active
global FreeMode     := false        ; cursor lock temporarily released (still kept off the taskbar's edge)
global FreeFrom     := 0            ; the game window focus was taken from when freeing the cursor
global GameHwnd     := 0            ; the game window the cursor is locked to (set when it's first focused)
global LastSwitchKey := -100000     ; A_TickCount of your last Windows key / Alt+Tab / click outside the game
global StealTimes   := []           ; recent times focus was taken back from another window (focus guard)
global GamingOn     := false        ; the Gaming workspace is active
global ActiveWS     := ""           ; active workspace ("" = none, Normal layout)
global PrevWS       := ""           ; workspace to return to when an auto-started game closes
global WSHotkeys    := Map()        ; registered workspace hotkey -> workspace name
global ActionKeys   := Map()        ; keys registered for ZoneSnap's own shortcuts (Hotkeys page)
global WSMenu       := Menu()       ; tray "Workspaces" submenu
global UpdateInfo   := ""           ; {version, url, exe: {url, sha256, size} or "", state} when a newer release is available
global UpdateReq    := ""           ; in-flight update check
global TrayUpdateName := ""
global UpdateDl     := ""           ; Update now's download while it runs: {req, started}
global JustUpdated  := ""           ; the version Update now just installed (until you dismiss the note)
global UpdatedFrom  := ""           ; ...and the version it replaced, read from the old .exe
global LockOn       := false
global DimOn        := false
global Dragging     := false
global Clipped      := false
global PrevAutoHide := -1
global Pending      := []           ; apps whose windows we are waiting to snap
global RawZones     := []           ; zones as saved (full-screen pixels)
global Snapped      := Map()        ; hwnd -> saved zone rectangle it was placed in (survives layout switches)
global Before       := Map()        ; hwnd -> where a workspace's app was before it switched on (put back on return to Normal)
global LastWA       := ""           ; last seen usable screen area (changes when taskbar shows/hides)
global LastMonKey   := ""           ; last seen monitor arrangement (changes on plug/unplug/resolution)
global Switcher     := ""           ; the quick switcher while it's open: {gui, lb, names}
global ZoneOrigin   := Map()        ; "x,y,w,h" -> saved line, for zones placed on a stand-in monitor

; tray item names; RegisterActionHotkeys renames them with your own shortcuts
global M_GAME := "Gaming mode", M_LOCK := "Cursor lock", M_DIM := "Dim side panes", M_EDIT := "Edit zones"
global TrayActiveName := ""
global M_AUTO := "Auto gaming mode (when a game starts)"
global M_BOOT := "Start with Windows"
global StartupLink := A_Startup "\ZoneSnap.lnk"

global AutoOn          := true    ; switch gaming mode on/off when a game starts/exits
global AutoStarted     := false   ; gaming mode was switched on automatically
global PrevGameRunning := false

global FirstRunInfo := ""             ; set on a brand-new install (or profile): what layout was created
MovedNote := StartProfile()           ; picks the profile, and sets IniFile
if !FileExist(IniFile)
    FirstRunInfo := WriteDefaults()
EnsureGamingSection()
MigrateLayouts()   ; saved layouts ("profiles", before 0.37.0) -> each workspace's and game's own
TidyOldSettings()  ; settings for features that have been removed
FinishUpdate()     ; after Update now: tidy up the old .exe and note the new version
SyncAppList()      ; the shared app list ([Apps]), filled in from older settings if need be
LoadConfig()
LastWA := WorkAreaKey()
LastMonKey := MonitorKey()
if !A_IsCompiled && FileExist(A_ScriptDir "\ZoneSnap.ico")
    TraySetIcon A_ScriptDir "\ZoneSnap.ico"      ; compiled: the icon is built into the .exe
InitTheme()
if A_IsCompiled
    PrepareUiFiles()
BuildOverlays()
RegisterHotkeys()
BuildTray()
OnExit(Cleanup)
SetTimer Tick, 100
AutoOn := GSInt("AutoGaming", 1) != 0
if FileExist(StartupLink)      ; keep the startup shortcut pointing here if the script was moved
    MakeStartupLink()
UpdateTray()
SetTimer AutoTick, 2000
SetTimer BorderlessTick, 500
RegisterWSHotkeys()
StartFlashGuard()
SetTimer () => AutoUpdateCheck(), -20000      ; first update check shortly after start
SetTimer AutoUpdateCheck, 6 * 3600 * 1000
if (imported := IniRead(IniFile, "Settings", "JustImported", "")) != "" {
    try IniDelete IniFile, "Settings", "JustImported"   ; braces: a bare "try" would claim the "else"
    UiPendingToast := "Settings imported. Your previous settings were saved as " imported
    OpenUI("general")                  ; back where you were, after the restart an import needs
} else if JustUpdated != "" {
    TrayTip "ZoneSnap was updated" (UpdatedFrom != "" ? " from " UpdatedFrom : "") " to " ZS_VERSION ". Your settings carried over.", "ZoneSnap update", 1
} else if FirstRunInfo != "" {
    OpenUI("general", FirstRunInfo)    ; first run: welcome + what was set up
} else if MovedNote != "" {
    TrayTip MovedNote ". Your old settings file was kept as ZoneSnap.ini.old.", "ZoneSnap", 1
} else {
    TrayTip DragLabel() " moves windows onto zones. " KeyText("Gaming") " toggles gaming mode."
        . (ProfileList().Length > 1 ? " Profile: " ActiveProfile : ""), "ZoneSnap", 1
}

; ---------------------------------------------------------------------------
; Files bundled into the .exe. This stays in ZoneSnap.ahk: Ahk2Exe looks for FileInstall
; sources next to the main script.
; ---------------------------------------------------------------------------
; Compiled: unpack the page and the WebView2 loader next to ZoneSnap's data (refreshed each start)
PrepareUiFiles() {
    dir := UIDir()
    try DirCreate dir
    ; Ahk2Exe only bundles a file when the line STARTS with FileInstall - never write
    ; "try FileInstall ...", or the file is silently left out of the .exe
    try {
        FileInstall "ui.html", dir "\ui.html", 1
    }
    try {
        FileInstall "guide.html", dir "\guide.html", 1
    }
    try {
        FileInstall "Lib\WebView2\64bit\WebView2Loader.dll", dir "\WebView2Loader.dll", 1
    }
}

; ---------------------------------------------------------------------------
; The rest of ZoneSnap (functions and hotkeys only)
; ---------------------------------------------------------------------------
#Include %A_ScriptDir%\src\Profiles.ahk
#Include %A_ScriptDir%\src\Config.ahk
#Include %A_ScriptDir%\src\Zones.ahk
#Include %A_ScriptDir%\src\Snapping.ahk
#Include %A_ScriptDir%\src\Workspaces.ahk
#Include %A_ScriptDir%\src\Apps.ahk
#Include %A_ScriptDir%\src\Games.ahk
#Include %A_ScriptDir%\src\Cursor.ahk
#Include %A_ScriptDir%\src\Dimming.ahk
#Include %A_ScriptDir%\src\Taskbar.ahk
#Include %A_ScriptDir%\src\Hotkeys.ahk
#Include %A_ScriptDir%\src\Tray.ahk
#Include %A_ScriptDir%\src\Theme.ahk
#Include %A_ScriptDir%\src\Switcher.ahk
#Include %A_ScriptDir%\src\Window.ahk
#Include %A_ScriptDir%\src\ImportExport.ahk
#Include %A_ScriptDir%\src\Updates.ahk
