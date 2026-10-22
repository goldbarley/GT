class_name QuadBeamDim
extends Node2D

## Dims the whole screen while the quad beam winds up, without dimming the
## mage or her beam.
##
## The dimming is done with a light rather than with an overlay.  A light
## reaches the whole canvas whatever the camera is doing, and a light has a
## mask: the things that must stay bright are given a mask of their own and
## the light is kept away from it.  An overlay would have to be drawn over
## the mage as well, and would then have to be un-drawn again.

## How much darker the screen goes, from 0 to 1.
@export var allow_dimming: bool = true
@export var dim_amount: float = 0.4
## How long the dim takes to come up.
@export var fade_in: float = 0.7
## How long the dim takes to go back down.
@export var fade_out: float = 0.5
## The mask the bright things wear.  The dimming light keeps to the default
## mask, so anything wearing this one is left alone.
@export var exempt_mask: int = 2

var _light: DirectionalLight2D = null
var _target: float = 1.0
var _speed: float = 0.0
## Whether a clip is driving the dim, in which case this does not touch it.
var driven: bool = false


func _ready() -> void:
	_light = get_node_or_null("DimLight") as DirectionalLight2D
	if _light == null:
		_light = DirectionalLight2D.new()
		_light.name = "DimLight"
		add_child(_light)
	# The light only touches the ordinary things in the world, and it takes
	# light away rather than giving it, which is what a dim is.  A light
	# that adds would only ever make things brighter.
	_light.light_mask = 1
	_light.blend_mode = Light2D.BLEND_MODE_SUB
	_light.energy = 0.0
	_target = 0.0


## Sets how dark the screen is, from 0 to 1, for when a clip drives it.
##
## The clip says how dark it wants and when, so this hands over to it and
## stops moving the light on its own.
func set_dim(amount: float) -> void:
	driven = true
	if _light == null:
		return
	# The light takes light away, so its energy is the amount of dimming
	# itself: no dimming is no energy at all.
	_light.energy = clampf(amount, 0.0, 1.0) if allow_dimming else 0.0


## Starts the dim coming up.
func start() -> void:
	_target = dim_amount
	_speed = dim_amount / maxf(fade_in, 0.001)


## Lets the screen back up.
func stop() -> void:
	_target = 0.0
	_speed = dim_amount / maxf(fade_out, 0.001)


## Whether the screen is dimmed at the moment.
func is_dimmed() -> bool:
	return _light != null and _light.energy > 0.001


## Keeps a thing out of the dim, and everything under it.
func set_exempt(node: Node) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).light_mask = exempt_mask
	for child in node.get_children():
		set_exempt(child)


func _process(delta: float) -> void:
	if _light == null or driven:
		return
	var energy := _light.energy
	if absf(energy - _target) <= 0.001:
		return
	_light.energy = move_toward(energy, _target, _speed * delta)
