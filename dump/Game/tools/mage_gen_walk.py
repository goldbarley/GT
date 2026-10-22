#!/usr/bin/env python3
"""
Generate the Mage's walk cycle.

The mage is a robed figure whose boots are separate pieces, so she walks the
way the archer placeholder does: the two boots swing in opposition and the
body bobs at twice their frequency.

The side views are a stride, with one boot planted forward while the other
swings through.  The front and back views are a shuffle, with the boots
lifting in turn, because there is no sideways travel to show.

Each perspective gets its own keys.  Which boot leads depends on which way the
mage is looking, and the front and back views are mirror images of each other,
so one set of keys cannot serve all four.

Run it with:  python3 tools/mage_gen_walk.py
"""

import json
import math
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Mage", "anim", "clips", "mage_walk.json")

# how long one full stride takes, in seconds
CYCLE = 0.6
# how many keys the cycle is cut into.  The last one repeats the first, so the
# curve's tangents meet and the loop does not hitch.
STEPS = 8

# which boot leads in each view, and which way she travels.
#
#   front   she is walking towards the camera
#   back    she is walking away from it
#   left    she is walking to the left
#   right   she is walking to the right
#
# The leading boot is the same foot of hers in every view, so the walk reads
# the same way round whichever way she is turned.
VIEWS = {
    "front": {"leading": "foot_a", "travel": 0.0, "depth": 1.0},
    "back": {"leading": "foot_b", "travel": 0.0, "depth": -1.0},
    "left": {"leading": "foot_b", "travel": -1.0, "depth": 0.0},
    "right": {"leading": "foot_a", "travel": 1.0, "depth": 0.0},
}


def poses_for(leading, travel, depth, phase):
    """The poses of the two boots and the body at one point in the cycle."""
    other = "foot_b" if leading == "foot_a" else "foot_a"
    swing = math.sin(phase)
    bob = math.sin(phase * 2.0)

    if travel != 0.0:
        # a stride: the leading boot is planted forward while the other one
        # swings through, and the body rides up and down
        lead = {
            "pos": {"x": swing * 3.0 * travel, "y": -max(0.0, swing) * 2.0},
            "rot": -swing * 9.0 * travel,
        }
        trail = {
            "pos": {"x": -swing * 3.0 * travel, "y": -max(0.0, -swing) * 2.0},
            "rot": swing * 9.0 * travel,
        }
        body_y = bob * 1.0
    else:
        # a shuffle: the boots lift in turn and step towards or away from the
        # camera, and there is no sideways travel to show
        lead = {
            "pos": {"x": 0.0, "y": max(0.0, swing) * 2.0 * depth},
            "rot": 0.0,
        }
        trail = {
            "pos": {"x": 0.0, "y": max(0.0, -swing) * 2.0 * depth},
            "rot": 0.0,
        }
        body_y = bob * 0.8 * depth

    return {
        leading: lead,
        other: trail,
        "torso": {"pos": {"x": 0.0, "y": body_y}},
    }


def build(view):
    v = VIEWS[view]
    keys = []
    for i in range(STEPS + 1):
        phase = 2.0 * math.pi * float(i) / float(STEPS)
        keys.append({
            "time": round(CYCLE * float(i) / float(STEPS), 4),
            "ease": "in_out",
            "poses": poses_for(v["leading"], v["travel"], v["depth"], phase),
            "fx": {},
        })
    return {"keys": keys}


if __name__ == "__main__":
    clip = {
        "clip": "mage_walk",
        "description": "Walk. The mage's boots swing in opposition and the body bobs with them.",
        "fps": 15,
        "loop": True,
        "duration": CYCLE,
        "interpolation": "smooth",
        "perspectives": {p: build(p) for p in VIEWS},
    }
    with open(OUT, "w") as fh:
        json.dump(clip, fh, indent=2)
        fh.write("\n")
    print("wrote", OUT)
