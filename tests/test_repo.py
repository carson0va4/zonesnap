"""Checks that the repository hangs together: one version everywhere, every module included,
the built guide up to date, and every file the .exe bundles present."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAIN = (ROOT / "ZoneSnap.ahk").read_text(encoding="utf-8")
sys.path.insert(0, str(ROOT / "tools"))
import build_guide  # noqa: E402


def version():
    return re.search(r'ZS_VERSION\s*:=\s*"([^"]+)"', MAIN).group(1)


def test_one_version_everywhere():
    v = version()
    assert re.fullmatch(r"\d+\.\d+\.\d+", v), "versions are plain x.y.z (no beta suffixes)"
    assert re.search(r";@Ahk2Exe-SetVersion\s+(\S+)", MAIN).group(1) == v, "Ahk2Exe-SetVersion"
    ui = (ROOT / "ui.html").read_text(encoding="utf-8")
    assert f'version: "{v}"' in ui, "ui.html demo version"
    top = re.search(r"^## (\S+)", (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), re.M).group(1)
    assert top == v, "the newest CHANGELOG section"


def test_guide_html_is_built_from_its_source():
    assert build_guide.build() == (ROOT / "guide.html").read_text(encoding="utf-8"), \
        "guide.html is out of date: run python tools/build_guide.py"


def test_every_module_is_included_and_exists():
    included = re.findall(r"^#Include %A_ScriptDir%\\src\\(\w+\.ahk)$", MAIN, re.M)
    for name in included:
        assert (ROOT / "src" / name).is_file(), f"src/{name} is included but missing"
    on_disk = sorted(p.name for p in (ROOT / "src").glob("*.ahk"))
    assert sorted(included) == on_disk, "every file in src/ should be included exactly once"


def test_bundled_files_exist():
    for src in re.findall(r'^\s*FileInstall\s+"([^"]+)"', MAIN, re.M):
        assert (ROOT / src.replace("\\", "/")).is_file(), f"FileInstall source {src} is missing"
    assert (ROOT / "ZoneSnap.ico").is_file()


def test_guide_images_all_used_and_present():
    src = (ROOT / "docs" / "guide" / "guide.src.html").read_text(encoding="utf-8")
    used = set(re.findall(r"\{\{img:([a-z_]+)\}\}", src))
    present = {p.stem for p in (ROOT / "docs" / "guide").glob("*.webp")}
    assert used <= present, f"missing guide images: {sorted(used - present)}"
    assert present <= used, f"unused guide images: {sorted(present - used)}"


def test_licence_is_present():
    text = (ROOT / "LICENSE").read_text(encoding="utf-8")
    assert text.startswith("MIT License") and "Commons Clause" not in text
    assert (ROOT / "Lib" / "LICENSE-ahk2_lib.txt").is_file(), "thqby's licence must ship with Lib"
    assert re.search(r";@Ahk2Exe-SetCopyright .*MIT", MAIN), "the .exe's file details name the licence"
    for d in re.findall(r"^;@Ahk2Exe-\w+ (.*)$", MAIN, re.M):
        assert "," not in d.replace("`,", ""), "Ahk2Exe directives split on commas: escape them as `,"


def test_readme_images_exist():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for path in re.findall(r"!\[[^\]]*\]\(([^)]+)\)", readme):
        assert (ROOT / path).is_file(), f"README image {path} is missing"
