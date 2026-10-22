extends Area2D
class_name ArrowProjectile

@export var speed: float = 320.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 1.8

func _ready() -> void:
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
