# GT engine implementation notes

The files under `scripts/` replace the scripts in the supplied repository dump. The original `BattleEngine` is still a **static class**, the original `Player`/`Character`/`IVector2`/`MapTable` structure is retained, and no FIFO queue is used for battle steps.

## Step encoding

- `0`: end of sequence; no more steps from this slot onward.
- `1`, `2`, `3`, `4`: up, down, left, right; one tile per tick.
- `5`: teleport, only for a player with the Teleport perk.
- `-1`, `-2`, etc.: `SkillTable.skills[class][Math.Abs(step)-1]`.
- Each character has `int[] steps`, `int[] directions` and `IVector2[] lengths`, all the same fixed length. `directions` is 1..4. For teleport, `lengths[slot].x` is the distance (positive integer). Skill patterns use the length vector and direction.
- Coordinate convention is the existing project convention: `map[x,y]` with `x = row`, `y = column`.

## Engine call order

1. `BattleEngine.setupEngine(mapIndex, optionalSeed)`.
2. `BattleEngine.setupPlayer(1, count, types, steps, positions, perk, optionalDirections, optionalLengths)` and likewise player `2`. Each team has **1–3** unique character classes, matching the original `Player` constructor's stated intended limit. Teams cannot overlap at spawn.
3. UI edits slots with `BattleEngine.setStep(playerNumber, characterIndex, slot, step, direction, length)`. `previewPosition` projects saved moves without mutating actual state or exposing opponents.
4. `BattleEngine.finishPlanning(1)` and `finishPlanning(2)`. For King Crimson, call `getVisibleOpponentSteps(owner)` during the bonus window, then `finishFutureSight(owner)`.
5. `selectCharacter(1, index)`, `selectCharacter(2, index)`, `startExchange()`.
6. `advanceOneTick()` exactly once per combat tick. When `needsRewindDecision()` is true, call either `passRewindDecision(defyOwner)` or `tryDefyDestiny(defyOwner, replacementStep, direction, length)` **before** advancing again.
7. The engine automatically ends an exchange when both selected sequences end. Select characters again for the next exchange. After the number of exchanges equal to player 1's roster size, a new planning cycle begins; saved plans/positions/HP persist and cooldowns reset.

`getOutcome()` returns 0 ongoing, 1 player 1 win, 2 player 2 win, 3 draw. `getDetails()` gives a deep-copy state; `getMatchStart()` gives the head of the linked pre-tick snapshot history.

## Rewind

- Every tick appends a **deep pre-tick snapshot** to a doubly linked list.
- `currState` updates after each tick, including a rewind replay.
- Defy Destiny is a 70% attempt once per exchange, offered **after** viewing the completed tick. A success restores the immediately preceding snapshot, removes the abandoned branch, and replays the same tick with the changed action. The permanent saved plan remains unchanged.
- `defyUsed` deliberately lives outside snapshot restoration, so loading a snapshot never refunds a rewind attempt. The PRNG is restored on rewind, then advanced past the Defy success roll to avoid rerolling that decision.

## Default balance

- Mage 75 HP, Warrior 120, Archer 100, Orc 200.
- Collision 5 per colliding actor; damage terrain 8 per tick; pits and invalid teleport landings instantly kill, ignoring defense.
- Mage skills by index: Fireball (15, chosen cardinal distance, cooldown 1); Shield (-20 on self, cooldown 1); Meteorite (20 on 3x3 at chosen distance, cooldown 3); Quad Beam (10 on each of four diagonal rays, 4 tiles long, cooldown 3).
- Warrior/Knight skills by index: Slash (20, distance 1, cooldown 0); Stab (30, distance 2, cooldown 1); Plunge (15 on 3x3 at distance 2 or 3, cooldown 3); Knight's Edge (25, distance 2, cooldown 2); Shield (-30 on self, cooldown 2).
- Archer skills by index: Basic (18, distance 3, cooldown 1); Double Shot (15 on each of two consecutive cells at distances 4 and 5, cooldown 2); Piercing Ultimate (10 on every tile along the chosen cardinal ray to map edge, cooldown 4).
- Orc skills unchanged: Smash (28), Area (20), Guard (-25).
- Skill `directions` are 1..4 (up/down/left/right). Chosen-distance skills read `length.x` for vertical casts and `length.y` for horizontal casts; omitted/default values mean distance 1. Mage Quad Beam ignores direction and targets all four diagonals.
- The animation notes do not specify exact damage/cooldowns, whether Archer's 2 targets means two actors or two tiles, or Knight's shield details. These are provisional values/interpretations. No actor-aware targeting was added to SkillTable, which only receives an effect grid.
- IMPORTANT: The skill arrays were reordered to match the animation descriptions. Previously stored negative skill step indices have different meanings and must be reviewed.
- Skill cooldowns are the integers returned by their pattern functions. A cooldown of 3 means t+1,t+2,t+3 are unavailable, and t+4 is ready. Teleport cooldown 1 global tick.

## Scope and limitations

- This is a source-level implementation, **not a verified Godot build**: `dotnet` and Godot are unavailable in the execution environment. Run `dotnet build` in your actual project and fix any version-specific Godot SDK errors.
- The supplied repository dump **does not contain** `Floating_Sky_Island.png`, `scripts/SkyIslandGrid.gd` or `icon.svg`, which the Godot scene references. The project zip cannot launch that scene without restoring these assets from the original repository. The separate scripts zip is intended for applying to your existing checkout.
- The UI owns timer enforcement, handoff/privacy presentation, sprite rendering, and deciding when King Crimson/Tactician information is shown. The engine's `getPlayer` gives direct references; the UI must not expose it during hidden-information phases.
- Damage, movement, basic collisions, cooldowns, four perks, snapshots and simple terrain effects are implemented. Complex multi-character contested-tile arbitration beyond the two active actors, a full combat-statistics report, and dedicated unit tests are **not** included. They should be tested before treating the engine as production-ready.
- The original `Queue.cs` remains unchanged but is not used by the battle engine.

## Spawn halves and visible initial positions

- Player 1 can spawn only in rows 0 through 7; Player 2 only in rows 8 through 14 on the 15-row Sky Island map. For other map heights, Player 1 gets the first `(rows + 1) / 2` rows, and Player 2 gets the remainder. Row is `IVector2.x` in the existing engine. Walls, pits and out-of-bounds locations are still invalid. Friendly stacking remains permitted.
- `BattleEngine.getOpponentSpawnPositions(uint player)` returns a defensive copy of the opponent's initial spawn coordinates (or an empty array until the opponent is configured). The UI can show these during planning as an anchor, without exposing live enemy locations.
- `setupEngine()` clears saved spawn positions. `loadSnapshot()` deliberately does not modify them, because initial spawn coordinates never change.
- Unnecessary inline and explanatory comments were removed from active scripts. The unused `Queue.cs` is preserved unchanged.
