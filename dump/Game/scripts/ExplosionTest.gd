extends Node2D

## Shows the pillar of fire on the sky island map.

@onready var explosion: ExplosionColumn = $Explosion


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	explosion.fire()
