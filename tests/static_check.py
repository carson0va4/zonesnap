"""Static checks for ZoneSnap's AutoHotkey v2 code, for things AutoHotkey itself only finds
at run time (or never):

  - unbalanced brackets
  - two spellings of one name in a function (AutoHotkey names ignore case, so they're one variable)
  - a local variable named like a global without "global" (it hides the global)
  - a one-line try/for/loop/while straight before "else" (AutoHotkey pairs the else with it)
  - FileInstall not at the start of its line (Ahk2Exe then leaves the file out of the .exe)
  - calls to functions that aren't defined anywhere and aren't AutoHotkey built-ins

Usage: python tests/static_check.py [repo root]. Exits 1 if anything is found.
"""
import os
import re
import sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
MAIN = os.path.join(ROOT, "ZoneSnap.ahk")

# AutoHotkey v2 built-in functions ZoneSnap uses (and a few more), so they aren't reported
BUILTIN = set("""Abs ATan Array Buffer CallbackCreate CaretGetPos Ceil Chr ClipWait ComCall ComObjActive ComObjValue ComObject
ComObjQuery ComValue ControlGetHwnd ControlGetPos CoordMode DateAdd DateDiff DetectHiddenWindows DirCreate DirDelete
DirExist DllCall Download Error EnvGet Exit ExitApp FileAppend FileCopy FileCreateShortcut FileDelete FileExist
FileGetAttrib FileGetShortcut FileGetSize FileGetTime FileGetVersion FileInstall FileMove FileOpen FileRead FileSelect Float Floor
Format FormatTime Func GetKeyState Gui HasProp HotIf Hotkey InStr IniDelete IniRead IniWrite InputBox
InstallKeybdHook InstallMouseHook Integer IsAlpha IsDigit IsInteger IsNumber IsObject IsSet IsSpace KeyHistory
KeyWait ListLines LTrim Map Max Menu MenuSelect Min Mod MonitorGet MonitorGetCount MonitorGetName MonitorGetPrimary
MonitorGetWorkArea MouseGetPos MouseMove MsgBox NumGet NumPut ObjAddRef Object ObjFromPtr ObjFromPtrAddRef ObjPtr
ObjRelease OnExit OnMessage Ord OutputDebug Persistent PostMessage ProcessClose ProcessExist ProcessGetName
ProcessGetPath ProcessSetPriority ProcessWait Random RegExMatch RegExReplace RegRead RegWrite Reload Round RTrim Run
RunWait Send SendMessage SendMode SetKeyDelay SetTimer SetWinDelay SetWorkingDir Sleep Sort SoundBeep Sqrt
StrCompare StrGet StrLen StrLower StrPtr StrPut StrReplace StrSplit StrUpper String SubStr Suspend SysGet ToolTip
TraySetIcon TrayTip Trim Type VarSetStrCapacity VerCompare WinActivate WinActive WinClose WinExist WinGetClass
WinGetClientPos WinGetExStyle WinGetID WinGetList WinGetMinMax WinGetPID WinGetPos WinGetProcessName
WinGetProcessPath WinGetStyle WinGetTitle WinHide WinMaximize WinMinimize WinMove WinRedraw WinRestore
WinSetAlwaysOnTop WinSetExStyle WinSetRegion WinSetStyle WinSetTransparent WinShow WinWait WinWaitActive
WinWaitClose BlockInput Click Class""".split())
KEYWORDS = {"if", "while", "for", "return", "switch", "not", "and", "or", "catch", "until", "loop", "throw", "super"}
# globals from the libraries in Lib
LIB_GLOBALS = {"json", "webview2", "promise", "comvar"}

problems = []


def expand(path):
    """ZoneSnap.ahk with its #Include %A_ScriptDir%\\... lines replaced by the files"""
    out = []
    for line in open(path, encoding="utf-8-sig").read().split("\n"):
        m = re.match(r"#Include %A_ScriptDir%\\(.+)$", line.strip())
        out.append(open(os.path.join(ROOT, m.group(1).replace("\\", "/")), encoding="utf-8-sig").read() if m else line)
    return "\n".join(out)


def strip_line(line):
    """A line without its strings' contents and its comment"""
    out, q = "", None
    for i, c in enumerate(line):
        if q:
            if c == q:
                q = None
            continue
        if c in "\"'":
            q = c
            continue
        if c == ";" and (i == 0 or line[i - 1] in " \t"):
            break
        out += c
    return out


src = expand(MAIN)
raw = src.splitlines()
lines = [strip_line(l) for l in raw]
code = "\n".join(lines)

for a, b in ["{}", "()", "[]"]:
    if code.count(a) != code.count(b):
        problems.append(f"Unbalanced {a}{b}: {code.count(a)} {a} and {code.count(b)} {b}")

# names spelled two ways in one function
func_re = re.compile(r"^\s*([A-Za-z_]\w*)\(([^)]*)\)\s*\{\s*$")
stack = []
for ln, l in enumerate(lines, 1):
    m = func_re.match(l)
    if m and m.group(1).lower() not in ("if", "while", "for", "loop", "switch", "catch"):
        stack.append([m.group(1), ln, 0, set()])
    if stack:
        for fr in stack:
            c = re.sub(r"\.\s*[A-Za-z_]\w*", "", l)            # properties
            c = re.sub(r"\b[A-Za-z_]\w*\s*:(?!=)", "", c)       # object literal keys
            fr[3].update(re.findall(r"\b([A-Za-z_]\w*)\b", c))
        stack[-1][2] += l.count("{") - l.count("}")
        if stack[-1][2] <= 0 and ("{" in l or "}" in l):
            name, start, _, ids = stack.pop()
            spellings = {}
            for i in ids:
                spellings.setdefault(i.lower(), set()).add(i)
            for v in spellings.values():
                if len(v) > 1:
                    problems.append(f"{name} (line {start} of the expanded script) spells one name {len(v)} ways: {', '.join(sorted(v))}")

# locals that hide globals
globs = {m.lower() for m in re.findall(r"^global\s+([A-Za-z_]\w*)", src, re.M)} | LIB_GLOBALS
for fn in re.finditer(r"^([A-Za-z_]\w*)\([^)]*\)\s*\{(.*?)^\}", code, re.M | re.S):
    body = fn.group(2)
    declared = {x.strip().lower() for d in re.findall(r"^\s*global\s+(.*)$", body, re.M)
                for x in re.split(r"[,\s]+", d) if x.strip()}
    for v in sorted(set(re.findall(r"(?:^|[\s,(])([A-Za-z_]\w*)\s*:=", body, re.M))):
        if v.lower() in globs and v.lower() not in declared:
            problems.append(f"{fn.group(1)}: local {v} hides the global of that name")

# one-line try/for/loop/while followed by else
for i in range(1, len(lines)):
    if re.match(r"^\s*else\b", lines[i]):
        j = i - 1
        while j >= 0 and lines[j].strip() == "":
            j -= 1
        if re.match(r"^\s*(try|for|loop|while)\b", lines[j], re.I) and not lines[j].rstrip().endswith("{"):
            problems.append(f"An else is paired with a one-line {lines[j].split()[0]}: {raw[j].strip()}")

# FileInstall must start its line
for i, l in enumerate(lines):
    if re.search(r"\bFileInstall\b", l) and not re.match(r"^\s*FileInstall\b", l):
        problems.append(f"FileInstall not at the start of its line, so Ahk2Exe won't bundle it: {raw[i].strip()}")

# undefined functions
files = [MAIN] + [os.path.join(ROOT, "src", f) for f in sorted(os.listdir(os.path.join(ROOT, "src"))) if f.endswith(".ahk")]
calls_code, defs = "", set()
for path in files:
    for line in open(path, encoding="utf-8-sig"):
        l = re.sub(r'"(?:``|`"|[^"])*"', '""', line)
        l = re.sub(r"'(?:``|`'|[^'])*'", "''", l)
        l = re.sub(r"(^|\s);.*$", "", l)
        m = re.match(r"\s*(?:static\s+)?([A-Za-z_]\w*)\(([^()]|\([^()]*\))*\)\s*(\{|=>)", l)
        if m:
            defs.add(m.group(1).lower())
        calls_code += l
calls = {m.group(1) for m in re.finditer(r"(?<![.\w%])([A-Za-z_]\w*)\(", calls_code)}
for c in sorted(calls):
    if c.lower() not in defs and c not in BUILTIN and c.lower() not in KEYWORDS:
        problems.append(f"Call to {c}(), which isn't defined")

if problems:
    print(f"{len(problems)} problem(s):")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print(f"Static checks passed ({len(files)} files, {len(defs)} functions)")
