extends Node2D

var kind: int = 0
var rigs: Dictionary = {}
var players: Dictionary = {}
var facing: String = "front"
var current: ChoreoPlayer
var motion: Tween
var active_clip: String = ""
var beam: MageBeamBurst
var edge_layers: Dictionary = {}
var tile_size: float = 0.0
var rest_bounds: Dictionary = {}
var cast_target_local := Vector2.INF
var action_elapsed := 0.0
var action_duration := 0.0
var authored_impact := 0.0
var impact_fraction := 0.58
var playing_action := 0
var reaction: Tween
var beam_started := false
var arena_clip := Rect2()

func configure(character_class: int) -> void:
	kind = character_class
	if current != null:
		current.stop()
		current.dismiss_effect()
	show_direction(2)
	idle()

func show_direction(direction: int) -> void:
	var perspective: String = ["front", "back", "front", "left", "right"][direction]
	if current != null:
		current.stop()
	for rig in rigs.values():
		rig.visible = false
		# Hide dark layer too
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
		player.clips_directory = "res://assets/characters/Mage/anim/clips" if kind == 0 else "res://assets/characters/Knight/Anim/clips"
		add_child(player)
		player.clip_finished.connect(_finished)
		rigs[perspective] = rig
		players[perspective] = player
	current = players[perspective]
	rigs[perspective].visible = true
	# Show dark layer for this perspective
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

func idle() -> void:
	queue_redraw()
	action_duration = 0.0
	if current != null:
		current.stop()
		current.dismiss_effect()
	active_clip = ""
	current.playback_speed = 1.0
	current.play("mage_idle" if kind == 0 else "knight_idle")

func perform(action: int, direction: int, destination: Vector2, target: Vector2, duration: float) -> void:
	action_duration = 0.0
	cast_target_local = target
	playing_action = action
	beam_started = false
	if beam != null:
		beam.set_playing(false)
	if motion != null and motion.is_valid():
		motion.kill()
	if current != null:
		current.stop()
		current.dismiss_effect()
	show_direction(direction if action < 0 or action == 5 else action if action > 0 else direction)
	var clip: String = ""
	if action >= 1 and action <= 4:
		clip = "mage_walk" if kind == 0 else "knight_walk"
	elif action == 5:
		clip = "mage_teleport_reappear" if kind == 0 else "knight_walk"
	elif action < 0:
		var names: Array = ["mage_fireball", "mage_energy_barrier", "mage_meteorite", "mage_cast"] if kind == 0 else ["knight_slash", "knight_stab", "knight_plunge", "knight_ultimate", "knight_guard"]
		clip = names[-action - 1]
	if kind == 0:
		rigs[facing].cast_target = get_parent().get_global_transform() * target
		if action == -3:
			var explosion: ExplosionColumn = rigs[facing].get_node_or_null("ExplosionFX")
			if explosion != null:
				explosion.clip_rect = arena_clip if arena_clip.has_area() else Rect2(Vector2.ZERO, get_viewport_rect().size)
				explosion.fps = 100.0
	if clip != "":
		active_clip = clip
		current.play(clip)
		current.restore_effect()
		if action < 0:
			action_elapsed = 0.0
			action_duration = maxf(duration, 0.1)
			impact_fraction = 0.20 if (kind == 0 and action == -2) or (kind == 1 and action == -5) else 0.58
			authored_impact = float(current.clip_data.get("impact", current.get_duration() * 0.5))
			current.scrub_time(0.0)
		elif action == 5:
			current.playback_speed = current.get_duration() / maxf(duration * 0.85, 0.1)
	var travel_time := duration * 0.38 if action >= 1 and action <= 4 else duration * 0.35
	if action >= 1 and action <= 4:
		current.playback_speed = current._duration / maxf(travel_time, 0.1)
	if action == 0:
		idle()
	motion = create_tween()
	motion.tween_property(self, "position", destination, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if action >= 1 and action <= 4:
		motion.tween_callback(idle)

func _finished(_clip: String) -> void:
	call_deferred("idle")

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _fire_beams(duration: float) -> void:
	if beam == null:
		beam = MageBeamBurst.new()
		beam.beam_scale = 0.15
		beam.fps = 160.0
		add_child(beam)
		beam.dim.dim_amount = 0.0
	beam.position = Vector2(0, -12)
	beam.fire()
	get_tree().create_timer(duration * 0.9, false).timeout.connect(func():
		if is_instance_valid(beam):
			beam.set_playing(false)
	)

func _add_edge(rig: ModularRig, perspective: String) -> void:
	# Dark layer (underneath) - blacks out the screen
	var dark_layer := CanvasLayer.new()
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

	# Fire layer (on top) - the fire sweep
	var fire_layer := CanvasLayer.new()
	fire_layer.layer = 101
	rig.add_child(fire_layer)
	edge_layers[perspective] = fire_layer
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
	fire_layer.add_child(effect)

func set_arena_clip(area: Rect2) -> void:
	arena_clip = area
	for layer in edge_layers.values():
		var material: ShaderMaterial = layer.get_child(0).material
		material.set_shader_parameter("arena_origin", area.position)
		material.set_shader_parameter("arena_size", area.size)
		# Also pass to dark layer
		var dark_layer: CanvasLayer = rigs[facing].get_node_or_null("KnightUltimateDarkLayer")
		if dark_layer != null:
			var dark: ColorRect = dark_layer.get_node_or_null("KnightUltimateDark")
			if dark != null and dark.material is ShaderMaterial:
				(dark.material as ShaderMaterial).set_shader_parameter("arena_origin", area.position)
				(dark.material as ShaderMaterial).set_shader_parameter("arena_size", area.size)
	for rig in rigs.values():
		var explosion: Node = rig.get_node_or_null("ExplosionFX")
		if explosion != null:
			explosion.clip_rect = area
		var effect: Node = rig.get_node_or_null("KnightUltimateFX")
		if effect != null:
			effect.set("arena_origin", area.position)
			effect.set("arena_size", area.size)

func react_to_hit(defeated: bool) -> void:
	if reaction != null and reaction.is_valid():
		reaction.kill()
	modulate = Color(1.6, 0.75, 0.75, 1.0)
	reaction = create_tween()
	reaction.tween_property(self, "modulate", Color(1, 1, 1, 0) if defeated else Color.WHITE, 0.24)
	if defeated:
		reaction.tween_callback(hide)

func reset_visual() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	if reaction != null and reaction.is_valid():
		reaction.kill()
	modulate = Color.WHITE
	if beam != null:
		beam.set_playing(false)
	# Hide ultimate effect layers
	for rig in rigs.values():
		var dark_layer: CanvasLayer = rig.get_node_or_null("KnightUltimateDarkLayer")
		if dark_layer != null:
			dark_layer.visible = false
	for layer in edge_layers.values():
		layer.visible = false
	idle()

func _process(delta: float) -> void:
	queue_redraw()
	if kind == 0 and rigs.has(facing) and cast_target_local != Vector2.INF:
		rigs[facing].cast_target = get_parent().get_global_transform() * cast_target_local
	if action_duration > 0.0:
		action_elapsed += delta
		var progress := action_elapsed / action_duration
		var time: float
		if progress < impact_fraction:
			time = authored_impact * progress / impact_fraction
		else:
			var recovery_start := impact_fraction + (0.04 if kind == 1 else 0.0)
			time = lerpf(authored_impact, current.get_duration(), clampf((progress - recovery_start) / (0.94 - recovery_start), 0.0, 1.0))
		current.scrub_time(time)
		if kind == 0 and playing_action == -4 and progress >= impact_fraction and not beam_started:
			beam_started = true
			_fire_beams(action_duration * 0.3)
		if progress >= 0.94:
			idle()
	if beam != null and beam.is_playing():
		beam.anchor_to_gem(rigs[facing])

func _draw() -> void:
	if kind != 1 or action_duration <= 0.0 or playing_action >= 0 or playing_action == -5:
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
	else:
		var radius := 17.0 if playing_action == -1 else 22.0
		var sweep := 1.1 if playing_action == -1 else 2.4
		for i in range(9):
			var a := angle - sweep + float(i) * sweep / 4.5
			var b := angle - sweep + float(i + 1) * sweep / 4.5
			draw_line((Vector2.from_angle(a) * radius).round(), (Vector2.from_angle(b) * radius).round(), tint, 2.0)
	if phase >= 0.0:
		for i in range(4):
			var ray := direction.rotated(float(i) * 0.8 - 1.2)
			var point := direction * 14.0 + ray * (4.0 + phase * 45.0)
			draw_rect(Rect2(point.round(), Vector2.ONE * 2.0), Color(1.0, 0.96, 0.85, strength))
