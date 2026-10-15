"""Orc heads, round 5 (critic r4 fix 1): hand-placed grids, one per source facing; the mirrors reuse them.

A broad skull, flattened on top, over a heavy jaw that is wider than the skull; a 2-row brow shelf in skin
step 4, a 1-px dark line under it, 2x1 soot eyes, a broad nose, a mouth line, and bone tusks rising from the
lower jaw past the upper lip.

Each grid letter is a hand-placed PLANE of the head, not a tone: its tone comes from the plane's normal and
the key light (draw.LIGHT, flipped for the mirrored facings, so W/SW/NW are lit from camera-left too), and its
normal goes to the normal strip. Codes: ' ' not head; 'K' soot 0; 'e' eye (soot 0); 'b' brow shelf (skin
step 4 in every facing); 'u' skin step 1, inside the face only (lead ruling 2026-10-16: never on a pixel
that touches the silhouette); 'y'/'x' tusk, left/right column (bone 3 lit, bone 2 shaded).
Planes: q top-left, t top, o top-right, l left side, h left-front, f front, p right-front, r right side,
w lower front, g underside.
"""

PLANES = {
    'q': (-0.5, -0.6, 0.62), 't': (0.0, -0.8, 0.6), 'o': (0.5, -0.6, 0.62),
    'l': (-0.8, 0.0, 0.6), 'h': (-0.5, 0.0, 0.87), 'f': (0.0, 0.0, 1.0), 'p': (0.5, 0.0, 0.87),
    'r': (0.8, 0.0, 0.6), 'w': (0.0, 0.4, 0.92), 'g': (0.0, 0.8, 0.6),
    'b': (0.0, -0.6, 0.8), 'u': (0.0, 0.3, 0.95), 'e': (0.0, 0.3, 0.95), 'K': (0.0, 0.0, 1.0),
    'y': (-0.5, 0.0, 0.87), 'x': (0.5, 0.0, 0.87),
}
SKIN = (['E', 'D', 'C'], [0.87, 0.75])      # plane tone: step 4 at d >= 0.87, step 3 at d >= 0.75, else step 2
TUSK = (['y', 'x'], [0.6])                  # bone 3 lit, bone 2 shaded
FIXED = {'K': 'K', 'e': 'K', 'u': 'B', 'b': 'E'}

# facing -> (x0, y0, rows)
HEADS = {
    0: (76, 36, [                       # S: jaw 21 px across its bottom 6 rows, crown 13 px
        "      KKKKKKKKKKKKK      ",
        "     KqqqqtttttttooK     ",
        "    KlqqqqttttttooorK    ",
        "    KllqqfffffffoorrK    ",
        "   KlbbbbbbbbbbbbbbbrK   ",
        "   KlbbbbbbbfbbbbbbbrK   ",
        "   KlfuuuuuuhuuuuuuprK   ",
        "   KlfffeeffhpfeeffprK   ",
        "  KllffffffhhpffffffprK  ",
        "  KllfffffugggufffffprK  ",
        " KllfffyfffffffffyfffprK ",
        " KllfffyxfffffffyxfffprK ",
        " KllfffyxfffffffyxfffprK ",
        " KllfffyxKKKKKKKyxfffprK ",
        " KllwwwwwffffffffwwwwrrK ",
        " KllwwwwwwwwwwwwwwwwwrrK ",
        " KKKKKKKKKKKKKKKKKKKKKKK ",
    ]),
    1: (80, 35, [                       # SE: three-quarter, face to the right, jaw over the far pauldron
        "      KKKKKKKKKK         ",
        "    KKqqqqttttooKK       ",
        "   KlqqqqttttttoooK      ",
        "  KllqqqtttttttffooK     ",
        "  KlllhhhbbbbbbbbbbbK    ",
        "  KlllhhhbbbbbbbbbbbbK   ",
        "  KlllhhhfuuuuuuuuuuK    ",
        "  KllhhhffffeeppppeepK   ",
        " KlllhhhfffffpppppfpppK  ",
        " KlllhhhfffffppppugggpK  ",
        " KlllhhfyffpppppppypprK  ",
        " KlllhhfyxfppppppyxpprK  ",
        " KlllhhfyxfppppppyxpprrK ",
        " KlllhhfyxKKKKKKKyxpprrK ",
        "KllllhhwwwwffffffwwwwwrrK",
        "KllllwwwwwwwwwwwwwwwwwrrK",
        " KlllggggggggggggggggrrK ",
        " KKKKKKKKKKKKKKKKKKKKKKK ",
    ]),
    2: (80, 33, [                       # E: profile, jaw 3 px ahead of the brow, forehead sloping back
        "     KKKKKKKKK            ",
        "   KKqqqqttttoKK          ",
        "  KqqqqqtttttooKK         ",
        " KlqqqqtttttttoooK        ",
        " KllqqfffffffffoorK       ",
        "KlllfffffffbbbbbbbbK      ",
        "KlllfffffffbbbbbbbbbbK    ",
        "KlllffffffffffuuuuurK     ",
        "KlllffffffffffffeefrK     ",
        "KlllfffffffffffffffoorK   ",
        "KlllfffffffffffffffgggK   ",
        "KlllfffffffffffffffryK    ",
        "KlllfffffffffffffffryxK   ",
        "KlllfffffffffffffKKKyxK   ",
        "KlllfffffffffffffffffffrrK",
        "KlllwwwwwwwwwwwwwwwwwwrrK ",
        " KllggggggggggggggggggrrK ",
        " KlllffffKKKKKKKKKKKKKKKK ",
        " KlllffffK                ",
    ]),
    3: (82, 28, [                       # NE: back three-quarter, the jaw corner and a tusk tip at the right
        "     KKKKKKKKK          ",
        "   KKqqqqttttoKK        ",
        "  KqqqqqtttttooK        ",
        " KlqqqqttttttooooK      ",
        " KllqqffffffffppooK     ",
        " KllffffffffffppprK     ",
        " KllfffffffffffppprK    ",
        " KllfffffffffffppprK    ",
        " KllffffffffffppprK     ",
        " KllffffffffffpppprK    ",
        "KlllffffffffffpppprrKK  ",
        "KlllffffffffffppppprrxK ",
        "KlllffffffffffppppprrxK ",
        "KlllfffffffffwwwwpprrK  ",
        "KlllwwwwwwwwwwwwwpprrK  ",
        " KllwwwwwwwwwwwwggrrK   ",
        " KllfffffffffKKKKKKK    ",
        " KllfffffffffK          ",
    ]),
    4: (76, 26, [                       # N: the back of the head, the jaw corners wider than the skull
        "      KKKKKKKKKKKKK      ",
        "     KqqqqtttttooooK     ",
        "    KlqqqqttttttooorK    ",
        "    KllqqffffffffforrK   ",
        "   KllffffffffffffprrK   ",
        "   KllffffffffffffprrK   ",
        "   KllffffffffffffprrK   ",
        "   KllffffffffffffprrK   ",
        "  KlllffffffffffffpprrK  ",
        "  KlllffffffffffffpprrK  ",
        " KlllfffffffffffffppprrK ",
        " KlllfffffffffffffppprrK ",
        " KlllwwwwwwwwwwwwwppprrK ",
        " KlllwwwwwwwwwwwwwppprrK ",
        " KKKlwwwwwwwwwwwwwwwrKKK ",
        "   KlfffffffffffffffrK   ",
        "   KlfffffffffffffffrK   ",
    ]),
}
