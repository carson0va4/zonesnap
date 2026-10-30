; ============================================================================
;  ZoneSnap - Import and export
;  Export and import of settings (General page -> Back up and share).
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Settings export and import. Export copies the profile's ZoneSnap.ini - everything, or only
; the layouts (for sharing them) - to a file you choose, with a [ZoneSnapExport] section
; saying what it is. Import shows what a file holds, saves your current settings as
; "ZoneSnap backup <date>.ini" in the profile's folder, then brings in either everything
; (ZoneSnap restarts to load it) or just the layouts (applied straight away). Layouts of
; workspaces you haven't got are left out. Files from before 0.37.0 can hold saved layouts
; ([Profile:<name>]); importing everything converts them as start-up does (MigrateLayouts).
; Apps are only brought in with "everything": their commands run when a workspace
; switches on, so the preview counts them and warns you.
; ---------------------------------------------------------------------------
LayoutSection(sec) => sec = "Zones" || sec = "GamingZones" || SubStr(sec, 1, 8) = "WSZones:"
    || SubStr(sec, 1, 10) = "GameZones:"

IniSections(path) {
    try secs := IniRead(path)
    catch
        return []
    out := []
    for sec in StrSplit(secs, "`n", "`r")
        if sec != ""
            out.Push(sec)
    return out
}

ExportSettings(what := "all") {
    if IsObject(UiGui)
        UiGui.Opt("+OwnDialogs")
    name := "ZoneSnap " (what = "zones" ? "zones" : "settings") " " FormatTime(, "yyyy-MM-dd") ".ini"
    dest := FileSelect("S16", EnvGet("USERPROFILE") "\Documents\" name,
        what = "zones" ? "Export ZoneSnap layouts" : "Export ZoneSnap settings", "ZoneSnap settings (*.ini)")
    if dest = ""
        return
    if !(dest ~= "i)\.ini$")
        dest .= ".ini"
    if dest = IniFile {
        ExportDone("Choose a different file from ZoneSnap's own settings file")
        return
    }
    try {
        if what = "zones" {
            FileOpen(dest, "w", "UTF-16").Close()       ; a fresh, empty file
            for sec in IniSections(IniFile)
                if LayoutSection(sec)
                    IniWrite IniRead(IniFile, sec), dest, sec
        } else {
            FileCopy IniFile, dest, 1
            for key in ["LastUpdateCheck", "SkippedVersion", "JustImported"]   ; this PC's bookkeeping
                try IniDelete dest, "Settings", key
        }
        IniWrite what, dest, "ZoneSnapExport", "Contains"
        IniWrite ZS_VERSION, dest, "ZoneSnapExport", "Version"
        IniWrite FormatTime(, "yyyy-MM-dd HH:mm"), dest, "ZoneSnapExport", "Exported"
    } catch as err {
        ExportDone("Couldn't export: " err.Message)
        return
    }
    SplitPath dest, &fileName
    ExportDone((what = "zones" ? "Layouts" : "Settings") " exported to " fileName)
}

ExportDone(msg) {
    Notify(msg)
    PushUiState(, msg)
}

; What a settings file holds, for the import preview ("" if it isn't one)
ImportSummary(path) {
    secs := IniSections(path)
    s := {zones: 0, gamingZones: 0, layouts: [], workspaces: [], apps: 0, commands: [], hotkeys: 0,
        settings: 0, contains: "", version: "", exported: ""}
    known := false
    for sec in secs {
        if sec = "Zones" || sec = "GamingZones" {
            n := IniRead(path, sec, "Count", 0)
            s.%(sec = "Zones" ? "zones" : "gamingZones")% := IsInteger(n) ? Integer(n) : 0
            known := true
        } else if SubStr(sec, 1, 8) = "WSZones:" || SubStr(sec, 1, 8) = "Profile:" {
            s.layouts.Push(SubStr(sec, 9)), known := true
        } else if SubStr(sec, 1, 10) = "GameZones:" {
            s.layouts.Push(RegExReplace(SubStr(sec, 11), "i)\.exe$")), known := true
        } else if sec = "GamingMode" || SubStr(sec, 1, 10) = "Workspace:" {
            if SubStr(sec, 1, 10) = "Workspace:"
                s.workspaces.Push(SubStr(sec, 11))
            known := true
            Loop 30 {
                v := IniRead(path, sec, "App" A_Index, "")
                if v = ""
                    continue
                s.apps++
                p := StrSplit(v, "|", " `t", 3)
                if p.Length = 3 && p[3] != ""
                    s.commands.Push(p[3])
            }
        } else if sec = "Hotkeys" {
            s.hotkeys := 1
        } else if sec = "Settings" {
            s.settings := 1, known := true
        } else if sec = "ZoneSnapExport" {
            s.contains := IniRead(path, sec, "Contains", ""), s.version := IniRead(path, sec, "Version", "")
            s.exported := IniRead(path, sec, "Exported", "")
        }
    }
    return known ? s : ""
}

ImportPick() {
    global ImportFile
    if IsObject(UiGui)
        UiGui.Opt("+OwnDialogs")
    path := FileSelect(3, EnvGet("USERPROFILE") "\Documents", "Import ZoneSnap settings", "ZoneSnap settings (*.ini)")
    if path = ""
        return
    if path = IniFile
        return PushUiState(, "That's ZoneSnap's own settings file - pick an exported one")
    sum := ImportSummary(path)
    if !IsObject(sum)
        return PushUiState(, "That file doesn't look like ZoneSnap settings")
    ImportFile := path
    SplitPath path, &fileName
    sum.file := fileName
    sum.canAll := sum.contains != "zones" && (sum.settings || sum.workspaces.Length || sum.apps) ? 1 : 0
    sum.type := "importPreview"
    try UiView.PostWebMessageAsJson(ToJson(sum))
}

; Copy your current settings into the profile's folder before an import. Returns the file name.
BackupSettings() {
    name := "ZoneSnap backup " FormatTime(, "yyyy-MM-dd HHmm") ".ini"
    FileCopy IniFile, ProfileDir() "\" name, 1
    return name
}

ImportApply(mode) {
    global ImportFile
    path := ImportFile, ImportFile := ""
    if path = "" || !FileExist(path) || !IsObject(ImportSummary(path))
        return PushUiState(, "Pick the file to import again")
    try backup := BackupSettings()
    catch as err
        return PushUiState(, "Couldn't back up your current settings, so nothing was imported (" err.Message ")")
    if mode = "all" {
        if ActiveWS != ""
            SwitchWorkspace("")             ; give back the taskbar and the cursor first
        try {
            FileCopy path, IniFile, 1
            try IniDelete IniFile, "ZoneSnapExport"
            IniWrite backup, IniFile, "Settings", "JustImported"
        } catch as err {
            try FileCopy ProfileDir() "\" backup, IniFile, 1
            return PushUiState(, "Couldn't import: " err.Message " - your settings are unchanged")
        }
        Reload                              ; hotkeys, workspaces, theme - everything starts fresh
        return
    }
    ; layouts only: swap those sections, keep everything else (a workspace's layout only if
    ; you've got that workspace)
    try {
        for sec in IniSections(IniFile)
            if LayoutSection(sec)
                IniDelete IniFile, sec
        for sec in IniSections(path)
            if LayoutSection(sec) && (SubStr(sec, 1, 8) != "WSZones:" || HasValue(WSList(), SubStr(sec, 9)))
                IniWrite IniRead(path, sec), IniFile, sec
    } catch as err {
        try FileCopy ProfileDir() "\" backup, IniFile, 1
        return PushUiState(, "Couldn't import: " err.Message " - your settings are unchanged")
    }
    ZoneOrigin.Clear()
    if GamingOn
        RefreshGameLayout()
    else
        ReloadZonesLive()
    PushUiState(, "Layouts imported. Your previous settings were saved as " backup " in your profile's folder")
}
