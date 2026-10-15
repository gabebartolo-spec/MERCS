"""Proof sheet for MERCS Ledger: 4K mock panels of real en.json text beside a reference face.

    python tools/typeface/proof_board.py --out D:/MERCS-vault/renders/typeface_2026-10-15 \
        --ref "D:/MERCS-vault/fonts_trial/tiny5/Tiny5[BLED,JITT,ROND,wdth,wght].ttf"

Every size is an integer multiple of the font's grid at 1920x1080 logical, doubled for the
4K canvas_items stretch, and drawn straight at physical size (no resampling), so the mock is
what the TV shows. Prints, per mock: colours found that are not one of the drawn colours
(blended pixels: must be 0 for our face), the WCAG contrast of every text colour on its
panel, and whether the slice help line fits on one line at 1920 px.
"""

import argparse
import json
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
EN = json.loads((ROOT / "data" / "text" / "en.json").read_text(encoding="utf-8"))
STRETCH = 2  # 1920x1080 logical -> 3840x2160
# look B core (assets/palette/core.json): soot, bone, heraldry gold, fire
SOOT0, SOOT1, SOOT3 = "#17120f", "#261e19", "#45392f"
BONE_HI, BONE, BONE_MID = "#efe1bd", "#d6c7a4", "#a59574"
GOLD, FIRE = "#d29a2a", "#e07a28"
STYLE_COLOUR = {"title": GOLD, "head": GOLD, "body": BONE_HI, "button": BONE_HI, "dim": BONE_MID,
                "wound": FIRE, "help": BONE}
CONFUSION = ["Il1| O0 rn m cl d S5 Z2 B8 HP SP", "Attack Defense lost c e r 8B s9 4 3",
             "Recruits  Rerruits  0123456789  44 33"]


def t(key, **kw):
    s = EN[key]
    for k, v in kw.items():
        s = s.replace("{" + k + "}", str(v))
    return s


def panel_lines():
    """(style, text): a hub, a recruit, the company panel and an aftermath, real strings."""
    wound = t("wiring.outcome.permanent", name="The Orc", injury=t("injury.lost_eye.name"),
              role=t("injury.lost_eye.role"))
    return [
        ("title", t("hub.title", day=14)),
        ("body", t("hub.status", purse=212, morale=6)),
        ("rule", ""),
        ("body", t("hub.wages.owed", owed=36, per_day=12, count=3, days=3)),
        ("button", t("hub.pay", owed=36)),
        ("rule", ""),
        ("head", t("hub.recruits.title", cost=40)),
        ("button", t("hub.recruit.hire", name="Bandit chief")),
        ("body", t("slice.recruit.body", name="Hedda", hp=14, attack=6, defense=4, presence=5)),
        ("rule", ""),
        ("head", t("company.header", name="The Orc", level=3)),
        ("dim", t("company.stat.hp", value=14) + "   " + t("company.stat.attack", value=6) + "   "
         + t("company.stat.defense", value=4) + "   " + t("company.stat.resolve", value=5)),
        ("wound", wound),
        ("body", t("company.injuries", list=t("company.injury.permanent", name="a lost eye"))),
        ("dim", t("memory.comrade_died", name="Hedda", day=9)),
        ("rule", ""),
        ("help", t("slice.help")),
    ]


def wrap(draw, text, font, width):
    out = []
    for para in text.split("\n"):
        cur = ""
        for word in para.split(" "):
            trial = (cur + " " + word) if cur else word
            if draw.textlength(trial, font=font) <= width or not cur:
                cur = trial
            else:
                out.append(cur)
                cur = word
        out.append(cur)
    return out


def luminance(hex_colour):
    c = [int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mock(face, out_png):
    """face: dict(label, body path/size, title path/size, line px). Returns stats."""
    W, H = 3840, 2160
    im = Image.new("RGB", (W, H), SOOT0)
    d = ImageDraw.Draw(im)
    body = ImageFont.truetype(face["body"], face["body_px"] * STRETCH)
    title = ImageFont.truetype(face["title"], face["title_px"] * STRETCH)
    x0, y0, pw = 160, 120, 1920 * STRETCH - 320
    d.rectangle([x0 - 48, y0 - 40, x0 + pw + 48, H - 80], fill=SOOT1)
    lh_body = face["line_px"] * STRETCH
    y = y0
    help_fits = None
    for style, text in panel_lines():
        if style == "rule":
            y += lh_body // 3
            d.rectangle([x0, y, x0 + pw, y + STRETCH * face["rule_px"] - 1], fill=SOOT3)
            y += lh_body // 2
            continue
        font = title if style in ("title",) else body
        if style == "help":
            help_fits = d.textlength(text, font=font) <= pw
        for ln in wrap(d, text, font, pw):
            d.text((x0, y), ln, font=font, fill=STYLE_COLOUR[style])
            y += face["title_line_px"] * STRETCH if style == "title" else lh_body
    y += lh_body
    for ln in CONFUSION:
        d.text((x0, y), ln, font=body, fill=BONE_HI)
        y += lh_body
    im.save(out_png)
    drawn = {SOOT0, SOOT1, SOOT3} | set(STYLE_COLOUR.values())
    drawn = {tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in drawn}
    counts = im.getcolors(1 << 24)
    blended = sum(n for n, c in counts if c not in drawn)
    return {"face": face["label"], "blended_pixels": blended, "colours": len(counts),
            "help_on_one_line": help_fits, "text_bottom_px": y}


def zoom(src, box, k, out):
    im = Image.open(src).crop(box)
    im.resize((im.width * k, im.height * k), Image.NEAREST).save(out)
    return out


SCENES = ["slice.arrive", "world.encounter.ambush", "slice.gate", "slice.fate", "slice.return"]
HEAD_CONFUSION = ["Il1| O0 rn m", "cl d S5 Z2 B8", "HP SP c e r s9", "Attack Defense", "Recruits Rerruits",
                  "Q O 0 8 0800 1048", "4 3 44 33 ! ? %", "“Aye,” he said.", "AV Ve Fa Po LT"]
HEADS = ["world.ironman.title", "end.title", "hub.prisoner.title", "slice.contract.title"]


def scene_panel(display, regular, out_png, label):
    """A 4K half-screen panel: real en.json scene headers (Display 42 -> 84 px) over their body text
    (Regular 28 -> 56 px), then more headers and two names. Returns (image, blended pixel count)."""
    W, H = 1900, 2040
    im = Image.new("RGB", (W, H), SOOT1)
    d = ImageDraw.Draw(im)
    head = ImageFont.truetype(display, 42 * STRETCH)
    body = ImageFont.truetype(regular, 28 * STRETCH)
    x, y, pw = 40, 30, W - 80
    d.text((x, y), label, font=body, fill=BONE_MID)
    y += 34 * STRETCH + 10
    for key in SCENES:
        d.text((x, y), EN[key + ".title"], font=head, fill=GOLD)
        y += 51 * STRETCH
        body_text = EN.get(key + ".body", "").replace("{day}", "14")
        for ln in wrap(d, body_text, body, pw)[:2]:
            d.text((x, y), ln, font=body, fill=BONE_HI)
            y += 34 * STRETCH
        y += 12
    for text in [EN[k] for k in HEADS] + [t("company.fallen.title", name="Hedda"),
                                          t("company.header", name="The Orc", level=3),
                                          t("world.header", day=14, supplies=1048)]:
        d.text((x, y), text, font=head, fill=GOLD)
        y += 51 * STRETCH
    im = im.crop((0, 0, W, min(H, y + 20)))
    im.save(out_png)
    drawn = {tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in (SOOT1, GOLD, BONE_HI, BONE_MID)}
    return im, sum(n for n, c in im.getcolors(1 << 24) if c not in drawn)


def board_v2(a, out):
    """Old Display beside the new one on the same real scene headers, then the confusion lines
    of the new Display and the Regular at 4x of the 4K screen (nearest neighbour)."""
    A, ba = scene_panel(a.old_display, a.regular, out / "panel_display_old.png", "A  Display before (round 1)")
    B, bb = scene_panel(a.display, a.regular, out / "panel_display_new.png", "B  Display now (grit)")
    zooms = []
    for path, px, label in ((a.display, 42, "Display now, 84 px on 4K, 4x"),
                            (a.old_display, 42, "Display before, 84 px on 4K, 4x"),
                            (a.regular, 28, "Regular (body), 56 px on 4K, 4x")):
        f = ImageFont.truetype(path, px * STRETCH)
        lines = (CONFUSION + ["Q O 0 8 0800 1048 ! ? % 100%", "“Aye,” he said. AV Ve Fa Po LT"]
                 if px == 28 else HEAD_CONFUSION)
        lh = px * STRETCH * 17 // 14
        strip = Image.new("RGB", (940, lh * len(lines) + 16), SOOT1)
        ds = ImageDraw.Draw(strip)
        for i, ln in enumerate(lines):
            ds.text((8, 8 + i * lh), ln, font=f, fill=BONE_HI)
        zooms.append((label, strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST)))
    lab = ImageFont.truetype(a.regular, 28 * STRETCH)
    Wb = 3840 + 60
    Hb = 40 + max(A.height, B.height) + sum(z.height + 120 for _, z in zooms) + 40
    board = Image.new("RGB", (Wb, Hb), "#0b0908")
    db = ImageDraw.Draw(board)
    board.paste(A, (20, 20))
    board.paste(B, (20 + 1940, 20))
    y = 40 + max(A.height, B.height)
    for label, z in zooms:
        db.text((20, y + 20), label + " (whole strip)", font=lab, fill=GOLD)
        board.paste(z, (20, y + 110))
        y += z.height + 120
    board.save(out / "board_v2.png")
    print("board_v2", out / "board_v2.png", board.size, "blended pixels: old panel", ba, "new panel", bb)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True)
    ap.add_argument("--regular", default=str(ROOT / "assets/fonts/MERCSLedger-Regular.ttf"))
    ap.add_argument("--display", default=str(ROOT / "assets/fonts/MERCSLedger-Display.ttf"))
    ap.add_argument("--ref", default="", help="reference face (Tiny5) for the round-1 comparison board")
    ap.add_argument("--old-display", default="", help="a previous Display build: draw board_v2 (old vs new)")
    a = ap.parse_args()
    if a.old_display:
        board_v2(a, Path(a.out))
        return
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    ours = {"label": "MERCS Ledger", "body": a.regular, "body_px": 28, "title": a.display,
            "title_px": 42, "line_px": 34, "title_line_px": 51, "rule_px": 1}
    ref = {"label": "Tiny5", "body": a.ref, "body_px": 24, "title": a.ref, "title_px": 32,
           "line_px": 32, "title_line_px": 44, "rule_px": 1}
    stats = [mock(ours, out / "mock_ledger.png"), mock(ref, out / "mock_tiny5.png")]
    for col in STYLE_COLOUR.values():
        stats.append({"contrast": col, "on_panel": round(contrast(col, SOOT1), 2)})
    (out / "stats.json").write_text(json.dumps(stats, indent=1), encoding="utf-8")
    for s in stats:
        print(s)

    # Glyph sheet: every character of both cuts at 4x of 1080p (8 px a grid pixel at 4K).
    cps = sorted(c for c in TTFont(a.regular).getBestCmap() if c > 32 and c != 0xA0)
    chars = "".join(chr(c) for c in cps)
    k = 4 * STRETCH
    sheet = Image.new("RGB", (3840, 17 * k * 6 + 2 * k), SOOT1)
    d = ImageDraw.Draw(sheet)
    rows = [chars[i:i + 45] for i in range(0, len(chars), 45)]
    y = k
    for path in (a.regular, a.display):
        f = ImageFont.truetype(path, 14 * k)
        for r in rows:
            d.text((k * 2, y), r, font=f, fill=BONE_HI)
            y += 17 * k
    sheet.save(out / "glyphs_4x.png")

    # Board: 1:1 crops of both mocks side by side, then a 4x zoom of the confusion lines.
    crop = (40, 40, 1940, 1420)
    A = Image.open(out / "mock_ledger.png").crop(crop)
    B = Image.open(out / "mock_tiny5.png").crop(crop)
    lab = ImageFont.truetype(a.regular, 28 * STRETCH)
    za = Image.open(out / "mock_ledger.png")
    zb = Image.open(out / "mock_tiny5.png")
    ya, yb = stats[0]["text_bottom_px"], stats[1]["text_bottom_px"]
    lha, lhb = 34 * STRETCH, 32 * STRETCH
    zA = za.crop((150, ya - 3 * lha - 4, 150 + 955, ya + 4))
    zB = zb.crop((150, yb - 3 * lhb - 4, 150 + 955, yb + 4))
    zA = zA.resize((zA.width * 4, zA.height * 4), Image.NEAREST)
    zB = zB.resize((zB.width * 4, zB.height * 4), Image.NEAREST)
    Wb = 3840 + 60
    Hb = 140 + A.height + 140 + zA.height + 40 + zB.height + 60
    board = Image.new("RGB", (Wb, Hb), "#0b0908")
    db = ImageDraw.Draw(board)
    db.text((20, 30), "A  MERCS Ledger (ours): body 28 px, heading Display 42 px", font=lab, fill=GOLD)
    db.text((20 + 1940, 30), "B  Tiny5 (round 1): body 24 px, heading 32 px", font=lab, fill=GOLD)
    board.paste(A, (20, 140))
    board.paste(B, (20 + 1940, 140))
    y = 140 + A.height + 30
    db.text((20, y), "Confusion lines, 4x zoom of the 4K screen (nearest neighbour): A above, B below",
            font=lab, fill=GOLD)
    y += 110
    board.paste(zA, (20, y))
    y += zA.height + 40
    board.paste(zB, (20, y))
    board.save(out / "board.png")
    print("board", out / "board.png", board.size)


if __name__ == "__main__":
    main()
