#!/usr/bin/env python3

"""
Add the Knight's Edge effect to every modular Knight perspective scene.

Knight's Edge is the Knight's ultimate attack, and it comes in three parts:
the blade catches fire, the screen goes to pitch black, and the fire sweeps
across the dark.

The fire itself is drawn in the knight's own space, so it is the size of the
knight and travels with him: it is a quad under the rig, and the script
drives it.  The darkness is the only part that belongs to the screen, so it
is a quad in a canvas layer over the game.

The placement - where the sweep turns about, how big it is, and which way it
faces - is measured from the frames and the rig by
`knight_edge_placement.py`.

Running it twice is a no-op.
"""

import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KNIGHT = os.path.join(ROOT, "Knight")
ANIM = os.path.join(KNIGHT, "Anim", "KnightUltimate")
VIEWS = ["front", "back", "left", "right"]

SHADER_FIRE = "res://Knight/Anim/KnightUltimate/knight_ultimate_fire.gdshader"
SHADER_DARK = "res://Knight/Anim/KnightUltimate/knight_ultimate_dark.gdshader"
FLIPBOOK = "res://Knight/Anim/KnightUltimate/sprites/fire_slash.png"
SCRIPT_FX = "res://Knight/Anim/KnightUltimate/knight_ultimate_fx.gd"

# the nodes the effect owns, and the resources it needs
NODES = ("KnightUltimateLayer", "KnightUltimateDark", "KnightUltimateFX")
RESOURCES = ("30_edge_fx", "31_edge_fire", "32_edge_dark", "33_edge_flames")
MATERIALS = ("ShaderMaterial_edge_fire", "ShaderMaterial_edge_dark")

def scene_path(view):
    return os.path.join(KNIGHT, "Knight_%s" % view, "Knight%s.tscn" % view.capitalize())


def strip_scene(text):
    """Takes the effect out of a scene, so it can be put back cleanly."""
    lines = text.split("\n")
    out = []
    skipping = False
    for line in lines:
        if line.startswith("[node "):
            match = re.search(r'name="([^"]+)"', line)
            skipping = match is not None and match.group(1) in NODES
        if skipping:
            continue
        out.append(line)
    text = "\n".join(out)

    # the materials
    lines = text.split("\n")
    out = []
    skipping = False
    for line in lines:
        if line.startswith("[sub_resource ") or line.startswith("[node ") or line.startswith("[ext_resource "):
            if line.startswith("[sub_resource "):
                match = re.search(r'id="([^"]+)"', line)
                skipping = match is not None and match.group(1) in MATERIALS
            else:
                skipping = False
        if skipping:
            continue
        out.append(line)
    text = "\n".join(out)

    # the resources
    for rid in RESOURCES:
        text = re.sub(r'\[ext_resource type="[A-Za-z0-9]+" path="[^"]*" id="%s"\]\n' % rid, "", text)

    # the load steps go down by what went
    match = re.search(r"\[gd_scene load_steps=(\d+) format=3\]", text)
    if match:
        steps = int(match.group(1))
        steps -= text.count("res://Knight/Anim/KnightUltimate/")
        steps -= sum(1 for line in text.split("\n") if line.startswith("[sub_resource"))
        text = text.replace(match.group(0), "[gd_scene load_steps=%d format=3]" % steps)
    return text


def add_scene(view, placement):
    """Puts the effect into one perspective's scene."""
    path = scene_path(view)
    text = strip_scene(open(path).read())

    info = placement[view]
    # the fire's quad, in the knight's own space: big enough to hold the
    # whole sweep, and set so the art's arc turns about the shoulder
    reach = info["reach"]
    scale = info["scale"]
    shoulder = info["shoulder"]
    offset = info["front_offset"]
    centre = info["arc_centre"]
    extent = info["art_extent"]
    canvas = info["canvas_size"]
    # The art's own extent about the arc's centre, in the master's pixels.
    # The quad has to cover all of it, and the arc's centre has to land on
    # the knight's shoulder.
    art_left = (extent["left"] - centre[0]) * scale
    art_right = (extent["right"] - centre[0]) * scale
    art_top = (extent["top"] - centre[1]) * scale
    art_bottom = (extent["bottom"] - centre[1]) * scale
    # the quad, in the knight's own space
    left = shoulder[0] + offset[0] + art_left
    top = shoulder[1] + offset[1] + art_top
    width = art_right - art_left
    height = art_bottom - art_top

    exts = len([l for l in text.split("\n") if l.startswith("[ext_resource")])
    subs = len([l for l in text.split("\n") if l.startswith("[sub_resource")])
    text = text.replace(
        "[gd_scene load_steps=%d format=3]" % (exts + subs),
        "[gd_scene load_steps=%d format=3]" % (exts + subs + 5),
        1,
    )

    # the resources the effect needs
    resources = [
        '[ext_resource type="Script" path="%s" id="30_edge_fx"]' % SCRIPT_FX,
        '[ext_resource type="Shader" path="%s" id="31_edge_fire"]' % SHADER_FIRE,
        '[ext_resource type="Shader" path="%s" id="32_edge_dark"]' % SHADER_DARK,
        '[ext_resource type="Texture2D" path="%s" id="33_edge_flames"]' % FLIPBOOK,
    ]
    lines = text.split("\n")
    last_ext = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
    lines[last_ext + 1:last_ext + 1] = resources
    text = "\n".join(lines)

    materials = """
[sub_resource type="ShaderMaterial" id="ShaderMaterial_edge_fire"]
resource_local_to_scene = true
shader = ExtResource("31_edge_fire")
shader_parameter/flipbook = ExtResource("33_edge_flames")
shader_parameter/frames = 8.0
shader_parameter/master_size = Vector2(%g, %g)
shader_parameter/art_centre = Vector2(%g, %g)
shader_parameter/art_radius = %g
shader_parameter/charge = 0.0
shader_parameter/slash = 0.0
shader_parameter/frame = 0.0
shader_parameter/time_seconds = 0.0
shader_parameter/origin = Vector2(0, 0)
shader_parameter/scale = %g
shader_parameter/mirror = %g
shader_parameter/drift = Vector2(0, 0)
shader_parameter/drift_mix = 0.0
shader_parameter/drift_wander = 34.0
shader_parameter/drift_time = 0.0
shader_parameter/blade_pos = Vector2(0, 0)
shader_parameter/blade_dir = Vector2(1, 0)
shader_parameter/blade_len = 10.0

[sub_resource type="ShaderMaterial" id="ShaderMaterial_edge_dark"]
resource_local_to_scene = true
shader = ExtResource("32_edge_dark")
shader_parameter/dim = 0.0
""" % (canvas[0], canvas[1],
       info["arc_centre"][0], info["arc_centre"][1], info["arc_radius"],
       scale, info["mirror"])
    lines = text.split("\n")
    first_node = next(i for i, l in enumerate(lines) if l.startswith("[node "))
    text = "\n".join(lines[:first_node]) + materials + "\n".join(lines[first_node:])

    # Both quads are in a layer over the game: the darkness covers the
    # screen, and the fire burns on top of it.  The fire is placed and sized
    # by the knight, so it is his size and where his sword is.
    nodes = """
[node name="KnightUltimateLayer" type="CanvasLayer" parent="."]
layer = 100

[node name="KnightUltimateDark" type="ColorRect" parent="KnightUltimateLayer"]
z_index = 0
material = SubResource("ShaderMaterial_edge_dark")
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 1)

[node name="KnightUltimateFX" type="ColorRect" parent="KnightUltimateLayer"]
z_index = 1
material = SubResource("ShaderMaterial_edge_fire")
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(1, 1, 1, 1)
script = ExtResource("30_edge_fx")
dark_path = NodePath("../KnightUltimateDark")
rig_path = NodePath("../..")
arc_centre_offset = Vector2(%g, %g)
arc_scale = %g
mirror = %g
""" % (offset[0], offset[1], scale, info["mirror"])
    text = text.rstrip("\n") + "\n" + nodes
    open(path, "w").write(text)
    print("  %s: the effect added" % view)


def main():
    with open(os.path.join(ANIM, "placement.json")) as handle:
        placement = json.load(handle)
    for view in VIEWS:
        add_scene(view, placement)


if __name__ == "__main__":
    main()
