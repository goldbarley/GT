class_name ArcherBeam
extends Area2D

## The beam the archer lets go of.
##
## It is a long streak of energy that runs out from the bow, with its head
## doing the damage and its tail burning away behind.  It tears the ground
## open along the line it flies, the same way the charged arrow did.

const GroundTearScene := preload("res://scenes/ground_tear.tscn")

## How long the beam is, in pixels.
const BEAM_LENGTH := 400.0

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

var _elapsed: float = 0.0
var _travel: float = 0.0
var _next_tear: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	_elapsed = 0.0
	_next_tear = tear_spacing
	var rect := get_node_or_null("Beam") as ColorRect
	if rect:
		_material = rect.material as ShaderMaterial
	if _material:
		_material.set_shader_parameter("seed", randf() * 10.0)
		_material.set_shader_parameter("length", 0.0)
		_material.set_shader_parameter("fade", 1.0)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	# the head runs on, and the beam stretches out behind it
	var step := direction.normalized() * speed * delta
	position += step
	_travel += step.length()
	if _material:
		# the beam is as long as the ground it has covered, up to its own
		# length, so it leaves the bow and stays attached to it on the way
		_material.set_shader_parameter("length",
				clampf(minf(_travel, BEAM_LENGTH) / BEAM_LENGTH, 0.0, 1.0))
		_material.set_shader_parameter("fade", clampf((lifetime - _elapsed) / 0.35, 0.0, 1.0))

	if spawn_ground_tear and _travel >= _next_tear:
		_next_tear += tear_spacing
		_spawn_tear()


func _spawn_tear() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var tear := GroundTearScene.instantiate() as GroundTear
	if tear == null:
		return
	tear.global_position = Vector2(position.x, ground_y_level)
	parent.add_child(tear)
