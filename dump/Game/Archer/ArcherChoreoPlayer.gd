extends ChoreoPlayer
class_name ArcherChoreoPlayer

## The Archer's clip player.  The work is all in the shared ChoreoPlayer, this
## is here so the name the Archer's own code has always used keeps working.

func _init() -> void:
	clips_directory = "res://Archer/anim/clips"
