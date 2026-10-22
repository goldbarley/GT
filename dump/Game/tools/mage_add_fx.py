#!/usr/bin/env python3
"""
Put the character clip material on every character sprite of the modular Mage
scenes, and point the teleport effect at the new bar shader.

The character pieces all share one material so that a single pair of band
values cuts the whole mage as one silhouette.  The material is marked
`resource_local_to_scene` so that every instance of a scene gets its own copy
and two mages can be clipped independently.

Running it twice is a no-op.
"""

import os
import re

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
BARS_SHADER = "res://Mage/anim/shaders/mage_teleport_bars.gdshader"
CLIP_SHADER = "res://Mage/anim/shaders/mage_character_clip.gdshader"
OLD_RING_SHADER = "res://Mage/anim/shaders/mage_teleport_ring.gdshader"

# the character sprites of every perspective. The mage scenes are flat, so the
# body is a plain Sprite2D called "Body".
CHARACTER_SPRITES = [
    "Body", "Hat", "Staff", "ArmLeft", "ArmRight",
    "FootLeft", "FootRight", "FootBack", "FootFront",
]


def strip_old(text):
    """Remove the previous effect wiring so the tool can be re-run.

    Every block is matched line by line and stops at the first blank line, so
    it can never swallow the node that follows it.
    """
    text = text.replace(f'[ext_resource type="Shader" path="{OLD_RING_SHADER}" id="3_teleport"]\n', "")

    def drop_block(pattern):
        out = []
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            if re.match(pattern, lines[i]):
                # skip this block until the first blank line
                while i < len(lines) and lines[i].strip() != "":
                    i += 1
                # drop one blank line as well
                if i < len(lines):
                    i += 1
                continue
            out.append(lines[i])
            i += 1
        return "\n".join(out)

    text = drop_block(r'^\[sub_resource type="ShaderMaterial" id="ShaderMaterial_teleport"\]$')
    text = drop_block(r'^\[node name="TeleportFX" type="ColorRect" parent="\."\]$')
    return text


for perspective in ["front", "back", "left", "right"]:
    path = os.path.join(MAGE_DIR, f"mage_{perspective}", f"mage_{perspective}.tscn")
    text = open(path).read()

    already_wired = "mage_character_clip.gdshader" in text
    if not already_wired:
        text = strip_old(text)

    # --- resources ---------------------------------------------------------
    if not already_wired:
        steps = len(re.findall(r"^\[ext_resource", text, re.M)) + \
            len(re.findall(r"^\[sub_resource", text, re.M)) + 1
        text = re.sub(r"\[gd_scene load_steps=\d+ format=3\]",
                      f"[gd_scene load_steps={steps + 3} format=3]", text, count=1)

        lines = text.split("\n")
        last_ext = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
        lines[last_ext + 1:last_ext + 1] = [
            f'[ext_resource type="Shader" path="{BARS_SHADER}" id="3_teleport"]',
            f'[ext_resource type="Shader" path="{CLIP_SHADER}" id="4_clip"]',
        ]
        text = "\n".join(lines)

        materials = '''
[sub_resource type="ShaderMaterial" id="ShaderMaterial_teleport"]
resource_local_to_scene = true
shader = ExtResource("3_teleport")
shader_parameter/progress = 0.0
shader_parameter/opacity = 1.0

[sub_resource type="ShaderMaterial" id="ShaderMaterial_character_clip"]
resource_local_to_scene = true
shader = ExtResource("4_clip")
shader_parameter/band_top = -1000.0
shader_parameter/band_bottom = 1000.0
'''
        lines = text.split("\n")
        first_node = next(i for i, l in enumerate(lines) if l.startswith("[node "))
        text = "\n".join(lines[:first_node]) + materials + "\n".join(lines[first_node:])

        # --- the effect quad ------------------------------------------------
        canvas_w = 38 if perspective in ("front", "left") else 37
        fx_node = f'''
[node name="TeleportFX" type="ColorRect" parent="."]
z_index = 10
material = SubResource("ShaderMaterial_teleport")
offset_top = -18.0
offset_right = {float(canvas_w)}
offset_bottom = 32.0
color = Color(1, 1, 1, 1)
'''
        text = text.rstrip("\n") + "\n" + fx_node

    # --- the character clip material on every character sprite ---------------
    for sprite in CHARACTER_SPRITES:
        pattern = re.compile(
            r'(\[node name="%s" type="Sprite2D"[^\]]*\]\n)(.*?)(?=\n\[|\Z)' % re.escape(sprite),
            re.S)
        m = pattern.search(text)
        if not m:
            continue
        blk = m.group(2)
        if "material = " in blk:
            continue
        # the material line goes first, then the rest of the node body
        blk = "material = SubResource(\"ShaderMaterial_character_clip\")\n" + blk
        text = text[: m.start(2)] + blk + text[m.end(2):]

    open(path, "w").write(text)
    print(f"  {perspective}: character clip wired")
