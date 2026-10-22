#!/usr/bin/env python3

"""
Add the contact shadow to every modular Mage perspective scene.

The shadow is a quad that lies on the ground under the mage's feet, and the
small driver that keeps it in the right place: it follows her feet, it sits
on the ground line, and it spreads out and fades while she is in the air.

Running it twice is a no-op.
"""

import os
import re

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
SHADER = "res://Mage/anim/shaders/mage_shadow.gdshader"
DRIVER = "res://Mage/anim/mage_shadow_fx.gd"
NODE = "ShadowFX"

# The shadow is drawn in the quad's own space and always sits in the middle
# of it, so the quad is centred on the node's position.
QUAD_W, QUAD_H = 78.0, 22.0

for perspective in ["front", "back", "left", "right"]:
    path = os.path.join(MAGE_DIR, f"mage_{perspective}", f"mage_{perspective}.tscn")
    text = open(path).read()
    if NODE in text:
        print(f"  {perspective}: already present")
        continue

    # --- resources ---------------------------------------------------------
    exts = len(re.findall(r"^\[ext_resource", text, re.M))
    subs = len(re.findall(r"^\[sub_resource", text, re.M))
    # one shader, one driver and one material are added
    text = re.sub(r"\[gd_scene load_steps=\d+ format=3\]",
                  f"[gd_scene load_steps={exts + subs + 4} format=3]", text, count=1)

    lines = text.split("\n")
    last_ext = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
    lines[last_ext + 1:last_ext + 1] = [
        f'[ext_resource type="Shader" path="{SHADER}" id="12_shadow"]',
        f'[ext_resource type="Script" path="{DRIVER}" id="13_shadow_fx"]',
    ]
    text = "\n".join(lines)

    material = f'''
[sub_resource type="ShaderMaterial" id="ShaderMaterial_shadow"]
resource_local_to_scene = true
shader = ExtResource("12_shadow")
shader_parameter/quad_size = Vector2({QUAD_W}, {QUAD_H})
shader_parameter/radius = 7.0
shader_parameter/squash = 0.34
shader_parameter/opacity = 0.34
shader_parameter/softness = 1.5
'''
    lines = text.split("\n")
    first_node = next(i for i, l in enumerate(lines) if l.startswith("[node "))
    text = "\n".join(lines[:first_node]) + material + "\n".join(lines[first_node:])

    node = f'''
[node name="{NODE}" type="ColorRect" parent="."]
z_index = -1
material = SubResource("ShaderMaterial_shadow")
offset_left = {-QUAD_W / 2.0}
offset_top = {-QUAD_H / 2.0}
offset_right = {QUAD_W / 2.0}
offset_bottom = {QUAD_H / 2.0}
color = Color(1, 1, 1, 1)
script = ExtResource("13_shadow_fx")
'''
    text = text.rstrip("\n") + "\n" + node
    open(path, "w").write(text)
    print(f"  {perspective}: contact shadow added")
