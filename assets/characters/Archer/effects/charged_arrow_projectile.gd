extends Area2D
class_name ChargedArrowProjectile

const GroundTearScene = preload("res://assets/characters/Archer/effects/ground_tear.tscn")

@export var speed: float = 520.0
@export var ground_y_level: float = 0.0 # Y coordinate of the ground line
@export var spawn_ground_tear: bool = true

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 1.6
var distance_traveled: float = 0.0
var next_tear_distance: float = 30.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	distance_traveled += step
	lifetime -= delta
	
	if spawn_ground_tear and distance_traveled >= next_tear_distance and distance_traveled < 320.0:
		next_tear_distance += 110.0
		_spawn_ground_fissure(global_position)
		
	if lifetime <= 0.0:
		queue_free()

func _spawn_ground_fissure(pos: Vector2) -> void:
	var tear = GroundTearScene.instantiate()
	if tear:
		tear.scale = scale
		# Place fissure on the ground plane below the projectile
		var tear_pos = Vector2(pos.x - 20.0 * scale.x, ground_y_level if ground_y_level != 0.0 else pos.y + 14.0 * scale.y)
		tear.global_position = tear_pos
		var p = get_parent() if get_parent() else (get_tree().current_scene if get_tree() else null)
		if p:
			p.add_child(tear)
