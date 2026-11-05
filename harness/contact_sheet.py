#!/usr/bin/env python3
"""Tile every PNG in a run folder into labelled contact sheets for quick review.
   python3 contact_sheet.py out/baseline [--cols 4] [--per 16]
   Writes out/baseline/sheet-1.jpg, sheet-2.jpg, ...
"""
import sys, glob, os, argparse
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("run")
ap.add_argument("--cols", type=int, default=4)
ap.add_argument("--per", type=int, default=16)
ap.add_argument("--width", type=int, default=480)
a = ap.parse_args()

files = sorted(f for f in glob.glob(os.path.join(a.run, "*.png")))
tw = a.width
for page in range(0, len(files), a.per):
    chunk = files[page:page + a.per]
    ims = []
    for f in chunk:
        im = Image.open(f).convert("RGB")
        im = im.resize((tw, round(im.height * tw / im.width)))
        ims.append((os.path.basename(f)[:-4], im))
    th = ims[0][1].height
    rows = (len(ims) + a.cols - 1) // a.cols
    sheet = Image.new("RGB", (a.cols * tw, rows * (th + 22)), "#202224")
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(ims):
        x, y = (i % a.cols) * tw, (i // a.cols) * (th + 22)
        sheet.paste(im, (x, y + 22))
        d.text((x + 6, y + 5), name, fill="#eeeeec")
    out = os.path.join(a.run, f"sheet-{page // a.per + 1}.jpg")
    sheet.save(out, quality=85)
    print(out)
