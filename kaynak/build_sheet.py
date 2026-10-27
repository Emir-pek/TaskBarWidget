# -*- coding: utf-8 -*-
import json, os
from PIL import Image
import art_cat, art_human, render
import art_sun, art_decor, art_dogis_extra

os.makedirs("assets", exist_ok=True)

# ---------------- palet ----------------
CAT_PAL = {
 "tarcin": dict(o="#5a2a12", b="#e8873a", d="#c05e22", l="#fdf5e8",
                p="#f0a2ae", e="#8fc95f", k="#17200f", w="#ffffff"),
 "maya":  dict(o="#8a5a2e", b="#f4cf9a", d="#dcae72", l="#fffdf5",
                p="#f0a2ae", e="#e3a33c", k="#2b1c0c", w="#ffffff"),
 "zilli":  dict(o="#333941", b="#8d969e", d="#6b747c", l="#c2c9cf",
                p="#d698a0", e="#f5c62e", k="#161a1e", w="#ffffff"),
}
HUM_PAL = dict(o="#241c1a", h="#332723", H="#584038", s="#e8b489", S="#c48f66",
               j="#efe8d8", J="#cdbfa6", t="#2d3b68", B="#4a5fd0", n="#2b303c", f="#15151a",
               k="#1a1210", m="#c4675f", w="#ffffff", y="#8a5a2b", r="#e05a7a")
FX_PAL = dict(o="#8f1f3a", M="#ff5f7e", w="#ffffff")
FX_PAL_Z = dict(o="#dfe6ef", M="#dfe6ef", w="#ffffff")
HUM_PAL.update(art_dogis_extra.HUM_PAL_ADD)          # yanak / kizarma renkleri
ANGER_PAL = art_dogis_extra.ANGER_PAL
SUN_PAL = art_sun.SUN_PAL
DECOR_PAL = art_decor.DECOR_PAL

# Bu aileler KIRPILMADAN hucrenin sol-alt kosesine konur: motor (scene.js)
# kanvas koordinatlarina gore yerlestirir, kareler arasi kayma olmasin.
NO_TRIM = ("sun_", "giraffe_", "flower_", "fx_anger", "fx_huff")

# ---------------- sekil degistiriciler ----------------
def trim(rows):
    """Bastaki/sondaki bos satir ve sutunlari kirp (taban hizasi sasmasin)."""
    rs = [r for r in rows]
    while rs and set(rs[0]) <= {'.'}:  rs.pop(0)
    while rs and set(rs[-1]) <= {'.'}: rs.pop()
    if not rs:
        return ["."]
    w = max(len(r) for r in rs)
    rs = [r.ljust(w, '.') for r in rs]
    l, r = 0, w - 1
    while l < w and all(row[l] == '.' for row in rs): l += 1
    while r > l and all(row[r] == '.' for row in rs): r -= 1
    return [row[l:r + 1] for row in rs]

def to_grid(rows):
    w = max(len(r) for r in rows)
    return [list(r.ljust(w, '.')) for r in rows]

def from_grid(g):
    return [''.join(r) for r in g]

def dilate(rows, horiz_only=False, pad=1):
    """Siluetii 1 px buyutur: fluffy / chonky gorunum."""
    g = to_grid(rows)
    h, w = len(g), len(g[0])
    ng = [['.'] * (w + 2 * pad) for _ in range(h + 2 * pad)]
    for y in range(h):
        for x in range(w):
            if g[y][x] != '.':
                ng[y + pad][x + pad] = g[y][x]
    # halka: bos ve komsusu dolu olan pikseller -> kontur
    ring = []
    ds = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    if horiz_only:
        ds = [(-1, 0), (1, 0)]
    for y in range(len(ng)):
        for x in range(len(ng[0])):
            if ng[y][x] != '.':
                continue
            for dx, dy in ds:
                yy, xx = y + dy, x + dx
                if 0 <= yy < len(ng) and 0 <= xx < len(ng[0]) and ng[yy][xx] != '.':
                    ring.append((x, y)); break
    for x, y in ring:
        ng[y][x] = 'o'
    # eski konturlar artik ic tarafta -> govde rengine cevir
    for y in range(1, len(ng) - 1):
        for x in range(1, len(ng[0]) - 1):
            if ng[y][x] == 'o' and (x, y) not in ring:
                nb = [ng[y + dy][x + dx] for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]]
                if all(c != '.' for c in nb):
                    ng[y][x] = 'b'
    return from_grid(ng)

def tufts(rows, cols):
    """Ust silueti uzerine 1 px tuy dikenleri ekler."""
    g = to_grid(rows)
    w = len(g[0])
    out = [['.'] * w] + g
    for x in cols:
        if x >= w:
            continue
        for y in range(1, len(out)):
            if out[y][x] != '.':
                out[y - 1][x] = 'o'
                break
    return from_grid(out)

LEGGED = {"stand", "walk_1", "walk_2", "walk_3", "walk_4",
          "jump_1", "jump_2", "jump_3", "stretch"}

def variant(name, pose, rows):
    """Palet disinda siluet farki: maya kabarik, zilli tombul."""
    if name == "maya":
        if pose in LEGGED:
            return tufts(rows, [2, 5, 8, 11])          # sirtta tuy dikenleri
        return tufts(dilate(rows), [3, 5, 8, 12, 16, 20])
    if name == "zilli":
        if pose in LEGGED or pose.startswith("sleep") or pose == "yawn":
            return rows                                 # yuz/bacak bozulmasin
        return dilate(rows, horiz_only=True)            # yuvarlak/tombul
    return rows                                          # tarcin: kisa tuylu

# ---------------- kareleri topla ----------------
frames = {}   # ad -> (rows, palet)
for cname, pal in CAT_PAL.items():
    for pose, rows in art_cat.CAT_POSES.items():
        frames["%s_%s" % (cname, pose)] = (variant(cname, pose, rows), pal)
for pose, rows in art_human.HUMAN_POSES.items():
    frames["dogis_" + pose] = (rows, HUM_PAL)
for pose, rows in art_dogis_extra.DOGIS_EXTRA_POSES.items():
    frames["dogis_" + pose] = (rows, HUM_PAL)
for name, rows in art_dogis_extra.FX_EXTRA_POSES.items():
    frames[name] = (rows, ANGER_PAL)
for name, rows in art_sun.SUN_POSES.items():
    frames[name] = (rows, SUN_PAL)
for name, rows in art_decor.DECOR_POSES.items():
    frames[name] = (rows, DECOR_PAL)
for pose, rows in art_human.FX_POSES.items():
    pal = FX_PAL_Z if pose.startswith("zzz") else FX_PAL
    frames["fx_" + pose] = (rows, pal)

def no_trim(n):
    return n.startswith(NO_TRIM)

chars = [v for n, v in frames.items() if not no_trim(n)]
CW = max(max(len(r) for r in rows) for rows, _ in chars) + 2
CH = max(len(rows) for rows, _ in chars) + 2
for n, (rows, _) in frames.items():
    if no_trim(n):
        assert max(len(r) for r in rows) <= CW and len(rows) <= CH, (n, CW, CH)
# TransparencyKey (Windows) magentasi hicbir palette olmamali
for n, (rows, pal) in frames.items():
    for ch in set("".join(rows)) - {".", " "}:
        c = pal.get(ch)
        assert c is not None, (n, ch)
        assert c.lower() not in ("#ff00ff", "#fe00fe"), (n, ch)
COLS = 10
names = sorted(frames)
ROWS = (len(names) + COLS - 1) // COLS

sheet = Image.new("RGBA", (CW * COLS, CH * ROWS), (0, 0, 0, 0))
index = {}
for i, n in enumerate(names):
    rows, pal = frames[n]
    nt = no_trim(n)
    im = render.render(rows if nt else trim(rows), pal)
    cx, cy = (i % COLS) * CW, (i // COLS) * CH
    lx = 0 if nt else (CW - im.width) // 2
    ly = CH - im.height                 # alta hizala (ayaklar taskbar cizgisinde)
    sheet.alpha_composite(im, (cx + lx, cy + ly))
    index[n] = dict(x=cx, y=cy, w=CW, h=CH, sw=im.width, sh=im.height, ox=lx, oy=ly)

sheet.save("assets/sprites.png")
json.dump(dict(cell_w=CW, cell_h=CH, frames=index), open("assets/sprites.json", "w"), indent=1)
print("sheet", sheet.size, "frames", len(names), "cell", CW, CH)
