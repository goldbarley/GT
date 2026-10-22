#!/usr/bin/env python3
"""
Extract Frame 10 (charge light on bow) and Frame 11 (muzzle flare on release)
from the reference dissection folder (~/archer_godray/frames_native).

Both frames are extracted with alpha transparency, scaled to game resolution,
and centered on the bow grip at (64, 64) in a 128x128 canvas matching energy_bow.png.

Outputs:
  Archer/art/basic_charge.png (Frame 10)
  Archer/art/basic_burst.png  (Frame 11)
"""

import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF_DIR = os.path.join(os.path.expanduser("~"), "archer_godray", "frames_native")
OUT_DIR = os.path.join(ROOT, "Archer", "art")

CANVAS = 128
SCALE = 32.0 / 45.0  # Scale from 45px video character to 32px game character
GRIP_REF_X = 78
GRIP_REF_Y = 75


def extract_frame_10():
    path = os.path.join(REF_DIR, "frame_0010.png")
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    cut = np.zeros_like(arr)

    # Frame 10 oval charge glow on bow string/grip
    for y in range(68, 83):
        for x in range(80, 87):
            r, g, b = arr[y, x, :3]
            # Glow is green/white/yellow (excluding brown bow wood)
            if (g > 120) or (r > 200 and g > 200):
                cut[y, x] = arr[y, x]

    im_cut = Image.fromarray(cut)
    w = int(round(im_cut.width * SCALE))
    h = int(round(im_cut.height * SCALE))
    scaled = im_cut.resize((w, h), Image.NEAREST)

    grip_x = int(round(GRIP_REF_X * SCALE))
    grip_y = int(round(GRIP_REF_Y * SCALE))

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (CANVAS // 2 - grip_x, CANVAS // 2 - grip_y))
    out_path = os.path.join(OUT_DIR, "basic_charge.png")
    canvas.save(out_path)
    print("Wrote", out_path)


def extract_frame_11():
    path = os.path.join(REF_DIR, "frame_0011.png")
    im = Image.open(path).convert("RGBA")
    arr = np.array(im)
    cut = np.zeros_like(arr)

    # Frame 11 explosive arrow release starburst
    for y in range(58, 88):
        for x in range(79, 122):
            r, g, b = arr[y, x, :3]
            if (g > 120) or (r > 200 and g > 200) or (g > 80 and g > r):
                cut[y, x] = arr[y, x]

    im_cut = Image.fromarray(cut)
    w = int(round(im_cut.width * SCALE))
    h = int(round(im_cut.height * SCALE))
    scaled = im_cut.resize((w, h), Image.NEAREST)

    grip_x = int(round(GRIP_REF_X * SCALE))
    grip_y = int(round(GRIP_REF_Y * SCALE))

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, (CANVAS // 2 - grip_x, CANVAS // 2 - grip_y))
    out_path = os.path.join(OUT_DIR, "basic_burst.png")
    canvas.save(out_path)
    print("Wrote", out_path)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    extract_frame_10()
    extract_frame_11()
