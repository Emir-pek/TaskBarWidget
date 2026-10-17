# -*- coding: utf-8 -*-
"""Electron surumunun ortak varliklarini uretir.

scene.js ve sprite sheet TEK kaynaktan gelir: kaynak/. Bu betik onlari
masaustu/ortak/ altina kopyalar ve tepsi ikonunu uretir.
scene.js'i her degistirdiginde bunu tekrar calistir.
"""
import json, os, shutil
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT  = os.path.join(ROOT, "masaustu", "ortak")
os.makedirs(OUT, exist_ok=True)

shutil.copy2(os.path.join(HERE, "scene.js"), os.path.join(OUT, "scene.js"))
for name in ("sprites.png", "sprites.json"):
    shutil.copy2(os.path.join(HERE, "assets", name), os.path.join(OUT, name))

# --- tepsi ikonu: Tarcin'in oturan halinin kafasi ---------------------
meta  = json.load(open(os.path.join(OUT, "sprites.json")))
sheet = Image.open(os.path.join(OUT, "sprites.png")).convert("RGBA")
f = meta["frames"]["tarcin_sit_a"]
cell = sheet.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))

left, top, right, bottom = cell.getbbox()
head = cell.crop((left, top, right, top + int((bottom - top) * 0.62)))

side = max(head.width, head.height)
icon = Image.new("RGBA", (side, side), (0, 0, 0, 0))
icon.paste(head, ((side - head.width) // 2, (side - head.height) // 2))
icon.resize((32, 32), Image.NEAREST).save(os.path.join(OUT, "tray.png"))

print("masaustu/ortak/ hazir -> scene.js, sprites.png, sprites.json, tray.png")
