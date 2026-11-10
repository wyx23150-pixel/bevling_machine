# -*- coding: utf-8 -*-
# CODING:UTF-8
# Repair pass: SP11 replaces the WHOLE POU text through either section handle, so
# every written object now carries a stripped declaration. Write head + full text
# (declaration block + implementation) through textual_declaration, then verify the
# implementation section came back as just the body.
import os
import scriptengine as se

STAGE = "__STAGE__"
SRC = r"__SRC__"

# name -> (folder, source file, head line, has implementation)
FB_TARGETS = [
    ("02_Devices", "FB_DeviceManager", "FUNCTION_BLOCK FB_DeviceManager"),
    ("02_Devices", "FB_RealCylinderGroup", "FUNCTION_BLOCK FB_RealCylinderGroup"),
    ("03_Units", "FB_ClearTransfer", "FUNCTION_BLOCK FB_ClearTransfer"),
    ("04_Machine", "FB_AutoCycle", "FUNCTION_BLOCK FB_AutoCycle"),
    ("04_Machine", "FB_IOMap", "FUNCTION_BLOCK FB_IOMap"),
    ("04_Machine", "FB_Interlocks", "FUNCTION_BLOCK FB_Interlocks"),
    ("04_Machine", "FB_Machine", "FUNCTION_BLOCK FB_Machine"),
]
PRG_TARGETS = [
    ("", "PLC_PRG", "PROGRAM PLC_PRG"),
]
FUN_TARGETS = [
    ("04_Machine", "F_RecipeValid", "FUNCTION F_RecipeValid : BOOL"),
]
DUT_TARGETS = [
    ("00_Types", "ST_Recipe"),
    ("00_Types", "ST_RealDeviceSettings"),
]
GVL_TARGETS = [
    ("01_Data", "GVL_DeviceIds"),
    ("01_Data", "GVL_IO"),
    ("01_Data", "GVL_IO_Physical"),
]


def as_unicode(text):
    if isinstance(text, unicode):
        return text
    return unicode(text, "utf-8")


def read_src(rel):
    path = os.path.join(SRC, rel.replace("/", os.sep))
    f = open(path, "rb")
    raw = f.read()
    f.close()
    text = as_unicode(raw.decode("utf-8"))
    if text and text[0] == u'\ufeff':
        text = text[1:]
    return text.replace("\r\n", "\n").replace("\r", "\n")


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


def locate(app, folder, name):
    if folder:
        node = find_in(app, folder)
        if node is not None:
            found = find_in(node, name)
            if found is not None:
                return found
    return find_anywhere(app, name)


def normalise(text):
    return u"\n".join([line.rstrip() for line in text.replace(u"\r\n", u"\n").split(u"\n")])


projs = se.projects
proj = projs.primary if projs.primary is not None else projs[0]
app = None
for obj in proj.get_children(True):
    try:
        if obj.is_application:
            app = obj
            break
    except Exception:
        pass

report = []


def describe(name, folder):
    obj = locate(app, folder, name)
    if obj is None:
        return None, "MISSING"
    d = ""
    i = ""
    try:
        d = obj.textual_declaration.text
    except Exception:
        pass
    try:
        i = obj.textual_implementation.text
    except Exception:
        pass
    return obj, "decl=%d impl=%d" % (len(d), len(i))


def write_full(obj, full):
    sec = obj.textual_declaration
    sec.replace(full)
    return sec.text


if STAGE == "check":
    for folder, name, head in FB_TARGETS + PRG_TARGETS + FUN_TARGETS:
        obj, info = describe(name, folder)
        print("%-22s %s" % (name, info))
        if obj is not None:
            try:
                print("    decl head: %r" % (obj.textual_declaration.text.split("\n")[0][:60],))
                print("    impl head: %r" % (obj.textual_implementation.text.split("\n")[0][:60],))
            except Exception as e:
                print("    read err %s" % e)
    for folder, name in DUT_TARGETS + GVL_TARGETS:
        obj, info = describe(name, folder)
        print("%-22s %s" % (name, info))
        if obj is not None:
            try:
                print("    decl head: %r" % (obj.textual_declaration.text.split("\n")[0][:60],))
            except Exception as e:
                print("    read err %s" % e)
    print("SCRIPT_SUCCESS")
    sys.exit(0)

# ---- write stage ----
for folder, name, head in FB_TARGETS + PRG_TARGETS + FUN_TARGETS:
    obj = locate(app, folder, name)
    if obj is None:
        raise ValueError("missing object %s" % name)
    rel = (folder + "/" + name if folder else name) + ".st"
    text = read_src(rel)
    full = head + u"\n" + text[text.index(head) + len(head):].lstrip(u"\n")
    after = write_full(obj, full)
    impl_after = obj.textual_implementation.text
    report.append("%s decl %d->%d impl=%d" % (name, len(full), len(after), len(impl_after)))

for folder, name in DUT_TARGETS + GVL_TARGETS:
    obj = locate(app, folder, name)
    if obj is None:
        raise ValueError("missing object %s" % name)
    rel = (folder + "/" + name if folder else name) + ".st"
    text = read_src(rel)
    after = write_full(obj, text)
    report.append("%s decl len=%d" % (name, len(after)))

proj.save()
print("REPAIRED %d objects" % len(report))
for r in report:
    print("  " + r)
print("SAVED")
print("SCRIPT_SUCCESS")
