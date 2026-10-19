# GT — Battle Engine & Godot UI Integration Specification

**Version 1.0 | 19 October 2026 | Design handoff, not a completed implementation**  
**Companion:** `GT_Battle_API_Contract.cs`  
**Authority:** Decisions made in the game discussion through Question 42 override earlier drafts.  
**Legend:** **CONFIRMED** = explicitly decided; **PROPOSED** = implementation guidance requiring team approval; **OPEN** = not yet decided. In particular, do not mistake proposed defaults for game rules.

## 1. Design intent

Two opponents compete in a top-down, tile-grid, prediction-based combat game. They do **not** move freely during an exchange. During a private planning interval each player programs an indexed, fixed-length series of **steps** for every character on their team. A step is one cardinal move, one skill, a perk-supplied teleport, or an explicit `Wait`. They observe their own tentative movements and skill areas while entering the plan. During exchanges, two selected characters execute their previously programmed actions on the same global tick, and all characters remain physically present, vulnerable and persistent between exchanges. **CONFIRMED.**

A plan is a **reusable indexed array**, not a FIFO queue. The next exchange starts the selected character at its **current actual tile**, and replays the same array from index zero. New planning cycles can edit and reuse previous arrays. Positions and HP **never reset** on a new cycle. **CONFIRMED.**

## 2. Ownership and absolute integration boundary

| Authoritative battle engine (C#) | Godot visuals and UI |
|---|---|
| Real HP, positions, alive flags, terrain hazards and collision | Position sprites using engine-provided tile coordinates |
| Two players, their roster, unique character IDs, equipped perk | Screens, inputs, keyboard prompts and privacy hand-offs |
| Fixed-length plan arrays per character, skill registry, cooldowns | Show editable plan slots and pending hover/preview |
| Preview projection that ignores hidden enemy state | Render returned preview path and skill markings |
| Two-phase tick resolution, damage, defense, skill patterns | Render events and animate one finished tick at a time |
| Exchange/cycle progression; Defy Destiny snapshots and RNG | Offer rewind screen after seeing completed events |
| Hidden-information filtering and match statistics | Results screen with detailed statistics |

Do **not** implement damage, collision, valid terrain rules or active cooldown evaluation twice. The UI calls engine methods and renders results. The engine remains independent of Godot pixel coordinates and framerate. Godot's `SkyIslandGrid.tile_to_world(Vector2i(x,y))` is the visual conversion.

**Repository findings:** `BattleEngine.cs` currently only stores a map and a clock; it does not execute a combat tick. `Character.cs` and `SkillTable.cs` contain unfinished/inconsistent declarations; `Player.cs` is currently much narrower than the intended roster. `MapTable.cs` embeds incompatible terrain codes and dimensions compared to the `15 × 13` Sky Island JSON/GDScript visual map. Do not promise to the UI developer that these methods already exist. The interface file is the **new contract to implement**, not a drop-in patch to the incomplete classes.

## 3. Persistent model

- Exactly two teams with equal roster size **N** for the basic match. **PROPOSED:** require `2 <= N <= 4`; the team discussion mentioned 2–4 characters, while one current `Player` implementation hardcodes exactly two.
- Every character has a stable `CharacterId`, owner, class, HP/max HP, actual tile, alive flag, class-dependent plan length, an indexed `PlannedAction[]`, and its cooldown counters.
- Existing `CharacterClass` enum in code: `MAGE = 0`, `WARRIOR = 1`, `ARCHER = 2`, `ORC = 3`. Code's tentative required plan lengths: Mage 10, Warrior 15, Archer 20, Orc 7. **PROPOSED balance values**, not finalized class design.
- Team perks are unique: neither player can choose the same super perk. First picker is selected at random **once** at the start of the match. **CONFIRMED.**
- Each character's starting tile is chosen **once only**, before the first planning cycle, anywhere valid on the board, including the same tile as friendly characters. Walls, obstacles and pits are not legal initial tiles. No later repositioning phase exists. **CONFIRMED.**
- Position `(X,Y)` means `X` increases right, `Y` increases down. Terrain arrays index `[Y,X]`. **PROPOSED coordinate convention**, consistent with the existing Godot grid.
- Match ends when an entire team's characters are dead. Simultaneous full elimination is an official **draw**. Detailed statistics are shown after every ending, including a draw. **CONFIRMED.**

### Source-of-truth terrain

Use `data/sky_island_tilemap.json` as the chosen scene's terrain. Existing values: `0=Walkable, 1=Wall, 2=Pit, 3=Obstacle, 4=Stairs`; it is **15 rows × 13 columns**. The C# `MapElement` enum currently uses `2=Damage, 3=Killzone, 4=Attack-area`, **which is NOT equivalent**. Normalize through a loader/adapter. If the scene needs ordinary damage tiles, add a separate terrain type, e.g. `5=Damage`, to the data file. Never use a permanent terrain element to represent a temporary skill overlay.

## 4. Complete match flow

```text
Initial Placement (once) ──> Random perk draft (once)
                                  │
                                  ▼
                         Private Planning Cycle
               Player 0 plans / handoff / Player 1 plans
                    └─ Future Sight bonus, if present
                                  │
                                  ▼
                       Select one living character each
                                  │
                                  ▼
                         Exchange: tick 1, tick 2 ...
                       ├─ last-step Defy Destiny opportunity
                       ├─ tick-by-tick events / possible deaths
                       └─ until both sequences ended (unless match ends)
                                  │
                         Increment exchange counter
                   ┌──────────────┴────────────────┐
                   │                               │
             counter < N                      counter == N
                   │                               │
             Choose again                New private planning cycle
            (same actors OK)            (plans retained; cooldowns reset)
                   └───────────────┬───────────────┘
                                   │
                          Team fully dead? ──> Final report
```

**CONFIRMED:** A planning cycle runs **N exchanges**, where N is the number of characters in a team; selecting the same character every exchange is allowed. After N exchanges, a fresh planning phase begins. **The actual character positions are not reset and no one is forced to select unused characters.**

**CONFIRMED:** When one selected character finishes a shorter script, it stays stationary while its opponent completes the longer one. If one selected character dies, the survivor still completes its own remaining planned steps. Other living characters stay on the battlefield, receive damage, provide collision occupancy, and have cooldowns ticking globally. Total team elimination ends the match, except the eligible Defy Destiny final rewind window must resolve first.

**PROPOSED implementation:** Keep separate `CycleIndex`, `ExchangeIndex`, `ExchangeTick`, and **monotonically increasing** `GlobalTick` (global tick should not reset between exchanges, while `ExchangeTick` does). Decrement every living character's cooldown once per executed global battle tick. The old single private clock can evolve into this pair. Cooldowns **persist between exchanges**, but **reset to zero when a new planning phase begins**. No real-time cooldown changes while planning. **CONFIRMED.**

## 5. Private planning, live preview and couch multiplayer

Each player's ordinary planning time is **60 seconds**. Tactician owners get **120 seconds**. Planning is private: players see **only their own characters and terrain**, not even the opponents' actual current positions. The UI must show a privacy/handoff screen before giving the device to the other player. Players may edit their own characters only.

### Interactive editing semantics — critical

1. Select the character and step slot to edit. The **confirmed preview position** is the projected position after previously confirmed actions (starting from that character's **current actual tile**).
2. Press `Up/Down/Left/Right`, choose a skill/direction, or choose Teleport/distance. Immediately show a **pending action preview**: ghost position or marked affected skill tiles. **No step is stored yet.**
3. Press **Enter** to commit that action to the current plan slot. Only now update the **confirmed** preview timeline and advance the slot cursor.
4. Press a different action key before Enter to change only the pending preview. Editing an earlier slot recomputes all subsequent projected positions. Actual character state remains unchanged.
5. When the planning timer expires, discard the unconfirmed pending action, retain all Enter-confirmed changes and any saved slots from earlier cycles, and replace truly unfilled slots with `Wait`. **CONFIRMED.**

Preview must **ignore hidden enemy actors entirely**; it does not expose occupancy by leaking a blocked move. It can account for **known terrain and visible teammates**. Skill previews highlight intended positive attack and negative defense tiles, without telling the user whether an unseen enemy will be hit or whether a skill will execute under future cooldown conditions. All preview work operates on **copied/projected state**. It must not change actual HP, position, real cooldowns, real clock or event history. **CONFIRMED.**

**PROPOSED:** The normal UI preview shows the tentative action's endpoint/area and the confirmed ghost path; invalid wall/obstacle destinations remain in place with a warning. Do not try to predict enemy reaction, future collisions or unseen movement. UI timers may trigger `TryFinishPlanning` at expiry; the engine enforces whether editing is permitted in the current phase.

### Information security for hot-seat play

The engine's `ViewFor(playerId)` in a private planning or Future Sight phase must omit opponent character information, except **the specific plans disclosed by Future Sight**. Do not create a full snapshot and expect the UI to hide unauthorized fields. `VisiblePlan()` is owner-only unless Future Sight explicitly authorizes enemy plans; `TacticianRevealFor()` is a separate, narrower read. During public battle playback, all actual combatant positions and HP are visible.

## 6. Perks (gameplay-authoritative rules)

### Future Sight / King Crimson — CONFIRMED

- After both sides complete normal planning, its owner gets **20 additional seconds**.
- Can see the **complete preplanned sequence of every opposing character**.
- Can edit **any of their own characters' sequences**, using the same live preview and Enter-confirm flow.
- Opponent cannot edit or see the owner's private pending previews. After bonus ends, plans lock for the exchange cycle.

### Defy Destiny — CONFIRMED

- **One attempt per exchange**, not per match, for the owner. Its changed action applies **only in the current exchange**, never overwriting the reusable base plan.
- **After** viewing a fully resolved tick (including damage, movement and deaths), the owner can choose to rewind **the immediately previous tick** and replace **one action of their selected character**.
- Save the **entire pre-tick authoritative snapshot** (including HP, positions, cooldowns, alive flags, tick counters and statistics), plus the pair of originally submitted actions and any RNG state required to replay deterministically.
- Roll once: **70% success**, **30% failure**. Success restores pre-tick state then re-executes the **whole same tick** with the replacement own action and the unchanged opposing action; other actors' environmental effects and collisions also recalculate. Failure retains the original result unchanged. **The attempt is consumed in both cases.**
- If the just-resolved tick apparently eliminated a team, do **not** finalize the match until any eligible Defy Destiny opportunity has been offered/resolved. A successful rewind may prevent defeat. Failure retains the defeat.
- Replay must not count both the original outcome and replacement outcome toward match statistics. The final report counts the committed timeline and perk attempt once.

**PROPOSED UI API:** `AdvanceOneTick()` returns a `NeedsRewindDecision` flag. During `RewindDecision`, the UI displays the finished tick's events, then lets the eligible owner either attempt `TryDefyDestiny(owner, replacement)` or pass using `TryPassRewindDecision(owner)`. Do not automatically advance the next tick until the decision window closes. A consumed use cannot be offered twice during the exchange.

**OPEN:** If both teams have selected a different perk they cannot both have Defy Destiny, so only one rewind owner exists. Exact UX timeout for the decision screen is not yet chosen; make it configurable.

### Teleport — CONFIRMED

- Adds a teleport action to the owner's available planning steps.
- Teleport travels **any positive integer distance** in **one cardinal direction** (`Up`, `Down`, `Left`, `Right`).
- Ignores **intermediate** walls, obstacles and pits.
- Going **outside the map instantly kills the character**.
- The destination tile is evaluated normally for terrain/occupancy. **PROPOSED:** a wall/obstacle destination is blocked, a pit destination kills, and any enemy occupying the landing tile uses standard collision handling. The user confirmed intermediate traversal and out-of-bounds death, not every landing-edge case.

### Tactician — CONFIRMED

- Has **120 seconds** to plan, versus the standard 60.
- Reveals the **entire stored sequence of one randomly chosen enemy character** during battle.
- Does **not** grant the ability to change own sequences during the reveal.
- **OPEN:** Whether a new enemy character is randomly sampled once per exchange or once per cycle, and exactly when the reveal appears. **PROPOSED:** select once per planning cycle, display when the following exchange cycle begins, and hold it visible for that cycle. Seed the RNG for testability.

## 7. Combat actions and the step clock

The roster-wide **global battle tick** is the only measure used for cooldown progression, including inactive characters. Each `AdvanceOneTick()` resolves exactly **one** pair of planned actions (or `Wait` for a dead/exhausted actor), updating *all* relevant living characters on the board. Godot controls visual playback speed; the engine advances only when called.

**Cooldown rule — CONFIRMED:** a skill with cooldown `3` used on tick 1 may be used again on tick 5. Three complete intervening global ticks must pass. If an action arrives while its skill is still unavailable, it **does nothing but consumes the slot**; do not retroactively reject the planned sequence. Cooldowns for all characters decrease each battle tick, including when their character is inactive. Reset cooldowns to zero at the beginning of each new planning phase.

**Suggested bookkeeping:** store `nextAllowedGlobalTick` or countdown-with-clear-before-apply convention, and test: tick `t` use → unavailable at `t+1`, `t+2`, `t+3`, available at `t+4`. If the last use crosses a planning boundary, reset makes it immediately available. Cooldown is a **property of the living character/skill state**, not of the array or UI.

## 8. Damage and defense model

Each skill is a character-relative **pattern function** operating on an ephemeral signed numeric effect grid. Positive values represent attack potency for enemy occupants; negative values represent defense for friendly occupants. **No friendly fire.** Do not overwrite terrain with the effect grid. No reason to thread or queue these calculations: small tile arrays and loops are enough.

**CONFIRMED** rules:

- Damage from **one attack** is divided equally across **all enemy characters occupying its affected tile**. Round down separately for that attack. E.g. 11 over 3 occupants = 3 each. If two attacks hit, divide each attack independently, *then* sum per-character incoming damage.
- Defensive effects from multiple friendly skills affecting one tile **stack additively** and last for **that global tick only**.
- **Latest correction wins:** distribute each attack's damage among occupants **first**, sum the per-character received damage, then subtract stacked tile defense **separately for each individual character**. Example 20 AoE / 2 enemies with defense 6 = 4 damage to each.
- Defense reduces incoming **attack, collision and damaging-terrain** damage. Minimum final damage is zero.
- Pit death is categorical and **ignores defense**.

A consistent per-character expression (pending final implementation decisions on cross-effect event ordering):

```
attackDamageFor(c) = Σ over attacks A affecting tile(c)
                      floor(A.damageAtTile / numberOfEnemyOccupantsForA)
collisionDamageFor(c) = allocated collision damage
terrainDamageFor(c) = hazard amount if c began tick on damage terrain
finalDamage(c) = max(0, attackDamageFor(c) + collisionDamageFor(c)
                           + terrainDamageFor(c) - friendlyDefenseAt(c.tile))
```

**PROPOSED:** apply each tile's defense **once per character per tick** to its total summed incoming numeric damage (rather than reusing the defense independently against each source). This is consistent with the latest response, but the exact interaction between separate environmental, collision and attack sources was not specified. Settle this if mixed-source edge cases matter in the hackathon demo.

## 9. Movement and collisions

**CONFIRMED:** Every ordinary Move attempts a single tile in its chosen cardinal direction. A character can share a tile with one or more **allied** characters with no collision. **No friendly fire.** An enemy occupying a desired destination triggers a collision even if that enemy is **inactive** and stationary. Both take numeric collision damage, subject to defense; the incoming character does not enter. If two opponents simultaneously attempt to **swap** their occupied tiles, **both swaps succeed**.

**CONFIRMED multi-actor rule:** Each colliding character produces a fixed amount of collision damage (example: 5), distributed equally over its opposing collision participants; each recipient's share is rounded down. In the confirmed 2 allies vs. 1 enemy example, friendly Mage + Archer both enter the contested tile and each deal 5 to the Warrior: Warrior takes 10 and bounces back, while it deals 5 in total divided among the two: Mage and Archer take `floor(5/2) = 2` each. Defense can reduce collision damage. This is intentionally **not** a generic "everybody bounces" rule.

**OPEN:** Formal arbitration for 3+ simultaneous movers with more complex positions (cycles, multiple opposing claimants, enemies already sharing tiles, or a friendly entrant behind an enemy) is not determined by examples. Implement the above decided cases in tests; other shapes should have a deterministic, documented MVP rule rather than an invented claimed game decision.

## 10. Tick resolution ordering — partly decided

The following is a recommended implementation outline; see **OPEN** ordering point below.

1. Read the active selected pair's actions for the **current exchange index**, or `Wait` after their plan ends/death. Read the initial actual positions of **all** living characters. Preserve pre-tick snapshot for possible Defy Destiny.
2. **Apply damage from hazardous terrain at starting coordinates**, even if a character is about to move out. Applies to **all living characters**, including inactive actors, on every global tick. **CONFIRMED.**
3. Evaluate both intended movements simultaneously, including legal swaps and enemy/friendly occupancy. Commit successful moves, and generate collision events/damage according to section 9. **CONFIRMED** relative to subsequent skill attacks: movement first, then calculate attack effects using **updated positions**.
4. Resolve skill casts that are off cooldown and within the actor's class skill registry. Generate ephemeral signed area grids. **CONFIRMED:** skill attacks check targets' **positions after movement**, so moving away from an attacked tile can avoid a hit. Protect every friendly target on matching defense tiles for **this tick only**.
5. Distribute each separate attack over its enemy occupants, add numeric collisions/hazards, apply defense and HP, and remove dead entities from occupancy. Pits kill regardless of defense. Emit detailed events and update stats.
6. Advance global tick **exactly once** and compute remaining cooldowns. Return one read-only state snapshot plus events. Transition to post-tick rewind decision if eligible, otherwise move on or end exchange/match as appropriate.

**IMPORTANT OPEN EDGE CASE:** Earlier the designer decided *starting-tile hazard damage happens before movement*, but did **not** answer whether lethal hazard damage prevents the movement (Question 25). Also, a defense skill on the same tick protects against environmental damage, which can conflict with an overly literal "apply HP loss and death before skill calculation" ordering. **PROPOSED implementation:** sample hazards from starting coordinates, accumulate their damage, process movement/skill protection, then apply all numeric damage simultaneously. This honors the starting-tile rule and defensive protection but permits a lethally injured character's planned action to be resolved before its death is committed. Treat this as provisional until specifically confirmed. Do not silently claim it was decided.

**Other OPEN mechanics:** Does entering a pit kill immediately that tick even though environmental damage is based on starting tiles? **PROPOSED:** yes, categorical pit check after movement. When overlapping defense skills target allies who subsequently move away, determine protection using post-movement positions, consistent with attacks.

## 11. Public C# API and data transfer

See `GT_Battle_API_Contract.cs` for exact proposed names and signatures. These types are **declarations only**, designed to let the UI developer mock a backend before the real implementation exists.

### Critical facade calls

| Method | Allowed phase | Behavior |
|---|---|---|
| `ViewFor(viewer)` | all | Snapshot filtered for viewer and privacy |
| `TerrainCopy()` | all | Read-only-by-copy terrain, indexed `[y,x]` |
| `TryPlaceCharacter(...)` | Placement | Set one-time spawn, validating terrain and team |
| `TryChoosePerk(...)` | PerkDraft | Exclusively lock unique perk after first-picker order |
| `PreviewPending(...)` | Planning/FutureSight | Return ghost destination and skill-marked cells; **no mutation** |
| `TryConfirmAt(...,slot,action)` | Planning/FutureSight | Enter-to-confirm slot; update reusable planned sequence |
| `TryClearSlot(...)` | Planning/FutureSight | Clear edit, preserving other slots |
| `TryFinishPlanning(...)` | Planning | Lock confirmed slots, fill empty with Wait, discard pending |
| `VisiblePlan(...)` | Planning/FutureSight | Reveal own arrays, or opponent's under Future Sight |
| `TryFinishFutureSight(...)` | FutureSight | Lock editing window |
| `TrySelectForExchange(...)` | Selection | Choose any living character, repeats permitted |
| `TryStartExchange()` | Selection | Reset **exchange index** only, preserve actual states |
| `AdvanceOneTick()` | Playback | Calculate one global tick and events |
| `TryDefyDestiny(...)` | RewindDecision | 70% replay, 30% original, both consume attempt |
| `TryPassRewindDecision(...)` | RewindDecision | Accept last step as-is and continue |
| `FinalReport()` | Finished | Immutable structured match statistics |

**Request/response shape:** `PlannedAction` includes kind, direction, optional `SkillId`, optional skill length, and Teleport distance. `DraftPreview` contains the prior confirmed ghost position, pending ghost position, skill affected tiles and warnings. `TickOutcome` returns a chronologically stable collection of `BattleEvent` records, a filtered `MatchView`, and flags for exchange end/rewind decision. `MatchReport` includes both teams' aggregate and per-character statistics. All mutators that can fail return `false` with a reason and must leave state unchanged.

**Security rule:** `ViewFor()` in private planning **must not include enemy characters at all**, not merely hide their future moves. Nor may `DraftPreview` expose hidden enemy occupancy through its success/failure or warnings.

### Typical UI calls

```csharp
// Pseudocode: interface declarations, not running implementation.
// 1) On an arrow key press, render a tentative movement:
var proposal = new PlannedAction(StepKind.Move, Cardinal.Up);
var draft = engine.PreviewPending(playerId, selectedCharacterId, proposal);
ShowGhost(draft.PendingPosition);            // no real-state mutation
ShowPattern(draft.AffectedTiles);

// 2) On Enter, store exactly one step:
if (!engine.TryConfirmAt(playerId, selectedCharacterId, slot, proposal, out var error))
    ShowError(error);

// 3) During playback, advance only after prior animations finish:
TickOutcome tick = engine.AdvanceOneTick();
Animate(tick.Events);
UpdateHud(tick.View);
// If tick.NeedsRewindDecision, prompt before making another AdvanceOneTick call.
```

In the actual Godot script, use signal/animation completion or an async state machine; **do not block** Godot's main frame loop with a `while` loop.

## 12. Skill pattern interface / simplifying the codebase

The original design intent is appropriate: one pattern function receives caster coordinates, direction, optional length and a mutable **temporary** signed integer grid, then marks relevant cells. A registry stores available skills **per class**. The engine knows which skill ID is being called and centrally applies cooldowns/targeting and resulting HP changes. It needn't expose separate "Get" and "Update" entrypoints for every attack.

```csharp
public delegate void SkillPattern(int x, int y, Cardinal direction,
                                  int length, int[,] signedEffectGrid);
```

A `SkillDefinition` supplies the cooldown value before the pattern runs. The pattern must never edit permanent terrain or living characters directly. Enforce bounds centrally. Do not mix the signed attack pattern grid with the terrain enum or use a single global signed grid in a way that cancels unrelated offense/defense contributions.

**Data structure choice:** `PlannedAction[]` (one fixed-length array per character). Access `steps[exchangeTick]`. Editing a slot is O(1); replay starts index 0 without copying a queue; revisions and snapshots work naturally. A queue offers no advantages here. For the MVP avoid custom threading, custom FIFOs and premature async combat jobs.

## 13. Statistics

Always report both a team breakdown and individual character breakdown. Keep counters in the authoritative engine and reconcile them on Defy Destiny rewind. Recommended fields (some counting definitions are PROPOSED until implemented):

- **Player/team:** actual damage dealt, taken and blocked; total global ticks, exchanges completed; perk activations, successes, failures; kills and losses.
- **Per character:** attempts/steps executed, tiles travelled, attack/defense uses, hits, skills skipped by cooldown, damage contributed, received and prevented, collisions, kills, death status.
- **Report:** official winner or draw; visible explanation of mutual elimination. Never decide a non-draw winner using the statistics; they are for players' own judgment.

Definitions to standardize: `damage dealt` should count **actual HP removed**, not theoretical attack value before defense; damage blocked should count actual prevented HP loss; `steps executed` should count resolved non-wait action attempts even when blocked or on cooldown. **PROPOSED** and testable.

## 14. Minimum acceptance tests

1. **Original and current coordinates:** choose spawn tile once; movement persists through repeats and new planning. Two identical replays start at different actual positions.
2. **Array reuse:** same character selected in all N exchanges; original indexed plan preserved. Next cycle shows old plan for edits.
3. **Preview:** arrow updates ghost instantly, Enter writes one slot, changing proposal discards unconfirmed state; no actual HP or coordinates change. Enemy actual positions are hidden and do not obstruct preview.
4. **Planning timeout:** previous saved slots and confirmed changes survive; unconfirmed action discarded; empty slots become Wait.
5. **Cooldown:** skill cooldown 3 used at global tick `t` is usable at `t+4`; ticks from other characters' exchanges count; subsequent planning cycle resets all cooldowns; invalid action executes as Wait.
6. **Collision:** a two-character swap succeeds; moving into stationary inactive enemy bounces and damages both; allied overlap is allowed; 2 allies vs 1 enemy damages are `[2,2,10]` at base collision 5.
7. **Skill/defense:** one attack of 20 on a tile with two enemies and defense 6 causes 4 to each; two independent attacks divide and floor independently; multiple defensive patterns stack for one tick.
8. **Terrain:** damages every tick while occupant is standing on damage terrain, even if inactive; starting-tile damage applies when character moves away; pits bypass numeric defenses.
9. **Unequal scripts and death:** exhausted actor Waits while longer other script continues; death removes occupancy immediately; surviving selected actor completes its remaining script unless a whole team is eliminated.
10. **Defy Destiny:** full pre-tick snapshot restore; replacement only for replayed tick; 70/30 seeded test; failures preserve old outcome; use consumed regardless; original planned array unchanged; statistics not double-counted; final defeat can be reversed.
11. **Future Sight:** only 20-second owner may read every enemy plan and edit any of their own; other viewer can't.
12. **Teleport:** arbitrary cardinal distance, traversal ignores obstacles, out-of-bounds arrival instantly kills.
13. **Tactician:** exactly 120-second planning; reveal full plan of one engine-chosen random enemy character; no edit entitlement.
14. **Privacy:** during planning `ViewFor(viewer)` contains **zero opposing `CharacterView`s**, even though actual engine state still has them.
15. **Result:** both sides wiped in same tick => draw after rewind rights expire; detailed stats always returned.

## 15. Team deliverables and staged integration

**Stage 1 — compile and contract:** agree on IDs/DTOs/interface names, load the JSON map, create initial `ViewFor()` and `PreviewPending()` mock results. Teammate can begin Godot controls immediately.

**Stage 2 — playable engine:** persistent team/character state, plans in fixed arrays, placement, moving, attack and defense, collisions, hazards, global clock, cycles/exchanges, snapshots/events.

**Stage 3 — super perks:** Future Sight private plan authorization, teleport, 120-second Tactician and random full-plan reveal, Defy Destiny snapshot/rewind/RNG. Verify match-finalization delay.

**Stage 4 — finish:** statistics, sound and visual feedback, couch hand-offs, automated edge-case tests and a full two-player demo.

### Remaining real ambiguities (do not hide them)

1. **Lethal starting-tile damage:** Does a character killed by the starting hazard execute its movement/skill before dying? (Question 25 never answered.)
2. **Tactician reveal timing:** random opponent character once per planning cycle, per exchange or match; exact display time.
3. **Teleport landing:** wall/obstacle destination, pit destination and enemy-occupied landing; above defaults are proposed.
4. **Multiple sources of damage:** is tile defense applied once to aggregated per-character attack+collision+terrain damage, or once separately for each source? Latest decision establishes **after attack distribution**, but mixed sources aren't explicitly addressed.
5. **Complex multi-character collision arbitration:** only given cases are authoritative; generalized algorithm still needs a deterministic rule.
6. **Exact balance inputs:** per-class HP/step counts, skill range/pattern/cooldown/damage, environmental and base collision damage. Base collision 5 appeared in confirmed examples; treat it as a suggested balance constant rather than fixed by initial design.
7. **Rewind prompt duration and finalization:** how long to leave the rewind decision open after each tick. Also exact behavior if both teams are eliminated and an eligible rewind exists.
8. **Initial setup sequencing:** whether perk draft precedes initial placement or vice versa is not specified; this document places it after placement as a proposed UI order.

These are not blockers for building most of the contract and UI. Where a default is necessary, document it in code and tests, and do not portray it as user-confirmed.
