#!/usr/bin/env python3

"""
Write the clip for Knight's Edge, the Knight's ultimate attack.

The attack comes in three parts:

    1. the knight raises his sword and the blade catches fire
    2. the whole screen goes to pitch black
    3. the fire sweeps across the dark

The clip drives all three: `charge` for the flame on the blade, `dim` for
the darkness, and `slash_t` for the sweep through the flipbook.  The sword's
raised pose is not written by hand: `knight_edge_pose.py` works it out from
the rig, because the sword sits differently in every view and the left view
has no arm of its own for the sword to ride on.

    python3 tools/knight_gen_ultimate.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")
ANIM = os.path.join(KNIGHT, "Anim", "KnightUltimate")
VIEWS = ["front", "back", "left", "right"]

# the phases, in seconds
PHASE_RAISE_END = 0.80
PHASE_DARK_END = 1.30
PHASE_SLASH_END = 2.20
# the embers keep drifting for a while after the sweep is done, so the last
# of the fire hangs in the air instead of stopping where it was
PHASE_DRIFT_END = 2.75
PHASE_END = 3.00

# the fire's frame the sweep starts on, and the one it ends on
FIRST_FRAME = 0
LAST_FRAME = 7


def build_clip(poses):
    """The clip, for every view."""
    perspectives = {}
    for view in VIEWS:
        info = poses[view]
        role = info["role"]
        raised = info["angle"]
        keys = []

        def key(time, arm, charge, dim, slash_t, slash):
            pose = {
                "root": {"pos": {"x": 0, "y": 0}},
                "torso": {"pos": {"x": 0, "y": 0}},
                role: {"rot": arm},
            }
            if role != "sword":
                pose["sword"] = {"rot": 0.0}
            return {
                "time": time,
                "ease": "in_out",
                "poses": pose,
                "fx": {"charge": charge, "dim": dim, "slash_t": slash_t, "slash": slash},
            }

        # the knight stands ready
        keys.append(key(0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
        # phase 1: the sword goes up and the blade catches fire
        keys.append(key(PHASE_RAISE_END * 0.55, raised * 0.55, 0.45, 0.0, 0.0, 0.0))
        keys.append(key(PHASE_RAISE_END, raised, 1.0, 0.0, 0.0, 0.0))
        # phase 2: the screen goes to pitch black
        keys.append(key(PHASE_DARK_END, raised, 1.0, 1.0, 0.0, 0.0))
        # phase 3: the fire sweeps across the dark
        keys.append(key(PHASE_SLASH_END, raised, 0.0, 1.0, 1.0, 1.0))
        # the last of the fire hangs in the air, drifting
        keys.append(key(PHASE_DRIFT_END, raised, 0.0, 1.0, 1.0, 1.0))
        # and the world comes back
        keys.append(key(PHASE_END, 0.0, 0.0, 0.0, 1.0, 0.0))
        perspectives[view] = {"keys": keys}
    return perspectives


def main():
    with open(os.path.join(ANIM, "pose.json")) as handle:
        poses = json.load(handle)

    clip = {
        "clip": "knight_ultimate",
        "description": (
            "Knight's Edge, the Knight's ultimate attack. He raises the sword and "
            "the blade catches fire, the world goes to pitch black, and the fire "
            "sweeps across the dark. The frames and the shaders live in "
            "Knight/Anim/KnightUltimate."
        ),
        "fps": 24,
        "loop": False,
        "duration": PHASE_END,
        "interpolation": "smooth",
        "fx": {"node": "KnightUltimateFX"},
        "perspectives": build_clip(poses),
    }

    path = os.path.join(KNIGHT, "Anim", "clips", "knight_ultimate.json")
    with open(path, "w") as handle:
        json.dump(clip, handle, indent=1)
    print("wrote", path)


if __name__ == "__main__":
    main()
