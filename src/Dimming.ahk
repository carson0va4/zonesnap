; ============================================================================
;  ZoneSnap - Dimming
;  Dimming side panes, and keeping a pane lit (shortcuts and the hover pin button).
;  Included by ZoneSnap.ahk; holds functions (and hotkeys) only, no start-up code.
; ============================================================================

; Keep a pane bright while dimming is on (e.g. a guide you're reading mid-game)
ToggleLit(n, *) {
    if n < 1 || n > Zones.Length {
        Notify("There's no zone " n " in the active layout")
        return
    }
    if n = GameZoneN {
        Notify("The game zone is never dimmed")
        return
    }
    if LitZones.Has(n) {
        LitZones.Delete(n)
        Notify("Zone " n " dims again")
    } else {
        LitZones[n] := true
        Notify("Zone " n " stays lit" (DimOn ? "" : " (dimming is off right now)"))
    }
    UpdatePinLabels()
}

PinLabel(n) => LitZones.Has(n) ? "📌 Lit - click to unpin" : "📌 Keep lit"

UpdatePinLabels() {
    for i, t in PinTexts
        if IsObject(t)
            try t.Text := PinLabel(i)
}

ToggleLitUnderMouse() {
    MouseGetPos &mx, &my
    if n := ZoneAt(mx, my)
        ToggleLit(n)
    else
        Notify("Point at a pane first, then press " KeyText("LitUnderMouse"))
}

LitZoneKey(hk) => ToggleLit(Integer(SubStr(hk, -1)))

SetDim(on) {
    global DimOn
    DimOn := on
    if on
        BuildDim()
    else
        DestroyDim()
    UpdateTray()
}

BuildDim() {
    global DimOverlays, DimVis
    DestroyDim()
    op := Max(0, Min(255, GSInt("DimOpacity", 170)))
    for i, z in Zones {
        if i = GameZoneN {
            DimOverlays.Push(0)
            DimVis.Push(false)
            PinBtns.Push(0), PinTexts.Push(0), PinVis.Push(false)
            continue
        }
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
        g.BackColor := "000000"
        g.Show("NA x" z.x " y" z.y " w" z.w " h" z.h)
        WinSetTransparent op, g
        DimOverlays.Push(g)
        DimVis.Push(true)
        PinBtns.Push(MakePinButton(i))      ; also adds its label to PinTexts
        PinVis.Push(false)
    }
}

; Small "Keep lit" button shown at the top-centre of a pane while you hover over it.
; E0x08000000 = no-activate: clicking it doesn't take focus from the game.
MakePinButton(n) {
    b := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale")
    b.BackColor := AccentHex
    RoundCorners(b.Hwnd, 3)
    b.MarginX := 0, b.MarginY := 0
    b.SetFont("s10 c" InkFor(AccentHex), "Segoe UI Emoji")
    txt := b.AddText("x0 y0 w170 h28 Center 0x200 BackgroundTrans", PinLabel(n))   ; 0x200 = centre vertically
    txt.OnEvent("Click", (*) => ToggleLit(n))
    PinTexts.Push(txt)
    return b
}

ShowPin(n, show) {
    b := PinBtns[n]
    if !IsObject(b)
        return
    if show {
        z := Zones[n]
        b.Show("NA x" (z.x + (z.w - 170) // 2) " y" (z.y + 6) " w170 h28")
        WinSetTransparent 230, b
    } else
        b.Hide()
}

DestroyDim() {
    global DimOverlays, DimVis, PinBtns, PinVis, PinTexts
    for g in DimOverlays
        if IsObject(g)
            g.Destroy()
    for b in PinBtns
        if IsObject(b)
            b.Destroy()
    DimOverlays := []
    DimVis := []
    PinBtns := []
    PinVis := []
    PinTexts := []
}
