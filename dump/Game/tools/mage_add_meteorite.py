#!/usr/bin/env python3
"""
Add the meteorite effect node to every modular Mage perspective scene.

The node is a large quad, much bigger than the character, so the meteorite can
come from off the top of the screen and the explosion can fill the ground. It
carries the meteorite shader and the small driver that keeps the ground line
correct as the mage flies up.

Running it twice is a no-op.
"""

import os
import re

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
SHADER = "res://Mage/anim/shaders/mage_meteorite.gdshader"
DRIVER = "res://Mage/anim/mage_meteorite_fx.gd"
NODE = "MeteoriteFX"

# the quad reaches well above the character and out to both sides
LEFT, TOP, RIGHT, BOTTOM = -80.0, -280.0, 140.0, 90.0

for perspective in ["front", "back", "left", "right"]:
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
        f'[ext_resource type="Shader" path="{SHADER}" id="9_meteorite"]',
        f'[ext_resource type="Script" path="{DRIVER}" id="10_meteorite_fx"]',
    ]
    text = "\n".join(lines)

    material = '''
[sub_resource type="ShaderMaterial" id="ShaderMaterial_meteorite"]
resource_local_to_scene = true
shader = ExtResource("9_meteorite")
shader_parameter/meteor_y = 260.0
shader_parameter/meteor_x = 26.0
shader_parameter/dust = 0.0
shader_parameter/explode = 0.0
shader_parameter/aftermath = 0.0
shader_parameter/shake = 0.0
shader_parameter/ground_y = 32.0
shader_parameter/gem_glow = 0.0
'''
    lines = text.split("\n")
    first_node = next(i for i, l in enumerate(lines) if l.startswith("[node "))
    text = "\n".join(lines[:first_node]) + material + "\n".join(lines[first_node:])

    node = f'''
[node name="{NODE}" type="ColorRect" parent="."]
z_index = 9
material = SubResource("ShaderMaterial_meteorite")
offset_left = {LEFT}
offset_top = {TOP}
offset_right = {RIGHT}
offset_bottom = {BOTTOM}
color = Color(1, 1, 1, 1)
script = ExtResource("10_meteorite_fx")
ground_y = 32.0
'''
    text = text.rstrip("\n") + "\n" + node
    open(path, "w").write(text)
    print(f"  {perspective}: meteorite effect node added")
