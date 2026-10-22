class_name ArcherShot
extends RefCounted

## The Archer's shot in the world.
##
## When the godray charge is let go, the beam goes: a long streak of energy
## that runs out from the bow, leaving the ground torn open along the line it
## flies.  The burst at the nock goes with it, and the dust the archer kicks
## up behind herself goes the other way.
##
## The beam is a world effect and is not scaled with the archer: its length is
## its own length, in world pixels.  The burst, the tear and the dust are
## sized with her, because they are sized against her.

const BeamScene := preload("res://assets/characters/Archer/effects/archer_beam.tscn")
const ShockwaveScene := preload("res://assets/characters/Archer/effects/arrow_shockwave.tscn")
const GroundTearScene := preload("res://assets/characters/Archer/effects/ground_tear.tscn")
const ArrowScene := preload("res://assets/characters/Archer/effects/arrow_projectile.tscn")
const ChargedArrowScene := preload("res://assets/characters/Archer/effects/charged_arrow_projectile.tscn")

## How far ahead of the bow the burst goes off.
const BURST_OFFSET := 10.0


## Fires the basic attack arrow in a straight line.
static func fire_basic_attack(parent: Node, origin: Vector2, direction: Vector2,
		speed: float = 1200.0, ground_y: float = 0.0, arrow_scale: float = 1.0,
		source_node: Node2D = null) -> void:
	if parent == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if source_node and is_instance_valid(source_node):
		origin = source_node.global_position

	var size := Vector2(arrow_scale, arrow_scale)

	# The arrow flies straight forward along the aim line
	var arrow := ArrowScene.instantiate() as ArrowProjectile
	if arrow:
		arrow.scale = size
		arrow.direction = dir
		arrow.speed = speed
		parent.add_child(arrow)
		arrow.global_position = origin + dir * 10.0 * arrow_scale
		arrow.rotation = dir.angle()


## Fires the quick arrow skill in a straight line.
static func fire_skill(parent: Node, origin: Vector2, direction: Vector2,
		speed: float = 1200.0, ground_y: float = 0.0, arrow_scale: float = 1.0,
		source_node: Node2D = null) -> void:
	if parent == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if source_node and is_instance_valid(source_node):
		origin = source_node.global_position

	var size := Vector2(arrow_scale, arrow_scale)

	var burst := ShockwaveScene.instantiate() as ArrowShockwave
	if burst:
		parent.add_child(burst)
		burst.scale = size * 0.7
		burst.global_position = origin + dir * 6.0 * arrow_scale
		burst.rotation = dir.angle()

	var arrow := ArrowScene.instantiate() as ArrowProjectile
	if arrow:
		arrow.scale = size
		arrow.direction = dir
		arrow.speed = speed
		parent.add_child(arrow)
		arrow.global_position = origin + dir * 10.0 * arrow_scale
		arrow.rotation = dir.angle()


## Fires the strong charged arrow skill in a straight line.
static func fire_strong_skill(parent: Node, origin: Vector2, direction: Vector2,
		speed: float = 1500.0, ground_y: float = 0.0, arrow_scale: float = 1.0,
		source_node: Node2D = null) -> void:
	if parent == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if source_node and is_instance_valid(source_node):
		origin = source_node.global_position

	var size := Vector2(arrow_scale, arrow_scale)

	var burst := ShockwaveScene.instantiate() as ArrowShockwave
	if burst:
		parent.add_child(burst)
		burst.scale = size
		burst.global_position = origin + dir * BURST_OFFSET * arrow_scale
		burst.rotation = dir.angle()

	var proj := ChargedArrowScene.instantiate() as ChargedArrowProjectile
	if proj:
		proj.scale = size
		proj.direction = dir
		proj.speed = speed
		proj.ground_y_level = ground_y
		parent.add_child(proj)
		proj.global_position = origin + dir * 14.0 * arrow_scale
		proj.rotation = dir.angle()

	var tear := GroundTearScene.instantiate() as GroundTear
	if tear:
		parent.add_child(tear)
		tear.scale = size
		tear.global_position = Vector2(origin.x + dir.x * 8.0 * arrow_scale, ground_y)

## Fires the shot.
##
## `parent` is where the shot is put, `origin` is the bow, `direction` is the
## way the shot goes, `ground_y` is the line it flies along, `scale` is how
## big the archer is, and `source_node` is the bow node to anchor to dynamically.
static func fire(parent: Node, origin: Vector2, direction: Vector2,
		speed: float, ground_y: float, arrow_scale: float = 1.0,
		source_node: Node2D = null) -> void:
	if parent == null:
		return
	var dir := direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if source_node and is_instance_valid(source_node):
		dir = Vector2.RIGHT.rotated(source_node.global_rotation)
		origin = source_node.global_position

	var size := Vector2(arrow_scale, arrow_scale)

	var burst := ShockwaveScene.instantiate() as ArrowShockwave
	if burst:
		parent.add_child(burst)
		burst.scale = size
		burst.global_position = origin + dir * BURST_OFFSET * arrow_scale
		burst.rotation = dir.angle()

	var beam := BeamScene.instantiate() as ArcherBeam
	if beam:
		beam.origin_node = source_node
		beam.direction = dir
		beam.origin_point = origin
		beam.speed = speed
		beam.ground_y_level = ground_y
		parent.add_child(beam)
		beam.global_position = origin
		beam.rotation = dir.angle()

	var tear := GroundTearScene.instantiate() as GroundTear
	if tear:
		parent.add_child(tear)

		tear.scale = size
		tear.global_position = Vector2(origin.x + dir.x * 8.0 * arrow_scale, ground_y)
