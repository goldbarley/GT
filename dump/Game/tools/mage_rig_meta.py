#!/usr/bin/env python3
"""
Write the choreography metadata that the clip format targets into `pieces.json`.

`roles` maps a stable, perspective independent name onto the concrete piece in
that perspective.  Clips refer to roles, so one clip can drive all four
perspectives even though the piece names differ (`arm_right` in the front and
back views, `arm_left` in the profile views).

    "roles": { "staff": "staff", "arm": "arm_right", "foot_a": "foot_front_a" }

`groups` moves several pieces rigidly about a shared pivot, which is what the
flat sibling structure cannot express on its own.  The pivot is in canvas
coordinates, so it is derived from that perspective's own layout.

    "groups": { "torso": { "pivot": { "x": 23, "y": 25 },
                            "members": ["body", "arm"] } }
"""

import json
import os

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")

# role -> piece name, per perspective.
#
# The two feet are named after the perspective they belong to, so no two
# perspectives can be confused with each other: the front view has
# foot_front_a and foot_front_b, the left view has foot_left_a and
# foot_left_b, and so on.  The roles below are still the stable, perspective
# independent names the clips use.
ROLES = {
    "front": {"body": "body", "hat": "hat", "staff": "staff",
              "arm": "arm_right", "foot_a": "foot_front_a", "foot_b": "foot_front_b"},
    "back": {"body": "body", "hat": "hat", "staff": "staff",
             "arm": "arm_right", "foot_a": "foot_back_a", "foot_b": "foot_back_b"},
    "left": {"body": "body", "hat": "hat", "staff": "staff",
             "foot_a": "foot_left_a", "foot_b": "foot_left_b"},
    "right": {"body": "body", "hat": "hat", "staff": "staff", "arm": "arm_left",
              "foot_a": "foot_right_a", "foot_b": "foot_right_b"},
}

# which roles swing together, and what the group is called.
# The hat belongs here as well: it sits on the head, so it has to travel with
# the torso or it visibly detaches from the body. The staff is not listed here
# because it is held by the arm and rides along with it through the hierarchy.
TORSO_MEMBERS = ["body", "hat", "arm"]

# which piece is held by which. The staff is gripped by the hand, so raising the
# arm has to carry the staff with it. The left view has no separate arm - it is
# drawn into the body - so the staff rides on the body there.
PIECE_PARENTS = {
    "front": {"staff": "arm"},
    "back": {"staff": "arm"},
    "left": {"staff": "body"},
    "right": {"staff": "arm"},
}


def build_groups(jd):
    body = jd["pieces"]["body"]
    canvas_w = jd["canvas_size"]["width"]
    canvas_h = jd["canvas_size"]["height"]
    # the waist: horizontal centre of the body, five pixels above its hem
    waist_x = int(body["position"]["x"] + body["region"]["w"] / 2.0)
    waist_y = int(body["position"]["y"] + body["region"]["h"] - 5)
    all_roles = list(ROLES[jd["perspective"]].keys())
    return {
        "torso": {
            "pivot": {"x": waist_x, "y": waist_y},
            "members": TORSO_MEMBERS,
        },
        "all": {
            "pivot": {"x": int(canvas_w / 2), "y": canvas_h},
            "members": all_roles,
        },
    }


if __name__ == "__main__":
    for perspective, roles in ROLES.items():
        path = os.path.join(MAGE_DIR, f"mage_{perspective}", "pieces.json")
        with open(path) as fh:
            jd = json.load(fh)
        jd["roles"] = roles
        jd["groups"] = build_groups(jd)
        jd["piece_parents"] = PIECE_PARENTS[perspective]
        ordered = {}
        for key in ["perspective", "canvas_size", "spritesheet", "source_sheet",
                    "source_regions", "source_pivots", "source_reference_rect",
                    "reference_rect", "roles", "groups", "piece_parents", "pieces"]:
            if key in jd:
                ordered[key] = jd[key]
        for key in jd:
            if key not in ordered:
                ordered[key] = jd[key]
        with open(path, "w") as fh:
            json.dump(ordered, fh, indent=2)
            fh.write("\n")
        print(f"  {perspective}: roles + groups written")
