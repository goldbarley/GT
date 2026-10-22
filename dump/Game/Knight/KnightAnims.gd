class_name KnightAnims
extends RefCounted

## The named animations the modular Knight can play.
##
## Every animation is its own clip file under `res://Knight/Anim/clips`, so the
## game can trigger them as independent actions:
##
##     player.play(KnightAnims.WALK)    # the walk cycle
##
## `KnightChoreoPlayer.play()` takes the clip name, so these constants are
## just a single import point for the game rather than magic strings.

const IDLE := "knight_idle"
const WALK := "knight_walk"
const SLASH := "knight_slash"
const STAB := "knight_stab"
const PLUNGE := "knight_plunge"
## The Knight's ultimate attack, one tile of ground.
const ULTIMATE := "knight_ultimate"

const CLIPS_DIRECTORY := "res://Knight/Anim/clips"


## Every animation the Knight knows about, in a stable order.
static func all() -> Array[String]:
	return [IDLE, WALK, SLASH, STAB, PLUNGE, ULTIMATE]


## The clip file an animation lives in.
static func clip_path(anim: String) -> String:
	return "%s/%s.json" % [CLIPS_DIRECTORY, anim]
