class_name KnightController
extends CharacterController

## The Knight's controller: four rigs, one per perspective, each with its own
## player, all of them sitting on the shared CharacterController.
##
## The rig's own origin is on the ground, where the knight's feet are, so
## nothing has to be moved into place: the controller only has to say which
## rig is on show and which clip is playing.

const RIG_SCENES := {
	"front": "res://Knight/Knight_front/KnightFront.tscn",
	"back": "res://Knight/Knight_back/KnightBack.tscn",
	"left": "res://Knight/Knight_left/KnightLeft.tscn",
	"right": "res://Knight/Knight_right/KnightRight.tscn",
}

const PERSPECTIVES := ["front", "back", "left", "right"]


func _init() -> void:
	idle_action = KnightAnims.IDLE
	walk_action = KnightAnims.WALK


func _build() -> void:
	for perspective in PERSPECTIVES:
		var scene := load(RIG_SCENES[perspective]) as PackedScene
		if scene == null:
			push_error("KnightController: cannot load " + RIG_SCENES[perspective])
			continue
		var rig := scene.instantiate()
		add_child(rig)
		rigs[perspective] = rig

		var player := KnightChoreoPlayer.new()
		player.target = rig
		add_child(player)
		players[perspective] = player
