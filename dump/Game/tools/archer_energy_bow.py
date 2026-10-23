#!/usr/bin/env python3
"""
Cut the energy bow out of the reference video and make it a sprite for the rig.

The reference video's charge has a shape that only really exists as drawn art:
at frame 54 the energy tears open into a torn blade standing up out of the
bow, a hot starburst where it comes out of the grip, and a streak of light
running off along the line of the shot.  Two attempts at drawing that in a
shader came out looking like something else, so the shape is taken straight
out of the frame instead.

The energy is the bright part of the frame, so it is picked out by its
brightness, and the grip is found as the densest knot of it, which is the
starburst the whole thing comes out of.

The result is laid into a square with the grip in the middle, so the rig can
hang it on the bow, and scaled so that it is the same size against the archer
as it is in the video.

Run it with:  python3 tools/archer_energy_bow.py
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEO_FRAMES = os.path.join(os.path.expanduser("~"), "archer_godray", "frames_native")
OUT = os.path.join(ROOT, "Archer", "art", "energy_bow.png")

# the frame where the energy tears open
FRAME = 54
# how bright a pixel has to be to be part of the energy
BRIGHT = 110
# the size of the square the shape is laid into, and where the grip goes in it
CANVAS = 128
# the archer is this tall in the video, and this tall in the game
VIDEO_ARCHER_HEIGHT = 45
GAME_ARCHER_HEIGHT = 32


def main():
    path = os.path.join(VIDEO_FRAMES, "frame_%04d.png" % FRAME)
    frame = np.array(Image.open(path).convert("RGB")).astype(int)
    bright = frame.max(axis=2) > BRIGHT

    # the grip: the densest knot of the energy, which is the starburst the
    # shape comes out of
    best = None
    for y in range(30, 110):
        for x in range(120, 200):
            score = bright[max(0, y - 3):y + 4, max(0, x - 3):x + 4].sum()
            if best is None or score > best[0]:
                best = (score, x, y)
    _, grip_x, grip_y = best
    print("the grip is at %d,%d in frame %d" % (grip_x, grip_y, FRAME))

    # cut the shape out
    cut = np.zeros((frame.shape[0], frame.shape[1], 4), dtype=np.uint8)
    cut[..., :3] = frame.astype(np.uint8)
    cut[..., 3] = np.where(bright, 255, 0).astype(np.uint8)
    art = Image.fromarray(cut, "RGBA")

    # scale it so that it sits against our archer the way it sits against
    # the one in the video
    scale = GAME_ARCHER_HEIGHT / float(VIDEO_ARCHER_HEIGHT)
    new_w = int(round(art.width * scale))
    new_h = int(round(art.height * scale))
    art = art.resize((new_w, new_h), Image.LANCZOS)
    grip_x = int(round(grip_x * scale))
    grip_y = int(round(grip_y * scale))

    # lay it into the square with the grip in the middle
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(art, (CANVAS // 2 - grip_x, CANVAS // 2 - grip_y))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    canvas.save(OUT)
    print("wrote", OUT, canvas.size)


if __name__ == "__main__":
    main()
