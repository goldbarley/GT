extends Node2D

## Demo scene for the modular Mage rig.
##
## Shows all four perspectives side by side and drives them with the
## choreography player, so a clip can be played, scrubbed and stepped through
## on the real rig.

@onready var btn_hat: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnToggleHat
@onready var btn_staff: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnToggleStaff
@onready var btn_rotate: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnRotateStaff
@onready var btn_reset: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnReset
@onready var btn_play_idle: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnPlayIdle
@onready var btn_cast: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnCast
@onready var btn_stop: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnStop
@onready var btn_teleport: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnTeleport
@onready var btn_reappear: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnReappear
@onready var btn_fireball: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnFireball
@onready var btn_barrier: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnBarrier
@onready var btn_dismiss: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnDismiss
@onready var btn_meteorite: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnMeteorite
@onready var btn_quad_beam: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnQuadBeam
@onready var slider_scrub: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderScrub
@onready var val_scrub: Label = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/ValScrub
@onready var slider_speed: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderSpeed
@onready var val_speed: Label = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/ValSpeed

const CLIP_IDLE := "mage_idle"
const CLIP_CAST := "mage_cast"
const CLIP_TELEPORT := MageAnims.TELEPORT
const CLIP_REAPPEAR := MageAnims.TELEPORT_REAPPEAR
const CLIP_FIREBALL := MageAnims.FIREBALL
const CLIP_BARRIER := MageAnims.BARRIER
const CLIP_METEORITE := MageAnims.METEORITE

var mages: Array[MageModularBase] = []
var players: Array[MageChoreoPlayer] = []
## The quad beam of each mage, so all four views can throw it at once.
var bursts: Array[MageBeamBurst] = []
## One dim for the lot.  Two dimming lights would take twice as much light
## away from the screen.
var beam_dim: QuadBeamDim = null
var staff_rotation: float = 0.0
var is_scrubbing: bool = false
var active_clip: String = CLIP_IDLE
var _shake_time: float = 0.0
var playback_speed: float = 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Instance all 4 perspectives
	var front = ModularMageUtility.instantiate_mage("front")
	var back = ModularMageUtility.instantiate_mage("back")
	var left = ModularMageUtility.instantiate_mage("left")
	var right = ModularMageUtility.instantiate_mage("right")

	mages = [front, back, left, right]
	# low enough that a mage who floats up in the air stays clear of the
	# panel above
	var positions = [
		Vector2(120, 470),
		Vector2(420, 470),
		Vector2(720, 470),
		Vector2(1020, 470)
	]

	for i in range(mages.size()):
		var m = mages[i]
		m.scale = Vector2(5, 5)
		m.position = positions[i]
		add_child(m)

		# the player is a sibling of the mage, not a child, so the mage has
		# already registered its pieces by the time the player caches the rest pose
		var player := MageChoreoPlayer.new()
		player.target = m
		add_child(player)
		players.append(player)

	_build_quad_beams()

	_connect_buttons()
	_play_clip(CLIP_IDLE)


## Gives each mage her quad beam, so the four views can be seen throwing it.
func _build_quad_beams() -> void:
	beam_dim = QuadBeamDim.new()
	beam_dim.name = "QuadBeamDim"
	add_child(beam_dim)
	for m in mages:
		var burst := MageBeamBurst.new()
		# the beam is drawn at the size of the character, so it is drawn at
		# the same scale as the character
		burst.scale = m.scale
		burst.dim = beam_dim
		add_child(burst)
		bursts.append(burst)


## Throws the quad beam out of every mage's staff.
func _on_quad_beam() -> void:
	for burst in bursts:
		burst.fire()


func _connect_buttons() -> void:
	if btn_hat:
		btn_hat.pressed.connect(func():
			for m in mages:
				var h = m.get_piece("hat")
				if h: h.visible = !h.visible
		)

	if btn_staff:
		btn_staff.pressed.connect(func():
			for m in mages:
				var s = m.get_piece("staff")
				if s: s.visible = !s.visible
		)

	if btn_rotate:
		btn_rotate.pressed.connect(func():
			staff_rotation += 0.25
			for m in mages:
				m.rotate_piece("staff", staff_rotation)
		)

	if btn_reset:
		btn_reset.pressed.connect(func():
			staff_rotation = 0.0
			for m in mages:
				m.reset_pose()
		)

	if btn_play_idle:
		btn_play_idle.pressed.connect(func(): _play_clip(CLIP_IDLE))
	if btn_cast:
		btn_cast.pressed.connect(func(): _play_clip(CLIP_CAST))
	if btn_teleport:
		btn_teleport.pressed.connect(func(): _play_clip(CLIP_TELEPORT))
	if btn_reappear:
		btn_reappear.pressed.connect(func(): _play_clip(CLIP_REAPPEAR))
	if btn_fireball:
		btn_fireball.pressed.connect(func(): _play_clip(CLIP_FIREBALL))
	if btn_barrier:
		btn_barrier.pressed.connect(func(): _play_clip(CLIP_BARRIER))
	if btn_meteorite:
		btn_meteorite.pressed.connect(func(): _play_clip(CLIP_METEORITE))
		btn_quad_beam.pressed.connect(_on_quad_beam)
	if btn_dismiss:
		btn_dismiss.pressed.connect(func():
			for p in players:
				p.dismiss_effect())
	if btn_stop:
		btn_stop.pressed.connect(func():
			for p in players:
				p.stop()
			active_clip = ""
			_update_scrub_label(0.0)
		)

	if slider_scrub:
		slider_scrub.drag_started.connect(func(): is_scrubbing = true)
		slider_scrub.drag_ended.connect(func(_v): is_scrubbing = false)
		slider_scrub.value_changed.connect(_on_scrub_changed)

	if slider_speed:
		slider_speed.value_changed.connect(_on_speed_changed)
		_on_speed_changed(slider_speed.value)


func _play_clip(clip_name: String) -> void:
	active_clip = clip_name
	for p in players:
		p.play(clip_name)


func _on_scrub_changed(value: float) -> void:
	if not is_scrubbing:
		return
	for p in players:
		# the clip carries on playing, so it can be watched in slow motion
		p.scrub_percent(value, true)
	_update_scrub_label(value / 100.0)


## Slows the clip down, or speeds it up, while it is playing.
func _on_speed_changed(value: float) -> void:
	playback_speed = value
	for p in players:
		p.set_playback_speed(value)
	if val_speed:
		val_speed.text = "%.2fx" % value


func _update_scrub_label(progress: float) -> void:
	if val_scrub:
		var name := active_clip if active_clip != "" else "-"
		val_scrub.text = "%s %d%%" % [name, int(round(progress * 100.0))]


func _process(delta: float) -> void:
	# each beam comes out of the gem on its own mage's staff
	for i in range(bursts.size()):
		if i < mages.size():
			bursts[i].anchor_to_gem(mages[i])

	_shake_time += delta
	_apply_camera_shake()

	if is_scrubbing or players.is_empty():
		return
	# keep the scrub bar in sync with whichever player is driving, unless the
	# pointer is on the slider, where the clip would fight the drag
	var lead: MageChoreoPlayer = players[0]
	if slider_scrub and not is_scrubbing:
		slider_scrub.value = lead.get_progress() * 100.0
	_update_scrub_label(lead.get_progress())


## Shakes the whole demo when a clip asks the camera to shake, the same way
## the game will use the `camera_shake_requested` signal.
func _apply_camera_shake() -> void:
	var amount := 0.0
	for p in players:
		amount = maxf(amount, p.get_camera_shake())
	if amount <= 0.001:
		position = Vector2.ZERO
		return
	# the rattle follows the clip's own clock, so it slows down with it
	var clock := _shake_time
	if not players.is_empty():
		clock = players[0].elapsed
	var x := sin(clock * 61.0) * 0.6 + sin(clock * 37.0) * 0.4
	var y := cos(clock * 53.0) * 0.6 + cos(clock * 29.0) * 0.4
	position = Vector2(x, y) * amount * 7.0
