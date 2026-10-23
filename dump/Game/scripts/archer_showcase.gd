extends Node2D

## Demo scene for the modular Archer rig.
##
## Shows the archer and drives her with the choreography player, so a clip can
## be played, scrubbed and stepped through on the real rig.  It is the
## archer's version of the mage's showcase.
##
## Only the right view is in play for now.

@onready var btn_cape: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnToggleCape
@onready var btn_quiver: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnToggleQuiver
@onready var btn_rotate: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnRotateBow
@onready var btn_reset: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnReset
@onready var btn_play_idle: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnPlayIdle
@onready var btn_play_walk: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls/BtnPlayWalk
@onready var btn_play_attack: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnPlayAttack
@onready var btn_play_skill: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnPlaySkill
@onready var btn_play_strong_skill: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnPlayStrongSkill
@onready var btn_play_shot: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnPlayShot
@onready var btn_stop: Button = $CanvasLayer/Panel/VBoxContainer/HBoxControls2/BtnStop
@onready var slider_scrub: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderScrub
@onready var val_scrub: Label = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/ValScrub
@onready var slider_speed: HSlider = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/SliderSpeed
@onready var val_speed: Label = $CanvasLayer/Panel/VBoxContainer/HBoxScrub/ValSpeed

const CLIP_IDLE := ArcherAnims.IDLE
const CLIP_WALK := ArcherAnims.WALK
const CLIP_BASIC_ATTACK := ArcherAnims.BASIC_ATTACK
const CLIP_SKILL := ArcherAnims.SKILL
const CLIP_STRONG_SKILL := ArcherAnims.STRONG_SKILL
const CLIP_SHOT := ArcherAnims.CHARGED_SHOT

## Where the demo shot is fired from, and which way it goes.  It is fired
## across the screen so that it can be seen.
const SHOT_FROM := 0
const SHOT_DIRECTION := Vector2.RIGHT
const SHOT_SPEED := 1500.0

## How big the archer is drawn, and the line her feet stand on.
const SCALE := 5.0
const GROUND_Y := 630.0

var archers: Array[ArcherModularBase] = []
var players: Array[ArcherChoreoPlayer] = []
var bow_rotation: float = 0.0
var is_scrubbing: bool = false
var active_clip: String = CLIP_IDLE
var playback_speed: float = 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Only the right view is in play for now
	var right = ModularArcherUtility.instantiate_archer("right")

	archers = [right]
	var positions = [
		Vector2(640, 0),
	]

	for i in range(archers.size()):
		var archer = archers[i]
		archer.scale = Vector2(SCALE, SCALE)
		# The rig's own origin is the top of the archer's head, so it is
		# dropped until her feet are on the ground line.
		archer.position = Vector2(positions[i].x, GROUND_Y - archer.get_feet_centre().y * SCALE)
		add_child(archer)

		# The player is a sibling of the archer, not a child, so the archer
		# has already registered its pieces by the time the player caches the
		# rest pose
		var player := ArcherChoreoPlayer.new()
		player.target = archer
		add_child(player)
		players.append(player)

	_connect_buttons()
	# The shot leaves on the clip's impact, which is the moment the string
	# lets go.
	players[SHOT_FROM].clip_impact.connect(_on_clip_impact)
	_play_clip(CLIP_IDLE)


func _connect_buttons() -> void:
	if btn_cape:
		btn_cape.pressed.connect(func():
			for a in archers:
				var c = a.get_piece("cape")
				if c: c.visible = !c.visible
		)

	if btn_quiver:
		btn_quiver.pressed.connect(func():
			for a in archers:
				var q = a.get_piece("quiver")
				if q: q.visible = !q.visible
		)

	if btn_rotate:
		btn_rotate.pressed.connect(func():
			bow_rotation += 0.25
			for a in archers:
				a.rotate_piece("bow", bow_rotation)
		)

	if btn_reset:
		btn_reset.pressed.connect(func():
			bow_rotation = 0.0
			for a in archers:
				a.reset_pose()
		)

	if btn_play_idle:
		btn_play_idle.pressed.connect(func(): _play_clip(CLIP_IDLE))

	if btn_play_walk:
		btn_play_walk.pressed.connect(func(): _play_clip(CLIP_WALK))

	if btn_play_attack:
		btn_play_attack.pressed.connect(func(): _play_clip(CLIP_BASIC_ATTACK))

	if btn_play_skill:
		btn_play_skill.pressed.connect(func(): _play_clip(CLIP_SKILL))

	if btn_play_strong_skill:
		btn_play_strong_skill.pressed.connect(func(): _play_clip(CLIP_STRONG_SKILL))

	if btn_play_shot:
		btn_play_shot.pressed.connect(func(): _play_clip(CLIP_SHOT))

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
		slider_speed.drag_started.connect(func(): is_scrubbing = true)
		slider_speed.drag_ended.connect(func(_v): is_scrubbing = false)
		slider_speed.value_changed.connect(_on_speed_changed)
		_on_speed_changed(slider_speed.value)


func _play_clip(clip_name: String) -> void:
	active_clip = clip_name
	for p in players:
		p.play(clip_name)


## The string has let go: the arrow or beam goes.
func _on_clip_impact(clip_name: String) -> void:
	var rig := archers[SHOT_FROM]
	var bow := rig.get_piece("bow")
	if bow == null:
		return
	var bow_dir := Vector2.RIGHT.rotated(bow.global_rotation)
	var facing_dir := Vector2.LEFT if rig.scale.x < 0.0 else Vector2.RIGHT

	match clip_name:
		CLIP_BASIC_ATTACK:
			ArcherShot.fire_basic_attack(self, bow.global_position, facing_dir, 1200.0,
					GROUND_Y, SCALE, bow)
		CLIP_SKILL:
			ArcherShot.fire_skill(self, bow.global_position, facing_dir, 1200.0,
					GROUND_Y, SCALE, bow)
		CLIP_STRONG_SKILL:
			ArcherShot.fire_strong_skill(self, bow.global_position, facing_dir, 1500.0,
					GROUND_Y, SCALE, bow)
		CLIP_SHOT:
			ArcherShot.fire(self, bow.global_position, bow_dir, SHOT_SPEED,
					GROUND_Y, SCALE, bow)



func _on_scrub_changed(value: float) -> void:
	if not is_scrubbing:
		return
	# the clip carries on playing, so it can be watched in slow motion
	for p in players:
		p.scrub_percent(value, true)
	_update_scrub_label(value / 100.0)


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
	if is_scrubbing or players.is_empty():
		return
	# keep the scrub bar in sync with whichever player is driving, unless the
	# pointer is on the slider, where the clip would fight the drag
	var lead: ArcherChoreoPlayer = players[0]
	if slider_scrub:
		slider_scrub.value = lead.get_progress() * 100.0
	_update_scrub_label(lead.get_progress())
