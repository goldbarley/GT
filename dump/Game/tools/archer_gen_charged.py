#!/usr/bin/env python3
"""
Generate the Archer's charged shot.

This is the godray charge, rebuilt on the modular rig from the reference
video.  The charge is one long sequence:

    gather      green energy streaks fly in toward the bow
    spiral      the energy gathers on the bow and starts spinning
    focus       the ring collapses to a single bright point
    energy bow  the point opens out into a large energy bow over the real one
    draw        the bow is drawn back and held
    release     the beam fires and the archer is shoved back
    wind down   the energy dissipates

The timings are the reference video's, taken frame by frame at 24 fps.  The
video runs the charge from frame 33 to frame 94, which is 2.58 seconds.

The archer herself only leans in and braces; the charge is mostly the effect,
which is drawn by the godray shader on the bow.

The shot leaves on the clip's "impact", so the beam goes on the same frame the
string snaps.

Run it with:  python3 tools/archer_gen_charged.py
"""

import json
import math
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Archer", "anim", "clips", "archer_charged_shot.json")

# The video runs at 24 fps.
FPS = 24.0

# The moments of the charge, in the video's own frames.
STAGES = [
    # frame  time    what
    (33, "gather"),      # the streaks start coming in
    (39, "spiral"),      # the energy is on the bow and spinning
    (47, "focus"),       # the ring collapses to a point
    (52, "energy_bow"),  # the big bow opens over the real one
    (56, "draw"),        # the arrow is drawn back
    (78, "hold"),        # held, at full draw
    (79, "release"),     # the beam goes
    (82, "wind"),        # the energy burns off
    (95, "rest"),        # back to rest
]

# How much of each part of the charge is showing at each stage.
CHARGE = {
    "gather":     dict(gather=1.00, spiral=0.10, focus=0.00, energy_bow=0.00, arrow=0.00, charge=0.10, flash=0.00),
    "spiral":     dict(gather=0.15, spiral=1.00, focus=0.00, energy_bow=0.00, arrow=0.00, charge=0.30, flash=0.00),
    "focus":      dict(gather=0.00, spiral=0.80, focus=1.00, energy_bow=0.00, arrow=0.00, charge=0.50, flash=0.00),
    "energy_bow": dict(gather=0.00, spiral=0.40, focus=1.00, energy_bow=1.00, arrow=0.00, charge=0.70, flash=0.00),
    "draw":       dict(gather=0.00, spiral=0.30, focus=1.00, energy_bow=1.00, arrow=0.60, charge=0.80, flash=0.00),
    "hold":       dict(gather=0.00, spiral=0.25, focus=1.00, energy_bow=1.00, arrow=1.00, charge=0.90, flash=0.00),
    "release":    dict(gather=0.00, spiral=0.00, focus=1.00, energy_bow=1.00, arrow=1.00, charge=1.00, flash=1.00),
    "wind":       dict(gather=0.00, spiral=0.00, focus=0.50, energy_bow=0.20, arrow=0.00, charge=0.25, flash=0.15),
    "rest":       dict(gather=0.00, spiral=0.00, focus=0.00, energy_bow=0.00, arrow=0.00, charge=0.00, flash=0.00),
}

# The way the shot goes in each view, and how she is pushed back by it.
#
# `aim` is the angle of the shot: 0 is to the right and 180 is to the left.
# `shove` is the way she is pushed back by the beam, in her own pixels.
# `arrow` is whether the drawn arrow can be shown: in the front and back views
# the shot goes towards or away from the camera, which a side on sprite cannot
# show.
VIEWS = {
    "front": {"aim": 0.0, "lean": -1.0, "shove": (0.0, 24.0), "arrow": 0.0},
    "back": {"aim": 180.0, "lean": 1.0, "shove": (0.0, -24.0), "arrow": 0.0},
    "left": {"aim": 180.0, "lean": -1.0, "shove": (24.0, 0.0), "arrow": 1.0},
    "right": {"aim": 0.0, "lean": 1.0, "shove": (-24.0, 0.0), "arrow": 1.0},
}


def arm_level(view):
    """
    How far the weapon arm has to turn to be parallel to the ground.

    It is worked out from the art: the arm runs from the shoulder to the hand
    that holds the bow, and the turn that puts that line flat is the answer.
    """
    path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "Archer", f"archer_{view}", "pieces.json")
    with open(path) as fh:
        data = json.load(fh)
    arm = data["pieces"]["arm"]
    bow = data["pieces"]["bow"]
    shoulder = (arm["position"]["x"] + arm["pivot"]["x"],
                arm["position"]["y"] + arm["pivot"]["y"])
    hand = (bow["position"]["x"] + bow["pivot"]["x"],
            bow["position"]["y"] + bow["pivot"]["y"])
    rest = math.degrees(math.atan2(hand[1] - shoulder[1], hand[0] - shoulder[0]))
    # the turn that puts the arm flat along the line of the shot
    turn = VIEWS[view]["aim"] - rest
    while turn > 180.0:
        turn -= 360.0
    while turn < -180.0:
        turn += 360.0
    return turn


def poses(v, stage, level):
    """How the archer holds herself at one stage of the charge."""
    if stage == "rest":
        return {}

    # how far up the arm has come by this stage, as a part of the way to flat
    reach = {
        "gather": 0.20,
        "spiral": 0.45,
        "focus": 0.70,
        "energy_bow": 0.85,
        "draw": 1.0,
        "hold": 1.0,
        "release": 0.70,
        "wind": 0.30,
    }[stage]
    lean = v["lean"]

    # how far her body leans at each stage
    torso_rot = {
        "gather": lean * 1.0,
        "spiral": lean * 1.0,
        "focus": lean * 1.0,
        "energy_bow": lean * 1.5,
        "draw": lean * 2.5,
        "hold": lean * 2.5,
        "release": -lean * 4.0,
        "wind": -lean * 1.5,
    }[stage]

    # The arm is turned by the amount that puts it flat, less the turn the
    # body is giving, so that it really does end up parallel to the ground.
    arm = level * reach - torso_rot
    # the bow turns back against the arm, so it stays upright
    bow = -level * reach

    if stage in ("draw", "hold"):
        # she leans in and braces
        return {
            "arm": {"rot": arm},
            "bow": {"rot": bow + lean * 2.0},
            "torso": {"rot": torso_rot, "pos": {"x": 0, "y": -1}},
            "foot_a": {"rot": lean * 3.0},
            "foot_b": {"rot": -lean * 3.0},
        }
    if stage == "release":
        # the beam goes and she is shoved back
        return {
            "arm": {"rot": arm},
            "bow": {"rot": bow},
            "torso": {"rot": torso_rot, "pos": {"x": 0, "y": 1}},
            "foot_a": {"rot": lean * 5.0},
            "foot_b": {"rot": -lean * 5.0},
            "root": {"pos": {"x": v["shove"][0], "y": v["shove"][1]}},
        }
    if stage == "wind":
        return {
            "arm": {"rot": arm},
            "bow": {"rot": bow},
            "torso": {"rot": torso_rot, "pos": {"x": 0, "y": 0}},
            "root": {"pos": {"x": v["shove"][0] * 0.4, "y": v["shove"][1] * 0.4}},
        }
    # she squares up to the shot
    return {
        "arm": {"rot": arm},
        "bow": {"rot": bow},
        "torso": {"rot": torso_rot, "pos": {"x": 0, "y": 0}},
    }


def build(view):
    v = VIEWS[view]
    level = arm_level(view)
    keys = []
    for frame, stage in STAGES:
        fx = dict(CHARGE[stage])
        if view in ("front", "back"):
            # the shot goes towards or away from the camera in these views,
            # which a side on sprite cannot show
            fx["arrow"] = 0.0
        keys.append({
            "time": round((frame - STAGES[0][0]) / FPS, 4),
            "ease": "in_out",
            "poses": poses(v, stage, level),
            "fx": fx,
        })
    return {"keys": keys}


if __name__ == "__main__":
    clip = {
        "clip": "archer_charged_shot",
        "description": "The godray charge. Green energy gathers on the bow, spirals, opens into a great energy bow, is drawn back and held, and then the beam is let go and the archer is shoved back.",
        "fps": 24,
        "loop": False,
        "duration": round((STAGES[-1][0] - STAGES[0][0]) / FPS, 4),
        "interpolation": "smooth",
        "impact": round((79 - STAGES[0][0]) / FPS, 4),
        "fx": {"node": "GodrayFX", "clip": False},
        "perspectives": {p: build(p) for p in VIEWS},
    }
    with open(OUT, "w") as fh:
        json.dump(clip, fh, indent=2)
        fh.write("\n")
    print("wrote", OUT)
