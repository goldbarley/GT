extends Node2D

## A bench for checking the modular Archer rig.
##
## All four perspectives stand side by side, each with a button for every
## piece underneath it.  Press a piece's button to pick it, and the piece can
## then be turned about its pivot with the slider, or set spinning to watch it
## swing.  The pivot itself is marked with a dot, so a pivot that is in the
## wrong place is obvious at a glance.
##
## Run with:  godot --path . res://scenes/ArcherRigTest.tscn

const PERSPECTIVES := ["front", "back", "left", "right"]
const SCALE := 6.0
const COL_W := 300.0
const GROUND_Y := 460.0
const BUTTON_W := 116.0
const MARKER_SIZE := 7

var rigs: Array[ArcherModularBase] = []
## pieces[rig][piece name] = the Sprite2D of that piece
var pieces: Array = []
## markers[rig][piece name] = the dot that shows where the pivot is
var markers: Array = []
## buttons[rig][piece name] = the button that picks that piece
var buttons: Array = []

var selected_rig: int = -1
var selected_piece: String = ""
var angle: float = 0.0
var spinning: bool = false
var show_all_pivots: bool = false

var _label: Label
var _slider: HSlider
var _spin_button: Button
var _marker_texture: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_marker_texture = _make_marker_texture()
	_build_rigs()
	_build_ui()
	_maybe_screenshot()
	if OS.get_cmdline_user_args().has("--check"):
		_print_report()
		get_tree().quit(0)
	if OS.get_cmdline_user_args().has("--clips"):
		_check_clips()


## Plays the idle and the walk clip on a real controller and reports what the
## rig ended up doing, so the clips can be checked without a window.
func _check_clips() -> void:
	var controller := ArcherController.new()
	add_child(controller)
	await get_tree().process_frame

	for clip in [ArcherAnims.IDLE, ArcherAnims.WALK]:
		controller.play_action(clip)
		await get_tree().process_frame
		# the clip is scrubbed a little way in, so the poses have moved
		for perspective in ["front", "back", "left", "right"]:
			var p: ChoreoPlayer = controller.players[perspective]
			p.scrub(0.3, true)
		print("== %s" % clip)
		for perspective in ["front", "back", "left", "right"]:
			var rig: Node2D = controller.rigs[perspective]
			var player: ChoreoPlayer = controller.players[perspective]
			var moved := []
			for child in rig.get_children():
				if child is Sprite2D:
					var sprite := child as Sprite2D
					if absf(sprite.rotation) > 0.01:
						moved.append("%s %.1f deg" % [sprite.name, rad_to_deg(sprite.rotation)])
			print("   %-6s playing %-14s  moved: %s" % [
				perspective, player.current_clip, ", ".join(moved)])
		controller.stop_action()
		await get_tree().process_frame
	get_tree().quit(0)


## Prints what the rig actually ended up as, so it can be compared with the
## data the tool wrote.
func _print_report() -> void:
	for i in range(rigs.size()):
		var rig := rigs[i]
		print("== %s   canvas %s   feet at %s" % [
			PERSPECTIVES[i], str(rig.canvas_size), str(rig.get_feet_centre())])
		for child in rig.get_children():
			if child is Sprite2D:
				var sprite := child as Sprite2D
				var pivot: Vector2 = sprite.get_meta("pivot", Vector2.ZERO)
				var art := sprite.position - pivot
				print("   %-10s art at (%5.1f,%5.1f)  pivot at (%5.1f,%5.1f)" % [
					sprite.name, art.x, art.y, sprite.position.x, sprite.position.y])


## Saves a picture of the bench and quits, when the scene is run with
## `--shot`.  Useful for checking the rig without a window.
func _maybe_screenshot() -> void:
	if not OS.get_cmdline_user_args().has("--shot"):
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "user://archer_rig_test.png"
		img.save_png(path)
		print("Saved rig test to: ", ProjectSettings.globalize_path(path))
	get_tree().quit(0)


# --------------------------------------------------------------------------- #
# the rigs
# --------------------------------------------------------------------------- #
func _build_rigs() -> void:
	for i in range(PERSPECTIVES.size()):
		var rig := ModularArcherUtility.instantiate_archer(PERSPECTIVES[i])
		if rig == null:
			continue
		rig.scale = Vector2(SCALE, SCALE)
		add_child(rig)
		# The rig's own origin is the top of the archer's head, so the rig is
		# dropped until her feet are on the ground line.
		rig.position = Vector2(COL_W * i + 150.0, GROUND_Y - rig.get_feet_centre().y * SCALE)
		rigs.append(rig)

		var rig_pieces := {}
		var rig_markers := {}
		for child in rig.get_children():
			if child is Sprite2D:
				var sprite := child as Sprite2D
				rig_pieces[sprite.name] = sprite
				var marker := Sprite2D.new()
				marker.texture = _marker_texture
				marker.visible = false
				add_child(marker)
				rig_markers[sprite.name] = marker
		pieces.append(rig_pieces)
		markers.append(rig_markers)


# --------------------------------------------------------------------------- #
# the controls
# --------------------------------------------------------------------------- #
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# --- the bar across the top -------------------------------------------
	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	_label = Label.new()
	_label.text = "no piece picked"
	_label.custom_minimum_size = Vector2(420, 0)
	top.add_child(_label)

	_slider = HSlider.new()
	_slider.min_value = -180.0
	_slider.max_value = 180.0
	_slider.step = 1.0
	_slider.custom_minimum_size = Vector2(320, 0)
	_slider.value_changed.connect(_on_slider_changed)
	top.add_child(_slider)

	_spin_button = Button.new()
	_spin_button.text = "spin"
	_spin_button.toggle_mode = true
	_spin_button.toggled.connect(func(on: bool) -> void:
		spinning = on
		if on:
			_slider.set_value_no_signal(0.0)
			angle = 0.0
	)
	top.add_child(_spin_button)

	var reset_button := Button.new()
	reset_button.text = "reset all"
	reset_button.pressed.connect(_reset_all)
	top.add_child(reset_button)

	var show_button := Button.new()
	show_button.text = "show pivots"
	show_button.toggle_mode = true
	show_button.toggled.connect(func(on: bool) -> void:
		show_all_pivots = on
	)
	top.add_child(show_button)

	# --- one column of buttons under each rig ------------------------------
	for i in range(rigs.size()):
		var column := VBoxContainer.new()
		column.position = Vector2(COL_W * i + 150.0 - BUTTON_W * 0.5, GROUND_Y + 40.0)
		column.add_theme_constant_override("separation", 2)
		root.add_child(column)

		var title := Label.new()
		title.text = PERSPECTIVES[i]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(title)

		var rig_buttons := {}
		for piece_name in pieces[i].keys():
			var button := Button.new()
			button.text = piece_name
			button.custom_minimum_size = Vector2(BUTTON_W, 22)
			button.toggle_mode = true
			button.pressed.connect(_select_piece.bind(i, piece_name))
			column.add_child(button)
			rig_buttons[piece_name] = button
		buttons.append(rig_buttons)


func _select_piece(rig_index: int, piece_name: String) -> void:
	selected_rig = rig_index
	selected_piece = piece_name
	angle = 0.0
	spinning = false
	if _spin_button:
		_spin_button.set_pressed_no_signal(false)
	if _slider:
		_slider.set_value_no_signal(0.0)
	for i in range(buttons.size()):
		for key in buttons[i].keys():
			buttons[i][key].set_pressed_no_signal(i == rig_index and key == piece_name)
	_label.text = "%s / %s" % [PERSPECTIVES[rig_index], piece_name]


func _on_slider_changed(value: float) -> void:
	angle = deg_to_rad(value)
	if _selected_sprite():
		_selected_sprite().rotation = angle


func _reset_all() -> void:
	angle = 0.0
	for rig_pieces in pieces:
		for key in rig_pieces.keys():
			rig_pieces[key].rotation = 0.0
	if _slider:
		_slider.set_value_no_signal(0.0)


func _selected_sprite() -> Sprite2D:
	if selected_rig < 0 or selected_rig >= pieces.size():
		return null
	return pieces[selected_rig].get(selected_piece, null)


# --------------------------------------------------------------------------- #
# every frame
# --------------------------------------------------------------------------- #
func _process(delta: float) -> void:
	if spinning:
		angle = wrapf(angle + delta * 1.2, -PI, PI)
		var sprite := _selected_sprite()
		if sprite:
			sprite.rotation = angle
			if _slider:
				_slider.set_value_no_signal(rad_to_deg(angle))

	# keep the pivot dots on their pivots
	for i in range(markers.size()):
		for key in markers[i].keys():
			var marker := markers[i][key] as Sprite2D
			var sprite := pieces[i][key] as Sprite2D
			marker.position = sprite.global_position
			marker.visible = show_all_pivots or (i == selected_rig and key == selected_piece)


# --------------------------------------------------------------------------- #
# the dot that marks a pivot
# --------------------------------------------------------------------------- #
func _make_marker_texture() -> ImageTexture:
	var size := MARKER_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var mid := (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - mid, y - mid).length()
			if d <= mid:
				# a ring with a bright core, so it reads over any art
				var a := 1.0 if d <= mid - 1.5 else 0.85
				image.set_pixel(x, y, Color(1.0, 0.25, 0.15, a))
	return ImageTexture.create_from_image(image)
