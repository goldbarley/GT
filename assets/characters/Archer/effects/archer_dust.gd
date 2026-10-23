class_name ArcherDust
extends CPUParticles2D

## The dust the archer kicks up behind herself when the shot goes.
##
## The beam shoves her back, and this is the dust she drags along with her.

func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	emitting = true
	# the dust hangs there and fades
	var tween := create_tween()
	tween.tween_interval(lifetime)
	tween.tween_callback(queue_free)
