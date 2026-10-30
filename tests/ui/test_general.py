"""The General page: settings save straight away (with Undo), profiles, the Advanced section."""


def setting(pg, key):
    return pg.evaluate("k => S.settings[k]", key)


def test_switch_saves_straight_away_and_undo_restores(open_ui):
    pg = open_ui("?page=general")
    assert setting(pg, "updateCheck") == 1
    pg.click("[data-set=updateCheck]")
    assert setting(pg, "updateCheck") == 0
    assert pg.get_attribute("[data-set=updateCheck]", "aria-checked") == "false"
    assert "Saved" in pg.inner_text("#toast")
    pg.click("#toast [data-act=undoSetting]")
    assert setting(pg, "updateCheck") == 1


def test_theme_and_drag_key_save(open_ui):
    pg = open_ui("?page=general")
    pg.click("[data-themepick=light]")
    assert setting(pg, "theme") == "light"
    assert pg.get_attribute("html", "data-theme") == "light"
    pg.click("[data-drag='#LButton']")
    assert setting(pg, "dragKey") == "#LButton"


def test_dim_slider_saves_when_let_go(open_ui):
    pg = open_ui("?page=general")
    pg.fill("#dim", "40")                     # fill sets the value and fires input + change
    assert setting(pg, "dimOpacity") == round(40 / 100 * 255)
    assert pg.inner_text("#dimval") == "40%"


def test_no_repository_box_and_advanced_folds(open_ui):
    pg = open_ui("?page=general")
    assert pg.locator("#repo").count() == 0
    assert not pg.locator("[data-act=restartAdmin]").is_visible()
    pg.click("#advanced summary")
    assert pg.locator("[data-act=restartAdmin]").is_visible()
    pg.click("[data-step='1']")
    assert setting(pg, "lockBottomMargin") == 3


def test_profiles_card(open_ui):
    pg = open_ui("?page=general")
    rows = pg.locator("#profiles .prof-row")
    assert rows.count() == 2
    assert "In use" in rows.nth(0).inner_text()
    assert pg.locator("#profiles [data-profdel=User]").count() == 0          # can't delete the one in use
    assert pg.locator("#profiles [data-profswitch='User 2']").count() == 1
    assert "User's profile" in pg.inner_text("#profchip")


def test_new_profile_dialog_checks_the_name(open_ui):
    pg = open_ui("?page=general")
    pg.click("#profiles [data-act=newProfile]")
    pg.fill("#modal-in", "user 2")                                     # taken, ignoring capitals
    pg.keyboard.press("Enter")
    assert "already" in pg.inner_text("#modal-err")
    pg.fill("#modal-in", "A/B")
    pg.keyboard.press("Enter")
    assert "without" in pg.inner_text("#modal-err")
    pg.fill("#modal-in", "User 4")
    pg.keyboard.press("Enter")
    assert "restarts on User 4" in pg.inner_text("#toast")


def test_rename_and_delete_profile(open_ui):
    pg = open_ui("?page=general")
    pg.click("[data-profrename='User 2']")
    pg.fill("#modal-in", "User 3")
    pg.keyboard.press("Enter")
    assert pg.evaluate("S.profiles.list") == ["User", "User 3"]
    pg.click("[data-profdel='User 3']")                               # confirm() is accepted
    assert pg.evaluate("S.profiles.list") == ["User"]
    assert "User's profile" in pg.inner_text("#profchip")            # shown with one profile too


def test_profile_chip_on_every_page_and_its_menu(open_ui):
    pg = open_ui("?page=zones")
    for page in ["zones", "workspaces", "apps", "general", "hotkeys"]:
        pg.click(f"[data-go={page}]")
        assert pg.locator("#profchip").is_visible()
        assert pg.inner_text("#profav") == "U"
    pg.click("#profchip")
    assert pg.get_attribute("#profchip", "aria-expanded") == "true"
    assert pg.locator("#profmenu [data-profswitch='User 2']").is_visible()
    pg.keyboard.press("Escape")
    assert not pg.locator("#profmenu").is_visible()
    pg.click("#profchip")
    pg.click("#profmenu [data-act=manageProfiles]")
    assert pg.locator("#page-general").is_visible()
    assert not pg.locator("#profmenu").is_visible()
    pg.click("#profchip")
    pg.click("#profmenu [data-act=newProfile]")
    assert pg.inner_text("#modal-h") == "New profile"


def test_profile_menu_switch_asks_first(open_ui):
    pg = open_ui("?page=apps")
    pg.click("#profchip")
    pg.click("#profmenu [data-profswitch='User 2']")                    # confirm() is accepted
    assert "restarts on User 2" in pg.inner_text("#toast")
    pg.click("main")                                               # clicking elsewhere closes the menu
    assert not pg.locator("#profmenu").is_visible()


def accent(pg, var="--accent"):
    return pg.evaluate("v => getComputedStyle(document.documentElement).getPropertyValue(v).trim().toUpperCase()", var)


# The picker is the house colour-editor.js: .swatch buttons (data-hex), .swatch-other (Other…), and the
# .colour-editor with its .ce-sv square, .ce-hue slider, hex box, .ce-note and Cancel / Apply colour.
OTHER, EDITOR, HEX = "#accent-picker .swatch-other", "#accent-picker .colour-editor", "#accent-picker .ce-preview .field"
APPLY, CANCEL = EDITOR + " .btn.primary", EDITOR + " .btn:not(.primary)"


def test_accent_colour_teal_by_default_then_custom(open_ui):
    pg = open_ui("?page=general")
    teal = accent(pg)
    assert pg.get_attribute("[data-accmode=teal]", "aria-pressed") == "true"
    assert not pg.locator("#accrow").is_visible()
    pg.click("[data-accmode=custom]")
    assert setting(pg, "accentMode") == "custom"
    assert pg.locator("#accrow").is_visible()
    assert accent(pg) == "#7A5AE0" != teal                         # the default custom colour: purple
    pg.click(".swatch[data-hex='3D8A4F']")
    assert setting(pg, "accentCustom") == "3D8A4F"
    assert pg.get_attribute(".swatch[data-hex='3D8A4F']", "aria-pressed") == "true"
    green = accent(pg)                                            # deepened a touch for white text
    assert green == "#" + pg.evaluate("accentShade('3D8A4F', '000000', 4.5, 'FFFFFF')")
    assert pg.evaluate("h => accentContrast(h, 'FFFFFF')", green.lstrip("#")) >= 4.5
    pg.click("#toast [data-act=undoSetting]")                    # back to purple
    assert accent(pg) == "#7A5AE0"
    assert pg.get_attribute(".swatch[data-hex='7A5AE0']", "aria-pressed") == "true"
    pg.click("[data-accmode=teal]")
    assert accent(pg) == teal


def test_other_colour_previews_live_and_applies_only_on_apply(open_ui):
    pg = open_ui("?page=general")
    pg.click("[data-accmode=custom]")
    pg.evaluate("window.sentMsgs = []; const real = demoHandle; demoHandle = (m) => { sentMsgs.push(m); real(m); }; 0")
    assert not pg.locator(EDITOR).is_visible()
    pg.click(OTHER)
    assert pg.locator(EDITOR).is_visible()
    assert pg.input_value(HEX) == "#7A5AE0"                         # opens on the current colour
    assert pg.locator(APPLY).is_visible()
    pg.fill(HEX, "#ffe680")                                         # typing a colour previews it...
    fill = accent(pg).lstrip("#")
    assert fill != "7A5AE0" and fill != "FFE680"                    # ...deepened so white text reads
    assert pg.evaluate("h => accentContrast(h, 'FFFFFF')", fill) >= 4.5
    assert pg.evaluate("h => accentContrast(h, '19202A')", accent(pg, "--guide-accent").lstrip("#")) >= 4.5
    assert "a little deeper" in pg.inner_text(EDITOR + " .ce-note")
    assert pg.evaluate("sentMsgs.some(m => m.type === 'accentPreview' && m.hex === 'FFE680')"), "the title bar previews too"
    assert setting(pg, "accentCustom") == "7A5AE0"                  # ...but nothing is saved yet
    pg.click(APPLY)
    assert setting(pg, "accentCustom") == "FFE680"
    assert not pg.locator(EDITOR).is_visible()
    assert "applied" in pg.inner_text("#toast")
    assert "#FFE680" in pg.inner_text(OTHER)                        # shown on the Other button


def test_other_colour_cancel_esc_and_leaving_put_it_back(open_ui):
    pg = open_ui("?page=general")
    pg.click("[data-accmode=custom]")
    purple = accent(pg)
    pg.click(OTHER)
    pg.fill(EDITOR + " .ce-hue", "120")                             # dragging the hue previews green
    assert accent(pg) != purple
    pg.click(CANCEL)
    assert accent(pg) == purple and not pg.locator(EDITOR).is_visible()
    pg.click(OTHER)
    pg.fill(HEX, "#3b6fd8")
    pg.focus(EDITOR + " .ce-sv")
    pg.keyboard.press("Escape")
    assert accent(pg) == purple and setting(pg, "accentCustom") == "7A5AE0"
    pg.click(OTHER)
    pg.fill(HEX, "#3b6fd8")
    pg.click("[data-go=zones]")                                      # leaving General drops the preview
    assert accent(pg) == purple
    pg.click("[data-go=general]")
    assert not pg.locator(EDITOR).is_visible()
    pg.click(OTHER)
    # a mouse click needs the square on screen, and clear of the toast at the bottom
    pg.evaluate("document.querySelector('#accent-picker .ce-sv').scrollIntoView({ block: 'center' })")
    box = pg.locator(EDITOR + " .ce-sv").bounding_box()
    x, y = box["x"] + box["width"] - 6, box["y"] + 6       # near the top right (inside its rounded corner): full colour
    under = pg.evaluate("([x, y]) => { const e = document.elementFromPoint(x, y); return e ? e.tagName + '.' + e.className : 'nothing'; }", [x, y])
    pg.mouse.click(x, y)
    assert pg.input_value(HEX) != "#7A5AE0", f"the click at {x:.0f},{y:.0f} hit {under}; editor open: {pg.evaluate('picker.isOpen()')}"
    pg.focus(HEX)
    pg.keyboard.press("Enter")                                      # Enter applies
    assert setting(pg, "accentCustom") != "7A5AE0"
    assert not pg.locator(EDITOR).is_visible()


def test_switching_away_from_custom_closes_the_editor(open_ui):
    pg = open_ui("?page=general")
    pg.click("[data-accmode=custom]")
    pg.click(OTHER)
    pg.fill(HEX, "#3b6fd8")
    pg.click("[data-accmode=teal]")
    assert setting(pg, "accentMode") == "teal"
    teal = pg.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--accent').trim().toUpperCase()")
    assert teal not in ("#7A5AE0", "#3B6FD8")                       # the preview and the custom colour are both gone
    assert not pg.evaluate("picker.isOpen()")


def test_accent_colour_follows_windows(open_ui):
    pg = open_ui("?page=general")
    pg.click("[data-accmode=windows]")
    assert setting(pg, "accentMode") == "windows"
    assert accent(pg) == "#C24E1C"                                # the demo's Windows accent
    assert not pg.locator("#accrow").is_visible()


def test_update_now_for_the_exe(open_ui):
    pg = open_ui("?page=general&update=1")
    banner = pg.locator("#update-banner")
    assert "0.39.3 is available" in banner.inner_text()
    assert banner.locator("[data-act=installUpdate]").is_visible()
    assert banner.locator("[data-act=openRelease]").inner_text() == "What's new"
    pg.click("#update-banner [data-act=installUpdate]")
    assert "Downloading ZoneSnap 0.39.3" in banner.inner_text()
    assert banner.locator("button").first.is_disabled()


def test_script_version_still_downloads_from_github(open_ui):
    pg = open_ui("?page=general&update=script")
    banner = pg.locator("#update-banner")
    assert banner.locator("[data-act=installUpdate]").count() == 0
    assert banner.locator("[data-act=openRelease]").inner_text() == "Download"


def test_updated_note_until_dismissed(open_ui):
    pg = open_ui("?page=general&updated=1")
    assert "Updated to ZoneSnap" in pg.inner_text("#update-banner")
    assert "From 0.39.0" in pg.inner_text("#update-banner")
    assert pg.locator("#update-banner [data-act=openWhatsNew]").is_visible()
    pg.click("#update-banner [data-act=dismissUpdated]")
    assert pg.inner_text("#update-banner") == ""


PICKS = ["437784", "3B6FD8", "7A5AE0", "C2477F", "C8463D", "C9692A", "A9821C", "3D8A4F", "5B6B80",   # the swatches
         "FFE680", "FFFFFF", "000000", "00FF00", "00FFFF"]                                        # awkward picks
PAIRS = [("--accent-fg", "--accent"), ("--accent-fg", "--accent-hover"), ("--guide-accent", "--card"), ("--guide-accent", "--bg"),
         ("--guide-accent", "--panel"), ("--tip-text", "--tip"), ("--key-badge-text", "--key-badge"), ("--text", "--row-selected"), ("--text", "--zone-selected")]


def test_every_accent_colour_stays_readable_in_both_themes(open_ui):
    """The same check as the house style's palette.py: any colour, every pair at 4.5:1."""
    for theme in ["dark", "light"]:
        pg = open_ui(f"?page=general&theme={theme}")
        pg.click("[data-accmode=custom]")
        for hexc in PICKS:
            pg.evaluate("h => { S.settings.accentCustom = h; applyTheme(); }", hexc)
            for fg, bg in PAIRS:
                ratio = pg.evaluate("""([f, b]) => { const cs = getComputedStyle(document.documentElement);
                    const v = (n) => cs.getPropertyValue(n).trim().replace('#', '');
                    return accentContrast(v(f), v(b)); }""", [fg, bg])
                assert ratio >= 4.5, f"{theme} #{hexc}: {fg} on {bg} = {ratio:.2f}"
