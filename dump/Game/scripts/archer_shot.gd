class_name ArcherShot
extends RefCounted

## The Archer's shot in the world.
##
## When the godray charge is let go, the beam goes: a long streak of energy
## that runs out from the bow, leaving the ground torn open along the line it
## flies.  The burst at the nock goes with it.

const BeamScene := preload("res://scenes/archer_beam.tscn")
const ShockwaveScene := preload("res://scenes/arrow_shockwave.tscn")
const GroundTearScene := preload("res://scenes/ground_tear.tscn")

## How far ahead of the bow the burst goes off.
const BURST_OFFSET := 10.0


## Fires the shot.
##
## `parent` is where the shot is put, `origin` is the bow, `direction` is the
## way the shot goes, `ground_y` is the line it flies along and `scale` is how
## big the archer is, so the shot is the same size as she is.
static func fire(parent: Node, origin: Vector2, direction: Vector2,
		speed: float, ground_y: float, arrow_scale: float = 1.0) -> void:
	if parent == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var size := Vector2(arrow_scale, arrow_scale)

	var burst := ShockwaveScene.instantiate() as ArrowShockwave
	if burst:
		burst.scale = size
		burst.global_position = origin + dir * BURST_OFFSET * arrow_scale
		burst.rotation = 0.0
		parent.add_child(burst)

	var beam := BeamScene.instantiate() as ArcherBeam
	if beam:
		beam.scale = size
		beam.global_position = origin
		beam.direction = dir
		beam.speed = speed
		beam.ground_y_level = ground_y
		parent.add_child(beam)

	var tear := GroundTearScene.instantiate() as GroundTear
	if tear:
		tear.scale = size
		tear.global_position = Vector2(origin.x + dir.x * 8.0 * arrow_scale, ground_y)
		parent.add_child(tear)
