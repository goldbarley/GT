#!/usr/bin/env python3
"""
Generate the Archer's walk cycle.

The archer is a booted figure, so she walks the way the mage does: the two
boots swing in opposition and the body bobs at twice their frequency.

The side views are a stride, with one boot planted forward while the other
swings through.  The front and back views are a shuffle, with the boots
lifting in turn, because there is no sideways travel to show.

Each perspective gets its own keys.  Which boot leads depends on which way the
archer is looking, and the front and back views are mirror images of each
other, so one set of keys cannot serve all four.

The leading boot is the same foot of hers in every view: `foot_a` is the foot
that is nearer the camera in the front view, and it is the one that reaches
forwards in the profile views.

Run it with:  python3 tools/archer_gen_walk.py
"""

import json
import math
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Archer", "anim", "clips", "archer_walk.json")

# how long one full stride takes, in seconds
CYCLE = 0.72
# how many keys the cycle is cut into.  The last one repeats the first, so the
# curve's tangents meet and the loop does not hitch.
STEPS = 12

# which boot leads in each view, and which way she travels.
#
#   front   she is walking towards the camera
#   back    she is walking away from it
#   left    she is walking to the left
#   right   she is walking to the right
VIEWS = {
    "front": {"leading": "foot_a", "travel": 0.0, "depth": 1.0},
    "back": {"leading": "foot_b", "travel": 0.0, "depth": -1.0},
    "left": {"leading": "foot_a", "travel": -1.0, "depth": 0.0},
    "right": {"leading": "foot_a", "travel": 1.0, "depth": 0.0},
}

# how far a boot travels in a stride, in pixels
STRIDE = 4.0
# how high a boot lifts as it swings through
LIFT = 2.0
# how far the boot turns as it swings through, in degrees
SWING = 12.0
# how much the body rides up and down, in pixels
BOB = 1.2


def poses_for(leading, travel, depth, phase):
    """The poses of the two boots and the body at one point in the cycle."""
    other = "foot_b" if leading == "foot_a" else "foot_a"
    swing = math.sin(phase)
    bob = math.sin(phase * 2.0)

    if travel != 0.0:
        # A stride.  The leading boot is planted forward while the other one
        # swings through, and the body rides up and down with them.
        lead = {
            "pos": {"x": swing * STRIDE * travel, "y": -max(0.0, swing) * LIFT},
            "rot": -swing * SWING * travel,
        }
        trail = {
            "pos": {"x": -swing * STRIDE * travel, "y": -max(0.0, -swing) * LIFT},
            "rot": swing * SWING * travel,
        }
        body_y = bob * BOB
    else:
        # A shuffle.  The boots lift in turn and step towards or away from
        # the camera, and there is no sideways travel to show.
        lead = {
            "pos": {"x": 0.0, "y": max(0.0, swing) * LIFT * depth},
            "rot": -max(0.0, swing) * 4.0 * depth,
        }
        trail = {
            "pos": {"x": 0.0, "y": max(0.0, -swing) * LIFT * depth},
            "rot": max(0.0, -swing) * 4.0 * depth,
        }
        body_y = bob * BOB * 0.6 * depth

    return {
        leading: lead,
        other: trail,
        # the chest rides up and down, and the shoulders roll a little
        "torso": {"pos": {"x": 0.0, "y": body_y}, "rot": swing * 1.5},
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
        "clip": "archer_walk",
        "description": "Walk. The archer's boots swing in opposition and the body bobs with them.",
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
