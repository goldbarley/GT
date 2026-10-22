extends Node2D

## Checks the Archer's charged shot.
##
## Plays the godray charge on a real controller and reports what happened:
## the archer leans in and braces, the charge effect is driven through its
## stages, the clip fires its impact at the right moment, and the beam, the
## burst and the tear are put into the world.
##
## Run with:  godot --headless --path . res://scenes/ArcherShotCheck.tscn

const STAGES := ["gather", "spiral", "focus", "energy_bow", "arrow", "flash"]

var controller: ArcherController
var rig: ArcherModularBase

var _rest_bow := Vector2.ZERO
var _rest_body := Vector2.ZERO
var _max_bow := Vector2.ZERO
var _max_body := Vector2.ZERO
var _impact_fired := false
var _impact_time := -1.0
var _effect_seen := {}
var _shots := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	controller = ArcherController.new()
	controller.scale = Vector2(5, 5)
	add_child(controller)
	await get_tree().process_frame

	rig = controller.active_rig
	_rest_bow = rig.get_piece("bow").position
	_rest_body = rig.get_piece("body").position
	controller.action_impact.connect(_on_impact)

	controller.play_charged_shot(Vector2.RIGHT)
	_run()


func _run() -> void:
	var start := Time.get_ticks_msec()
	var elapsed := 0.0
	for i in range(600):
		await get_tree().process_frame
		elapsed = float(Time.get_ticks_msec() - start) / 1000.0
		if rig == null:
			continue
		var bow := rig.get_piece("bow")
		var body := rig.get_piece("body")
		if bow:
			_max_bow = _max_bow.max((bow.position - _rest_bow).abs())
		if body:
			_max_body = _max_body.max((body.position - _rest_body).abs())
		_read_effect()
		if _impact_fired and _impact_time < 0.0:
			_impact_time = elapsed
			break

	print("== charged shot")
	print("   the bow moves up to %5.2f px, the body up to %4.2f px" % [
		maxf(_max_bow.x, _max_bow.y), maxf(_max_body.x, _max_body.y)])
	for stage in STAGES:
		print("   the effect reached %-10s %s" % [stage, "yes" if _effect_seen.get(stage, false) else "NO"])
	print("   the impact fired at %.2f s" % _impact_time)

	# what the rig looks like at full draw
	var player: ArcherChoreoPlayer = controller.players["right"]
	player.scrub(1.8 / 2.5833, true)
	await get_tree().process_frame
	for name in ["arm", "bow", "body", "cape"]:
		var piece := rig.get_piece(name)
		if piece:
			print("   at full draw %-5s rotation %7.2f deg" % [
				name, rad_to_deg(piece.rotation)])
	for name in ["arm", "bow", "body"]:
		var piece := rig.get_piece(name)
		if piece:
			print("   %-5s rotation %7.2f deg   position %s" % [
				name, rad_to_deg(piece.rotation), str(piece.position)])
	for child in get_children():
		if child is ArcherBeam:
			var beam := child as ArcherBeam
			var rect := beam.get_node_or_null("Beam") as ColorRect
			print("   the beam is at %s  size %s  visible %s" % [
				str(beam.global_position), str(rect.size) if rect else "-",
				str(rect.visible) if rect else "-"])
			if rect:
				var mat := rect.material as ShaderMaterial
				if mat:
					var tail_x := float(mat.get_shader_parameter("tail_x"))
					var head: Vector2 = beam.global_position
					var tail: Vector2 = head - beam.direction * ((1.0 - tail_x) * 1200.0)
					var grip: Vector2 = rig.get_piece("bow").global_position
					print("   the controller's rig is %s, the check's rig is %s" % [
						str(controller.active_rig.name), str(rig.name)])
					print("   the bow on the controller's rig is at %s" % [
						str(controller.active_rig.get_piece("bow").global_position)])
					print("   the beam: the node is at %s  the origin is %s" % [
						str(beam.global_position), str(beam.origin_point)])
					print("   the head is at %.1f, the tail is at %.1f, the bow was at %.1f  %s" % [
						head.x, tail.x, beam.origin_point.x,
						"forward" if tail.x >= beam.origin_point.x - 1.0 else "BACKWARD"])
	var fx := _godray()
	if fx:
		var mat := fx.material as ShaderMaterial
		var art: Variant = mat.get_shader_parameter("energy_tex") if mat else null
		print("   GodrayFX: visible %s  size %s  material %s" % [
			str(fx.visible), str(fx.size), str(fx.material)])
		print("   the energy bow art on the shader: %s" % [
			"a texture" if art is Texture2D else "NOT SET (%s)" % str(art)])
		var bow := rig.get_piece("bow")
		print("   the bow is at %s, the grip is its own origin" % str(bow.global_position))
	_count_shot()
	get_tree().quit(0)


## Reads the godray shader's parameters, so the stages it goes through can be
## seen.
func _read_effect() -> void:
	var fx := _godray()
	if fx == null:
		return
	var material := fx.material as ShaderMaterial
	if material == null:
		return
	for stage in STAGES:
		var value := float(material.get_shader_parameter(stage))
		if value > 0.5:
			_effect_seen[stage] = true


func _godray() -> ColorRect:
	if rig == null:
		return null
	var bow := rig.get_piece("bow")
	if bow == null:
		return null
	return bow.get_node_or_null("GodrayFX") as ColorRect


func _on_impact(action_name: String) -> void:
	if action_name == ArcherAnims.CHARGED_SHOT:
		_impact_fired = true


func _count_shot() -> void:
	var beams := 0
	var bursts := 0
	var tears := 0
	for child in get_children():
		if child is ArcherBeam:
			beams += 1
		elif child is ArrowShockwave:
			bursts += 1
		elif child is GroundTear:
			tears += 1
	print("   beam %d, burst %d, tear %d" % [beams, bursts, tears])
	_shots = beams + bursts + tears
