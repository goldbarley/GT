#!/usr/bin/env python3
"""
Add the energy barrier effect node to every modular Mage perspective scene.

The node is a quad covering the mage carrying the barrier shader, and the small
driver that lets the game dismiss the barrier again once it is up.

Running it twice is a no-op.
"""

import os
import re

MAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Mage")
SHADER = "res://Mage/anim/shaders/mage_energy_barrier.gdshader"
DRIVER = "res://Mage/anim/mage_energy_barrier_fx.gd"
NODE = "BarrierFX"

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
        f'[ext_resource type="Shader" path="{SHADER}" id="7_barrier"]',
        f'[ext_resource type="Script" path="{DRIVER}" id="8_barrier_fx"]',
    ]
    text = "\n".join(lines)

    material = '''
[sub_resource type="ShaderMaterial" id="ShaderMaterial_barrier"]
resource_local_to_scene = true
shader = ExtResource("7_barrier")
shader_parameter/progress = 0.0
shader_parameter/ground_progress = 0.0
shader_parameter/dismiss_fade = 1.0
'''
    lines = text.split("\n")
    first_node = next(i for i, l in enumerate(lines) if l.startswith("[node "))
    text = "\n".join(lines[:first_node]) + material + "\n".join(lines[first_node:])

    node = f'''
[node name="{NODE}" type="ColorRect" parent="."]
z_index = 6
material = SubResource("ShaderMaterial_barrier")
offset_left = -16.0
offset_top = -40.0
offset_right = 54.0
offset_bottom = 36.0
color = Color(1, 1, 1, 1)
script = ExtResource("8_barrier_fx")
'''
    text = text.rstrip("\n") + "\n" + node
    open(path, "w").write(text)
    print(f"  {perspective}: energy barrier node added")
