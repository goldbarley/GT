class_name MageFireballFX
extends ColorRect

## Drives the fireball effect of a modular Mage.
##
## The effect itself is drawn by `mage_fireball.gdshader`. This script keeps the
## shader informed about the staff, so the glow at the gem follows the staff as
## it is raised and turned, it keeps the clock the embers rise on, and it keeps
## the pit of fire where the fireball landed.

## How long the pit of fire keeps burning after the cast is over.
@export var linger_duration: float = 2.5

var _mage: MageModularBase = null
var _material: ShaderMaterial = null
var _time: float = 0.0
var _pit_world: Vector2 = Vector2.INF   # where the fireball landed, in the world


func _ready() -> void:
	_material = material as ShaderMaterial
	var mage := get_parent() as MageModularBase
	if mage != null:
		_mage = mage
	if _material != null:
		_material.set_shader_parameter("linger_duration", linger_duration)
	# run after the choreography player so the staff is already posed
	process_priority = 10
	set_process(_mage != null and _material != null)


func _process(delta: float) -> void:
	if _mage == null or _material == null:
		return
	# the embers of the burning pit rise on their own clock
	_time += delta
	_material.set_shader_parameter("time_seconds", _time)
	# the gem is looked for in the staff's own pixels, so the glow lands
	# exactly on it however the staff is turned
	_material.set_shader_parameter("gem_pos", _mage.get_gem_position())
	_aim_at_target()
	_place_pit()


## Points the fireball at where the spell was aimed, and puts the pit of
## fire there too.
##
## The aim is a place in the world, turned into the mage's own space here,
## because that is the space the effect is drawn in.  How far away it is
## also decides how high the fireball arcs.
func _aim_at_target() -> void:
	if _mage == null:
		return
	var target: Vector2 = _mage.cast_target
	if target == Vector2.INF:
		return
	var aim := _mage.to_local(target)
	var bounds := Rect2(Vector2(-40, -80), Vector2(120, 160)).expand(aim).grow(24)
	position = bounds.position
	size = bounds.size
	_material.set_shader_parameter("quad_origin", bounds.position)
	_material.set_shader_parameter("quad_size", bounds.size)
	_material.set_shader_parameter("impact_pos", aim)
	_material.set_shader_parameter("pit_pos", aim)
	# a shot that has further to go arcs higher
	var spawn: Variant = _material.get_shader_parameter("spawn_pos")
	if spawn is Vector2:
		var distance := absf(aim.x - (spawn as Vector2).x)
		_material.set_shader_parameter("arc_height", 15.0 + distance * 0.25)


## Keeps the pit of fire where the fireball landed.
##
## The pit is drawn in the mage's own space, so without this it would walk
## away with her.  The place it landed is remembered in the world the moment
## the fire touches the ground, and it is handed back to the shader in her
## own space every frame, so the fire stays where it was lit.
func _place_pit() -> void:
	var strength: float = float(_material.get_shader_parameter("pit_strength"))
	if strength <= 0.0:
		# there is no fire, so the next cast gets a pit of its own
		_pit_world = Vector2.INF
		return
	if _pit_world == Vector2.INF:
		# the fire has just touched the ground: this is where it landed
		var landed: Variant = _material.get_shader_parameter("pit_pos")
		if landed is Vector2:
			_pit_world = _mage.get_parent().get_parent().get_global_transform().affine_inverse() * _mage.to_global(landed)
		return
	_material.set_shader_parameter("pit_pos", _mage.to_local(_mage.get_parent().get_parent().get_global_transform() * _pit_world))
