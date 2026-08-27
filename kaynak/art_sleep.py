# -*- coding: utf-8 -*-
"""Uyku / esneme / gerinme pozlari.
Yuruyus sprite'inin ispatli kafasi uzerine kurulu: belirgin kulaklar,
kapali goz, pembe burun; govde yere yatik; kuyruk arkadan disari kivrilir."""

def pad(rows):
    w = max(len(r) for r in rows)
    return [r.ljust(w, '.') for r in rows]

SLEEP_A = pad([
    "....................oo...oo...",
    "...................opbo.obpo..",
    "...................obbbbbbbbo.",
    "..................obbbbbbbbbbo",
    "..................obbbbbbbbbbo",
    "...........oooooobbbboooobbbo.",
    "........oooddddddbbbbbbbbbbppo",
    "......oobbbbbbbbbbbbbbbbbbbppo",
    ".....obbbbbbbbbbbbbbbbbbbbbbo.",
    "....obbbbbbbllllllllllllllbbo.",
    "oo..obbbbbllllllllllllllllbbo.",
    "obo.obbbbbbllllllllllllllbbbo.",
    "obbooobbbbbbbbbbbbbbbbbbbbbo..",
    ".obbbbbbbbbbbbbbbbbbbbbbbbo...",
    "..oooooooooooooooooooooooo....",
])

SLEEP_B = pad([                       # nefes alis: govde 1 px kabarir
    "....................oo...oo...",
    "...................opbo.obpo..",
    "...................obbbbbbbbo.",
    "..................obbbbbbbbbbo",
    "..................obbbbbbbbbbo",
    "..........oooooobbbbboooobbbo.",
    ".......oooddddddbbbbbbbbbbbppo",
    ".....oobbbbbbbbbbbbbbbbbbbbppo",
    "....obbbbbbbbbbbbbbbbbbbbbbbo.",
    "....obbbbbbbbbbbbbbbbbbbbbbbo.",
    "oo..obbbbllllllllllllllllllbo.",
    "obo.obbbbllllllllllllllllllbo.",
    "obbooobbbbllllllllllllllllbo..",
    ".obbbbbbbbbbbbbbbbbbbbbbbbo...",
    "..oooooooooooooooooooooooo....",
])

YAWN = pad([                          # esneme: gozler kisik, agiz acik
    "....................oo...oo...",
    "...................opbo.obpo..",
    "...................obbbbbbbbo.",
    "..................obbbbbbbbbbo",
    "..................obbbbbbbbbbo",
    "...........oooooobbbboooobbbo.",
    "........oooddddddbbbbbbbbbopo.",
    "......oobbbbbbbbbbbbbbbbbokko.",
    ".....obbbbbbbbbbbbbbbbbbokkko.",
    "....obbbbbllllllllllllbbbokko.",
    "oo..obbbbllllllllllllllllboo..",
    "obo.obbbbllllllllllllllllllbo.",
    "obbooobbbbbbbbbbbbbbbbbbbbbo..",
    ".obbbbbbbbbbbbbbbbbbbbbbbbo...",
    "..oooooooooooooooooooooooo....",
])

STRETCH = pad([                       # gerinme: on patiler ileri, kalca yukarida
    "..................oo...oo.",
    ".................opbo.obpo",
    "....ooooo........obbbbbbbo",
    "..oobbbbbboo....obbbbbbbbb",
    ".obbbbbbbbbboo.obbbbbbbbbb",
    "obbdddddddddbbobbbboooobbb",
    "obbdddddddddbbbbbbbbbbbbpp",
    "obbbbbbbbbbbbbbbbbbbbbbbpp",
    ".obbllllllllllllllllllllbo",
    ".obbllllllllllllllllllllbo",
    ".obblbo..obbbllllllllllbo.",
    ".oblbo...obblllllllllllbo.",
    ".oblo....obbbbbbbbbbbbbo..",
    ".ooo.....oooooooooooooo...",
])

SLEEP_POSES = dict(sleep_a=SLEEP_A, sleep_b=SLEEP_B, yawn=YAWN, stretch=STRETCH)
