extends Node2D

## Renders a clip as a sequence of frames so the motion can be reviewed.
##
## The clip is stepped by hand in fixed time steps, so the result is exactly what
## the player would show at that frame rate.
##
##   godot --path . res://scenes/MageAnimCapture.tscn -- clip=mage_fireball \
##       perspective=right frames=24 fps=12

@export var clip_name: String = "mage_fireball"
@export var perspective: String = "right"
@export var frame_count: int = 24
@export var fps: float = 12.0
@export var zoom: int = 4
@export var out_dir: String = "user://anim_frames"

var _mage: MageModularBase
var _player: MageChoreoPlayer
var _vp: SubViewport


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("clip="):
			clip_name = arg.substr(5)
		elif arg.begins_with("perspective="):
			perspective = arg.substr(12)
		elif arg.begins_with("frames="):
			frame_count = int(arg.substr(7))
		elif arg.begins_with("fps="):
			fps = float(arg.substr(4))
	DirAccess.make_dir_recursive_absolute(out_dir)

	_vp = SubViewport.new()
	_vp.size = Vector2i(38, 32)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	_mage = ModularMageUtility.instantiate_mage(perspective)
	_mage.scale = Vector2.ONE
	_vp.add_child(_mage)
	_mage._ready()

	_player = MageChoreoPlayer.new()
	_player.target = _mage
	add_child(_player)
	_player._ready()
	_player.load_clip(clip_name)

	var duration: float = _player.get_duration()
	for i in range(frame_count):
		# step at a fixed rate, so the frames show what the player would show
		var t: float = float(i) / max(fps, 1.0)
		if t > duration:
			t = duration
		_player.scrub_time(t)
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png("%s/%s_%s_%03d.png" % [out_dir, clip_name, perspective, i])
	print("Saved %d frames to %s" % [frame_count, ProjectSettings.globalize_path(out_dir)])
	get_tree().quit(0)
