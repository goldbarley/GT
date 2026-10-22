class_name MageMeteoriteFX
extends ColorRect

## Drives the meteorite effect of a modular Mage.
##
## The effect itself is drawn by mage_meteorite.gdshader. This script keeps the
## shader informed about the ground, which moves down the further the mage
## rises, about the gem on the staff, and about time, so the flames keep
## burning.

## Where the ground is, in the mage's local space, while she stands on it.
@export var ground_y: float = 32.0

var _mage: MageModularBase = null
var _rest_y: float = 0.0
var _time: float = 0.0
var _material: ShaderMaterial = null


func _ready() -> void:
	_material = material as ShaderMaterial
	_mage = get_parent() as MageModularBase
	if _mage != null:
		_rest_y = _mage.position.y
	# run after the choreography player so the staff is already posed
	process_priority = 10
	set_process(_material != null)


func _process(delta: float) -> void:
	if _material == null:
		return
	_time += delta
	if _mage != null:
		_material.set_shader_parameter("gem_pos", _mage.get_gem_position())
	_material.set_shader_parameter("time_seconds", _time)

	# The ground drops away as the mage flies up, so the meteorite still lands
	# on the same spot she left.  The rise is measured in the mage's own
	# pixels, because the shader works in her space and she may well be
	# scaled up.
	var rise := 0.0
	if _mage != null:
		var scale_y := _mage.scale.y
		if absf(scale_y) > 0.0001:
			rise = (_mage.position.y - _rest_y) / scale_y
	_material.set_shader_parameter("ground_y", ground_y - rise)

	if _mage == null:
		return

	# The dust comes out from under her feet, which are in a different place
	# in every view.
	_material.set_shader_parameter("centre_x", _mage.get_feet_centre().x)

	# The meteor lands where the spell was aimed, and not in front of her.
	# The aim is a place in the world, and it is turned into her own space
	# here, because that is the space the effect is drawn in.
	var aim := _aim_in_mage_space()
	if aim != Vector2.INF:
		var bounds := Rect2(Vector2(-80, -280), Vector2(220, 370)).expand(aim + Vector2(-80, -280)).expand(aim + Vector2(80, 90))
		position = bounds.position
		size = bounds.size
		_material.set_shader_parameter("quad_origin", bounds.position)
		_material.set_shader_parameter("quad_size", bounds.size)
		_material.set_shader_parameter("meteor_x", aim.x)
		_material.set_shader_parameter("ground_y", aim.y)

	# The site of the meteor's impact is written down here, and the pillar
	# of fire is put on it, so the two can never be in different places.
	var explosion := get_parent().get_node_or_null("ExplosionFX")
	if explosion != null:
		var meteor_x := 60.0
		if _material.get_shader_parameter("meteor_x") != null:
			meteor_x = float(_material.get_shader_parameter("meteor_x"))
		var ground := 32.0
		if _material.get_shader_parameter("ground_y") != null:
			ground = float(_material.get_shader_parameter("ground_y"))
		explosion.position = Vector2(meteor_x, ground)


## Where the spell is aimed, in the mage's own space, or nothing at all if
## she has not been told where to aim.
func _aim_in_mage_space() -> Vector2:
	if _mage == null:
		return Vector2.INF
	var target: Vector2 = _mage.cast_target
	if target == Vector2.INF:
		return Vector2.INF
	return _mage.to_local(target)

