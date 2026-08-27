# -*- coding: utf-8 -*-
""". saydam | o kontur | b govde | d koyu | l acik/beyaz | p pembe
   e goz irisi | k goz bebegi | w parlama"""

W = 25  # yan gorunum genisligi

def pad(rows, w=None):
    w = w or max(len(r) for r in rows)
    return [r.ljust(w, '.') for r in rows]

def stack(*blocks):
    rows = []
    for b in blocks:
        rows.extend(b)
    return pad(rows)

# ------------------------------------------------------------------
#  YAN GORUNUM GOVDE (saga bakar) - 12 satir
#  kafa satir 0-8 (col 13-24) govdeden 3 satir yukarida durur
#  govde satir 5-11 (col 1-16) | kuyruk col 0-3 | agiz col 22-24
# ------------------------------------------------------------------
SIDE_BODY = [
    "...............oo...oo...",
    "..............opbo.obpo..",
    "..oo..........obbbbbbbbo.",
    ".obbo........obbbbbbbbbbo",
    ".obbo........obbbbbbewbbo",
    ".obbo.oooooooobbbbbbkebbo",
    "..obboddddddbbbbbbbbbbppo",
    "...obbbbbbbbbbbbbbbbbppo.",
    "..obbbbbbbbbbbbbbbbbbbbo.",
    "..obbbbbbbbbbbbbbbbbbbo..",
    "..obllllllllllllllllbbo..",
    "...obllllllllllllllbo....",
]

# ---- bacaklar: programatik ----
# taban x: uzak-arka 4, yakin-arka 8, uzak-on 14, yakin-on 18
LEG_BASE = [3, 7, 13, 17]

def make_legs(offsets, lifts, rows=4, width=W):
    grid = [['.'] * width for _ in range(rows)]
    def put(x, y, ch):
        if 0 <= x < width and 0 <= y < rows:
            grid[y][x] = ch
    order = [(0, True), (2, True), (1, False), (3, False)]  # uzaklar once
    for idx, far in order:
        x = LEG_BASE[idx] + offsets[idx]
        lift = lifts[idx]
        fill = 'd' if far else 'b'
        paw = 'd' if far else 'l'
        w = 3 if far else 4
        h = rows - lift
        for y in range(h):
            for dx in range(w):
                put(x + dx, y, 'o' if dx in (0, w - 1) else fill)
        # pati
        for dx in range(w):
            put(x + dx, h - 1, 'o' if dx in (0, w - 1) else paw)
        for dx in range(w):
            put(x + dx, h, 'o')
    return [''.join(r) for r in grid]

LEGS_STAND = make_legs([0, 0, 0, 0], [0, 0, 0, 0])
LEGS_W1    = make_legs([2, -2, -2, 2], [0, 1, 1, 0])
LEGS_W2    = make_legs([0, 0, 0, 0], [0, 0, 0, 0])
LEGS_W3    = make_legs([-2, 2, 2, -2], [1, 0, 0, 1])
LEGS_W4    = make_legs([0, 0, 0, 0], [0, 0, 0, 0])
LEGS_CROUCH = make_legs([1, -1, -1, 1], [2, 2, 2, 2])

STAND  = stack(SIDE_BODY, LEGS_STAND)
WALK_1 = stack(SIDE_BODY, LEGS_W1)
WALK_2 = stack(SIDE_BODY, LEGS_W2)
WALK_3 = stack(SIDE_BODY, LEGS_W3)
WALK_4 = stack(SIDE_BODY, LEGS_W4)

# ---- ziplama ----
JUMP_1 = stack(SIDE_BODY, LEGS_CROUCH)          # comelme
JUMP_2 = stack(SIDE_BODY, [                     # havada, bacaklar toplu
    "...obbo..obbo..obbo.obbo",
    "...ollo..ollo..ollo.ollo",
    "....oo....oo....oo...oo.",
    "........................",
])
JUMP_3 = stack(SIDE_BODY, [                     # havada, bacaklar acik
    ".obbo.......obbo....obbo",
    "ollo.........ollo....oll",
    "oo............oo......oo",
    "........................",
])

# ------------------------------------------------------------------
#  OTURAN KEDI (on-3/4)   22 genis
# ------------------------------------------------------------------
def sit(eyes, tail):
    """19 piksel genisliginde govde + sag tarafa 6 piksel kuyruk sutunu"""
    head = [
        "....oo........oo...",
        "...obpo......opbo..",
        "..obbpo......opbbo.",
        "..obbppoooooopplbo.",
        "..obbbbbbbbbbbbbbo.",
        ".obbbbbbbbbbbbbbbbo",
    ]
    eye_rows = [
        ".obbb" + e + "bbbb" + e[::-1] + "bbbo" for e in eyes
    ]
    lower = [
        ".obbbbbbbppbbbbbbbo",
        "..obbbbopoobbbbbbo.",
        "..obbbbbbbbbbbbbbo.",
        "..obbllllllllllbbo.",
        ".obbllllllllllllbbo",
        ".obllllllllllllllbo",
        "obblllllllllllllbbo",
        "oblllllllllllllllbo",
        "oblllllllllllllllbo",
        "obblllllllllllllbbo",
        ".obboolllllloobbbo.",
        "..oo..oooooo..ooo..",
    ]
    rows = head + eye_rows + lower
    n = len(rows)
    out = []
    for i, r in enumerate(rows):
        j = i - (n - len(tail))
        out.append(r + (tail[j] if j >= 0 else ''))
    return pad(out)

EYE_OPEN  = ["wee", "eke", "eke"]
EYE_HAPPY = ["ooo", "obo", "bbb"]     # ^ ^ mutlu goz
EYE_SHUT  = ["bbb", "ooo", "bbb"]

TAIL_DOWN = [".oo...", "obbo..", "obbo..", ".obbo.", "..obo.", "..obo.", "..obo.", "..ooo."]
TAIL_UP   = ["oo....", "obo...", "obo...", "obbo..", ".obbo.", "..obbo", "...obo", "...ooo"]

SIT_A  = sit(EYE_OPEN,  TAIL_DOWN)
SIT_B  = sit(EYE_OPEN,  TAIL_UP)
SIT_BLINK = sit(EYE_SHUT, TAIL_DOWN)
SIT_HAPPY = sit(EYE_HAPPY, TAIL_UP)

# yukari bakan (gozler yukarida)
LOOKUP = pad([
    "....oo........oo......",
    "...obpo......opbo.....",
    "..obbpo......opbbo....",
    "..obbppoooooopplbo....",
    "..obbbwbbbbbbwbbbbo...",
    ".obbbekebbbbekebbbo...",
    ".obbbekebbbbekebbbo...",
    ".obbbeeebbbbeeebbbo...",
    ".obbbbbbbppbbbbbbbo...",
    "..obbbbbopobbbbbbbo...",
    "..obbbbbbbbbbbbbbbo...",
    "..obbllllllllllbbbo...",
    ".obbllllllllllllbbo...",
    ".obllllllllllllllbo...",
    "obbllllllllllllllbboo..",
    "obllllllllllllllllbobbo",
    "obllllllllllllllllbo.obo",
    "obbllllllllllllllbbo.obo",
    ".obboolllllloobbbbo..obo",
    "..oo..oooooo..oooo...ooo",
])

# basini surtme: govde yana egilir
RUB_A = SIT_HAPPY
RUB_B = pad([
    "......oo........oo....",
    ".....obpo......opbo...",
    "....obbpo......opbbo..",
    "....obbppoooooopplbo..",
    "....obbbbbbbbbbbbbbo..",
    "...obbbooobbooobbbbo..",
    "...obbbobobobobbbbbo..",
    "...obbbbbbbbbbbbbbbo..",
    "...obbbbbbppbbbbbbbo..",
    "....obbbbopobbbbbbbo..",
    "...obbbbbbbbbbbbbbo...",
    "..obbllllllllllbbbo...",
    ".obbllllllllllllbbo...",
    ".obllllllllllllllbo.oo",
    "obbllllllllllllllbbobbo",
    "obllllllllllllllllbo.bo",
    "obllllllllllllllllbo.obo",
    "obbllllllllllllllbbo.obo",
    ".obboolllllloobbbbo..obo",
    "..oo..oooooo..oooo...ooo",
])

from art_sleep import SLEEP_A, SLEEP_B, YAWN, STRETCH

CAT_POSES = {
    "stand": STAND, "walk_1": WALK_1, "walk_2": WALK_2,
    "walk_3": WALK_3, "walk_4": WALK_4,
    "jump_1": JUMP_1, "jump_2": JUMP_2, "jump_3": JUMP_3,
    "sit_a": SIT_A, "sit_b": SIT_B, "sit_blink": SIT_BLINK, "sit_happy": SIT_HAPPY,
    "lookup": LOOKUP, "rub_a": RUB_A, "rub_b": RUB_B,
    "sleep_a": SLEEP_A, "sleep_b": SLEEP_B, "yawn": YAWN, "stretch": STRETCH,
}
