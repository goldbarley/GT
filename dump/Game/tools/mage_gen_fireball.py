#!/usr/bin/env python3
"""
Generate the fireball cast clip.

The cast is authored per perspective because the arm and the staff are drawn
differently in each of the four views: the angle the arm has to swing through
to lift the hand, and the angle the staff has to turn through in the hand to
end up pointing in the cast direction, are both different.

The angles below are the interesting numbers to tune:

    arm_raise      how far the arm swings to lift the hand
    staff_colinear how far the staff turns in the hand, relative to the arm
    arm_down       how far the arm comes back down
    spawn/impact   where the fireball is called from and where it lands, in the
                    mage's own pixels. The game will eventually hand over a tile
                    coordinate instead, so these are the values to replace.
    arc            how far the throw arcs above the straight line between the
                    two points.

Run it with:  python3 tools/mage_gen_fireball.py
"""

import json, os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "Mage", "anim", "clips", "mage_fireball.json")

# per perspective: how the cast reads in that view
VIEWS = {
    # the arm's rest direction and the staff's rest direction differ per view,
    # so the cast is authored as: raise the arm (the staff rides up with it),
    # then turn the staff down in the hand, then swing the arm down.
    "front": dict(
        arm_raise=32.0, staff_colinear=-52.0, arm_down=-8.0,
        staff_mid=-26.0, staff_raise=0.0, lean=-3.0, recoil=2.0,
        spawn=(9.0, 10.0), impact=(-9.0, 30.0), arc=15.0,
    ),
    "back": dict(
        arm_raise=-32.0, staff_colinear=40.0, arm_down=4.0,
        staff_mid=20.0, staff_raise=0.0, lean=3.0, recoil=-2.0,
        spawn=(23.0, 6.0), impact=(41.0, 30.0), arc=15.0,
    ),
    "left": dict(
        arm_raise=0.0, staff_colinear=-55.0, arm_down=0.0,
        staff_mid=-24.0, staff_raise=35.0, lean=-3.0, recoil=2.0,
        spawn=(11.0, 13.0), impact=(-7.0, 30.0), arc=15.0,
    ),
    "right": dict(
        arm_raise=-36.0, staff_colinear=52.0, arm_down=-2.0,
        staff_mid=26.0, staff_raise=0.0, lean=3.0, recoil=-2.0,
        spawn=(27.0, 8.0), impact=(45.0, 30.0), arc=15.0,
    ),
}

TIMELINE = [
    # (time, ease, arm, staff, lean, fall, gem, pit)
    #
    # The beats overlap so the cast reads as one continuous movement.
    #
    # The timings are also chosen so the staff never turns fast enough to boil.
    # A piece boils when the art at its far end travels more than about half a
    # pixel per frame:  tip travel = radius * radians per frame.  The staff's
    # far end is about 13px from the grip, so its screen rotation has to stay
    # under roughly 2.2 degrees per frame, which is why the turn is spread
    # over nearly half a second and why the arm takes a share of it.
    #
    # The times are the ones the shader's own phases call for: the arm is up
    # and the gem is lit by 0.28, the ball is summoned and hangs in the sky
    # until 0.42, it falls until it hits the ground at 0.90, and the pit is
    # left burning over the last tenth of the clip.
    (0.00, "in_out", None, None, 0.0, 0.0, 0.0, 0.0),
    (0.40, "in_out", "raise", None, "lean", 0.0, 1.0, 0.0),
    (0.59, "in_out", "raise", None, "lean", 0.0, 1.0, 0.0),
    (1.26, "in_out", "raise", "colinear", "lean", 1.0, 1.0, 0.0),
    (1.40, "in_out", "down", "colinear", "recoil", 1.0, 0.0, 1.0),
]

def build(view, v):
    keys = []
    for (t, ease, arm, staff, lean, fall, gem, pit) in TIMELINE:
        poses = {}
        if arm is not None:
            if arm == "raise":
                poses["arm"] = {"rot": v["arm_raise"]}
            elif arm == "half":
                poses["arm"] = {"rot": v["arm_raise"] * 0.45}
            else:
                poses["arm"] = {"rot": v["arm_down"]}
        if staff is not None:
            # the staff turns in the hand, so the rotation is relative to the arm
            if staff == "colinear":
                poses["staff"] = {"rot": v["staff_colinear"]}
            else:
                poses["staff"] = {"rot": v["staff_mid"]}
        elif v.get("staff_raise", 0.0) != 0.0 and arm == "raise":
            poses["staff"] = {"rot": v["staff_raise"]}
        if lean:
            poses["torso"] = {"rot": v["lean"] if lean == "lean" else v["recoil"]}
        keys.append({
            "time": t,
            "ease": ease,
            "poses": poses,
            "fx": {
                "progress": round(t / 1.4, 4),
                "fall": fall,
                "gem_glow": gem,
                "pit_strength": pit,
                "opacity": 1.0,
                "spawn_pos": {"x": v["spawn"][0], "y": v["spawn"][1]},
                "impact_pos": {"x": v["impact"][0], "y": v["impact"][1]},
                "pit_pos": {"x": v["impact"][0], "y": v["impact"][1]},
                "arc_height": v["arc"],
            },
        })
    return keys

clip = {
    "clip": "mage_fireball",
    "description": "Fireball cast. The arm raises and the gem at the top of the staff lights up, a fireball is called out of the gem, and the staff turns down in the hand which throws it forward in an arc until it crashes into the ground and leaves a pit of fire that burns out on its own.",
    "fps": 15,
    "loop": False,
    "duration": 1.4,
    "linger": 2.5,
    "fx": {"node": "FireballFX", "clip": True},
    "perspectives": {p: {"keys": build(p, v)} for p, v in VIEWS.items()},
}
with open(OUT, "w") as fh:
    json.dump(clip, fh, indent=2)
    fh.write("\n")
print("wrote", OUT)
