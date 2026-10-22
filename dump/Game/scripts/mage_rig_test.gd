extends Node2D

## Development harness for the modular Mage rig and choreography clips.
##
## Renders every perspective side by side at a few interesting moments so the
## clips can be eyeballed against the art:
##   row 0 - the authored rest pose
##   row 1 - the cast clip at its peak
##   row 2 - the idle clip at the top of the breath
##
## Run with:  godot --path . res://scenes/MageRigTest.tscn

const SAVE_PATH := "user://mage_rig_test.png"
const PERSPECTIVES := ["front", "back", "left", "right"]
const COL_W := 210
const ROW_H := 230

var rows: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_add_row("REST POSE", "")
	_add_row("CAST CLIP - PEAK", "mage_cast", 0.35 / 0.9)
	_add_row("IDLE CLIP - BREATH PEAK", "mage_idle", 0.5)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	if img:
		img.save_png(SAVE_PATH)
		print("Saved rig test to: ", ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().quit(0)


## Builds one row of four mages. With no clip the row stays at the rest pose,
## otherwise every player in the row is scrubbed to the same progress.
func _add_row(title: String, clip_name: String, progress: float = 0.0) -> void:
	var row_index := rows.size()
	var players: Array[MageChoreoPlayer] = []
	for col in range(PERSPECTIVES.size()):
		var mage: MageModularBase = ModularMageUtility.instantiate_mage(PERSPECTIVES[col])
		mage.scale = Vector2(5, 5)
		mage.position = Vector2(COL_W * col + 60, 40 + row_index * ROW_H)
		add_child(mage)

		var player := MageChoreoPlayer.new()
		player.target = mage
		add_child(player)
		players.append(player)
	rows.append(players)

	var label := Label.new()
	label.text = title
	label.position = Vector2(20, 40 + row_index * ROW_H + 150)
	add_child(label)

	# the player's own _ready has already run (it is added to a live tree), so
	# the rig is cached and the clip can be scrubbed right away
	if clip_name != "":
		for p in players:
			p.load_clip(clip_name)
			p.scrub(progress)
