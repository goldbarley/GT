class_name MageAnims
extends RefCounted

## The named animations the modular Mage can play.
##
## Every animation is its own clip file under `res://Mage/anim/clips`, so the
## game can trigger them as independent actions:
##
##     player.play(MageAnims.TELEPORT)          # the mage vanishes
##     player.play(MageAnims.TELEPORT_REAPPEAR)  # the mage comes back
##
## `MageChoreoPlayer.play()` takes the clip name, so these constants are just
## a single import point for the game rather than magic strings.

const IDLE := "mage_idle"
const CAST := "mage_cast"
const TELEPORT := "mage_teleport"
const TELEPORT_REAPPEAR := "mage_teleport_reappear"
const FIREBALL := "mage_fireball"
const BARRIER := "mage_energy_barrier"
const METEORITE := "mage_meteorite"
const WALK := "mage_walk"

const CLIPS_DIRECTORY := "res://Mage/anim/clips"


## Every animation the mage knows about, in a stable order.
static func all() -> Array[String]:
	return [IDLE, WALK, CAST, TELEPORT, TELEPORT_REAPPEAR, FIREBALL, BARRIER, METEORITE]


## The clip file an animation lives in.
static func clip_path(anim: String) -> String:
	return "%s/%s.json" % [CLIPS_DIRECTORY, anim]


## Plays a named animation on a player.
static func play(player: MageChoreoPlayer, anim: String) -> void:
	if player == null:
		push_error("MageAnims.play: no player given")
		return
	player.play(anim)


## Plays the teleport out, the mage vanishes.
static func teleport(player: MageChoreoPlayer) -> void:
	play(player, TELEPORT)


## Plays the teleport in, the mage reappears.
static func teleport_reappear(player: MageChoreoPlayer) -> void:
	play(player, TELEPORT_REAPPEAR)


## Plays the fireball cast.
static func fireball(player: MageChoreoPlayer) -> void:
	play(player, FIREBALL)


## Calls the meteorite down. The mage jumps, floats high on her own magic and
## brings a burning rock down on the ground beside her. The player asks the
## camera to shake while it falls, through `camera_shake_requested`.
static func meteorite(player: MageChoreoPlayer) -> void:
	play(player, METEORITE)


## Raises the energy barrier around the mage. The barrier stays up until it is
## dismissed with `MageChoreoPlayer.dismiss_effect()`.
static func barrier(player: MageChoreoPlayer) -> void:
	play(player, BARRIER)
