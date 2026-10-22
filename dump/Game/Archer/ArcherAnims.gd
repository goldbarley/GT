class_name ArcherAnims
extends RefCounted

## The named animations the modular Archer can play.
##
## Every animation is its own clip file under `res://Archer/anim/clips`, so the
## game can trigger them as independent actions:
##
##     player.play(ArcherAnims.WALK)    # the walk cycle
##
## `ArcherChoreoPlayer.play()` takes the clip name, so these constants are
## just a single import point for the game rather than magic strings.

const IDLE := "archer_idle"
const WALK := "archer_walk"
## Basic attack: raises arm with upright bow -> Frame 10 glow -> Frame 11 burst -> arrow fires straight.
const BASIC_ATTACK := "archer_basic_attack"
## Quick shot: the archer raises the bow, draws swiftly, and releases an arrow.
const SKILL := "archer_skill"
## Power shot: deep stance, heavy draw tension, releasing a charged energy arrow.
const STRONG_SKILL := "archer_strong_skill"
## The godray charge: the energy gathers on the bow, spirals, opens into a
## great energy bow, is drawn back and held, and then the beam is let go.  The
## beam leaves on the clip's impact.
const CHARGED_SHOT := "archer_charged_shot"

const CLIPS_DIRECTORY := "res://Archer/anim/clips"


## Every animation the archer knows about, in a stable order.
static func all() -> Array[String]:
	return [IDLE, WALK, BASIC_ATTACK, SKILL, STRONG_SKILL, CHARGED_SHOT]


## The clip file an animation lives in.
static func clip_path(anim: String) -> String:
	return "%s/%s.json" % [CLIPS_DIRECTORY, anim]
