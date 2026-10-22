extends Node2D
class_name ArrowShockwave

@export var auto_free: bool = true
@export var manual_timeline: bool = false

@onready var sprite: Sprite2D = $ShockwaveSprite
@onready var particles: CPUParticles2D = $LingeringParticles

var frame_textures: Array[Texture2D] = [
	preload("res://sprites/effects/arrow_shockwave/frame_1.png"),
	preload("res://sprites/effects/arrow_shockwave/frame_2.png"),
	preload("res://sprites/effects/arrow_shockwave/frame_3.png"),
	preload("res://sprites/effects/arrow_shockwave/frame_4.png"),
	preload("res://sprites/effects/arrow_shockwave/frame_5.png")
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

# Exact Stage 5 remnant coordinates from frame_5 pixel art
const REMNANT_SEEDS: Array[Vector2] = [
	Vector2(22, 1), Vector2(26, 5), Vector2(8, 13), Vector2(28, 13),
	Vector2(9, 14), Vector2(22, 14), Vector2(23, 14), Vector2(11, 15),
	Vector2(17, 15), Vector2(18, 15), Vector2(35, 15), Vector2(10, 16),
	Vector2(21, 16), Vector2(23, 16), Vector2(24, 16), Vector2(31, 16),
	Vector2(32, 16), Vector2(33, 16), Vector2(37, 16), Vector2(39, 17),
	Vector2(14, 18), Vector2(20, 18), Vector2(12, 19), Vector2(19, 19),
	Vector2(20, 19), Vector2(11, 20), Vector2(12, 20), Vector2(12, 22),
	Vector2(24, 22), Vector2(9, 25), Vector2(9, 29), Vector2(10, 32)
]

class RemnantParticle:
	var initial_pos: Vector2
	var pos: Vector2
	var vel: Vector2
	var base_color: Color
	var age_frames: int = 0
	var max_frames: int = 30

var stage_5_particles: Array[RemnantParticle] = []
var stage_5_active: bool = false
var is_finished: bool = false

func _ensure_nodes() -> void:
	if not sprite:
		sprite = get_node_or_null("ShockwaveSprite") as Sprite2D
	if not particles:
		particles = get_node_or_null("LingeringParticles") as CPUParticles2D

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
	
	# Simulate 30-frame Stage 5 dissipating remnant particles
	if stage_5_active:
		for p in stage_5_particles:
			p.pos += p.vel * delta
			# Light particle slow damping
			p.vel = p.vel.move_toward(Vector2.ZERO, 4.0 * delta)
			# Small 10% chance per frame to change direction due to arbitrary wind
			if randf() < 0.10:
				var wind = Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
				p.vel += wind
			p.age_frames += 1
		queue_redraw()
	
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
		
	if sprite and idx < frame_textures.size() and idx < 4:
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
			if particles:
				particles.emitting = true
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
			# Stage 5: Core shockwave ended; spawn 30-frame dissipating remnants
			sprite.visible = false
			_spawn_stage_5_dissipating_particles()

func _spawn_stage_5_dissipating_particles() -> void:
	stage_5_active = true
	stage_5_particles.clear()
	var center = Vector2(22.0, 0.0) # Shockwave center
	
	for seed in REMNANT_SEEDS:
		var p = RemnantParticle.new()
		p.initial_pos = Vector2(seed.x, seed.y - 16.0)
		p.pos = p.initial_pos
		
		# Slowly move opposite to the centre of the shockwave in all directions
		var diff = p.pos - center
		var dir = diff.normalized() if diff.length_squared() > 0.01 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		# Low inertial motion for very light particles
		var speed = randf_range(8.0, 16.0)
		p.vel = dir * speed
		
		# Color: All yellow (golden yellow near middle, amber near archer)
		var t_pos = clamp(seed.x / 40.0, 0.0, 1.0)
		var yellow = Color(1.0, 0.88, 0.08)
		var amber = Color(0.86, 0.52, 0.0)
		p.base_color = amber.lerp(yellow, t_pos)
		p.max_frames = 30
		p.age_frames = 0
		stage_5_particles.append(p)
	
	queue_redraw()

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

func evaluate_time(time_s: float) -> void:
	manual_timeline = true
	_ensure_nodes()
	if time_s < 0.0:
		visible = false
		if particles: particles.emitting = false
		stage_5_active = false
		return
		
	var total_dur = 0.0
	for d in STAGE_DURATIONS:
		total_dur += d
		
	if time_s >= total_dur:
		visible = false
		if particles: particles.emitting = false
		stage_5_active = false
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
	
	if target_stage < 4:
		stage_5_active = false
		if sprite:
			sprite.visible = true
			if target_stage < frame_textures.size():
				sprite.texture = frame_textures[target_stage]
			_apply_stage_material(target_stage)
			_update_shader_parameters(target_stage, progress)
		if particles:
			particles.emitting = (target_stage >= 1)
	else:
		if sprite:
			sprite.visible = false
		if particles:
			particles.emitting = false
		if not stage_5_active or stage_5_particles.is_empty():
			_spawn_stage_5_dissipating_particles()
		_evaluate_stage_5_scrub(progress)
		
	queue_redraw()

func _evaluate_stage_5_scrub(progress: float) -> void:
	stage_5_active = true
	var current_frame = int(clamp(progress * 30.0, 0.0, 30.0))
	var t_sec = progress * 0.50
	for p in stage_5_particles:
		p.age_frames = current_frame
		p.pos = p.initial_pos + p.vel * t_sec * (1.0 - 0.4 * progress)

func reset() -> void:
	is_finished = false
	stage_index = 0
	stage_timer = 0.0
	stage_5_active = false
	visible = false
	if not manual_timeline:
		set_process(true)
	if sprite:
		sprite.visible = true
		sprite.texture = frame_textures[0]
		_apply_stage_material(0)
	if particles:
		particles.emitting = false
		particles.restart()
	stage_5_particles.clear()
	queue_redraw()

func _draw() -> void:
	if not stage_5_active:
		return
	for p in stage_5_particles:
		var alpha = clamp(1.0 - float(p.age_frames) / float(p.max_frames), 0.0, 1.0)
		if alpha > 0.01:
			var col = Color(p.base_color.r, p.base_color.g, p.base_color.b, alpha)
			draw_rect(Rect2(p.pos, Vector2(1.2, 1.2)), col)

func _finish_shockwave() -> void:
	if is_finished:
		return
	is_finished = true
	set_process(false)
	stage_5_active = false
	if sprite:
		sprite.visible = false
	if particles:
		particles.emitting = false
	if not auto_free:
		visible = false
		return
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
