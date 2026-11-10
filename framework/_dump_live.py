# -*- coding: utf-8 -*-
# CODING:UTF-8
# Dump live declaration/implementation text of the changed objects for inspection.
import os
import scriptengine as se

BASE = r"C:\Users\Lenovo\Desktop\PLC\huichuan\Beveling machine\beveling\framework"
NAMES = ["ST_RealDeviceSettings", "ST_Recipe", "GVL_DeviceIds", "GVL_IO", "GVL_IO_Physical",
         "FB_DeviceManager", "FB_RealCylinderGroup", "FB_ClearTransfer", "FB_AutoCycle",
         "FB_IOMap", "FB_Interlocks", "FB_Machine", "PLC_PRG"]


def find_anywhere(app, name):
    for obj in app.get_children(True):
        try:
            if obj.get_name() == name:
                return obj
        except Exception:
            pass
    return None


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

for name in NAMES:
    obj = find_anywhere(app, name)
    if obj is None:
        print("MISSING %s" % name)
        continue
    try:
        d = obj.textual_declaration.text
    except Exception as e:
        d = None
    try:
        i = obj.textual_implementation.text
    except Exception as e:
        i = None
    out = u"=== " + name + u" ===\n--- DECL ---\n" + (d if d is not None else u"<none>") + u"\n--- IMPL ---\n" + (i if i is not None else u"<none>") + u"\n"
    path = os.path.join(BASE, "_live_" + name + ".txt")
    f = open(path, "wb")
    f.write(out.encode("utf-8"))
    f.close()
    print("%s decl=%s impl=%s" % (name, len(d) if d is not None else "-", len(i) if i is not None else "-"))
print("SCRIPT_SUCCESS")
