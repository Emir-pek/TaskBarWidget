# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw
import art_cat

T = (0, 0, 0, 0)

def rgb(h):
    h = h.lstrip('#')
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), 255)

# --- Karakter paletleri ---
PALETTES = {
 # 1) turuncu-beyaz kisa tuylu, yesilimsi goz
 "tarcin": dict(o="#5c2a12", b="#e8873a", d="#c25f22", l="#fdf6ec",
                p="#f2a6b0", e="#9ed36a", k="#1d2415", w="#ffffff"),
 # 2) kabarik krem/turuncu, amber goz
 "pamuk":  dict(o="#7a4a26", b="#f6cf98", d="#e0ab6c", l="#fffaf0",
                p="#f2a6b0", e="#e0a13c", k="#2a1c0d", w="#ffffff"),
 # 3) gri British, sari goz
 "duman":  dict(o="#3a3f46", b="#8e979f", d="#6d767e", l="#b9c0c6",
                p="#d99aa2", e="#f2c230", k="#1a1d21", w="#ffffff"),
}

def render(rows, pal, scale=1):
    w = max(len(r) for r in rows)
    h = len(rows)
    img = Image.new("RGBA", (w, h), T)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '.' or ch == ' ':
                continue
            c = pal.get(ch)
            if c is None:
                c = "#ff00ff"
            px[x, y] = rgb(c)
    if scale != 1:
        img = img.resize((w*scale, h*scale), Image.NEAREST)
    return img

def contact_sheet(poses, pal, scale=6, cols=4, bg="#2b2f36", label=True):
    names = list(poses.keys())
    cw = max(max(len(r) for r in poses[n]) for n in names) * scale + 8
    chh = max(len(poses[n]) for n in names) * scale + (18 if label else 8)
    rows_n = (len(names) + cols - 1)//cols
    sheet = Image.new("RGBA", (cw*cols, chh*rows_n), rgb(bg))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        cx = (i % cols) * cw
        cy = (i//cols) * chh
        im = render(poses[n], pal, scale)
        sheet.alpha_composite(im, (cx+4, cy+4))
        if label:
            d.text((cx+4, cy+chh-14), n, fill=(255,255,255,255))
    return sheet

if __name__ == "__main__":
    s = contact_sheet(art_cat.CAT_POSES, PALETTES["tarcin"], scale=6, cols=4)
    s.save("build/cats_tarcin.png")
    print("ok", s.size)
