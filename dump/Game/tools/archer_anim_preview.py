#!/usr/bin/env python3
"""
Draw a clip on the modular Archer rig and write it out as a strip of pictures.

This is the offline twin of the Godot clip player: it reads the same
`pieces.json` and the same clip file, works out where every piece goes at
every moment of the clip, and draws the result.  It is how the walk cycle and
the idle can be checked without a window.

The maths is the same maths the Godot player does, so what comes out here is
what the game shows:

  * a clip is sampled as a smooth curve through its keys, so the motion
    carries on through a key instead of easing to a stop at it
  * a pose is applied in three layers: the piece's own pose, then the group
    it belongs to, then the piece it is held by

Run it with:  python3 tools/archer_anim_preview.py [clip] [perspective]
"""

import json
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHER_DIR = os.path.join(ROOT, "Archer")
CLIP_DIR = os.path.join(ARCHER_DIR, "anim", "clips")
PERSPECTIVES = ["front", "back", "left", "right"]


# --------------------------------------------------------------------------- #
# sampling
# --------------------------------------------------------------------------- #
def curve_value(points, t):
    """The value of a Hermite curve through a list of [time, value] points."""
    count = len(points)
    if count == 0:
        return 0.0
    if count == 1:
        return float(points[0][1])
    if t <= float(points[0][0]):
        return float(points[0][1])
    if t >= float(points[count - 1][0]):
        return float(points[count - 1][1])

    i = 0
    for k in range(count - 1):
        if float(points[k][0]) <= t <= float(points[k + 1][0]):
            i = k
            break

    t0 = float(points[i][0])
    t1 = float(points[i + 1][0])
    v0 = float(points[i][1])
    v1 = float(points[i + 1][1])
    h = t1 - t0
    if h <= 0.0:
        return v1
    s = (t - t0) / h
    m0 = curve_tangent(points, i)
    m1 = curve_tangent(points, i + 1)
    s2 = s * s
    s3 = s2 * s
    return (2.0 * s3 - 3.0 * s2 + 1.0) * v0 \
        + (s3 - 2.0 * s2 + s) * h * m0 \
        + (-2.0 * s3 + 3.0 * s2) * v1 \
        + (s3 - s2) * h * m1


def curve_tangent(points, i):
    """The slope of a curve at a point, taken from its neighbours."""
    count = len(points)
    m = 0.0
    before = 0.0
    after = 0.0
    if i > 0:
        before = (float(points[i][1]) - float(points[i - 1][1])) / maxf(float(points[i][0]) - float(points[i - 1][0]), 0.0001)
    if i < count - 1:
        after = (float(points[i + 1][1]) - float(points[i][1])) / maxf(float(points[i + 1][0]) - float(points[i][0]), 0.0001)
    if i == 0:
        m = after
    elif i == count - 1:
        m = before
    else:
        m = (float(points[i + 1][1]) - float(points[i - 1][1])) / maxf(float(points[i + 1][0]) - float(points[i - 1][0]), 0.0001)

    delta = after if i < count - 1 else before
    if delta != 0.0:
        ratio = m / delta
        if ratio < 0.0:
            m = 0.0
        elif ratio > 3.0:
            m = 3.0 * delta

    if (i > 0 and before == 0.0) or (i < count - 1 and after == 0.0):
        m = 0.0
    return m


def maxf(a, b):
    return a if a > b else b


def to_vec(value):
    if isinstance(value, dict):
        return (float(value.get("x", 0.0)), float(value.get("y", 0.0)))
    if isinstance(value, (list, tuple)) and len(value) >= 2:
        return (float(value[0]), float(value[1]))
    return (0.0, 0.0)


def sample_smooth(keys, t):
    """The pose of every target at time t, as a smooth curve through the keys."""
    result = {}
    order = []
    for key in keys:
        for target in key.get("poses", {}).keys():
            if target not in order:
                order.append(target)

    curves = {}
    for target in order:
        curve = {"rot": [], "pos_x": [], "pos_y": []}
        for key in keys:
            kt = float(key.get("time", 0.0))
            value = key.get("poses", {}).get(target, {})
            pos = to_vec(value.get("pos", (0.0, 0.0)))
            curve["rot"].append([kt, float(value.get("rot", 0.0))])
            curve["pos_x"].append([kt, pos[0]])
            curve["pos_y"].append([kt, pos[1]])
        curves[target] = curve

    for target in order:
        c = curves[target]
        result[target] = {
            "rot": curve_value(c["rot"], t),
            "pos": (curve_value(c["pos_x"], t), curve_value(c["pos_y"], t)),
        }
    return result


# --------------------------------------------------------------------------- #
# the rig
# --------------------------------------------------------------------------- #
class Rig:
    def __init__(self, perspective):
        base = os.path.join(ARCHER_DIR, f"archer_{perspective}")
        self.data = json.load(open(os.path.join(base, "pieces.json")))
        self.clean = Image.open(os.path.join(base, self.data["spritesheet"])).convert("RGBA")
        self.perspective = perspective
        self.width = self.data["canvas_size"]["width"]
        self.height = self.data["canvas_size"]["height"]
        self.pieces = self.data["pieces"]
        self.roles = self.data["roles"]
        self.groups = self.data["groups"]
        self.parents = self.data.get("piece_parents", {})

        # the rest pose of every piece: where its art sits and where it turns
        self.rest_pos = {}
        self.rest_rot = {}
        for name, piece in self.pieces.items():
            pos = piece["position"]
            piv = piece["pivot"]
            self.rest_pos[name] = (pos["x"] + piv["x"], pos["y"] + piv["y"])
            self.rest_rot[name] = 0.0

        # the role -> piece table, and the parent -> child table
        self.role_to_piece = {}
        for role, piece in self.roles.items():
            if piece in self.pieces:
                self.role_to_piece[role] = piece

        self.parent_of = {}
        for role, parent_role in self.parents.items():
            if role in self.role_to_piece and parent_role in self.role_to_piece:
                self.parent_of[self.role_to_piece[role]] = self.role_to_piece[parent_role]
        self.children_of = {}
        for child, parent in self.parent_of.items():
            self.children_of.setdefault(parent, []).append(child)

        self.order = []
        self._visit(self.pieces.keys())

    def _visit(self, names):
        for name in names:
            if name in self.order:
                continue
            parent = self.parent_of.get(name)
            if parent:
                self._visit([parent])
            self.order.append(name)

    def subtree(self, name):
        out = [name]
        for child in self.children_of.get(name, []):
            out.extend(self.subtree(child))
        return out

    def resolve(self, key):
        if key in self.role_to_piece:
            return self.role_to_piece[key]
        if key in self.pieces:
            return key
        return ""

    def pose_at(self, pose):
        """Where every piece ends up, given a sampled pose."""
        local_rot = {}
        local_off = {}
        for key, value in pose.items():
            if key in self.groups:
                continue
            name = self.resolve(key)
            if not name:
                continue
            local_rot[name] = math.radians(float(value.get("rot", 0.0)))
            local_off[name] = to_vec(value.get("pos", (0.0, 0.0)))

        frame_origin = {}
        chain_rot = {}
        for name in self.order:
            rest = self.rest_pos[name]
            own_rot = local_rot.get(name, 0.0)
            own_off = local_off.get(name, (0.0, 0.0))
            parent = self.parent_of.get(name)
            if parent and parent in frame_origin:
                offset = (rest[0] - self.rest_pos[parent][0],
                          rest[1] - self.rest_pos[parent][1])
                swung = rotate(offset, chain_rot[parent])
                frame_origin[name] = (frame_origin[parent][0] + swung[0] + own_off[0],
                                      frame_origin[parent][1] + swung[1] + own_off[1])
                chain_rot[name] = chain_rot[parent] + own_rot
            else:
                frame_origin[name] = (rest[0] + own_off[0], rest[1] + own_off[1])
                chain_rot[name] = own_rot

        final_pos = {}
        final_rot = {}
        for name in self.order:
            if name in frame_origin:
                final_pos[name] = frame_origin[name]
                final_rot[name] = chain_rot[name]

        for key, value in pose.items():
            if key not in self.groups:
                continue
            group = self.groups[key]
            pivot = to_vec(group.get("pivot", {}))
            theta = math.radians(float(value.get("rot", 0.0)))
            offset = to_vec(value.get("pos", (0.0, 0.0)))
            for member in group.get("members", []):
                member_name = self.resolve(member)
                if not member_name or member_name in self.parent_of:
                    continue
                for name in self.subtree(member_name):
                    if name not in frame_origin:
                        continue
                    base = (frame_origin[name][0] - pivot[0],
                            frame_origin[name][1] - pivot[1])
                    swung = rotate(base, theta)
                    final_pos[name] = (swung[0] + pivot[0] + offset[0],
                                       swung[1] + pivot[1] + offset[1])
                    final_rot[name] = theta + chain_rot[name]

        # the "root" target moves the whole archer, which is how the recoil
        # of a shot is done
        root = pose.get("root", {})
        if root:
            offset = to_vec(root.get("pos", (0.0, 0.0)))
            for name in final_pos:
                final_pos[name] = (final_pos[name][0] + offset[0],
                                   final_pos[name][1] + offset[1])

        return final_pos, final_rot

    def draw(self, final_pos, final_rot):
        """Draw the rig at one moment."""
        canvas = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 0))
        for name in sorted(self.pieces, key=lambda n: self.pieces[n]["z_index"]):
            piece = self.pieces[name]
            region = piece["region"]
            piv = piece["pivot"]
            art = self.clean.crop((region["x"], region["y"],
                                   region["x"] + region["w"],
                                   region["y"] + region["h"]))
            angle = math.degrees(final_rot.get(name, 0.0))
            if abs(angle) > 0.01:
                art = art.rotate(-angle, resample=Image.BICUBIC,
                                 center=(piv["x"], piv["y"]))
            pos = final_pos.get(name, self.rest_pos[name])
            canvas.alpha_composite(art, (int(round(pos[0] - piv["x"])),
                                         int(round(pos[1] - piv["y"]))))
        return canvas


def rotate(point, angle):
    """A point turned about the origin."""
    c = math.cos(angle)
    s = math.sin(angle)
    return (point[0] * c - point[1] * s, point[0] * s + point[1] * c)


# --------------------------------------------------------------------------- #
# the clip
# --------------------------------------------------------------------------- #
def clip_keys(clip, perspective):
    data = json.load(open(os.path.join(CLIP_DIR, clip + ".json")))
    source = data
    per = data.get("perspectives", {})
    if perspective in per:
        source = per[perspective]
    keys = list(source.get("keys", []))
    keys.sort(key=lambda k: float(k.get("time", 0.0)))
    duration = float(data.get("duration", keys[-1].get("time", 1.0) if keys else 1.0))
    return keys, duration


def strip(clip, perspective, frames=8, scale=3):
    rig = Rig(perspective)
    keys, duration = clip_keys(clip, perspective)
    images = []
    for i in range(frames):
        t = duration * float(i) / float(frames)
        pose = sample_smooth(keys, t)
        final_pos, final_rot = rig.pose_at(pose)
        image = rig.draw(final_pos, final_rot)
        images.append(image)
    width = rig.width * scale
    height = rig.height * scale
    out = Image.new("RGBA", (width * frames, height), (28, 29, 36, 255))
    for i, image in enumerate(images):
        out.alpha_composite(image.resize((width, height), Image.NEAREST), (i * width, 0))
    path = os.path.join("/tmp/opencode", f"clip_{clip}_{perspective}.png")
    out.save(path)
    print(f"wrote {path}  ({frames} frames of {clip} in {perspective})")
    return path


if __name__ == "__main__":
    args = sys.argv[1:]
    clip = args[0] if args else "archer_walk"
    views = args[1:] if len(args) > 1 else PERSPECTIVES
    for perspective in views:
        strip(clip, perspective)
