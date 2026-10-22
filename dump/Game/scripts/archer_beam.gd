class_name ArcherBeam
extends Area2D

## The beam the archer lets go of.
##
## It is a long streak of energy that runs out from the bow, with its head
## doing the damage and its tail burning away behind it.  The tail stays on the
## bow, so the beam only ever reaches forward.  It tears the ground open along
## the line it flies, the same way the charged arrow did.

const GroundTearScene := preload("res://scenes/ground_tear.tscn")

## How long the beam is, in pixels.
const BEAM_LENGTH := 1200.0

## How fast the beam flies, in pixels a second.
@export var speed: float = 1500.0
## The line the ground is on.
@export var ground_y_level: float = 0.0
## Whether the beam leaves a tear in the ground behind it.
@export var spawn_ground_tear: bool = true
## How long the beam lives, in seconds.
@export var lifetime: float = 1.6
## How far apart the tears are left, in pixels.
@export var tear_spacing: float = 60.0

## The way the beam is going.
var direction: Vector2 = Vector2.RIGHT
## Where the beam left the bow, in world space.
var origin_point: Vector2 = Vector2.ZERO
## If an origin node is provided (e.g. the Bow Sprite2D), the beam continuously
## locks its origin position and orientation to it dynamically.
var origin_node: Node2D = null

var _elapsed: float = 0.0
var _travel: float = 0.0
var _next_tear: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	_elapsed = 0.0
	_next_tear = tear_spacing
	if origin_node and is_instance_valid(origin_node):
		origin_point = origin_node.global_position
		global_position = origin_point
		rotation = origin_node.global_rotation
	elif origin_point == Vector2.ZERO:
		origin_point = global_position
		rotation = direction.angle()
	else:
		global_position = origin_point
		rotation = direction.angle()

	var rect := get_node_or_null("Beam") as ColorRect
	if rect:
		_material = rect.material as ShaderMaterial
	if _material:
		_material.set_shader_parameter("seed", randf() * 10.0)
		_material.set_shader_parameter("tail_x", 1.0)
		_material.set_shader_parameter("fade", 1.0)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	# Dynamically follow origin node if present, otherwise stay anchored at origin_point
	if origin_node and is_instance_valid(origin_node):
		global_position = origin_node.global_position
		rotation = origin_node.global_rotation
	else:
		global_position = origin_point


	if _material:
		# Beam starts at peak full blast, then fades as it sweeps/burns out
		var fade_val: float = 1.0
		if _elapsed > 0.3:
			fade_val = clampf(1.0 - (_elapsed - 0.3) / (lifetime - 0.3), 0.0, 1.0)
		_material.set_shader_parameter("fade", fade_val)

	if spawn_ground_tear and _travel >= _next_tear:
		_next_tear += tear_spacing
		_spawn_tear()
		_travel += tear_spacing



func _spawn_tear() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var tear := GroundTearScene.instantiate() as GroundTear
	if tear == null:
		return
	tear.global_position = Vector2(global_position.x, ground_y_level)
	parent.add_child(tear)
