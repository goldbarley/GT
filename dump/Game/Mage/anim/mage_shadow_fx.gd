class_name MageShadowFX
extends ColorRect

## The soft shadow under a modular Mage's feet.
##
## The shadow itself is drawn by `mage_shadow.gdshader`.  This script keeps
## it in the right place: the quad follows her feet, it sits on the ground
## line, and it spreads out and fades as she lifts off the ground.

## Where the ground is, in the mage's own space, while she stands on it.
@export var ground_y: float = 32.0
## The shadow's half width while she is standing still.
@export var base_radius: float = 7.0
## How dark the shadow is while she is standing still.
@export var base_opacity: float = 0.34

var _mage: MageModularBase = null
var _rest_y: float = 0.0
var _material: ShaderMaterial = null


func _ready() -> void:
	_material = material as ShaderMaterial
	_mage = get_parent() as MageModularBase
	if _mage != null:
		_rest_y = _mage.position.y
	# run after the choreography player, so the mage is already posed
	process_priority = 10
	set_process(_material != null)


func _process(_delta: float) -> void:
	if _material == null:
		return

	# The ground drops away as the mage rises, so the shadow stays on the
	# ground she left.  The rise is measured in her own pixels, because the
	# shadow works in her space and she may well be scaled up.
	var rise := 0.0
	var feet := 19.0
	if _mage != null:
		var scale_y := _mage.scale.y
		if absf(scale_y) > 0.0001:
			rise = (_mage.position.y - _rest_y) / scale_y
		feet = _mage.get_feet_centre().x

	# the higher she is, the wider and the fainter the shadow
	var height := maxf(-rise, 0.0)
	_material.set_shader_parameter("radius", base_radius * (1.0 + height * 0.018))
	_material.set_shader_parameter("opacity", base_opacity * clampf(1.0 - height * 0.010, 0.0, 1.0))

	# The shadow is drawn in the middle of its quad, so the quad is put
	# where the middle of it lands on her feet, on the ground.  A control's
	# position is the corner of its rect, so the half of the quad is taken
	# off to centre it.
	var half := size * 0.5
	position = Vector2(feet - half.x, ground_y - rise - half.y)
