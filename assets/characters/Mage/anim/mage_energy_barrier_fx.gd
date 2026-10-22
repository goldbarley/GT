class_name MageEnergyBarrierFX
extends ColorRect

## The energy barrier that closes around a modular Mage.
##
## The choreography clip drives the barrier forming, and once the clip is over
## the barrier simply stays up.  `dismiss()` fades it out again.

## How long the barrier takes to fade away when it is dismissed.
@export var dismiss_duration: float = 0.45

var _fade: float = 1.0
var _fading: bool = false


func _ready() -> void:
	# the barrier starts invisible because the shader draws nothing until the
	# clip has driven the progress up
	_apply_fade()
	set_process(true)


func _process(delta: float) -> void:
	if not _fading:
		return
	_fade = maxf(0.0, _fade - delta / maxf(dismiss_duration, 0.001))
	_apply_fade()
	if _fade <= 0.0:
		_fading = false


## Fades the barrier out.
func dismiss() -> void:
	if _fade <= 0.0:
		return
	_fading = true


## Brings the barrier straight back up, without the fade.
func restore() -> void:
	_fading = false
	_fade = 1.0
	_apply_fade()


## True while the barrier is on its way out.
func is_dismissing() -> bool:
	return _fading


func _apply_fade() -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("dismiss_fade", _fade)
