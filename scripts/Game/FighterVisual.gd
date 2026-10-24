extends Node2D

const HitEffectClass := preload("res://assets/effects/hit/hit_effect.gd")

var kind: int = 0
var rigs: Dictionary = {}
var players: Dictionary = {}
var facing: String = "front"
var current: ChoreoPlayer
var motion: Tween
var formation_motion: Tween
var active_clip: String = ""
var beam: MageBeamBurst
var edge_layers: Dictionary = {}
var bowstring_upper: Line2D
var bowstring_lower: Line2D
var tile_size: float = 0.0
var rest_bounds: Dictionary = {}
var cast_target_local := Vector2.INF
var action_elapsed := 0.0
var action_duration := 0.0
var authored_impact := 0.0
var impact_fraction := 0.58
var playing_action := 0
var reaction: Tween
var arena_clip := Rect2()
var teleport_progress := -1.0
var teleport_destination := Vector2.ZERO
var teleport_moved := false
var teleport_phase := 0
const TELEPORT_PHASE_DURATION := 0.9

func configure(character_class: int) -> void:
	kind = character_class
	if kind == 2:
		bowstring_upper = _new_bowstring()
		bowstring_lower = _new_bowstring()
		add_child(bowstring_upper)
		add_child(bowstring_lower)
	if current != null:
		current.stop()
		current.dismiss_effect()
	show_direction(2)
	idle()

func _new_bowstring() -> Line2D:
	var line := Line2D.new()
	line.width = 1.2
	line.default_color = Color(1.0, 0.88, 0.57, 0.95)
	line.z_index = 1
	line.visible = false
	return line

func show_direction(direction: int) -> void:
	var perspective: String = ["front", "back", "front", "left", "right"][direction]
	if current != null:
		current.stop()
	for rig in rigs.values():
		rig.visible = false
		var dark_layer: CanvasLayer = rig.get_node_or_null("KnightUltimateDarkLayer")
		if dark_layer != null:
			dark_layer.visible = false
	for layer in edge_layers.values():
		layer.visible = false
	for player in players.values():
		player.set_process(false)
	facing = perspective
	if not rigs.has(perspective):
		var path: String
		if kind == 0:
			path = "res://assets/characters/Mage/mage_%s/mage_%s.tscn" % [perspective, perspective]
		elif kind == 2:
			path = "res://assets/characters/Archer/archer_%s/archer_%s.tscn" % [perspective, perspective]
		else:
			path = "res://assets/characters/Knight/Knight_%s/Knight%s.tscn" % [perspective, perspective.capitalize()]
		var rig := (load(path) as PackedScene).instantiate() as ModularRig
		add_child(rig)
		_ignore_mouse(rig)
		var dim := rig.get_node_or_null("MeteoriteDim")
		if dim != null:
			dim.allow_dimming = false
		if kind == 1:
			_add_edge(rig, perspective)
		var bounds := _visible_bounds(rig)
		rest_bounds[perspective] = bounds
		rig.position = -bounds.get_center()
		var player := ChoreoPlayer.new()
		player.target = rig
		player.smooth_rotation = false
		player.clips_directory = "res://assets/characters/Mage/anim/clips" if kind == 0 else "res://assets/characters/Archer/anim/clips" if kind == 2 else "res://assets/characters/Knight/Anim/clips"
		add_child(player)
		if not player.is_inside_tree():
			player._cache_rig()
		player.clip_finished.connect(_finished)
		player.clip_impact.connect(_animation_impact)
		rigs[perspective] = rig
		players[perspective] = player
	current = players[perspective]
	rigs[perspective].visible = true
	var dark_layer: CanvasLayer = rigs[perspective].get_node_or_null("KnightUltimateDarkLayer")
	if dark_layer != null:
		dark_layer.visible = true
	if edge_layers.has(perspective):
		edge_layers[perspective].visible = true
	current.set_process(true)
	if tile_size > 0.0:
		fit_tile(tile_size)

func _visible_bounds(rig: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	for child in rig.get_children():
		if not child is Sprite2D or child.texture == null:
			continue
		var sprite := child as Sprite2D
		var pixels := sprite.texture.get_image()
		if sprite.region_enabled:
			pixels = pixels.get_region(Rect2i(sprite.region_rect))
		var used := pixels.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var area := Rect2(sprite.get_rect().position + Vector2(used.position), Vector2(used.size))
		for corner in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
			var point: Vector2 = sprite.transform * corner
			if not found:
				bounds = Rect2(point, Vector2.ZERO)
				found = true
			else:
				bounds = bounds.expand(point)
	return bounds

func fit_tile(size_in_pixels: float) -> void:
	tile_size = size_in_pixels
	var canvas: Vector2 = rigs[facing].canvas_size
	var scale_val := tile_size / maxf(canvas.x, canvas.y)
	scale = Vector2.ONE * scale_val

func fit_display(area: Vector2) -> void:
	tile_size = 0.0
	var bounds: Rect2 = rest_bounds[facing]
	var factor := maxf(1.0, floorf(minf(area.x / maxf(bounds.size.x, 1.0), area.y / maxf(bounds.size.y, 1.0))))
	scale = Vector2.ONE * factor

func idle() -> void:
	queue_redraw()
	action_duration = 0.0
	teleport_progress = -1.0
	teleport_phase = 0
	for rig in rigs.values():
		rig.modulate = Color.WHITE
	if current != null:
		current.stop()
		current.dismiss_effect()
	active_clip = ""
	current.playback_speed = 1.0
	current.play("mage_idle" if kind == 0 else "archer_idle" if kind == 2 else "knight_idle")

func set_menu_walk(enabled: bool) -> void:
	if current == null:
		return
	for rig in rigs.values():
		var shadow: Node = rig.get_node_or_null("ShadowFX")
		if shadow != null:
			shadow.visible = false
	if enabled:
		current.set_process(true)
		current.playback_speed = 1.0
		current.play("mage_walk" if kind == 0 else "archer_walk" if kind == 2 else "knight_walk")
	else:
		current.set_process(false)

func set_menu_direction(direction: int) -> void:
	show_direction(direction)
	set_menu_walk(true)

func get_menu_shadow_offset() -> Vector2:
	var rig: ModularRig = rigs[facing]
	var shadow: Node = rig.get_node_or_null("ShadowFX")
	var shadow_center: Vector2
	if shadow != null:
		shadow_center = Vector2(rig.get_feet_centre().x, float(shadow.get("ground_y")))
	else:
		var bounds: Rect2 = rest_bounds[facing]
		shadow_center = Vector2(bounds.get_center().x, bounds.end.y)
	return scale * (rig.position + shadow_center)

func perform(action: int, direction: int, destination: Vector2, target: Vector2, duration: float) -> void:
	action_duration = 0.0
	teleport_progress = -1.0
	authored_impact = 0.0
	cast_target_local = target
	playing_action = action
	if beam != null:
		beam.set_playing(false)
	if motion != null and motion.is_valid():
		motion.kill()
	if current != null:
		current.stop()
		current.dismiss_effect()
	show_direction(direction if action < 0 or action == 5 else action if action > 0 else direction)
	if action == 5:
		teleport_destination = target
		teleport_moved = false
		action_elapsed = 0.0
		teleport_phase = 1
		active_clip = "mage_teleport"
		if kind == 0:
			current.playback_speed = 1.0
			current.play(active_clip)
			current.restore_effect()
			action_duration = current.get_duration()
			return
		teleport_progress = 0.0
		action_duration = TELEPORT_PHASE_DURATION
		current.playback_speed = 1.0
		current.play("archer_idle" if kind == 2 else "knight_idle")
		return
	var clip: String = ""
	if action >= 1 and action <= 4:
		clip = "mage_walk" if kind == 0 else "archer_walk" if kind == 2 else "knight_walk"
	elif action < 0:
		var names: Array
		if kind == 0:
			names = ["mage_fireball", "mage_energy_barrier", "mage_meteorite", "mage_cast"]
		elif kind == 2:
			names = ["archer_basic_attack", "archer_skill", "archer_strong_skill", "archer_charged_shot"]
		else:
			names = ["knight_slash", "knight_stab", "knight_plunge", "knight_ultimate", "knight_guard"]
		clip = names[-action - 1]
	if kind == 0:
		rigs[facing].cast_target = _parent_to_global(target)
		if action == -3:
			var explosion: ExplosionColumn = rigs[facing].get_node_or_null("ExplosionFX")
			if explosion != null:
				explosion.clip_rect = arena_clip if arena_clip.has_area() else Rect2(Vector2.ZERO, get_viewport_rect().size)
	if clip != "":
		active_clip = clip
		current.playback_speed = 1.0
		current.play(clip)
		current.restore_effect()
		action_elapsed = 0.0
		action_duration = current.get_duration()
		authored_impact = float(current.clip_data.get("impact", current.get_duration() * 0.5))
		impact_fraction = clampf(authored_impact / maxf(action_duration, 0.001), 0.0, 1.0)
	if action == 0:
		idle()
	elif action >= 1 and action <= 4:
		var travel_time := current.get_duration() if current != null else maxf(duration, 0.1)
		motion = create_tween()
		motion.tween_property(self, "position", destination, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.tween_callback(_finish_move)

func _finished(_clip: String) -> void:
	if playing_action == 5 and kind == 0:
		if teleport_phase == 1:
			position = teleport_destination
			teleport_moved = true
			teleport_phase = 2
			active_clip = "mage_teleport_reappear"
			current.playback_speed = 1.0
			current.play(active_clip)
			current.restore_effect()
			action_elapsed = 0.0
			action_duration = current.get_duration()
			return
		if teleport_phase == 2:
			teleport_phase = 0
			teleport_progress = -1.0
			idle()
			return
	call_deferred("idle")

func _parent_global_transform() -> Transform2D:
	var parent := get_parent()
	if parent is Node2D:
		return (parent as Node2D).get_global_transform()
	if parent is Control:
		return (parent as Control).get_global_transform()
	return Transform2D.IDENTITY

func _parent_to_global(point: Vector2) -> Vector2:
	return _parent_global_transform() * point

func _finish_move() -> void:
	idle()

func _animation_impact(clip: String) -> void:
	if kind == 2:
		_archer_impact(clip)
		_spawn_attack_impact()
		return
	if kind == 0 and playing_action == -4:
		_fire_beams()
	elif kind == 1 and playing_action < 0 and playing_action != -5:
		_spawn_attack_impact()

func _spawn_attack_impact() -> void:
	var point := global_position if playing_action == -2 or playing_action == -5 else _parent_to_global(cast_target_local)
	var tint := Color("ffd27a") if kind == 1 else Color("b9f2ff") if kind == 0 else Color("c7f28a")
	HitEffectClass.spawn_at(get_parent(), point, 0.46, 0.22, tint)

func _archer_impact(_clip: String) -> void:
	var rig: ModularRig = rigs[facing]
	var bow: Sprite2D = rig.get_piece("bow")
	if bow == null:
		push_error("Archer attack rig is missing its bow.")
		return
	var direction := _direction_vector(_direction_code(facing))
	var shot_scale := absf(scale.x)
	var host: Node = get_parent()
	var origin := get_archer_nock_global_position()
	var ground_y := rig.to_global(rig.get_feet_centre()).y
	if playing_action == -1:
		ArcherShot.fire_basic_attack(host, origin, direction, 1200.0, ground_y, shot_scale)
	elif playing_action == -2:
		var transform := _parent_global_transform()
		var tile_offset := (transform.x * direction.x + transform.y * direction.y) * 52.0
		var spread := direction.orthogonal() * 3.0 * shot_scale
		ArcherShot.fire_skill(host, origin - spread, direction, 1200.0, ground_y, shot_scale)
		ArcherShot.fire_skill(host, origin + tile_offset + spread, direction, 1200.0, ground_y, shot_scale)
	elif playing_action == -3:
		ArcherShot.fire_strong_skill(host, origin, direction, 1500.0, ground_y, shot_scale)
	elif playing_action == -4:
		ArcherShot.fire(host, origin, direction, 1500.0, ground_y, shot_scale)

func get_archer_nock_global_position() -> Vector2:
	if kind != 2 or not rigs.has(facing):
		return global_position
	var bow: Sprite2D = rigs[facing].get_piece("bow")
	if bow == null:
		return global_position
	var center := bow.to_global(bow.get_rect().get_center())
	var aim := _parent_global_transform().basis_xform(_direction_vector(_direction_code(facing))).normalized()
	return center - aim * 4.5 * absf(global_scale.x) * get_archer_draw_strength()

func get_archer_draw_strength() -> float:
	if kind != 2 or playing_action >= 0 or action_duration <= 0.0:
		return 0.0
	var release_time := get_action_impact_time()
	if release_time <= 0.0:
		return 0.0
	if action_elapsed <= release_time:
		return smoothstep(0.0, release_time, action_elapsed)
	return 1.0 - clampf((action_elapsed - release_time) / 0.08, 0.0, 1.0)

func _direction_code(perspective: String) -> int:
	return {"back": 1, "front": 2, "left": 3, "right": 4}[perspective]

func _direction_vector(direction: int) -> Vector2:
	return {1: Vector2.UP, 2: Vector2.DOWN, 3: Vector2.LEFT, 4: Vector2.RIGHT}.get(direction, Vector2.RIGHT)

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _fire_beams() -> void:
	if beam == null:
		beam = MageBeamBurst.new()
		beam.beam_scale = 0.15
		add_child(beam)
		beam.dim.dim_amount = 0.0
	beam.position = Vector2(0, -12)
	beam.fire()

func _add_edge(rig: ModularRig, perspective: String) -> void:
	var dark_layer := CanvasLayer.new()
	dark_layer.name = "KnightUltimateDarkLayer"
	dark_layer.layer = 100
	rig.add_child(dark_layer)
	var dark := ColorRect.new()
	dark.name = "KnightUltimateDark"
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dark_material := ShaderMaterial.new()
	dark_material.shader = load("res://assets/characters/Knight/Anim/KnightUltimate/knight_ultimate_dark.gdshader")
	dark.material = dark_material
	dark_layer.add_child(dark)

	var layer := CanvasLayer.new()
	layer.name = "KnightUltimateLayer"
	layer.layer = 101
	rig.add_child(layer)
	edge_layers[perspective] = layer
	var effect := ColorRect.new()
	effect.name = "KnightUltimateFX"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/characters/Knight/Anim/KnightUltimate/knight_ultimate_fire.gdshader")
	material.set_shader_parameter("flipbook", load("res://assets/characters/Knight/Anim/KnightUltimate/sprites/fire_slash.png"))
	material.set_shader_parameter("master_size", Vector2(1158, 740))
	material.set_shader_parameter("art_centre", Vector2(472.9, 294.77))
	material.set_shader_parameter("art_radius", 264.75)
	material.set_shader_parameter("art_mouth", Vector2(-0.939693, 0.34202))
	effect.material = material
	effect.set_script(load("res://assets/characters/Knight/Anim/KnightUltimate/knight_ultimate_fx.gd"))
	effect.set("rig_path", NodePath("../.."))
	effect.set("dark_path", NodePath("../../KnightUltimateDarkLayer/KnightUltimateDark"))
	effect.set("art_scale", 0.037469)
	effect.set("art_distance", 15.92)
	effect.set("drift_speed", Vector2(-14.0, -52.0))
	effect.set("mirror", -1.0 if perspective == "front" or perspective == "right" else 1.0)
	layer.add_child(effect)

func set_arena_clip(area: Rect2) -> void:
	arena_clip = area
	for rig in rigs.values():
		var explosion: Node = rig.get_node_or_null("ExplosionFX")
		if explosion != null:
			explosion.clip_rect = area

func react_to_hit(defeated: bool, knockback: Vector2, damaged: bool) -> void:
	if reaction != null and reaction.is_valid():
		reaction.kill()
	var tint := Color(1.0, 0.82, 0.28, 1.0) if damaged else Color(0.62, 1.0, 0.66, 1.0)
	HitEffectClass.spawn_at(get_parent(), global_position, 0.55, 0.28, tint)
	var home := position
	var recoil := knockback.normalized() * maxf(tile_size * 0.12, 3.0) if damaged else Vector2.UP * maxf(tile_size * 0.08, 2.0)
	var flash := Color(1.6, 0.72, 0.68, 1.0) if damaged else Color(0.72, 1.35, 0.82, 1.0)
	reaction = create_tween()
	reaction.tween_property(self, "modulate", flash, 0.035)
	reaction.tween_property(self, "position", home + recoil, 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reaction.parallel().tween_property(self, "modulate", Color(1.2, 0.88, 0.76, 1.0), 0.065)
	if defeated:
		reaction.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.18)
	else:
		reaction.tween_property(self, "position", home, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reaction.parallel().tween_property(self, "modulate", Color.WHITE, 0.14)
	if defeated:
		reaction.tween_callback(hide)

func reset_visual() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	if formation_motion != null and formation_motion.is_valid():
		formation_motion.kill()
	if reaction != null and reaction.is_valid():
		reaction.kill()
	modulate = Color.WHITE
	teleport_progress = -1.0
	teleport_phase = 0
	if beam != null:
		beam.set_playing(false)
	for rig in rigs.values():
		var dark_layer: CanvasLayer = rig.get_node_or_null("KnightUltimateDarkLayer")
		if dark_layer != null:
			dark_layer.visible = false
	for layer in edge_layers.values():
		layer.visible = false
	idle()

func is_action_playing() -> bool:
	return action_duration > 0.0 or (motion != null and motion.is_running()) or (formation_motion != null and formation_motion.is_running()) or (reaction != null and reaction.is_running()) or (beam != null and beam.is_playing())

func slide_to(destination: Vector2, duration: float) -> void:
	if formation_motion != null and formation_motion.is_valid():
		formation_motion.kill()
	if position.is_equal_approx(destination):
		return
	formation_motion = create_tween()
	formation_motion.tween_property(self, "position", destination, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func get_action_impact_time() -> float:
	if action_duration <= 0.0:
		return 0.0
	return authored_impact if authored_impact > 0.0 else action_duration * impact_fraction

func _process(delta: float) -> void:
	queue_redraw()
	_update_bowstring()
	if kind == 0 and rigs.has(facing) and cast_target_local != Vector2.INF:
		rigs[facing].cast_target = _parent_to_global(cast_target_local)
	if action_duration > 0.0:
		action_elapsed += delta
		var progress := action_elapsed / action_duration
		if playing_action == 5 and kind != 0:
			teleport_progress = clampf(progress, 0.0, 1.0)
			var opacity := 1.0 - teleport_progress if teleport_phase == 1 else teleport_progress
			rigs[facing].modulate = Color(1.0, 1.0, 1.0, opacity)
		if progress >= 1.0:
			if playing_action == 5 and kind != 0:
				if teleport_phase == 1:
					position = teleport_destination
					teleport_moved = true
					teleport_phase = 2
					active_clip = "mage_teleport_reappear"
					action_elapsed = 0.0
					action_duration = TELEPORT_PHASE_DURATION
					teleport_progress = 0.0
				else:
					idle()
			elif not (kind == 0 and playing_action == 5):
				idle()
	if beam != null and beam.is_playing():
		beam.anchor_to_gem(rigs[facing])

func _update_bowstring() -> void:
	if bowstring_upper == null or bowstring_lower == null:
		return
	var drawing := kind == 2 and rigs.has(facing) and action_duration > 0.0 and playing_action < 0
	bowstring_upper.visible = drawing
	bowstring_lower.visible = drawing
	if not drawing:
		return
	var bow: Sprite2D = rigs[facing].get_piece("bow")
	if bow == null:
		return
	var center := bow.to_global(bow.get_rect().get_center())
	var aim := _parent_global_transform().basis_xform(_direction_vector(_direction_code(facing))).normalized()
	var radius := 7.0 * absf(global_scale.x)
	var upper := to_local(center - aim.orthogonal() * radius)
	var lower := to_local(center + aim.orthogonal() * radius)
	var nock := to_local(get_archer_nock_global_position())
	bowstring_upper.points = PackedVector2Array([upper, nock])
	bowstring_lower.points = PackedVector2Array([nock, lower])

func _draw() -> void:
	if teleport_progress >= 0.0 and kind != 0:
		var progress := teleport_progress if teleport_phase == 1 else 1.0 - teleport_progress
		var bar_progress := progress / 0.7 if progress <= 0.7 else (1.0 - progress) / 0.3
		var half_width := lerpf(0.5, 16.0, clampf(bar_progress, 0.0, 1.0))
		var offset := lerpf(16.0, 0.0, progress)
		var tint := Color(0.72, 0.93, 1.0, 0.9)
		for y in [-offset, offset]:
			draw_line(Vector2(-half_width, y), Vector2(half_width, y), tint, 2.0, true)
	if kind != 1 or action_duration <= 0.0 or playing_action >= 0 or playing_action == -5 or playing_action == -4:
		return
	var phase := action_elapsed / action_duration - impact_fraction
	if phase < -0.08 or phase > 0.16:
		return
	var strength := clampf(1.0 - absf(phase) / 0.16, 0.0, 1.0)
	var direction: Vector2 = {"front": Vector2.DOWN, "back": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[facing]
	var angle := direction.angle()
	var tint := Color(1.0, 0.86, 0.62, strength)
	if playing_action == -2:
		var tip := direction * (19.0 + phase * 32.0)
		draw_line((direction * 8.0).round(), tip.round(), tint, 2.0)
		draw_line(tip.round(), (tip - direction.rotated(0.6) * 5.0).round(), tint, 1.0)
	elif playing_action == -3:
		var ground_y := roundf(tile_size * 0.32)
		var reach := 7.0 + clampf(phase, 0.0, 0.16) * 90.0
		draw_line(Vector2(-reach, ground_y), Vector2(reach, ground_y), tint, 2.0)
		draw_line(Vector2(-reach * 0.65, ground_y + 3.0), Vector2(reach * 0.65, ground_y + 3.0), Color(tint, strength * 0.7), 1.0)
	else:
		var radius := 17.0
		var sweep := 1.1
		for i in range(9):
			var a := angle - sweep + float(i) * sweep / 4.5
			var b := angle - sweep + float(i + 1) * sweep / 4.5
			draw_line((Vector2.from_angle(a) * radius).round(), (Vector2.from_angle(b) * radius).round(), tint, 2.0)
	if phase >= 0.0:
		for i in range(4):
			var ray := direction.rotated(float(i) * 0.8 - 1.2)
			var point := direction * 14.0 + ray * (4.0 + phase * 45.0)
			draw_rect(Rect2(point.round(), Vector2.ONE * 2.0), Color(1.0, 0.96, 0.85, strength))
