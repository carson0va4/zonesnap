; ============================================================================
;  ZoneSnap - Profiles
;  Where settings live, and profiles: separate setups on one Windows account.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Settings live in your Windows user folder, so each Windows account has its own:
;     %APPDATA%\ZoneSnap\profiles\<profile>\ZoneSnap.ini     (and that profile's import backups)
;     %APPDATA%\ZoneSnap\profiles.ini                         [Profiles] Last=<profile used last>
; A profile is a complete setup of its own, as if ZoneSnap had been installed fresh for that
; person: a new one starts with the first-run setup. Switching restarts ZoneSnap on the other
; profile, so nothing (hotkeys, timers, windows it moved) carries over.
; Before 0.37.0 the settings file sat next to ZoneSnap; the first start moves it into a
; profile named after your Windows user name and leaves the old file as ZoneSnap.ini.old.
; ---------------------------------------------------------------------------
DataDir() => A_AppData "\ZoneSnap"
ProfilesFile() => DataDir() "\profiles.ini"
ProfileDir(name := "") => DataDir() "\profiles\" (name = "" ? ActiveProfile : name)

; Profile names, as their folders are named
ProfileList() {
    out := []
    Loop Files DataDir() "\profiles\*", "D"
        out.Push(A_LoopFileName)
    return out
}

; The profile's name as stored, matched without regard to capitals ("" if there's none)
FindProfile(name) {
    for p in ProfileList()
        if p = name
            return p
    return ""
}

; A profile name that works as a folder name on Windows
ValidProfileName(nm) => nm != "" && StrLen(nm) <= 40 && !(nm ~= '[\\/:*?"<>|\x00-\x1F]')
    && !(nm ~= "^[ .]|[ .]$") && !(nm ~= "i)^(con|prn|aux|nul|com\d|lpt\d)$")

; The ZoneSnap window's title: "ZoneSnap – <profile>", so the taskbar and Alt+Tab say whose it is
UiTitle() => "ZoneSnap " Chr(0x2013) " " ActiveProfile

ProfileNameRule() => "Please use a name up to 40 characters, without \ / : * ? `" < > |"

; Start-up: choose the profile (moving older settings into one if need be) and point the
; settings file at it. Returns a note for the tray if settings were moved, else "".
StartProfile() {
    global ActiveProfile, IniFile
    note := ""
    DirCreate DataDir() "\profiles"
    if !FileExist(ProfilesFile())
        FileAppend "[Profiles]`r`n", ProfilesFile(), "UTF-16"     ; UTF-16 so any name survives
    if !ProfileList().Length {
        name := ValidProfileName(A_UserName) ? A_UserName : "Me"
        DirCreate ProfileDir(name)
        old := A_ScriptDir "\ZoneSnap.ini"
        if FileExist(old) {
            FileCopy old, ProfileDir(name) "\ZoneSnap.ini"
            try FileMove old, old ".old", 1
            note := "Your settings now live in your Windows user folder, as the profile " name
        }
    }
    last := FindProfile(IniRead(ProfilesFile(), "Profiles", "Last", ""))
    ActiveProfile := last != "" ? last : ProfileList()[1]
    IniFile := ProfileDir() "\ZoneSnap.ini"
    IniWrite ActiveProfile, ProfilesFile(), "Profiles", "Last"
    return note
}

; Switch to another profile: back to Default first (windows go back, the taskbar and cursor
; are given back), then restart on it
SwitchProfile(name) {
    name := FindProfile(name)
    if name = "" || name == ActiveProfile
        return
    if ActiveWS != ""
        SwitchWorkspace("")
    IniWrite name, ProfilesFile(), "Profiles", "Last"
    Reload
}

; A new, empty profile, switched to straight away: it starts with the first-run setup
CreateProfile(name) {
    name := Trim(name)
    if !ValidProfileName(name)
        return ProfileNameRule()
    if FindProfile(name) != ""
        return "There's already a profile called " name
    try DirCreate ProfileDir(name)
    catch as err
        return "Couldn't create the profile: " err.Message
    SwitchProfile(name)
    return ""
}

RenameProfile(old, new) {
    global ActiveProfile, IniFile
    new := Trim(new), old := FindProfile(old)
    if old = ""
        return "That profile doesn't exist"
    if !ValidProfileName(new)
        return ProfileNameRule()
    if new == old
        return ""
    if (other := FindProfile(new)) != "" && other != old
        return "There's already a profile called " new
    try {
        if new = old {                          ; only the capitals change: go via another name
            DirMove ProfileDir(old), ProfileDir(old) ".renaming"
            DirMove ProfileDir(old) ".renaming", ProfileDir(new)
        } else
            DirMove ProfileDir(old), ProfileDir(new)
    } catch as err
        return "Couldn't rename the profile: " err.Message
    if old = ActiveProfile {
        ActiveProfile := new
        IniFile := ProfileDir() "\ZoneSnap.ini"
        IniWrite new, ProfilesFile(), "Profiles", "Last"
        if IsObject(UiGui)
            UiGui.Title := UiTitle()
        UpdateTray()
    }
    return ""
}

DeleteProfile(name) {
    name := FindProfile(name)
    if name = ""
        return "That profile doesn't exist"
    if name = ActiveProfile
        return "Switch to another profile before deleting this one"
    try DirDelete ProfileDir(name), true
    catch as err
        return "Couldn't delete the profile: " err.Message
    UpdateTray()
    return ""
}

; Tray "Profile" submenu: each profile (the one in use ticked), then New profile
UpdateProfileMenu() {
    try ProfileMenu.Delete()
    for p in ProfileList() {
        ProfileMenu.Add(p, (name, *) => SwitchProfile(name))
        if p == ActiveProfile
            ProfileMenu.Check(p)
    }
    ProfileMenu.Add()
    ProfileMenu.Add("New profile...", (*) => NewProfileFromTray())
}

NewProfileFromTray() {
    ib := InputBox("A new profile is a separate setup, as if ZoneSnap were installed fresh: its own "
        . "zones, workspaces, apps and shortcuts. ZoneSnap switches to it straight away.`n`nName:",
        "ZoneSnap - new profile", "w420 h190")
    if ib.Result != "OK" || Trim(ib.Value) = ""
        return
    if (why := CreateProfile(ib.Value)) != ""
        MsgBox why, "ZoneSnap", "Icon!"
}
