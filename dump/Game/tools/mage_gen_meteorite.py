#!/usr/bin/env python3
"""
Generate the meteorite cast.

The grand animation, in the order of the storyboard:

    0.00  idle
    0.35  the body winds up, the feet stay planted
    0.80  she jumps, dust comes off the ground
    1.00  she starts floating up on her own magic
    2.20  she reaches the top, 150% of her height off the ground
    2.60  her arm goes up, the staff lights up, she starts to shake
    3.00  a meteorite comes down out of the sky, burning
    3.95  it hits the ground and detonates in a mushroom cloud
    4.45  half a second later she starts to come down
    5.30  she lands
    5.60  back to idle

The angles differ per perspective because the arm and the staff are drawn
differently in each of the four views. The numbers to tune are the arm's
raise, how far the staff turns in the hand, and where the meteorite lands.

Run it with:  python3 tools/mage_gen_meteorite.py
"""

import json
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Mage", "anim", "clips", "mage_meteorite.json")

# the mage is 32 pixels tall, she floats 150% of that off the ground
FLOOR_Y = 32.0
HOVER_Y = -48.0

# Where the arm and the staff point, in degrees, once she is floating and
# calling the meteorite down.  0 is right, 90 is down, 180 is left, 270 is up.
#
# The staff is aimed out to the side so the gem clears the hat, which is very
# wide in the front and back views.  The right view is the one that matches the
# storyboard, with the staff held straight up.
#
# The rotations are worked out from these, because the arm and the staff are
# drawn at different angles in every view.
REST = {
    #            arm direction, staff direction
    "front": (146.3, 227.7),
    "back": (-26.6, -52.4),
    "left": (None, 227.7),
    "right": (29.7, -45.0),
}

TARGET = {
    "front": (200.0, 210.0),
    "back": (-70.0, 330.0),
    "left": (None, 210.0),
    "right": (-70.0, -80.0),
}

VIEWS = {
    "front": dict(lean=-4.0, wind=4.0),
    "back": dict(lean=4.0, wind=4.0),
    "left": dict(lean=-4.0, wind=4.0),
    "right": dict(lean=4.0, wind=4.0),
}


def rotations(view):
    """The arm's rotation and the staff's rotation, from the target directions."""
    arm_rest, staff_rest = REST[view]
    arm_target, staff_target = TARGET[view]
    arm_raise = 0.0 if arm_rest is None else (arm_target - arm_rest)
    # the staff's own rotation is relative to the arm it is held by
    staff_raise = staff_target - staff_rest - arm_raise
    # keep the numbers readable
    arm_raise = (arm_raise + 180.0) % 360.0 - 180.0
    staff_raise = (staff_raise + 180.0) % 360.0 - 180.0
    return arm_raise, staff_raise

# where the meteorite lands, to the side of the mage
METEOR_X = 26.0
METEOR_START_Y = 260.0

# The moments of the cast, in seconds.  Everything after the fall follows on
# from the impact, so the whole tail can be moved by changing one number.
JUMP = 0.82
HOVER = 2.20
ARM_UP = 2.65
FALL_START = 3.00

# How long the meteorite takes to come down.  The first draft was 0.95
# seconds; 40% slower means it runs at 60% of the speed, so it takes a third
# of a second longer.
FALL_TIME = 0.95 / 0.6

IMPACT = FALL_START + FALL_TIME        # it hits the ground
BLAST = IMPACT + 0.23                  # the mushroom cloud at full size
WIND_DOWN = IMPACT + 0.50              # half a second later she starts to come down
LAND = IMPACT + 1.35                   # she lands

# The cloud does not wait for her.  It keeps spreading and thinning for two
# seconds after it has reached full size, long after she has come back down,
# so the blast and her descent play out at the same time.
CLOUD_TIME = 2.0
CLOUD_END = BLAST + CLOUD_TIME
END = CLOUD_END + 0.05

# The beats of the cast.  `root` is how far the mage leaves the ground, the
# arm and staff are 0 to 1 for how far they have gone, and the rest are the
# effect's own parameters.
TIMELINE = [
    dict(t=0.00, ease="in_out", root=0.0, torso=0.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=0.35, ease="in_out", root=0.0, torso=1.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=0.58, ease="in_out", root=0.0, torso=1.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=0.72, ease="out_cubic", root=0.0, torso=0.9, arm=0.0, staff=0.0, lean=0.0,
         dust=1.0, spread=0.05, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=JUMP, ease="out_cubic", root=-12.0, torso=0.6, arm=0.0, staff=0.0, lean=0.0,
         dust=0.85, spread=0.18, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=0.95, ease="in_out", root=-13.0, torso=0.2, arm=0.0, staff=0.0, lean=0.0,
         dust=0.55, spread=0.45, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=1.25, ease="in_out", root=-16.0, torso=0.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=1.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=HOVER, ease="in_out", root=HOVER_Y, torso=0.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=0.0),
    # her arm goes up and the gem on the staff lights up
    dict(t=ARM_UP, ease="in_out", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.0, camera=0.0, gem=1.0),
    # she starts to tremble as the rock comes down
    dict(t=FALL_START, ease="in_out", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=METEOR_START_Y, explode=0.0, aftermath=0.0,
         shake=0.15, camera=0.10, gem=1.0),
    dict(t=FALL_START + FALL_TIME * 0.21, ease="in_out", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=175.0, explode=0.0, aftermath=0.0,
         shake=0.50, camera=0.45, gem=1.0),
    dict(t=FALL_START + FALL_TIME * 0.58, ease="in_out", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=70.0, explode=0.0, aftermath=0.0,
         shake=1.00, camera=0.85, gem=1.0),
    # it lands
    dict(t=IMPACT, ease="in_out", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=0.0, explode=0.0, aftermath=0.0,
         shake=1.40, camera=1.00, gem=1.0),
    # the mushroom cloud
    dict(t=BLAST, ease="out_cubic", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=0.0, explode=1.0, aftermath=0.15, age=0.0,
         shake=1.00, camera=0.60, gem=1.0),
    # half a second later she starts to come down, while the cloud carries on
    dict(t=WIND_DOWN, ease="in_out", root=HOVER_Y, torso=0.0, arm=1.0, staff=1.0, lean=1.0,
         dust=0.0, spread=0.0, meteor_y=0.0, explode=1.0, aftermath=0.35, age=0.14,
         shake=0.40, camera=0.20, gem=1.0),
    dict(t=LAND, ease="in_out", root=0.0, torso=0.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=0.0, explode=1.0, aftermath=0.55, age=0.53,
         shake=0.0, camera=0.0, gem=0.0),
    # the cloud spreads out and thins until it has merged with the air
    dict(t=CLOUD_END, ease="in_out", root=0.0, torso=0.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=0.0, explode=1.0, aftermath=0.0, age=1.0,
         shake=0.0, camera=0.0, gem=0.0),
    dict(t=END, ease="in_out", root=0.0, torso=0.0, arm=0.0, staff=0.0, lean=0.0,
         dust=0.0, spread=0.0, meteor_y=0.0, explode=1.0, aftermath=0.0, age=1.0,
         shake=0.0, camera=0.0, gem=0.0),
]


def build(view, v):
    arm_raise, staff_raise = rotations(view)
    keys = []
    for row in TIMELINE:
        poses = {
            "root": {"pos": {"x": 0, "y": row["root"]}},
            "torso": {"pos": {"x": 0, "y": row["torso"] * v["wind"]}},
        }
        if row["arm"] > 0.0:
            poses["arm"] = {"rot": arm_raise * row["arm"]}
        if row["staff"] > 0.0:
            poses["staff"] = {"rot": staff_raise * row["staff"]}
        if row["lean"] > 0.0:
            poses["torso"]["rot"] = v["lean"] * row["lean"]
        keys.append({
            "time": row["t"],
            "ease": row["ease"],
            "poses": poses,
            "fx": {
                "meteor_y": row["meteor_y"],
                "meteor_x": METEOR_X,
                "dust": row["dust"],
                "dust_spread": row.get("spread", 0.0),
                "explode": row["explode"],
                "aftermath": row["aftermath"],
                "cloud_age": row.get("age", 0.0),
                "shake": row["shake"],
                "camera_shake": row["camera"],
                "gem_glow": row["gem"],
            },
        })
    return {"keys": keys}


if __name__ == "__main__":
    clip = {
        "clip": "mage_meteorite",
        "description": "Meteorite. The mage winds up, jumps, and floats high on her own magic. Her staff lights up and a burning meteorite comes down out of the sky, shaking the camera, and detonates on the ground in a mushroom cloud. Half a second after the blast she comes back down.",
        "fps": 15,
        "loop": False,
        "duration": round(END + 0.05, 3),
        "interpolation": "smooth",
        "fx": {"node": "MeteoriteFX", "clip": True},
        "perspectives": {p: build(p, v) for p, v in VIEWS.items()},
    }
    with open(OUT, "w") as fh:
        json.dump(clip, fh, indent=2)
        fh.write("\n")
    print("wrote", OUT)
