extends Node2D
class_name ArrowShockwave

@export var auto_free: bool = true
@export var manual_timeline: bool = false

@onready var sprite: Sprite2D = $ShockwaveSprite

var frame_textures: Array[Texture2D] = [
	preload("res://assets/characters/Archer/effects/frame_1.png"),
	preload("res://assets/characters/Archer/effects/frame_2.png"),
	preload("res://assets/characters/Archer/effects/frame_3.png"),
	preload("res://assets/characters/Archer/effects/frame_4.png"),
	preload("res://assets/characters/Archer/effects/frame_5.png")
]

var stage_index: int = 0
var stage_timer: float = 0.0

# 5 stages: Stages 1-4 take 0.13s (~8 frames at 60fps), Stage 5 lasts 30 frames (0.50s)
const STAGE_DURATIONS: Array[float] = [
	0.13,  # Stage 1: Initial burst ignition (Image 1) - 8 frames
	0.13,  # Stage 2: Peak horizontal & 3D circular wrap (Image 2) - 8 frames
	0.13,  # Stage 3: Circular shockwave thinning (Image 3) - 8 frames
	0.13,  # Stage 4: Both dying down (Image 4) - 8 frames
	0.50   # Stage 5: Dissipating remnants - 30 frames (0.50s at 60fps)
]

var is_finished: bool = false

func _ensure_nodes() -> void:
	if not sprite:
		sprite = get_node_or_null("ShockwaveSprite") as Sprite2D

func _ready() -> void:
	_ensure_nodes()
	_apply_stage(0)

func _process(delta: float) -> void:
	if manual_timeline or is_finished or stage_index >= STAGE_DURATIONS.size():
		return
		
	stage_timer += delta
	var target_duration = STAGE_DURATIONS[stage_index]
	var progress = clamp(stage_timer / target_duration, 0.0, 1.0)
	
	_update_shader_parameters(stage_index, progress)
	
	if stage_timer >= target_duration:
		stage_timer -= target_duration
		stage_index += 1
		if stage_index < STAGE_DURATIONS.size():
			_apply_stage(stage_index)
		else:
			_finish_shockwave()

func _apply_stage(idx: int) -> void:
	stage_index = idx
	_ensure_nodes()
		
	if sprite and idx < frame_textures.size():
		sprite.texture = frame_textures[idx]
		
	_apply_stage_material(idx)

func _apply_stage_material(idx: int) -> void:
	if not sprite or not sprite.material:
		return
		
	match idx:
		0:
			sprite.visible = true
			sprite.material.set_shader_parameter("energy_boost", 1.0)
			sprite.material.set_shader_parameter("dissolve_progress", 0.0)
			sprite.material.set_shader_parameter("opacity", 1.0)
		1:
			sprite.visible = true
			sprite.material.set_shader_parameter("energy_boost", 1.4)
			sprite.material.set_shader_parameter("dissolve_progress", 0.0)
			sprite.material.set_shader_parameter("opacity", 1.0)
		2:
			sprite.visible = true
			sprite.material.set_shader_parameter("energy_boost", 1.1)
			sprite.material.set_shader_parameter("dissolve_progress", 0.05)
			sprite.material.set_shader_parameter("opacity", 1.0)
		3:
			sprite.visible = true
			sprite.material.set_shader_parameter("energy_boost", 0.9)
			sprite.material.set_shader_parameter("dissolve_progress", 0.15)
			sprite.material.set_shader_parameter("opacity", 0.9)
		4:
			sprite.visible = true
			sprite.material.set_shader_parameter("energy_boost", 0.8)
			sprite.material.set_shader_parameter("dissolve_progress", 0.25)
			sprite.material.set_shader_parameter("opacity", 0.75)

func _update_shader_parameters(idx: int, t: float) -> void:
	if not sprite:
		sprite = get_node_or_null("ShockwaveSprite") as Sprite2D
	if not sprite or not sprite.material:
		return
	if idx == 1:
		sprite.material.set_shader_parameter("energy_boost", lerp(1.4, 1.15, t))
	elif idx == 3:
		sprite.material.set_shader_parameter("dissolve_progress", lerp(0.10, 0.25, t))
		sprite.material.set_shader_parameter("opacity", lerp(0.95, 0.75, t))
	elif idx == 4:
		sprite.material.set_shader_parameter("dissolve_progress", lerp(0.25, 1.0, t))
		sprite.material.set_shader_parameter("opacity", lerp(0.75, 0.0, t))

func evaluate_time(time_s: float) -> void:
	manual_timeline = true
	_ensure_nodes()
	if time_s < 0.0:
		visible = false
		return
		
	var total_dur = 0.0
	for d in STAGE_DURATIONS:
		total_dur += d
		
	if time_s >= total_dur:
		visible = false
		return
		
	visible = true
	var accum = 0.0
	var target_stage = 0
	var progress = 0.0
	for i in range(STAGE_DURATIONS.size()):
		var d = STAGE_DURATIONS[i]
		if time_s < accum + d:
			target_stage = i
			progress = (time_s - accum) / max(0.0001, d)
			break
		accum += d
		
	stage_index = target_stage
	stage_timer = progress * STAGE_DURATIONS[target_stage]
	if sprite:
		sprite.visible = true
		sprite.texture = frame_textures[target_stage]
		_apply_stage_material(target_stage)
		_update_shader_parameters(target_stage, progress)
	queue_redraw()

func reset() -> void:
	is_finished = false
	stage_index = 0
	stage_timer = 0.0
	visible = false
	if not manual_timeline:
		set_process(true)
	if sprite:
		sprite.visible = true
		sprite.texture = frame_textures[0]
		_apply_stage_material(0)
	queue_redraw()

func _finish_shockwave() -> void:
	if is_finished:
		return
	is_finished = true
	set_process(false)
	if sprite:
		sprite.visible = false
	if not auto_free:
		visible = false
		return
	queue_free()
