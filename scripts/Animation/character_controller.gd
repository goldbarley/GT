class_name CharacterController
extends Node2D

## The controller every character sits on.
##
## It owns one rig per perspective, shows the one the character is facing, and
## drives a player for each of them.  The motor above only ever talks to this
## interface, so it does not matter whether the character is a knight with a
## sword or a mage with a staff.
##
## Where the position of the character lives matters, because three different
## things want to move it:
##
##   the motor       owns this controller's world position, so the character
##                    can walk around the map
##   a clip          owns the rig's local position, for the root motion of a
##                    cast such as the meteorite, where the mage leaves the
##                    ground
##   a piece         owns its own position inside the rig
##
## They never fight, because each of them writes to a different one.

signal action_started(action_name: String)
signal action_impact(action_name: String)
signal action_finished(action_name: String)
signal camera_shake_requested(amount: float)

## The action played while the character is standing still.
@export var idle_action: String = ""
## The action played while the character is walking.
@export var walk_action: String = ""

## The four rigs, one per perspective.
var rigs: Dictionary = {}
## The four players, one for each rig.
var players: Dictionary = {}
## Which rig is on show.
var active_perspective: String = ""
var active_rig: Node = null
var active_player: Node = null
## The way the character is looking.
var facing: Vector2 = Vector2.RIGHT
## Whether the character is walking.
var is_walking: bool = false

var _action_name: String = ""
var _busy: bool = false
var _connected_player: Node = null


func _ready() -> void:
	# building twice would leave a second set of rigs behind
	if rigs.is_empty():
		_build()
	if rigs.is_empty():
		return
	_set_perspective(_perspective_for(facing))


## Subclasses fill in the rigs and the players, one pair per perspective.
func _build() -> void:
	pass


## Which rig to show for a direction.
func _perspective_for(dir: Vector2) -> String:
	if absf(dir.x) >= absf(dir.y):
		return "right" if dir.x >= 0.0 else "left"
	return "back" if dir.y < 0.0 else "front"


## Points the character in a direction, showing the matching rig.
func set_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	facing = dir.normalized()
	_set_perspective(_perspective_for(facing))


func get_facing() -> Vector2:
	return facing


## Shows one rig and hides the rest.
func _set_perspective(perspective: String) -> void:
	if not rigs.has(perspective):
		return
	active_perspective = perspective
	active_rig = rigs[perspective]
	active_player = players.get(perspective)
	for key in rigs:
		rigs[key].visible = (key == perspective)
	_connect_player(active_player)


## Connects a player's signals to the controller's, so the world only ever
## hears about the character once, and only from the rig that is on show.
func _connect_player(player: Node) -> void:
	if player == _connected_player:
		return
	if _connected_player != null:
		var old := _connected_player
		if old.has_signal("clip_started") and old.is_connected("clip_started", _on_player_clip_started):
			old.clip_started.disconnect(_on_player_clip_started)
		if old.has_signal("clip_impact") and old.is_connected("clip_impact", _on_player_clip_impact):
			old.clip_impact.disconnect(_on_player_clip_impact)
		if old.has_signal("clip_finished") and old.is_connected("clip_finished", _on_player_clip_finished):
			old.clip_finished.disconnect(_on_player_clip_finished)
		if old.has_signal("camera_shake_requested") and old.is_connected("camera_shake_requested", _on_player_camera_shake):
			old.camera_shake_requested.disconnect(_on_player_camera_shake)
	_connected_player = player
	if player == null:
		return
	if player.has_signal("clip_started"):
		player.clip_started.connect(_on_player_clip_started)
	if player.has_signal("clip_impact"):
		player.clip_impact.connect(_on_player_clip_impact)
	if player.has_signal("clip_finished"):
		player.clip_finished.connect(_on_player_clip_finished)
	if player.has_signal("camera_shake_requested"):
		player.camera_shake_requested.connect(_on_player_camera_shake)


## Plays an action on every perspective, so they all stay in step.  The world
## only hears about it once, through the signals above.
func play_action(action_name: String) -> void:
	if action_name == "":
		return
	_action_name = action_name
	_busy = true
	for key in players:
		players[key].play(action_name)


## Stops whatever is playing and leaves the character at rest.
func stop_action() -> void:
	_busy = false
	_action_name = ""
	for key in players:
		players[key].stop()


## Whether an action is playing.  The motor uses this to stop walking while
## the character is busy, so a cast is not interrupted by a step.
func is_busy() -> bool:
	return _busy


func get_action_name() -> String:
	return _action_name


## Starts or stops the walk cycle.  It does nothing while an action is
## playing.
func set_walking(walking: bool) -> void:
	if walking == is_walking:
		return
	is_walking = walking
	_apply_locomotion()


## Puts the character into the walk or the idle clip, unless an action has
## hold of it.
func _apply_locomotion() -> void:
	if _busy:
		return
	var action := walk_action if is_walking else idle_action
	if action == "":
		return
	for key in players:
		players[key].play(action)


## How fast the clips play.
func set_playback_speed(speed: float) -> void:
	for key in players:
		players[key].set_playback_speed(speed)


func _on_player_clip_started(clip_name: String) -> void:
	action_started.emit(clip_name)


func _on_player_clip_impact(clip_name: String) -> void:
	action_impact.emit(clip_name)


func _on_player_clip_finished(clip_name: String) -> void:
	_busy = false
	_action_name = ""
	action_finished.emit(clip_name)
	# the character goes back to standing still, or carries on walking
	_apply_locomotion()


func _on_player_camera_shake(amount: float) -> void:
	camera_shake_requested.emit(amount)
