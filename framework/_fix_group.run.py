# -*- coding: utf-8 -*-
# CODING:UTF-8
# Fix freshly created POU: textual_declaration of a new object is empty, so the
# declaration must be written through the body (head first line + text + body).
import os
import scriptengine as se

SRC = r"C:\Users\Lenovo\Desktop\PLC\huichuan\Beveling machine\beveling\framework\sources"
NAME = "FB_RealCylinderGroup"


def as_unicode(text):
    if isinstance(text, unicode):
        return text
    return unicode(text, "utf-8")


def find_anywhere(app, name):
    for obj in app.get_children(True):
        try:
            if obj.get_name() == name:
                return obj
        except Exception:
            pass
    return None


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

path = os.path.join(SRC, "02_Devices", NAME + ".st")
f = open(path, "rb")
text = as_unicode(f.read().decode("utf-8"))
f.close()
if text and text[0] == u'\ufeff':
    text = text[1:]
text = text.replace("\r\n", "\n").replace("\r", "\n")

lines = text.split(u"\n")
head_idx = None
for idx in range(len(lines)):
    if lines[idx].startswith(u"FUNCTION_BLOCK "):
        head_idx = idx
        break
if head_idx is None:
    raise ValueError("FUNCTION_BLOCK line not found")
head = lines[head_idx]
body = u"\n".join(lines[head_idx + 1:])

obj = find_anywhere(app, NAME)
if obj is None:
    raise ValueError("object not found: %s" % NAME)
cur = obj.textual_declaration
print("decl before: %r" % (cur.text,))
cur.replace(head + u"\n" + body)
print("decl after len=%d" % len(cur.text))
print("impl len=%d" % len(obj.textual_implementation.text))
proj.save()
print("SAVED")
print("SCRIPT_SUCCESS")
