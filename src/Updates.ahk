; ============================================================================
;  ZoneSnap - Updates
;  The update check against the GitHub repository's releases.
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; ---------------------------------------------------------------------------
; Update check: asks GitHub for the latest release of ZoneSnap's repository (ZS_REPO; a
; [Settings] UpdateRepo=owner/name line points it at a fork instead)
; at most once a day ([Settings] UpdateCheck=1), or when you click Check now. A newer
; version shows a tray message, a tray menu item and a banner in Settings. Nothing is
; downloaded until you choose Update now (InstallUpdate, below).
; ---------------------------------------------------------------------------
UpdateRepo() {
    repo := Trim(IniRead(IniFile, "Settings", "UpdateRepo", ""))
    if repo = ""
        repo := ZS_REPO
    repo := RegExReplace(repo, "i)^https?://github\.com/|\.git$|/$")      ; accept a pasted URL
    return repo ~= "^[\w.-]+/[\w.-]+$" ? repo : ""
}

AutoUpdateCheck() {
    if IniRead(IniFile, "Settings", "UpdateCheck", "1") != "1" || UpdateRepo() = ""
        return
    last := IniRead(IniFile, "Settings", "LastUpdateCheck", "")
    if last != "" && IsInteger(last) && DateDiff(A_Now, last, "Hours") < 24
        return
    CheckForUpdates(false)
}

CheckForUpdates(manual := false) {
    global UpdateReq
    repo := UpdateRepo()
    if repo = "" {
        if manual
            UpdateDone("The update check has no GitHub repository to ask", manual)
        return
    }
    if IsObject(UpdateReq) || IsObject(UpdateDl)          ; already checking, or Update now is downloading
        return
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        ; newest releases first, pre-releases included (/releases/latest skips pre-releases,
        ; and 0.x betas are published as pre-releases)
        req.Open("GET", "https://api.github.com/repos/" repo "/releases?per_page=10", true)
        req.SetRequestHeader("User-Agent", "ZoneSnap/" ZS_VERSION)
        req.SetRequestHeader("Accept", "application/vnd.github+json")
        req.Send()
    } catch {
        UpdateDone("Couldn't check for updates (no connection?)", manual)
        return
    }
    UpdateReq := {req: req, manual: manual, started: A_TickCount, repo: repo}
    SetTimer PollUpdate, 250
}

PollUpdate() {
    global UpdateReq, UpdateInfo
    if !IsObject(UpdateReq) {
        SetTimer PollUpdate, 0
        return
    }
    r := UpdateReq
    finished := false
    try finished := r.req.WaitForResponse(0)
    if !finished {
        if A_TickCount - r.started > 15000 {
            SetTimer PollUpdate, 0
            UpdateReq := ""
            UpdateDone("The update check timed out", r.manual)
        }
        return
    }
    SetTimer PollUpdate, 0
    UpdateReq := ""
    IniWrite A_Now, IniFile, "Settings", "LastUpdateCheck"
    try {
        status := r.req.Status
        body := r.req.ResponseText
    } catch {
        UpdateDone("Couldn't check for updates", r.manual)
        return
    }
    if status = 404 {
        UpdateDone("Couldn't find " r.repo " on GitHub - check the name, and that the repository is public", r.manual)
        return
    }
    if status = 200 && !InStr(body, '"tag_name"') {
        UpdateDone("No releases found for " r.repo, r.manual)
        return
    }
    if status != 200 || !NewestReleaseTag(body, &mt) {
        UpdateDone("Couldn't check for updates (GitHub said " status ")", r.manual)
        return
    }
    tag := mt[1]
    latest := RegExReplace(tag, "i)^v")
    newer := false
    try newer := VerCompare(latest, ZS_VERSION) > 0
    skipped := IniRead(IniFile, "Settings", "SkippedVersion", "")
    if newer && (r.manual || latest != skipped) {
        UpdateInfo := {version: latest, url: "https://github.com/" r.repo "/releases/tag/" tag,
            exe: ReleaseExe(body, tag), state: ""}
        TrayTip "ZoneSnap " latest " is available. " (CanSelfUpdate() ? "Update now from the tray menu or Settings." : "Tray menu or Settings to download it."), "ZoneSnap update", 1
        UpdateDone("", r.manual)
    } else {
        UpdateInfo := ""
        UpdateDone("You're on the latest version (" ZS_VERSION ")", r.manual)
    }
}

; The highest version among the listed releases, skipping drafts. Returns it in m[1].
NewestReleaseTag(body, &m) {
    best := "", pos := 1
    while pos := RegExMatch(body, '"tag_name"\s*:\s*"([^"]+)"', &hit, pos) {
        pos += hit.Len
        nextTag := RegExMatch(body, '"tag_name"', , pos)
        chunk := SubStr(body, pos, nextTag ? nextTag - pos : 2000)
        if RegExMatch(chunk, '"draft"\s*:\s*true')
            continue
        tagVer := RegExReplace(hit[1], "i)^v")
        try {
            if best = "" || VerCompare(tagVer, RegExReplace(best, "i)^v")) > 0
                best := hit[1]
        }
    }
    m := [best]
    return best != ""
}

UpdateDone(msg, manual) {
    UpdateTray()
    if manual && msg != "" {
        Notify(msg)
        PushUiState(, msg)
    }
}

UpdateTrayUpdateItem() {
    global TrayUpdateName
    newName := !IsObject(UpdateInfo) ? ""
        : CanSelfUpdate() ? "Update now to ZoneSnap " UpdateInfo.version
        : "Update available: ZoneSnap " UpdateInfo.version
    if newName = TrayUpdateName
        return
    if TrayUpdateName != ""
        try A_TrayMenu.Delete(TrayUpdateName)
    TrayUpdateName := newName
    if newName != ""
        try A_TrayMenu.Insert("1&", newName, (*) => InstallUpdate())
}

OpenReleasePage() {
    if IsObject(UpdateInfo) && SubStr(UpdateInfo.url, 1, 19) = "https://github.com/"
        Run UpdateInfo.url
}

SkipUpdate() {
    global UpdateInfo
    if IsObject(UpdateInfo)
        IniWrite UpdateInfo.version, IniFile, "Settings", "SkippedVersion"
    UpdateInfo := ""
    UpdateTray()
}

; ---------------------------------------------------------------------------
; Update now (ZoneSnap.exe only; the script version opens the release page instead):
;   1. download the release's ZoneSnap.exe next to this one, as <name>.new.exe
;   2. check it: its SHA-256 must match the digest GitHub publishes for the file, and its
;      file version must be the release's version - otherwise it's deleted and nothing changes
;   3. Windows won't let a running program overwrite itself but will let it be renamed:
;      this .exe becomes <name>.old.exe, the new one takes its name and place (so Start with
;      Windows still points at it), starts, and this one exits. The new one deletes the old.
; Settings are in %APPDATA%, so nothing else needs to move.
; ---------------------------------------------------------------------------

; The release's ZoneSnap.exe: {url, sha256, size}, or "" when it has none or no digest. Looks
; only inside that release's part of the API's answer (its assets come after its tag_name).
ReleaseExe(body, tag) {
    start := InStr(body, '"tag_name"')
    while start {
        if RegExMatch(body, '"tag_name"\s*:\s*"([^"]+)"', &t, start) = start && t[1] = tag
            break
        start := InStr(body, '"tag_name"', , start + 10)
    }
    if !start
        return ""
    stop := InStr(body, '"tag_name"', , start + 10)
    chunk := SubStr(body, start, stop ? stop - start : StrLen(body))
    if !(at := RegExMatch(chunk, '"name"\s*:\s*"ZoneSnap\.exe"'))
        return ""
    if !RegExMatch(chunk, '"browser_download_url"\s*:\s*"(https://github\.com/[^"]+/ZoneSnap\.exe)"', &u, at)
        return ""
    if !RegExMatch(chunk, '"digest"\s*:\s*"sha256:([0-9a-fA-F]{64})"', &d, at) || d.Pos > u.Pos
        return ""
    size := RegExMatch(chunk, '"size"\s*:\s*(\d+)', &z, at) && z.Pos < u.Pos ? Integer(z[1]) : 0
    return {url: u[1], sha256: StrLower(d[1]), size: size}
}

CanSelfUpdate() => A_IsCompiled && IsObject(UpdateInfo) && IsObject(UpdateInfo.exe)

UpdatePath(kind) => A_ScriptDir "\" RegExReplace(A_ScriptName, "i)\.exe$") "." kind ".exe"

InstallUpdate() {
    global UpdateDl
    if !IsObject(UpdateInfo)
        return
    if !CanSelfUpdate() {
        OpenReleasePage()
        return
    }
    if UpdateInfo.state = "downloading"
        return
    test := A_ScriptDir "\ZoneSnap.write-test"
    try {
        FileAppend "", test
        FileDelete test
    } catch {
        UpdateFailed("ZoneSnap can't save files in its folder (" A_ScriptDir "), so the release page opens instead.")
        OpenReleasePage()
        return
    }
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", UpdateInfo.exe.url, true)            ; GitHub redirects to its file store
        req.SetRequestHeader("User-Agent", "ZoneSnap/" ZS_VERSION)
        req.Send()
    } catch {
        UpdateFailed("Couldn't start the download (no connection?)")
        return
    }
    UpdateInfo.state := "downloading"
    UpdateDl := {req: req, started: A_TickCount}
    UpdateTray()
    PushUiState()
    SetTimer PollInstall, 250
}

PollInstall() {
    global UpdateDl
    if !IsObject(UpdateDl) {
        SetTimer PollInstall, 0
        return
    }
    finished := false
    try finished := UpdateDl.req.WaitForResponse(0)
    if !finished {
        if A_TickCount - UpdateDl.started > 120000 {
            SetTimer PollInstall, 0
            UpdateDl := ""
            UpdateFailed("The download timed out")
        }
        return
    }
    SetTimer PollInstall, 0
    req := UpdateDl.req, UpdateDl := ""
    newPath := UpdatePath("new")
    try {
        if req.Status != 200
            throw Error("GitHub said " req.Status)
        body := req.ResponseBody                              ; a SAFEARRAY of bytes
        size := body.MaxIndex() + 1
        f := FileOpen(newPath, "w")
        f.RawWrite(NumGet(ComObjValue(body), 8 + A_PtrSize, "ptr"), size)      ; its pvData
        f.Close()
    } catch as e {
        try FileDelete newPath
        UpdateFailed("The download failed (" e.Message ")")
        return
    }
    if UpdateInfo.exe.size && FileGetSize(newPath) != UpdateInfo.exe.size
        || Sha256File(newPath) != UpdateInfo.exe.sha256 {
        try FileDelete newPath
        UpdateFailed("The download didn't match the release's file, so it was deleted. Nothing has changed.")
        return
    }
    v := ""
    try v := RegExReplace(FileGetVersion(newPath), "^(\d+\.\d+\.\d+)\.0$", "$1")     ; 0.39.1.0 -> 0.39.1
    same := v != "" && v = UpdateInfo.version
    if !same {
        try FileDelete newPath
        UpdateFailed("The download is version " (v = "" ? "unknown" : v) ", not " UpdateInfo.version ", so it was deleted.")
        return
    }
    SwapAndRestart(newPath)
}

SwapAndRestart(newPath) {
    exe := A_ScriptFullPath, old := UpdatePath("old")
    UpdateInfo.state := "installing"
    PushUiState()
    try FileDelete old
    try FileMove exe, old                    ; a running .exe can be renamed, not overwritten
    catch {
        try FileDelete newPath
        UpdateFailed("Windows wouldn't let ZoneSnap replace itself. Nothing has changed.")
        return
    }
    try FileMove newPath, exe
    catch {
        try FileMove old, exe                ; put it back as it was
        try FileDelete newPath
        UpdateFailed("Windows wouldn't let ZoneSnap replace itself. Nothing has changed.")
        return
    }
    IniWrite UpdateInfo.version, IniFile, "Settings", "JustUpdated"
    try Run '"' exe '"'
    catch {
        IniDelete IniFile, "Settings", "JustUpdated"
        try {
            FileMove exe, newPath, 1
            FileMove old, exe
        }
        UpdateFailed("The new version wouldn't start, so ZoneSnap kept the one you had.")
        return
    }
    ExitApp
}

UpdateFailed(msg) {
    if IsObject(UpdateInfo)
        UpdateInfo.state := ""
    UpdateTray()
    TrayTip msg, "ZoneSnap update", 2
    PushUiState(, msg)
}

; SHA-256 of a file as lowercase hex (Windows' own CNG), "" if it can't be read
Sha256File(path) {
    try {
        f := FileOpen(path, "r"), size := f.Length, buf := Buffer(Max(size, 1)), f.RawRead(buf, size), f.Close()
    } catch
        return ""
    hAlg := 0, hash := Buffer(32, 0)
    if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "ptr*", &hAlg, "wstr", "SHA256", "ptr", 0, "uint", 0, "uint") != 0
        return ""
    r := DllCall("bcrypt\BCryptHash", "ptr", hAlg, "ptr", 0, "uint", 0, "ptr", buf, "uint", size, "ptr", hash, "uint", 32, "uint")
    DllCall("bcrypt\BCryptCloseAlgorithmProvider", "ptr", hAlg, "uint", 0)
    if r != 0
        return ""
    hex := ""
    loop 32
        hex .= Format("{:02x}", NumGet(hash, A_Index - 1, "uchar"))
    return hex
}

; After an update: the old .exe goes (it may still be closing, so try again shortly), and
; ZoneSnap says it was updated, with a link to what's new until you dismiss it
FinishUpdate() {
    global JustUpdated, UpdatedFrom
    if !A_IsCompiled
        return
    old := UpdatePath("old")
    if FileExist(old) {
        try UpdatedFrom := RegExReplace(FileGetVersion(old), "^(\d+\.\d+\.\d+)\.0$", "$1")   ; the version you had
        try FileDelete old
        catch
            SetTimer () => (FileExist(old) && TryDelete(old)), -4000
    }
    try FileDelete UpdatePath("new")
    JustUpdated := IniRead(IniFile, "Settings", "JustUpdated", "")
    if JustUpdated != ""
        try IniDelete IniFile, "Settings", "JustUpdated"
}
TryDelete(path) {
    try FileDelete path
    return true
}

DismissUpdated() {
    global UpdatedFrom := ""
    global JustUpdated := ""
    PushUiState()
}

OpenWhatsNew() {
    repo := UpdateRepo()
    if repo != ""
        Run "https://github.com/" repo "/releases/tag/v" ZS_VERSION
}
