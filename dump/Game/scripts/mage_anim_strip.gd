extends Node2D

## Filmstrip renderer for modular Mage clips.
##
## Renders a clip as a grid of frames so the motion can be reviewed frame by
## frame. The exported properties are meant to be tweaked in the inspector or
## overridden from the command line with
## `godot --path . res://scenes/MageAnimStrip.tscn -- clip=mage_teleport`.
##
## The strip is drawn into its own viewport, so the saved picture always comes
## out the same size no matter what the window happens to be.

@export var clip_name: String = "mage_idle"
@export var perspective: String = "front"
@export var frame_count: int = 6
@export var zoom: int = 5
@export var columns: int = 3
## How much room to leave above the character, in character pixels, for
## effects that come down from off the top of the screen.
@export var headroom: int = 30
## Where in the clip to start showing frames, as a fraction of the length.
@export var start_fraction: float = 0.0
@export var render_size: Vector2i = Vector2i(1400, 1000)
@export var save_path: String = "user://mage_anim_strip.png"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# allow `godot ... -- clip=mage_cast perspective=right` style overrides
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("clip="):
			clip_name = arg.substr(5)
		elif arg.begins_with("perspective="):
			perspective = arg.substr(12)
		elif arg.begins_with("frames="):
			frame_count = int(arg.substr(7))
		elif arg.begins_with("head="):
			headroom = int(arg.substr(5))
		elif arg.begins_with("zoom="):
			zoom = int(arg.substr(5))
		elif arg.begins_with("start="):
			start_fraction = float(arg.substr(6))
		elif arg.begins_with("size="):
			var parts := arg.substr(5).split("x")
			if parts.size() == 2:
				render_size = Vector2i(int(parts[0]), int(parts[1]))

	# the strip is drawn in its own viewport, so the picture is a fixed size
	var viewport := SubViewport.new()
	viewport.size = render_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	var sheet := Node2D.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sheet)

	# leave headroom above the character so effects that fly in are visible
	var cell_w := 38 * zoom + 12
	var head := headroom * zoom
	var cell_h := 32 * zoom + 22 + head

	for i in range(frame_count):
		var row := i / columns
		var col := i % columns
		var mage: MageModularBase = ModularMageUtility.instantiate_mage(perspective)
		mage.scale = Vector2(zoom, zoom)
		mage.position = Vector2(col * cell_w + 40, row * cell_h + head + 40)
		sheet.add_child(mage)

		var player := MageChoreoPlayer.new()
		player.target = mage
		sheet.add_child(player)
		player.load_clip(clip_name)

		# spread the samples evenly over the clip
		var t := 0.0
		if frame_count > 1:
			t = (start_fraction + (1.0 - start_fraction) * float(i) / float(frame_count - 1)) * 0.999
		player.scrub(t)

		var label := Label.new()
		label.text = "%s  %.2fs" % [perspective, t * player.get_duration()]
		label.position = mage.position + Vector2(0, 32 * zoom + 4)
		sheet.add_child(label)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = viewport.get_texture().get_image()
	if img:
		img.save_png(save_path)
		print("Saved anim strip to: ", ProjectSettings.globalize_path(save_path))
	get_tree().quit(0)
