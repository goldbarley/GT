extends ChoreoPlayer
class_name KnightChoreoPlayer

## The Knight's clip player.  The work is all in the shared ChoreoPlayer, this
## is here so the Knight has its own clips and its own name.

## Where the Knight's clips live.
const CLIPS_DIRECTORY := "res://assets/characters/Knight/Anim/clips"


func _init() -> void:
	clips_directory = CLIPS_DIRECTORY


func _ready() -> void:
	# the export may have put the Mage's directory back, so it is set again
	clips_directory = CLIPS_DIRECTORY
	super._ready()
