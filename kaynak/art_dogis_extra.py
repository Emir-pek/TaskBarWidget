# -*- coding: utf-8 -*-
"""Dogis - ek pozlar: sevilme (pet) ve sinirlenme (angry, kollar kavusturulmus).

Tum pozlar `stand` ile ayni tuvalde: 20 genis x 31 satir, ayaklar en alt satirda,
yatay bbox merkezi stand ile ayni (9.5). Yan etkisiz import edilir.

Yeni palet anahtarlari (HUM_PAL_ADD):
  L  ceket kol isigi (one gelen on kol)     p  pembe yanak (mutlu)
  q  kizarmis ten (sinirli)                  Q  kizarmis ten golge
  R  koyu kirmizi yanak (sinirli)
"""
import art_human as _A                  # ayni klasorde (kaynak/)

HEAD, LEGS_STAND = _A.HEAD, _A.LEGS_STAND
W = 20

HUM_PAL_ADD = dict(
    L="#3a6fe8",   # kol isigi
    p="#f08c8c",   # mutlu yanak
    q="#f0846f",   # kizarik ten
    Q="#c95f50",   # kizarik ten golge
    R="#e0584e",   # sinirli yanak
)
ANGER_PAL = dict(
    a="#e8333b",   # damar isareti kirmizi
    A="#a8162a",   # damar isareti koyu kenar
    v="#eef1f4",   # buhar
    V="#8d97a3",   # buhar kenar
)


def _face(inner, base=HEAD, start=5):
    """Yuz ic bolgesini (sutun 6-13, 8 piksel) satir satir degistir."""
    h = list(base)
    for i, r in enumerate(inner):
        if r is None:
            continue
        assert len(r) == 8, r
        h[start + i] = h[start + i][:6] + r + h[start + i][14:]
    return h


def _down1(head):
    """Kafayi 1 px asagi bastir (okşanirken): ust satir bos, boyun 1 kisalir."""
    return ["." * W] + head[:-1]


#                 67890123
HEAD_PET_1 = _face(["ssssssss",
                    "skksskks",     # kapali mutlu gozler  ^ ^
                    "kssssssk",
                    "ppommopp"])    # yanak + gulumseme (HEAD_SMILE agzi)
HEAD_PET_2 = _down1(_face(["ssssssss",
                           "skksskks",
                           "pssssssp",  # yanak kabarir (nabiz)
                           "ppommopp"]))

HEAD_ANGRY_1 = _face(["kkqqqqkk",   # catik kaslar: dis uc yukarda
                      "qkkqqkkq",   # \ /  ice-asagi egik kizgin gozler
                      "RqqqqqqR",   # koyu kirmizi yanaklar
                      "RRqooqRR",   # surat asma
                      "qqSSSSqq"])
HEAD_ANGRY_2 = _face(["kkqqqqkk",
                      "qkkqqkkq",
                      "RqqqqqqR",
                      "RqooooqR",   # "hmph" - agiz genisler (puf)
                      "qqSSSSqq"])

# kollar kavusturulmus govde (satir 13-22): ustteki on kol acik mavi (L/j),
# eli sagdaki ust kolu kavrar; alttaki on kol koyu (J), eli soldan gorunur.
# Dirsekler yanlara tasar (sol ustte, sag altta) -> bbox 1..18, merkez 9.5.
ARMS_CROSSED = [
    #01234567890123456789
    "..ohhoojjjjjjoohho..",   # 13
    "..ohhojjjttjjjohho..",   # 14
    "..ohhojjjttjjjohho..",   # 15
    ".ojjjoooooooooojjo..",   # 16
    ".ojjLLLLLLLLLLLsso..",   # 17
    ".ojjjjjjjjjjjjjsso..",   # 18
    "..oooooooooooooojjo.",   # 19
    "..ossJJJJJJJJJJJJjo.",   # 20
    "..ossJJJJJJJJJJJJoo.",   # 21
    "...oooooooooooooo...",   # 22
]

# ayak vurma: sag ayak 1 px kalkik
LEGS_TAP = [
    "....onnnoonnno......",
    "....onnnoonnno......",
    "....onnnoonnno......",
    "....onnnoonnno......",
    "....onnnoonnno......",
    "....onnnooofffo.....",
    "...offfo..ooooo.....",
    "...ooooo............",
]


def _pad(rows):
    return [r.ljust(W, ".")[:W] for r in rows]


def _crossed(head, legs=LEGS_STAND):
    return _pad(list(head) + ARMS_CROSSED + list(legs))


PET_1 = _A.torso(_A.ARM_DOWN, _A.ARM_DOWN_R, LEGS_STAND, HEAD_PET_1)
PET_2 = _A.torso(_A.ARM_DOWN, _A.ARM_DOWN_R, LEGS_STAND, HEAD_PET_2)
ANGRY_1 = _crossed(HEAD_ANGRY_1)
ANGRY_2 = _crossed(HEAD_ANGRY_2, LEGS_TAP)

DOGIS_EXTRA_POSES = {
    "pet_1": _pad(PET_1), "pet_2": _pad(PET_2),
    "angry_1": ANGRY_1, "angry_2": ANGRY_2,
}

# ---------------- efektler ----------------
# manga sinir damari (💢): dort kose, merkezde arti seklinde bosluk
FX_ANGER_1 = [
    "..a.a..",
    ".Aa.aA.",
    "aaA.Aaa",
    ".......",
    "aaA.Aaa",
    ".Aa.aA.",
    "..a.a..",
]
FX_ANGER_2 = [            # kucuk (nabiz) - ayni 7x7 tuvalde ortali
    ".......",
    "..a.a..",
    ".aa.aa.",
    ".......",
    ".aa.aa.",
    "..a.a..",
    ".......",
]
FX_HUFF = [               # minik "hmph" buhari (yuzun yaninda)
    "..VV.",
    ".VvvV",
    "Vvvv.",
    ".VV..",
]

FX_EXTRA_POSES = {
    "fx_anger_1": FX_ANGER_1,
    "fx_anger_2": FX_ANGER_2,
    "fx_huff": FX_HUFF,
}
