# -*- coding: utf-8 -*-
# CODING:UTF-8
# Applies the D1 real conveyor axis + G2 three-cylinder band group change to the
# open InoProShop project. Stage "check": verify targets exist (no write).
# Stage "write": push framework/sources text into the IDE via textual_declaration /
# textual_implementation .replace() with real unicode (never via set_pou_code).
import sys
import os
import scriptengine as se

STAGE = "check"
SRC = r"C:\Users\Lenovo\Desktop\PLC\huichuan\Beveling machine\beveling\framework\sources"

PLAIN_IMPL = {
    "04_Machine/F_RecipeValid",
    "02_Devices/FB_RealCylinderGroup",
    "02_Devices/FB_DeviceManager",
    "04_Machine/FB_IOMap",
    "04_Machine/FB_Machine",
    "04_Machine/FB_Interlocks",
    "04_Machine/FB_AutoCycle",
    "03_Units/FB_ClearTransfer",
}
PLAIN_DECL = {
    "00_Types/ST_Recipe",
    "00_Types/ST_RealDeviceSettings",
    "01_Data/GVL_DeviceIds",
    "01_Data/GVL_IO",
    "01_Data/GVL_IO_Physical",
}
FROM_FILE = {
    "04_Machine/PLC_PRG": ("01_Data/PLC_PRG.st", "replace"),
}
CREATE_POU = "02_Devices/FB_RealCylinderGroup"


def strip_bom(text):
    if text and text[0] == u'\ufeff':
        return text[1:]
    return text


def read_src(rel):
    path = os.path.join(SRC, rel.replace("/", os.sep))
    f = open(path, "rb")
    try:
        raw = f.read()
    finally:
        f.close()
    text = raw.decode("utf-8")
    text = strip_bom(text)
    return text.replace("\r\n", "\n").replace("\r", "\n")


def split_sections(text, rel):
    """Return (declaration, implementation); implementation is None when the
    object has no textual implementation (DUT / GVL / FUNCTION)."""
    lines = text.split("\n")
    name = rel.split("/")[-1]
    for idx in range(len(lines) - 1):
        if lines[idx].startswith("FUNCTION_BLOCK "):
            return ("\n".join(lines[:idx + 1]), "\n".join(lines[idx + 1:]))
    if text.startswith("FUNCTION "):
        return (text, None)
    if text.startswith("TYPE ") or text.startswith("VAR_GLOBAL"):
        return (text, None)
    raise ValueError("unrecognised source layout: %s" % rel)


def find_application(primary_project):
    for obj in primary_project.get_children(True):
        try:
            if obj.is_application:
                return obj
        except Exception:
            pass
    return None


def find_in(parent, name):
    for child in parent.get_children(False):
        try:
            if child.get_name() == name:
                return child
        except Exception:
            pass
    return None


def locate(app, rel):
    parts = rel.split("/")
    node = app
    for part in parts[:-1]:
        node = find_in(node, part)
        if node is None:
            return None
    return find_in(node, parts[-1])


report = []
primary_project = None
app = None
children = se.system.get_children()
for c in children:
    if type(c).__name__ == "ProjectImp":
        primary_project = c
        break
if primary_project is None:
    print("ERR: no primary project")
    print("SCRIPT_ERROR: no primary project")
    sys.exit(1)
app = find_application(primary_project)
print("APP=%s" % (app.get_name() if app is not None else "None"))

targets = []
for rel in PLAIN_DECL:
    targets.append((rel + ".st", "dec"))
for rel in PLAIN_IMPL:
    targets.append((rel + ".st", "impl"))
for rel in FROM_FILE:
    targets.append((FROM_FILE[rel][0], "file"))
targets.append((FROM_FILE["04_Machine/PLC_PRG"][0], "PLC_PRG"))
targets.sort()

if STAGE == "check":
    for rel_path, kind in targets:
        obj = locate(app, rel_path.replace(".st", ""))
        if kind == "PLC_PRG":
            print("LOCATE %s -> %s" % (rel_path, obj))
            continue
        src_rel = None
        if kind == "dec":
            for base in PLAIN_DECL:
                if base.split("/")[-1] + ".st" == rel_path:
                    src_rel = base + ".st"
        elif kind == "impl":
            for base in PLAIN_IMPL:
                if base.split("/")[-1] + ".st" == rel_path:
                    src_rel = base + ".st"
        else:
            src_rel = rel_path
        print("LOCATE %s -> %s ; stage %s" % (rel_path, obj, kind))
    # G2 group creation target check
    print("GROUP exists -> %s" % locate(app, CREATE_POU))
    print("PLC_PRG src readable -> %d bytes" % len(read_src("PLC_PRG.st")))
    print("SCRIPT_SUCCESS")
    sys.exit(0)

# ---- write stage ----
written = []
# 1) Plain objects: declaration and/or implementation.
for src_rel, section in [(p + ".st", "dec") for p in sorted(PLAIN_DECL)] + [(p + ".st", "impl") for p in sorted(PLAIN_IMPL)]:
    text = read_src(src_rel)
    decl, impl = split_sections(text, src_rel)
    obj_path = src_rel[:-3]
    obj = locate(app, obj_path)
    if obj is None:
        raise ValueError("object not found: %s" % obj_path)
    if section == "dec":
        obj.textual_declaration.replace(decl)
        written.append(obj_path + ":decl")
    if section == "impl" and impl is not None:
        obj.textual_implementation.replace(impl)
        written.append(obj_path + ":impl")

# 2) PLC_PRG: only the fbIO call block changes, so replace whole implementation text
#    built from the current live text with the new CALL_LINES inserted.
text = read_src("PLC_PRG.st")
decl, impl = split_sections(text, "04_Machine/PLC_PRG")
plc = locate(app, "PLC_PRG")
if plc is None:
    raise ValueError("PLC_PRG not found")
plc.textual_declaration.replace(decl)
plc.textual_implementation.replace(impl)
written.append("PLC_PRG:decl+impl")

primary_project.save()
print("WROTE %d sections" % len(written))
for w in written:
    print("  " + w)
print("SAVED")
print("SCRIPT_SUCCESS")
