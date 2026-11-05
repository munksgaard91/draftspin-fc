#!/usr/bin/env python3
"""Samler demoskærmbilleder til ét oversigtsbillede (skærmgalleri).
Kør: python3 scripts/gallery_sheet.py <ud.png> "nøgle|titel|billede.jpg" ...
Billederne tages af Claude i browser-panelet (390x844) fra index.html?demo=<nøgle>; se demo/README i CLAUDE.md."""
import sys
from PIL import Image, ImageDraw, ImageFont

out, items = sys.argv[1], [a.split("|", 2) for a in sys.argv[2:]]
W, H, COLS, PAD, CAP = 390, 844, 5, 28, 46
rows = (len(items) + COLS - 1) // COLS
sheet = Image.new("RGB", (COLS * W + (COLS + 1) * PAD, rows * (H + CAP) + (rows + 1) * PAD), (18, 10, 32))
d = ImageDraw.Draw(sheet)
try:
    f1 = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 22, index=1)
    f2 = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 16)
except Exception:
    f1 = f2 = ImageFont.load_default()
for i, (key, title, path) in enumerate(items):
    r, c = divmod(i, COLS)
    x, y = PAD + c * (W + PAD), PAD + r * (H + CAP + PAD)
    im = Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS)
    sheet.paste(im, (x, y + CAP))
    d.text((x, y), title, fill=(240, 236, 250), font=f1)
    d.text((x, y + 26), "?demo=" + key, fill=(150, 140, 175), font=f2)
sheet.save(out, optimize=True)
print(out, sheet.size)
