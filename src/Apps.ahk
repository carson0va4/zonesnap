; ============================================================================
;  ZoneSnap - Apps
;  The app list: the shared [Apps] list, where each workspace and the Default layout
;  put each app, names, commands, Ctrl+Alt+A, and finding an app's window.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

ReadApps(ws := "Gaming") {
    apps := []
    sec := WSSection(ws)
    Loop 30 {
        v := IniRead(IniFile, sec, "App" A_Index, "")
        if v = ""
            continue
        p := StrSplit(v, "|", " `t", 3)
        if p.Length >= 2 && IsInteger(p[1]) && p[2] != ""
            apps.Push({zone: Integer(p[1]), win: p[2], cmd: p.Length = 3 ? p[3] : ""})
    }
    return apps
}

; ---------------------------------------------------------------------------
; The app list. Every app you add (games aside) goes into one shared list, [Apps]
; <window match>=|<command> (the "|" keeps a quoted command intact: Windows strips quotes
; around a whole value). Each workspace then says where it puts the app: a zone, Don't move
; (0), or nothing (not used there). Zones on the Default layout ("Normal" in the settings
; file, from before it was renamed) are in [NormalZones].
; ---------------------------------------------------------------------------
CatalogApps() {
    out := Map()
    try sec := IniRead(IniFile, "Apps")
    catch
        return out
    for line in StrSplit(sec, "`n", "`r") {
        eq := InStr(line, "=")              ; matches never contain "=", commands can
        if eq > 1
            out[Trim(SubStr(line, 1, eq - 1))] := Trim(RegExReplace(SubStr(line, eq + 1), "^\s*\|"))
    }
    return out
}

; Put an app on the shared list (or update its command)
CatalogPut(match, cmd) {
    if SafeIniKey(match)
        IniWrite "|" cmd, IniFile, "Apps", match
}

; Make sure every app in a workspace is on the shared list, and bring over 0.29.0's
; [NormalApps]. Run at startup and after anything that adds apps.
SyncAppList() {
    cat := CatalogApps()
    try {
        for line in StrSplit(IniRead(IniFile, "NormalApps"), "`n", "`r")
            if (eq := InStr(line, "=")) > 1 && !cat.Has(m := Trim(SubStr(line, 1, eq - 1)))
                CatalogPut(m, cat[m] := Trim(RegExReplace(SubStr(line, eq + 1), "^\s*\|")))
        IniDelete IniFile, "NormalApps"
    }
    for ws in WSList() {
        gz := WSGameZone(ws)
        for app in ReadApps(ws)
            if !IsGameApp(gz, app.zone, app.win) && !cat.Has(app.win) && SafeIniKey(app.win)
                CatalogPut(app.win, cat[app.win] := app.cmd)
    }
    ; before 0.30.0, adding Steam saved the command of its web helper, which doesn't open Steam
    for match, cmd in cat
        if (fixed := SteamCmd(cmd)) != cmd
            SetAppCommandAll(match, fixed)
    ; an installed web app saved with "msedge.exe --app=<address>": that opens the website in a
    ; new window with a different app ID, so ZoneSnap can't find it to snap it. Use the installed
    ; app's own shortcut instead, when there is one.
    for match, cmd in cat
        if WebAddressCmd(match, cmd) && (fixed := AppShortcutCommand(SubStr(match, 7))) != ""
            SetAppCommandAll(match, fixed)
}

; A web app whose command opens its website rather than the installed app
WebAddressCmd(match, cmd) => SubStr(match, 1, 6) = "appid:" && cmd ~= "i)\s--app=https?:"

; ---------------------------------------------------------------------------
; Installed web apps (Edge, Chrome and the like). Each has a Windows app ID. Edge registers
; its installed apps with Windows (app IDs like "discord.com-XXXXXXXX_xxxxxxxxxxxxx!App"), so
; their Start menu entries aren't ordinary shortcut files and their taskbar pins have no
; target. Windows opens any app in its app list (shell:AppsFolder) by app ID, the same way
; the Start menu does, so that's the command ZoneSnap saves. Shortcut files with a browser
; target are the fallback (for browsers that make them).
; ---------------------------------------------------------------------------
AppShortcutCommand(aumid) {
    if aumid = "" || aumid ~= "[\x00-\x1F\x22]"
        return ""
    if InAppsFolder(aumid)
        return "explorer.exe shell:AppsFolder\" aumid
    dirs := [A_AppData "\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
        A_Programs, A_ProgramsCommon, A_Desktop]
    for dir in dirs {
        if !DirExist(dir)
            continue
        Loop Files dir "\*.lnk", "R" {
            try FileGetShortcut A_LoopFileFullPath, &target, , &args
            catch
                continue
            if target = "" || !(target ~= "i)\\(msedge|msedge_proxy|chrome|chrome_proxy|brave|vivaldi|opera)\.exe$")
                continue                        ; only browsers' app shortcuts
            id := FileAppId(A_LoopFileFullPath)
            appArg := RegExMatch(args, "i)--app-id=([a-z0-9]+)", &am) ? am[1] : ""
            if (id != "" && id = aumid) || (appArg != "" && InStr(aumid, appArg))
                return '"' target '"' (args != "" ? " " args : "")
        }
    }
    return ""
}

; Is this app ID in Windows' app list (what the Start menu shows)?
InAppsFolder(aumid) {
    try {
        for item in ComObject("Shell.Application").NameSpace("shell:AppsFolder").Items()
            if item.Path = aumid
                return true
    }
    return false
}

; Apps page: look for an installed web app's shortcut now, and use its command
FindAppShortcut(match) {
    if SubStr(match, 1, 6) != "appid:"
        return "Only web apps have an installed-app shortcut to find"
    if (cmd := AppShortcutCommand(SubStr(match, 7))) = ""
        return "Couldn't find this app in Windows' app list. Open the installed app from its taskbar pin and add it again with " KeyText("AddApp") ", or edit its command."
    SetAppCommandAll(match, cmd)
    return ""
}

; '"...\Steam\bin\cef\cef.win64\steamwebhelper.exe"' -> '"...\Steam\steam.exe"'
SteamCmd(cmd) => RegExReplace(cmd, 'i)^"(.*)\\bin\\cef\\[^"]*\\steamwebhelper\.exe"', '"$1\steam.exe"')

; The game zone the Apps page and the app list go by (only Gaming has games)
WSGameZone(ws) => ws = "Gaming" ? GSInt("GameZone", 2) : -1

; The shared app list for the Apps page: each app once, with the workspaces that use it and
; its Normal zone (0 = back where it was)
CatalogForUi() {
    out := [], nz := NormalZones(), used := Map()
    for ws in WSList()
        for a in AppsForUi(ws)
            if a.kind != "Game"
                used[a.win] := (used.Has(a.win) ? used[a.win] ", " : "") ws
    for match, cmd in CatalogApps() {
        auto := AutoAppName(match), label := AppLabel(match)
        out.Push({win: match, name: label != "" ? label : auto, auto: auto, label: label,
            kind: SubStr(match, 1, 6) = "appid:" ? "Web app" : "App", cmd: cmd,
            in: used.Has(match) ? used[match] : "", zone: nz.Has(match) ? nz[match] : -1})     ; -1 = not used in Default (back where it was)
    }
    return out
}

; A workspace's apps, for the Apps page
AppsForUi(ws) {
    apps := []
    sec := WSSection(ws)
    gz := ws = "Gaming" ? GSInt("GameZone", 2) : -1
    Loop 30 {
        v := IniRead(IniFile, sec, "App" A_Index, "")
        if v = ""
            continue
        parts := StrSplit(v, "|", " `t", 3)
        if parts.Length < 2 || !IsInteger(parts[1])
            continue
        web := SubStr(parts[2], 1, 6) = "appid:"
        game := IsGameApp(gz, Integer(parts[1]), parts[2])
        exe := ExeOf(parts[2])
        auto := AutoAppName(parts[2])
        label := AppLabel(parts[2])
        apps.Push({key: "App" A_Index, zone: Integer(parts[1]), win: parts[2],
            name: label != "" ? label : auto, auto: auto, label: label,
            kind: web ? "Web app" : (game ? "Game" : "App"),
            exe: (gz >= 1 && Integer(parts[1]) = gz) ? exe : "",     ; in the game zone: game or not is up to you
            cmd: parts.Length = 3 ? parts[3] : ""})
    }
    return apps
}

; Apps page: where a workspace puts an app. zone -1 = not used there, 0 = Don't move,
; 1+ = that zone. The app keeps its place on the shared list either way.
PlaceApp(ws, match, zone) {
    if !HasValue(WSList(), ws) || !SafeIniKey(match)
        return
    cat := CatalogApps()
    sec := WSSection(ws), gz := WSGameZone(ws)
    slot := 0, free := 0, cmd := cat.Has(match) ? cat[match] : ""
    Loop 30 {
        v := IniRead(IniFile, sec, "App" A_Index, "")
        p := StrSplit(v, "|", " `t", 3)
        if v = "" {
            if !free
                free := A_Index
        } else if p.Length >= 2 && p[2] = match && !slot {
            slot := A_Index
            if !cat.Has(match) && p.Length = 3      ; keep a command that's only in the entry
                cmd := p[3]
        }
    }
    if !cat.Has(match) && !slot
        return                                  ; not an app ZoneSnap knows
    if zone < 0 {
        if slot {
            try {
                if !cat.Has(match) && !IsGameApp(gz, Integer(StrSplit(IniRead(IniFile, sec, "App" slot), "|")[1]), match)
                    CatalogPut(match, cmd)      ; stays on the shared list
            }
            try IniDelete IniFile, sec, "App" slot
        }
        return
    }
    if !slot && !free {
        Notify("That workspace's app list is full (30).")
        return
    }
    if IsGameApp(gz, zone, match)
        cmd := ""                               ; games are detected, never launched
    IniWrite zone "|" match "|" cmd, IniFile, sec, "App" (slot ? slot : free)
    if zone >= 1 && ws = ActiveWS && (hwnd := FindWin(match))
        SnapTo(hwnd, GamingOn ? MapAppZone(zone) : zone)
}

; Every non-game app entry with this window match, as [section, key, zone, cmd]
AppEntries(match) {
    out := []
    for ws in WSList() {
        sec := WSSection(ws)
        gz := ws = "Gaming" ? GSInt("GameZone", 2) : -1
        Loop 30 {
            v := IniRead(IniFile, sec, "App" A_Index, "")
            p := StrSplit(v, "|", " `t", 3)
            if p.Length < 2 || p[2] != match || !IsInteger(p[1])
                continue
            if IsGameApp(gz, Integer(p[1]), match)
                continue                        ; that's a game entry
            out.Push([sec, "App" A_Index, p[1], p.Length = 3 ? p[3] : ""])
        }
    }
    return out
}

; [AppNames] <window match>=<name>: your own name for an app, shown instead of the automatic one
AppLabel(match) {
    if !SafeIniKey(match)
        return ""
    try return Trim(IniRead(IniFile, "AppNames", match, ""))
    return ""
}

; Name (or, with an empty name, un-name) an app in any workspace
SetAppLabel(match, name) {
    known := CatalogApps().Has(match) || HasValue(GameExes(), ExeOf(match))
    for ws in WSList()
        for a in AppsForUi(ws)
            if a.win = match
                known := true
    if !known || !SafeIniKey(match)
        return
    name := Trim(RegExReplace(name, "[\x00-\x1F\x7F]"))
    if StrLen(name) > 60
        name := SubStr(name, 1, 60)
    if name != "" && name != AutoAppName(match)
        IniWrite name, IniFile, "AppNames", match
    else
        try IniDelete IniFile, "AppNames", match
    UpdateTray()
}

; The Apps page's edit: one command for the app, everywhere it's used
SetAppCommandAll(match, cmd) {
    cmd := Trim(RegExReplace(cmd, "[\r\n]"))
    for e in AppEntries(match)
        IniWrite e[3] "|" match "|" cmd, IniFile, e[1], e[2]
    if CatalogApps().Has(match) || AppEntries(match).Length
        CatalogPut(match, cmd)
}

; The Apps page's remove: take the app off the list and out of every workspace, with its
; Normal zone and name
RemoveAppAll(match) {
    entries := AppEntries(match)
    listed := CatalogApps().Has(match)
    if !entries.Length && !listed
        return
    if listed
        try IniDelete IniFile, "Apps", match
    for e in entries
        try IniDelete IniFile, e[1], e[2]
    if SafeIniKey(match) {
        try IniDelete IniFile, "NormalZones", match
        try IniDelete IniFile, "AppNames", match
    }
    UpdateTray()
}

; Where Default puts an app: a zone (1+), Don't move (0), or not used (-1: back where it
; was, the same as having no entry); only for apps on the list
SetNormalZone(match, zone) {
    if !CatalogApps().Has(match) || !SafeIniKey(match)
        return
    if zone >= 0
        IniWrite zone, IniFile, "NormalZones", match
    else
        try IniDelete IniFile, "NormalZones", match
    ; no workspace on: move the window now
    if ActiveWS = "" && zone >= 1 && zone <= Zones.Length && (hwnd := FindWin(match))
        SnapTo(hwnd, zone)
}

AddActiveApp() {
    hwnd := WinExist("A")
    if !hwnd
        return
    try {
        exe  := WinGetProcessName(hwnd)
        path := WinGetProcessPath(hwnd)
        WinGetPos &x, &y, &w, &h, hwnd
    } catch
        return
    z := ZoneAt(x + w // 2, y + h // 2)        ; 0 = not in a zone: added as "Don't move"

    match := "ahk_exe " exe
    cmd   := '"' path '"'
    name  := exe
    ; Steam's window belongs to its web helper, deep inside the Steam folder: open Steam itself
    if exe = "steamwebhelper.exe" && RegExMatch(path, "i)^(.*)\\bin\\cef\\", &sm) && FileExist(sm[1] "\steam.exe") {
        cmd := '"' sm[1] '\steam.exe"', name := "Steam"
        if AppLabel(match) = ""
            IniWrite "Steam", IniFile, "AppNames", match
    }
    ; Browser app windows (Edge/Chrome --app, installed web apps) all share the browser's .exe,
    ; so identify them by their Windows app ID instead - it stays fixed even when the title changes.
    if exe ~= "i)^(msedge|chrome|brave|vivaldi|opera|firefox)\.exe$" {
        id := GetAppId(hwnd)
        if id = "" {
            Notify("Couldn't identify this browser window as an app - not added.")
            return
        }
        match := "appid:" id
        name  := WinGetTitle(hwnd)
        ; an app ID that doesn't name its site (a Firefox web app, say) gives a meaningless
        ; automatic name like "5e79188c", so name it after its window title instead
        ; (renamable on the Apps page)
        if AutoAppName(match) ~= "\d|^$" && AppLabel(match) = "" && SafeIniKey(match) {
            t := Trim(RegExReplace(name, "^.*\s[-|\x{2013}\x{2014}]\s"))   ; "#general | Server - Discord" -> "Discord"
            if t != ""
                IniWrite SubStr(t, 1, 60), IniFile, "AppNames", match
        }
        ; an installed app: use its own shortcut's command, so it opens as itself (and can be snapped)
        cmd := AppShortcutCommand(id)
        if cmd = "" {
            ib := InputBox("ZoneSnap couldn't find this web app in Windows' app list or the Start menu.`n"
                . "Its app ID is " id "`n`n"
                . "Paste the command that opens it, or leave it blank to only snap the app when it's already open.",
                "ZoneSnap - add app", "w620 h200", "")
            if ib.Result != "OK"
                return
            cmd := Trim(ib.Value)
        }
    }

    if !SafeIniKey(match) {
        Notify("Can't add that window - its name can't be stored.")
        return
    }
    if ActiveWS = "" {                  ; Default on: onto the list, placed in Default
        known := CatalogApps().Has(match)
        CatalogPut(match, cmd)
        IniWrite z, IniFile, "NormalZones", match       ; (0 = not in a zone: Don't move)
        Notify(name (known ? " updated" : " added") " - Default, "
            . ZoneWords(z)
            . ". It's on every workspace's list on the Apps page, ready to place.")
        PushUiQuiet()
        return
    }
    target := ActiveWS
    sec := WSSection(target)
    where := target = "Gaming" ? "gaming mode" : "the " target " workspace"
    isGame := target = "Gaming" && IsGameApp(GSInt("GameZone", 2), z, match)
    launcher := target = "Gaming" && z = GSInt("GameZone", 2) && !isGame && ExeOf(match) != ""
    if isGame
        cmd := ""       ; games are detected and snapped, never launched by gaming mode
    else
        CatalogPut(match, cmd)          ; on the shared list, for every workspace
    entry := z "|" match "|" cmd
    free := 0
    Loop 30 {
        v := IniRead(IniFile, sec, "App" A_Index, "")
        if v = "" {
            if !free
                free := A_Index
        } else if InStr(v, "|" match "|") {
            IniWrite entry, IniFile, sec, "App" A_Index
            Notify(name (isGame ? " updated - game (auto gaming mode watches for it)" : " updated - " where ", " ZoneWords(z)))
            PushUiQuiet()
            return
        }
    }
    if !free {
        Notify("That workspace's app list is full (30).")
        return
    }
    IniWrite entry, IniFile, sec, "App" free
    Notify(name (isGame ? " added as a game - auto gaming mode will watch for it" : " added to " where " - " ZoneWords(z)
        . (launcher ? " (not as a game: it's a launcher or marked as not a game)" : "")))
    PushUiQuiet()          ; show it on the Apps page straight away
}

ZoneWords(z) => z >= 1 ? "zone " z : "not in a zone, so it won't be moved (change it on the Apps page)"

; Find a window by an AHK WinTitle, or by "appid:<text>" = Windows app ID containing <text>.
FindWin(match) {
    if SubStr(match, 1, 6) = "appid:" {
        want := SubStr(match, 7)
        for hwnd in WinGetList() {
            id := GetAppId(hwnd)
            if id != "" && InStr(id, want)
                return hwnd
        }
        return 0
    }
    return WinExist(match)
}

; The window's AppUserModelID (what Windows groups taskbar buttons by), or "" if it has none.
GetAppId(hwnd) {
    ps := 0
    if DllCall("shell32\SHGetPropertyStoreForWindow", "ptr", hwnd, "ptr", AppIdKeys().iid, "ptr*", &ps, "int") != 0 || !ps
        return ""
    return StoreAppId(ps)
}

; The app ID a shortcut (.lnk) opens with, "" if it hasn't one
FileAppId(path) {
    ps := 0
    if DllCall("shell32\SHGetPropertyStoreFromParsingName", "str", path, "ptr", 0, "int", 0, "ptr", AppIdKeys().iid, "ptr*", &ps, "int") != 0 || !ps
        return ""
    return StoreAppId(ps)
}

; IID_IPropertyStore and PKEY_AppUserModel_ID, made once
AppIdKeys() {
    static k := 0
    if !k {
        k := {iid: Buffer(16), key: Buffer(20)}
        DllCall("ole32\CLSIDFromString", "str", "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}", "ptr", k.iid)  ; IPropertyStore
        DllCall("ole32\CLSIDFromString", "str", "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", "ptr", k.key)  ; PKEY_AppUserModel_ID
        NumPut("uint", 5, k.key, 16)
    }
    return k
}

; Read the app ID from a property store, and release it
StoreAppId(ps) {
    key := AppIdKeys().key
    id := ""
    pv := Buffer(24, 0)
    try {
        ComCall(5, ps, "ptr", key, "ptr", pv)          ; IPropertyStore::GetValue
        if NumGet(pv, 0, "ushort") = 31                ; VT_LPWSTR
            id := StrGet(NumGet(pv, 8, "ptr"), "UTF-16")
        DllCall("ole32\PropVariantClear", "ptr", pv)
    }
    ObjRelease(ps)
    return id
}

; Automatic name for an app's window match: its program, or a web app's site
AutoAppName(match) {
    if SubStr(match, 1, 6) = "appid:" {             ; e.g. open.spotify.com-D551...!App -> Spotify
        id := SubStr(match, 7)
        site := RegExReplace(InStr(id, "-") ? SubStr(id, 1, InStr(id, "-") - 1) : id, "i)^(www|open|app|web)\.")
        site := InStr(site, ".") ? SubStr(site, 1, InStr(site, ".") - 1) : site
        return StrUpper(SubStr(site, 1, 1)) SubStr(site, 2)
    }
    return RegExReplace(match, "i)^ahk_exe\s+")
}
