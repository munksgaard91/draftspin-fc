#!/usr/bin/env python3
"""Bygger billedarket (atlas) med spillerbilleder fra et sortitoutsi-facepack.

Brug:
  python3 scripts/build_atlas.py <faces-mappe> <ids.json> <ud.webp>

<faces-mappe>: mappen med face_<id>.png, fx
  "~/Library/Application Support/Sports Interactive/Football Manager 27/graphics/sortitoutsi/faces"
<ids.json>: liste af FM-ID'er (face_id fra players-tabellen), fx eksporteret med
  supabase db query "select face_id from players where face_id>0" --remote=apagcfedizgjnnuefzfo \
    --read-only --output-format json
  (både en ren liste af tal og CLI'ens {"rows":[{"face_id":..}]} accepteres)

Skriver <ud.webp> og <ud>.order.json (FACE_ORDER til index.html) og udskriver
CSS-størrelsen til background-size. Cellerne er 96 px (vises i 36 px), 24 pr. række.
ID'er uden billede i pakken springes over og udskrives.
Egne billeder (spillere uden for FM, fx Max Dowman) ligger i data/faces_extra/face_<id>.png
og bruges, hvis pakken ikke har billedet.
"""
import json, math, os, sys
from PIL import Image

CELL, COLS, SHOW = 96, 24, 36
EXTRA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "faces_extra")


def find(faces, i):
    for d in (faces, EXTRA):
        f = f"{d}/face_{i}.png"
        if os.path.exists(f):
            return f
    return None


def load_ids(path):
    d = json.load(open(path))
    if isinstance(d, dict):
        d = d.get("rows", [])
    ids = [int(x["face_id"] if isinstance(x, dict) else x) for x in d]
    return sorted({i for i in ids if i > 0})


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    faces, idsfile, out = os.path.expanduser(sys.argv[1]), sys.argv[2], sys.argv[3]
    ids = load_ids(idsfile)
    order, missing = [], []
    for i in ids:
        (order if find(faces, i) else missing).append(i)
    rows = math.ceil(len(order) / COLS)
    atlas = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    for n, i in enumerate(order):
        im = Image.open(find(faces, i)).convert("RGBA").resize((CELL, CELL), Image.LANCZOS)
        atlas.paste(im, (n % COLS * CELL, n // COLS * CELL))
    atlas.save(out, "WEBP", quality=82, method=6)
    json.dump(order, open(os.path.splitext(out)[0] + ".order.json", "w"), separators=(",", ":"))
    print(f"{len(order)} billeder, {rows} rækker, {os.path.getsize(out)/1e6:.2f} MB -> {out}")
    print(f"CSS: background-size:{COLS*SHOW}px {rows*SHOW}px")
    if missing:
        print(f"Uden billede i pakken ({len(missing)}): {missing}")


if __name__ == "__main__":
    main()
