#!/usr/bin/env python3
"""
Generate the Archer's Animation Clips:
- Basic Attack (archer_basic_attack.json)
- Skill (archer_skill.json)
- Strong Skill (archer_strong_skill.json)

All clips ensure that whenever the archer raises her arm, the bow rotates 35 degrees
anti-clockwise so that it sits at a right angle to the ground.

Basic Attack:
  Archer raises arm + bow rotates 35° anti-clockwise (upright)
  -> Frame 10 on the bow (gathering charge light)
  -> Frame 11 on the bow (burst release flare at impact 0.25s)
  -> Arrow shoots forward in a straight line.
"""

import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIPS_DIR = os.path.join(ROOT, "Archer", "anim", "clips")

VIEWS = {
    "front": {"aim": 0.0, "lean": -1.0},
    "back": {"aim": 180.0, "lean": 1.0},
    "left": {"aim": 180.0, "lean": -1.0},
    "right": {"aim": 0.0, "lean": 1.0},
}


def arm_level(view):
    """
    How far the weapon arm has to turn to be parallel to the ground.
    Calculated from shoulder pivot to hand pivot.
    """
    path = os.path.join(ROOT, "Archer", f"archer_{view}", "pieces.json")
    with open(path) as fh:
        data = json.load(fh)
    arm = data["pieces"]["arm"]
    bow = data["pieces"]["bow"]
    shoulder = (arm["position"]["x"] + arm["pivot"]["x"],
                arm["position"]["y"] + arm["pivot"]["y"])
    hand = (bow["position"]["x"] + bow["pivot"]["x"],
            bow["position"]["y"] + bow["pivot"]["y"])
    rest = math.degrees(math.atan2(hand[1] - shoulder[1], hand[0] - shoulder[0]))
    turn = VIEWS[view]["aim"] - rest
    while turn > 180.0:
        turn -= 360.0
    while turn < -180.0:
        turn += 360.0
    return turn


# Clean zero FX to prevent shader bleed
FX_ZERO = {
    "gather": 0.0,
    "spiral": 0.0,
    "focus": 0.0,
    "energy_bow": 0.0,
    "arrow": 0.0,
    "charge": 0.0,
    "flash": 0.0,
    "basic_charge": 0.0,
    "basic_burst": 0.0
}


def build_basic_attack_clip(view):
    level = arm_level(view)
    lean = VIEWS[view]["lean"]

    # Basic Attack sequence:
    # 0.00s: Rest
    # 0.12s: Archer raises arm + bow rotates 35° anti-clockwise (upright)
    # 0.17s: Frame 10 on the bow (gathering charge)
    # 0.25s: Frame 11 on the bow (impact burst flare)
    # 0.35s: Flare ends, recovery
    # 0.48s: Return to rest
    arm_aim = round(level * 1.0 - lean * 1.0, 3)
    bow_upright = round(-level * 1.0 - 35.0 * lean, 3)

    fx_frame10 = dict(FX_ZERO)
    fx_frame10["basic_charge"] = 1.0

    fx_frame11 = dict(FX_ZERO)
    fx_frame11["basic_burst"] = 1.0

    keys = [
        {
            "time": 0.0,
            "ease": "in_out",
            "poses": {},
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.12,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": arm_aim},
                "bow": {"rot": bow_upright},
                "torso": {"rot": round(lean * 1.0, 3), "pos": {"x": 0, "y": 0}},
                "foot_a": {"rot": round(lean * 1.0, 3)},
                "foot_b": {"rot": round(-lean * 1.0, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.17,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": arm_aim},
                "bow": {"rot": bow_upright},
                "torso": {"rot": round(lean * 1.0, 3), "pos": {"x": 0, "y": 0}},
                "foot_a": {"rot": round(lean * 1.0, 3)},
                "foot_b": {"rot": round(-lean * 1.0, 3)}
            },
            "fx": fx_frame10
        },
        {
            "time": 0.25,
            "ease": "out_cubic",
            "poses": {
                "arm": {"rot": round(level * 0.95 + lean * 0.5, 3)},
                "bow": {"rot": round(-level * 0.95 - 35.0 * 0.95 * lean, 3)},
                "torso": {"rot": round(-lean * 0.8, 3), "pos": {"x": 0, "y": 0}},
                "foot_a": {"rot": round(lean * 0.5, 3)},
                "foot_b": {"rot": round(-lean * 0.5, 3)}
            },
            "fx": fx_frame11
        },
        {
            "time": 0.35,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 0.40, 3)},
                "bow": {"rot": round(-level * 0.40 - 35.0 * 0.40 * lean, 3)},
                "torso": {"rot": 0.0, "pos": {"x": 0, "y": 0}}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.48,
            "ease": "in_out",
            "poses": {},
            "fx": dict(FX_ZERO)
        }
    ]
    return {"keys": keys}


def build_skill_clip(view):
    level = arm_level(view)
    lean = VIEWS[view]["lean"]

    # Quick shot keyframes:
    # 0.00s: Rest
    # 0.12s: Swift draw & aim (bow rotated 35° anti-clockwise)
    # 0.22s: Full draw tension
    # 0.25s: Impact / string release
    # 0.38s: Recovery
    # 0.55s: Return to rest
    keys = [
        {
            "time": 0.0,
            "ease": "in_out",
            "poses": {},
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.12,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 0.85 - lean * 1.5, 3)},
                "bow": {"rot": round(-level * 0.85 - 35.0 * 0.85 * lean + lean * 1.0, 3)},
                "torso": {"rot": round(lean * 1.5, 3), "pos": {"x": 0, "y": -1}},
                "foot_a": {"rot": round(lean * 1.5, 3)},
                "foot_b": {"rot": round(-lean * 1.5, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.22,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 1.0 - lean * 2.0, 3)},
                "bow": {"rot": round(-level * 1.0 - 35.0 * lean + lean * 1.5, 3)},
                "torso": {"rot": round(lean * 2.0, 3), "pos": {"x": 0, "y": -1}},
                "foot_a": {"rot": round(lean * 2.5, 3)},
                "foot_b": {"rot": round(-lean * 2.5, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.25,
            "ease": "out_cubic",
            "poses": {
                "arm": {"rot": round(level * 0.95 + lean * 1.0, 3)},
                "bow": {"rot": round(-level * 0.95 - 35.0 * 0.95 * lean, 3)},
                "torso": {"rot": round(-lean * 1.2, 3), "pos": {"x": 0, "y": 0}},
                "foot_a": {"rot": round(lean * 1.0, 3)},
                "foot_b": {"rot": round(-lean * 1.0, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.38,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 0.35, 3)},
                "bow": {"rot": round(-level * 0.35 - 35.0 * 0.35 * lean, 3)},
                "torso": {"rot": 0.0, "pos": {"x": 0, "y": 0}}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.55,
            "ease": "in_out",
            "poses": {},
            "fx": dict(FX_ZERO)
        }
    ]
    return {"keys": keys}


def build_strong_skill_clip(view):
    level = arm_level(view)
    lean = VIEWS[view]["lean"]

    # Power shot keyframes:
    # 0.00s: Rest
    # 0.18s: Raise bow & plant stance
    # 0.40s: Deep draw into strong archery stance
    # 0.60s: Full power draw & tension hold
    # 0.67s: Peak charge tension
    # 0.70s: Impact / release with recoil
    # 0.88s: Recoil recovery
    # 1.15s: Return to rest
    keys = [
        {
            "time": 0.0,
            "ease": "in_out",
            "poses": {},
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.18,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 0.45 - lean * 1.0, 3)},
                "bow": {"rot": round(-level * 0.45 - 35.0 * 0.45 * lean, 3)},
                "torso": {"rot": round(lean * 1.0, 3), "pos": {"x": 0, "y": 0}},
                "foot_a": {"rot": round(lean * 2.0, 3)},
                "foot_b": {"rot": round(-lean * 2.0, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.40,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 0.85 - lean * 2.5, 3)},
                "bow": {"rot": round(-level * 0.85 - 35.0 * 0.85 * lean + lean * 2.0, 3)},
                "torso": {"rot": round(lean * 2.5, 3), "pos": {"x": 0, "y": -1}},
                "foot_a": {"rot": round(lean * 3.5, 3)},
                "foot_b": {"rot": round(-lean * 3.5, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.60,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 1.0 - lean * 3.0, 3)},
                "bow": {"rot": round(-level * 1.0 - 35.0 * lean + lean * 3.0, 3)},
                "torso": {"rot": round(lean * 3.0, 3), "pos": {"x": 0, "y": -1}},
                "foot_a": {"rot": round(lean * 4.0, 3)},
                "foot_b": {"rot": round(-lean * 4.0, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.67,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 1.0 - lean * 3.2, 3)},
                "bow": {"rot": round(-level * 1.0 - 35.0 * lean + lean * 3.2, 3)},
                "torso": {"rot": round(lean * 3.2, 3), "pos": {"x": 0, "y": -1}},
                "foot_a": {"rot": round(lean * 4.2, 3)},
                "foot_b": {"rot": round(-lean * 4.2, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.70,
            "ease": "out_cubic",
            "poses": {
                "arm": {"rot": round(level * 0.85, 3)},
                "bow": {"rot": round(-level * 0.85 - 35.0 * 0.85 * lean, 3)},
                "torso": {"rot": round(-lean * 3.0, 3), "pos": {"x": 0, "y": 1}},
                "foot_a": {"rot": round(lean * 4.5, 3)},
                "foot_b": {"rot": round(-lean * 4.5, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 0.88,
            "ease": "in_out",
            "poses": {
                "arm": {"rot": round(level * 0.40, 3)},
                "bow": {"rot": round(-level * 0.40 - 35.0 * 0.40 * lean, 3)},
                "torso": {"rot": round(-lean * 1.0, 3), "pos": {"x": 0, "y": 0}},
                "foot_a": {"rot": round(lean * 1.5, 3)},
                "foot_b": {"rot": round(-lean * 1.5, 3)}
            },
            "fx": dict(FX_ZERO)
        },
        {
            "time": 1.15,
            "ease": "in_out",
            "poses": {},
            "fx": dict(FX_ZERO)
        }
    ]
    return {"keys": keys}


def main():
    # 1. Basic Attack
    basic_clip = {
        "clip": "archer_basic_attack",
        "description": "Basic attack: Archer raises arm with bow upright (35° anti-clockwise) -> Frame 10 on the bow -> Frame 11 burst -> arrow shoots forward in a straight line.",
        "fps": 24,
        "loop": False,
        "duration": 0.48,
        "impact": 0.25,
        "interpolation": "smooth",
        "fx": {"node": "GodrayFX", "clip": False},
        "perspectives": {p: build_basic_attack_clip(p) for p in VIEWS}
    }
    basic_path = os.path.join(CLIPS_DIR, "archer_basic_attack.json")
    with open(basic_path, "w") as f:
        json.dump(basic_clip, f, indent=2)
        f.write("\n")
    print("Wrote", basic_path)

    # 2. Skill
    skill_clip = {
        "clip": "archer_skill",
        "description": "Quick shot: the archer swiftly brings up the bow upright (35° anti-clockwise), draws, fires an arrow on impact, and returns to rest.",
        "fps": 24,
        "loop": False,
        "duration": 0.55,
        "impact": 0.25,
        "interpolation": "smooth",
        "fx": {"node": "GodrayFX", "clip": False},
        "perspectives": {p: build_skill_clip(p) for p in VIEWS}
    }
    skill_path = os.path.join(CLIPS_DIR, "archer_skill.json")
    with open(skill_path, "w") as f:
        json.dump(skill_clip, f, indent=2)
        f.write("\n")
    print("Wrote", skill_path)

    # 3. Strong Skill
    strong_skill_clip = {
        "clip": "archer_strong_skill",
        "description": "Power shot: the archer braces in a deep stance with bow upright (35° anti-clockwise), draws with heavy tension, releases a charged arrow with recoil impact, and recovers.",
        "fps": 24,
        "loop": False,
        "duration": 1.15,
        "impact": 0.70,
        "interpolation": "smooth",
        "fx": {"node": "GodrayFX", "clip": False},
        "perspectives": {p: build_strong_skill_clip(p) for p in VIEWS}
    }
    strong_path = os.path.join(CLIPS_DIR, "archer_strong_skill.json")
    with open(strong_path, "w") as f:
        json.dump(strong_skill_clip, f, indent=2)
        f.write("\n")
    print("Wrote", strong_path)


if __name__ == "__main__":
    main()
