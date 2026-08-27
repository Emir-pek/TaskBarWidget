# -*- coding: utf-8 -*-
""". saydam | o kontur | h sac | H sac isik | s ten | S ten golge
   j ceket mavi | J ceket koyu | t siyah ust | n pantolon | f ayakkabi
   k goz | m agiz | w parlama | y oyuncak sap | r oyuncak tuy"""

def pad(rows, w=None):
    w = w or max(len(r) for r in rows)
    return [r.ljust(w, '.') for r in rows]

# --- ortak kafa (satir 0-12), 18 genis ---
HEAD = [
    "......oooooo........",
    ".....ohhhhhhho......",
    "....ohhhhhhhhhho....",
    "...ohhhhhhhhhhhho...",
    "...ohhHhhhhhhHhho...",
    "...ohhssssssssHho...",
    "...ohhskksskkshho...",
    "...ohhssssssssHho...",
    "...ohhsssmmssshho...",
    "...ohhssSSSSsshho...",
    "...ohhhoSSSSohhho...",
    "...ohhhoSSSSohhho...",
    "...ohhhoSSSSohhho...",
]
HEAD_BLINK = HEAD[:6] + ["...ohhsooosooshho..."[:20]] + HEAD[7:]
HEAD_SMILE = HEAD[:8] + ["...ohhssommosshho..."[:20]] + HEAD[9:]

def torso(arm_l, arm_r, legs, head=None):
    """arm_l/arm_r: 10 satirlik 3 genis kol sutunlari (satir 13-22)"""
    head = head or HEAD
    body = [
        "ojjjjjjo",   # 13 omuz
        "jjjttjjj",   # 14
        "jjjttjjj",   # 15
        "jjjttjjj",   # 16
        "jjjttjjj",   # 17
        "jjjttjjj",   # 18
        "jjjttjjj",   # 19
        "jjttttjj",   # 20
        "jjttttjj",   # 21
        "ojttttjo",   # 22
    ]
    rows = list(head)
    for i, b in enumerate(body):
        rows.append(".." + arm_l[i] + "o" + b + "o" + arm_r[i] + "..")
    rows.extend(legs)
    return pad(rows)

ARM_DOWN = ["ohh", "ohh", "ohh", "ojj", "ojj", "ojo", "ojo", "ojo", "oso", "oso"]
ARM_DOWN_R = ["hho", "hho", "hho", "jjo", "jjo", "ojo", "ojo", "ojo", "oso", "oso"]
ARM_SWING_F = ["ohh", "ohh", "ojj", "ojj", "ojo", "ojo", "oso", "...", "...", "..."]
ARM_SWING_B = ["ohh", "ohh", "ohh", "ojj", "ojj", "ojo", "ojo", "ojo", "ojo", "oso"]
# kalkik kol (oyuncak tutar)
ARM_UP    = ["oso", "ojo", "ojo", "ojo", "ohh", "ohh", "ohh", "ohh", "ohh", "ohh"]

LEGS_STAND = [
    "....onnnoonnno....",
    "....onnnoonnno....",
    "....onnnoonnno....",
    "....onnnoonnno....",
    "....onnnoonnno....",
    "....onnnoonnno....",
    "...offfo..offfo...",
    "...ooooo..ooooo...",
]
LEGS_W1 = [
    "....onnnoonnno....",
    "...onnno..onnno...",
    "...onnno...onnno..",
    "..onnno....onnno..",
    "..onnno.....onnno.",
    "..onno......onno..",
    ".offfo......offfo.",
    ".ooooo......ooooo.",
]
LEGS_W2 = LEGS_STAND
LEGS_W3 = [
    "....onnnoonnno....",
    "...onnno..onnno...",
    "..onnno....onnno..",
    "..onnno....onnno..",
    ".onnno......onnno.",
    ".onno.......onno..",
    "offfo.......offfo.",
    "ooooo.......ooooo.",
]
LEGS_W4 = LEGS_STAND

HUMAN_STAND = torso(ARM_DOWN, ARM_DOWN_R, LEGS_STAND)
HUMAN_WALK_1 = torso(ARM_SWING_F, ARM_SWING_B, LEGS_W1)
HUMAN_WALK_2 = torso(ARM_DOWN, ARM_DOWN_R, LEGS_W2)
HUMAN_WALK_3 = torso(ARM_SWING_B, ARM_SWING_F, LEGS_W3)
HUMAN_WALK_4 = torso(ARM_DOWN, ARM_DOWN_R, LEGS_W4)

# --- oyuncak sallama: sag kol yukarida, elinde tuylu cubuk ---
def wave(tilt, head=None):
    rows = torso(ARM_DOWN, ARM_UP, LEGS_STAND, head)
    w = max(len(r) for r in rows)
    grid = [list(r.ljust(w + 12, '.')) for r in rows]
    # el konumu: sag kol ust ucu ~ satir 13, col 16-17
    hx, hy = 17, 13
    for i in range(6):                       # cubuk
        x = hx + i
        y = hy - i + tilt * (1 if i > 2 else 0)
        if 0 <= y < len(grid) and x < len(grid[0]):
            grid[y][x] = 'y'
    tx, ty = hx + 6, hy - 5 + tilt
    tuft = ["rrr", "rrrr", ".rrr"]           # tuy
    for dy, line in enumerate(tuft):
        for dx, ch in enumerate(line):
            if ch == '.':
                continue
            x, y = tx + dx - 1, ty + dy - 1
            if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
                grid[y][x] = 'r'
    return pad([''.join(r).rstrip('.') or '.' for r in grid])

HUMAN_WAVE_1 = wave(0, HEAD_SMILE)
HUMAN_WAVE_2 = wave(1, HEAD_SMILE)
HUMAN_WAVE_3 = wave(2, HEAD)

# --- comelme / sevme ---
HUMAN_CROUCH_1 = pad([
    "..................",
    "..................",
    "..................",
    "....oooooooo......",
    "...ohhhhhhhho.....",
    "..ohhhhhhhhhho....",
    "..ohhhhhhhhhhho...",
    "..ohhhhhhhhhhho...",
    "..ohhsssssssHho...",
    "..ohhsooosooshho..",
    "..ohhsssssssshoo..",
    "..ohhssmmssshho...",
    "..ohhsSSSSSshho...",
    "..ohhhossssohho...",
    ".oohhhoSSSSohhoo..",
    ".ojjjjjjjjjjjjjo..",
    ".ojjjjttttjjjjjo..",
    ".ojjjttttttjjjooo.",
    ".ojjjttttttjjjosso",
    ".ojjttttttttjjoo..",
    ".onnnnnnnnnnnno...",
    ".onnnnnnnnnnnno...",
    "onnnnoooonnnnno...",
    "onnno....onnnno...",
    "onnno....onnno....",
    "offfoo..offfo.....",
    "ooooooo.oooo......",
])
HUMAN_CROUCH_2 = pad([
    "..................",
    "..................",
    "..................",
    "....oooooooo......",
    "...ohhhhhhhho.....",
    "..ohhhhhhhhhho....",
    "..ohhhhhhhhhhho...",
    "..ohhhhhhhhhhho...",
    "..ohhsssssssHho...",
    "..ohhsooosooshho..",
    "..ohhsssssssshoo..",
    "..ohhsommosshho...",
    "..ohhsSSSSSshho...",
    "..ohhhossssohho...",
    ".oohhhoSSSSohhoo..",
    ".ojjjjjjjjjjjjjo..",
    ".ojjjjttttjjjjjoooooo",
    ".ojjjttttttjjjjossssso",
    ".ojjjttttttjjjjoooooo",
    ".ojjttttttttjjoo..",
    ".onnnnnnnnnnnno...",
    ".onnnnnnnnnnnno...",
    "onnnnoooonnnnno...",
    "onnno....onnnno...",
    "onnno....onnno....",
    "offfoo..offfo.....",
    "ooooooo.oooo......",
])

HUMAN_POSES = {
    "stand": HUMAN_STAND,
    "walk_1": HUMAN_WALK_1, "walk_2": HUMAN_WALK_2,
    "walk_3": HUMAN_WALK_3, "walk_4": HUMAN_WALK_4,
    "wave_1": HUMAN_WAVE_1, "wave_2": HUMAN_WAVE_2, "wave_3": HUMAN_WAVE_3,
    "crouch_1": HUMAN_CROUCH_1, "crouch_2": HUMAN_CROUCH_2,
}

# ==================================================================
#  EFEKTLER
# ==================================================================
HEART = [
    ".oo.oo.",
    "oMMoMMo",
    "oMMMMMo",
    ".oMMMo.",
    "..oMo..",
    "...o...",
]
HEART_S = [
    ".o.o.",
    "oMoMo",
    "oMMMo",
    ".oMo.",
    "..o..",
]
ZZZ_BIG = ["ooooo", "...oo", "..oo.", ".oo..", "ooooo"]
ZZZ_MID = ["oooo", "..oo", ".oo.", "oooo"]
ZZZ_SML = ["ooo", ".oo", "ooo"]

SPARK = [".o.", "ooo", ".o."]

FX_POSES = {
    "heart": HEART, "heart_s": HEART_S,
    "zzz_1": ZZZ_BIG, "zzz_2": ZZZ_MID, "zzz_3": ZZZ_SML,
    "spark": SPARK,
}
