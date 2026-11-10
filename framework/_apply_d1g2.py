# -*- coding: utf-8 -*-
# CODING:UTF-8
# Applies the D1 real conveyor axis + G2 three-cylinder band group change to the
# open InoProShop project. Stage "check": verify targets exist (no write).
# Stage "write": push framework/sources text into the IDE via textual_declaration /
# textual_implementation .replace() with real unicode (never via set_pou_code).
import sys
import os
import scriptengine as se

STAGE = "__STAGE__"
SRC = r"__SRC__"

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


def as_unicode(text):
    if isinstance(text, unicode):
        return text
    return unicode(text, "utf-8")


def strip_bom(text):
    text = as_unicode(text)
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
    text = as_unicode(raw.decode("utf-8"))
    text = strip_bom(text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return text


def split_sections(text, rel):
    """Return (declaration, implementation); implementation is None when the
    object has no textual implementation (DUT / GVL / FUNCTION)."""
    lines = text.split(u"\n")
    for idx in range(len(lines) - 1):
        if lines[idx].startswith(u"PROGRAM "):
            return ("", u"\n".join(lines[idx + 1:]))
        if lines[idx].startswith(u"FUNCTION_BLOCK "):
            return (u"\n".join(lines[:idx + 1]), u"\n".join(lines[idx + 1:]))
    if u"\nTYPE " in text or u"\nVAR_GLOBAL" in text or u"\nFUNCTION " in text:
        return (text, None)
    raise ValueError("unrecognised source layout: %s" % rel)


def split_header(text, head):
    """Drop the leading 'FUNCTION_BLOCK X' / 'PROGRAM X' line and a '(* ... *)'
    module comment that follows it: InoProShop keeps the declaration block in
    POU_head (which textual_declaration returns) and the tool must not repeat."""
    pos = text.find(head)
    rest = text[pos + len(head):]
    rest = rest.lstrip(u"\n")
    if rest.startswith(u"(*"):
        end = rest.find(u"*)")
        if end >= 0 and u";" not in rest[:end]:
            rest = rest[end + 2:]
            if rest.startswith(u"\n"):
                rest = rest[1:]
    return rest


def normalise_ws(text):
    return u"\n".join([line.rstrip() for line in text.replace(u"\r\n", u"\n").split(u"\n")])


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


def find_anywhere(app, name):
    for obj in app.get_children(True):
        try:
            if obj.get_name() == name:
                return obj
        except Exception:
            pass
    return None


def locate(app, rel):
    parts = rel.split("/")
    if len(parts) == 1:
        return find_in(app, parts[0])
    node = app
    for part in parts[:-1]:
        node = find_in(node, part)
        if node is None:
            return find_anywhere(app, parts[-1])
    return find_in(node, parts[-1])


report = []
projs = se.projects
primary_project = projs.primary if projs.primary is not None else projs[0]
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
    print("PLC_PRG anywhere -> %s" % find_anywhere(app, "PLC_PRG"))
    for obj in app.get_children(False):
        print("  top-level child: %s" % obj.get_name())
    print("PLC_PRG src readable -> %d bytes" % len(read_src("PLC_PRG.st")))
    print("SCRIPT_SUCCESS")
    sys.exit(0)

# ---- write stage ----
written = []
# 1) Plain objects: declaration and/or implementation.
# 0) New FB_RealCylinderGroup: create under Application/02_Devices first.
if locate(app, CREATE_POU) is None:
    folder = locate(app, "02_Devices")
    if folder is None:
        raise ValueError("folder 02_Devices not found")
    folder.create_pou(name="FB_RealCylinderGroup", type=se.PouType.FunctionBlock, language=se.ImplementationLanguages.st)
    written.append("CREATE " + CREATE_POU)

for src_rel, section in [(p + ".st", "dec") for p in sorted(PLAIN_DECL)] + [(p + ".st", "impl") for p in sorted(PLAIN_IMPL)]:
    text = read_src(src_rel)
    decl, impl = split_sections(text, src_rel)
    obj_path = src_rel[:-3]
    obj = locate(app, obj_path)
    if obj is None:
        raise ValueError("object not found: %s" % obj_path)
    if section == "dec":
        obj.textual_declaration.replace(decl)
        now = obj.textual_declaration.text
        if normalise_ws(now) != normalise_ws(decl):
            raise ValueError("declaration mismatch after write: %s (now %d chars, want %d)" % (obj_path, len(now), len(decl)))
        written.append(obj_path + ":decl")
    if section == "impl" and impl is not None:
        obj.textual_implementation.replace(impl)
        now = obj.textual_implementation.text
        if normalise_ws(now) != normalise_ws(impl):
            raise ValueError("implementation mismatch after write: %s (now %d chars, want %d)" % (obj_path, len(now), len(impl)))
        written.append(obj_path + ":impl")

# 2) PLC_PRG sits at application root; replace only the implementation (fbIO call block changed).
text = read_src("PLC_PRG.st")
decl, impl = split_sections(text, "PLC_PRG")
plc = locate(app, "PLC_PRG")
if plc is None:
    raise ValueError("PLC_PRG not found")
plc_impl = split_header(impl, u"PROGRAM PLC_PRG")
plc.textual_implementation.replace(plc_impl)
if normalise_ws(plc.textual_implementation.text) != normalise_ws(plc_impl):
    raise ValueError("PLC_PRG implementation mismatch after write")
written.append("PLC_PRG:impl")

# 3) New FB_RealCylinderGroup: create under Application/02_Devices, then push text.
text = read_src(CREATE_POU + ".st")
decl, impl = split_sections(text, CREATE_POU)
grp = locate(app, CREATE_POU)
if grp is None:
    raise ValueError("FB_RealCylinderGroup not found after create")
grp_decl = split_header(decl, u"FUNCTION_BLOCK FB_RealCylinderGroup")
grp.textual_declaration.replace(grp_decl)
grp.textual_implementation.replace(impl)
if normalise_ws(grp.textual_declaration.text) != normalise_ws(grp_decl):
    raise ValueError("FB_RealCylinderGroup declaration mismatch after write")
if normalise_ws(grp.textual_implementation.text) != normalise_ws(impl):
    raise ValueError("FB_RealCylinderGroup implementation mismatch after write")
written.append(CREATE_POU + ":decl+impl")

primary_project.save()
print("WROTE %d sections" % len(written))
for w in written:
    print("  " + w)
print("SAVED")
print("SCRIPT_SUCCESS")
