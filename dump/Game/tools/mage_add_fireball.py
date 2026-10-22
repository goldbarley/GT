#!/usr/bin/env python3
"""
Add the fireball effect node to every modular Mage perspective scene.

The node is a quad that reaches well above and to the side of the character so
the fireball can be summoned out of the sky and land away from the mage's feet.
It carries the fireball shader and the small driver that keeps the shader in
sync with the staff.

Running it twice is a no-op.
"""

import os
import re

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
SHADER = "res://Mage/anim/shaders/mage_fireball.gdshader"
DRIVER = "res://Mage/anim/mage_fireball_fx.gd"
NODE = "FireballFX"

# the quad reaches out past the character canvas
QUAD_LEFT, QUAD_TOP, QUAD_RIGHT, QUAD_BOTTOM = -34.0, -40.0, 56.0, 36.0

# where the gem sits on the staff, measured from the grip in the staff's frame
GEM_OFFSET = {
    "front": (-11.0, -10.0),
    "back": (10.0, -13.0),
    "left": (-11.0, -10.0),
    "right": (9.0, -9.0),
}

for perspective, (gx, gy) in GEM_OFFSET.items():
    path = os.path.join(MAGE_DIR, f"mage_{perspective}", f"mage_{perspective}.tscn")
    text = open(path).read()
    if NODE in text:
        print(f"  {perspective}: already present")
        continue

    steps = len(re.findall(r"^\[ext_resource", text, re.M)) + \
        len(re.findall(r"^\[sub_resource", text, re.M)) + 1
    text = re.sub(r"\[gd_scene load_steps=\d+ format=3\]",
                  f"[gd_scene load_steps={steps + 2} format=3]", text, count=1)

    lines = text.split("\n")
    last_ext = max(i for i, l in enumerate(lines) if l.startswith("[ext_resource"))
    lines[last_ext + 1:last_ext + 1] = [
        f'[ext_resource type="Shader" path="{SHADER}" id="5_fireball"]',
        f'[ext_resource type="Script" path="{DRIVER}" id="6_fireball_fx"]',
    ]
    text = "\n".join(lines)

    material = '''
[sub_resource type="ShaderMaterial" id="ShaderMaterial_fireball"]
resource_local_to_scene = true
shader = ExtResource("5_fireball")
shader_parameter/progress = 0.0
shader_parameter/fall = 0.0
shader_parameter/opacity = 1.0
shader_parameter/spawn_pos = Vector2(9, 10)
shader_parameter/impact_pos = Vector2(-9, 30)
shader_parameter/arc_height = 15.0
shader_parameter/gem_pos = Vector2(2, 15)
shader_parameter/gem_glow = 0.0
shader_parameter/pit_pos = Vector2(34, 30)
shader_parameter/pit_strength = 0.0
shader_parameter/linger = 0.0
shader_parameter/linger_duration = 2.5
shader_parameter/quad_origin = Vector2(-34, -40)
shader_parameter/quad_size = Vector2(90, 76)
shader_parameter/fireball_radius = 4.0
'''
    lines = text.split("\n")
    first_node = next(i for i, l in enumerate(lines) if l.startswith("[node "))
    text = "\n".join(lines[:first_node]) + material + "\n".join(lines[first_node:])

    node = f'''
[node name="{NODE}" type="ColorRect" parent="."]
z_index = 8
material = SubResource("ShaderMaterial_fireball")
offset_left = {QUAD_LEFT}
offset_top = {QUAD_TOP}
offset_right = {QUAD_RIGHT}
offset_bottom = {QUAD_BOTTOM}
color = Color(1, 1, 1, 1)
script = ExtResource("6_fireball_fx")
gem_offset = Vector2({gx}, {gy})
'''
    text = text.rstrip("\n") + "\n" + node
    open(path, "w").write(text)
    print(f"  {perspective}: fireball effect node added")
