# GT Battle Engine — Prescriptive Implementation Specification
**Version:** 1.0 · 19 October 2026  
**Audience:** Engineer implementing the C# battle engine  
**Purpose:** Specify exactly what to build, what to avoid, how the engine runs, and how its behavior will be accepted.  
**Companions:** `GT_Battle_Engine_API_Spec.md` (gameplay rules); `GT_Battle_API_Contract.cs` (public integration surface).

> **Read this first.** The game designer is delegating **implementation**, not redesign. Follow the established gameplay rules. Do not add features, structures, alternate battle algorithms, queues, multi-threaded combat, new movement models, or public methods merely because they seem architecturally elegant. If something genuinely cannot be implemented as stated, communicate the specific problem and a minimal proposed fix **before** changing the contract.

## 0. Authority, scope, and definitions

Priority if documents disagree:
1. Most recent explicit gameplay decision from the designer.
2. Rules designated **CONFIRMED** in the companion gameplay specification.
3. This document's **Implementation defaults**, only where the designer has not decided a rule.
4. Old code / old comments / earlier WhatsApp brainstorming.

**CONFIRMED** = game-design rule. **REQUIRED IMPLEMENTATION** = implementation constraint for this handoff. **DEFAULT / OPEN** = deterministic placeholder that must be documented and may require designer approval. Never quietly promote DEFAULT to CONFIRMED.

### Deliverable

Produce a testable C# battle engine that:
- Accepts a loaded square-grid map and two player rosters.
- Owns current positions, HP, plans, cooldowns, exchange/cycle progress and match outcome.
- Supports private initial placement and private step-by-step planning with **key-to-preview, Enter-to-confirm**.
- Supports two simultaneously selected characters per exchange and all characters remaining on the board.
- Resolves **one discrete global tick per method call**, not via a real-time game loop or threads.
- Supports all four perk behaviors, including **one-step global rewind and deterministic replay**.
- Returns **read-only, privacy-filtered views**, previews, tick events and a detailed final report to Godot.
- Passes deterministic headless tests without Godot graphics loaded.

No file should have to call into scene nodes to compute battle outcomes.

## 1. Source files and ownership — exact structure

Keep the structure shallow. You may reorganize the incomplete old implementation, but **do not** create separate Mage/Archer/Warrior classes or a web of interfaces unless a real need is demonstrated.

| File / unit | Owns | Explicitly does NOT own |
|---|---|---|
| `BattleEngine.cs` | Public facade, match phase machine, controlled state mutations, global/exchange clock, tick orchestration, rewind window, victory | Godot sprites, input keys, pixel positions |
| `Player.cs` | Player/team ID, character IDs, chosen perk | Damage calculation, planning UI |
| `Character.cs` | Class, HP, actual grid position, alive flag, fixed-length `PlannedAction[]`, per-skill cooldown state | Scanning Godot map, arbitrating collisions, advancing global clock |
| `MapTable.cs` or `TerrainGrid.cs` | Immutable tile matrix + tile queries, map dimensions and bounds | Attack overlays or dynamically mutating terrain as a side effect of attacks |
| `SkillTable.cs` | Static skill definitions and **pattern functions** | Character HP, global phase, cooldown progression, encounter-wide rules |
| `BattleTypes.cs` | Public DTOs/enums **matching contract** | Hidden mutable engine references |
| `BattleResolver.cs` *(optional)* | Pure-ish single-tick helper to keep `BattleEngine` readable | Its own independently changing engine state |
| `BattleStats.cs` *(optional)* | Stats counters / snapshot-copy utilities | Calculating HP from stats, determining winner |
| `BattleEngineTests` | Headless deterministic scenario tests | Production logic |

**REQUIRED IMPLEMENTATION:** `IBattleEngine` stays the single public facade. Internal helper methods are private/internal, not alternate public combat APIs. The Godot developer should never need to read or mutate `Character.Steps` or `BattleEngine` fields directly.

### What to remove / stop working on

- `Queue.cs`, custom FIFO, linked-list attack buffers or mailbox code **must not be part of the battle execution path**. It can be deleted if unreferenced; do not leave a live shadow implementation.
- No thread pool, worker queues, background attack calculations or locks. This is a small **deterministic grid simulation**, not a high-throughput messaging service.
- No physics collision detection through Godot engine nodes; collisions use integer tile coordinates.
- Do not overwrite `MapElement` with temporary attack cells. Do not mix `Damage=2` from the old C# enum with `Pit=2` from the actual JSON.
- No independent runtime `GetAttack/UpdateAttack` pair for each skill if a single registered pattern function suffices.
- Do not let the skill pattern function apply damage directly, move an actor, decide team membership, or decrement cooldown.
- Do not create an AI opponent, network multiplayer, item inventory, equipment system, hitbox physics, projectiles with per-frame updates, or unrelated features.

## 2. Storage layout and invariants

Suggested *internal* representation (implementation detail, not a new API):

```csharp
private readonly TerrainTile[,] _terrain;          // [row, column] = [Y, X]
private readonly Player[] _players = new Player[2];
private readonly Dictionary<int, Character> _byId;
private readonly Random _rng;                     // Inject deterministic seed
private int _globalTick;                          // Increments on each real resolved tick
private int _exchangeTick;                        // Zero-based action array index
private int _exchangeNumberInCycle;               // 0 .. roster size
private int _cycleNumber;
private MatchPhase _phase;
```

Each `Character` contains:
```csharp
public int Id { get; }
public int OwnerId { get; }
public CharacterClass Class { get; }
public Cell ActualPosition { get; private set; }
public int Hp { get; private set; }
public int MaxHp { get; }
public PlannedAction[] Plan { get; }  // fixed length, one sequence reused each exchange
// Store cooldown count OR nextAllowedTick for each SkillId, not both as competing truth.
```

**Required invariants:**
1. Exactly two player IDs (`0` and `1`), each character belongs to exactly one team and has a globally unique ID.
2. Authoritative `ActualPosition` and HP can change **only** through engine-controlled setup / tick mutations. Planning previews never change them.
3. Character plans are fixed-length indexed arrays. Running a plan **reads** `Plan[exchangeTick]`; it does not dequeue, shift or erase a slot.
4. Every exchange begins reading each selected character's array at **index zero**, but at their **current actual position** with current HP and current cooldown state.
5. The same living character may be selected in several exchanges. No `IsSpent` flag.
6. At the start of a **new planning phase**, preserve HP, positions and plans, but clear **all skill cooldowns**.
7. Every advanced global combat tick progresses **all** skill cooldowns of **all living characters**, including inactive ones.
8. Private `ViewFor(playerId)` never includes the other team's characters during planning.
9. Snapshots returned to Godot are copies/immutable DTOs, never writable live references or aliased arrays.
10. `AdvanceOneTick()` performs exactly one resolution from one starting state, records exactly one committed tick, and cannot run twice for the same tick while the rewind decision is unresolved.
11. Exactly **N exchanges per planning cycle**, where N is roster size. Repeat selection is legal.
12. Match ends only on a team's complete elimination (both teams eliminated = draw), subject to any available Defy Destiny rewind opportunity.

## 3. Map implementation

**Use the repository's `data/sky_island_tilemap.json` as authoritative terrain for Sky Island**:
- 15 rows, 13 columns; `[Y,X]`; X right, Y down.
- `0` ground/walkable; `1` wall; `2` pit; `3` obstacle; `4` stairs/walkable.
- The original C# map enum conflicts with these values. **Do not cast old `MapElement` directly** onto loaded JSON values. Either replace the old enum or provide an explicit converter.
- Add a distinct terrain code e.g. `5` for nonlethal damaging terrain when needed. `2` always means pit in this map.
- Arrays for skill effects have **identical dimensions** to terrain and default to zero.
- Out-of-bounds normal Move is blocked; **Teleport beyond map is instant death**.
- At initial spawn selection, reject walls, obstacles, pits, and out-of-bounds. Allied occupancy is allowed.
- Do not use world pixels (`24`, `.tscn` dimensions, etc.) for combat; Godot's grid code maps `Cell(X,Y)` to pixels.

For performance, direct `[,]` indexed loops are sufficient. No raycast, vector-rotation framework or spatial partitioning required for current cardinal patterns.

## 4. Match phase machine and legal methods

**Proposed exact phase transition order** (setup order is **DEFAULT** because not authoritatively chosen): 

```text
Placement (once)
 -> PerkDraft (random first picker; unique choice for each player)
 -> Planning (private player 0 / handoff / private player 1)
 -> FutureSight (if selected; 20-second edit and reveal)
 -> Selection (one living character from each team)
 -> Playback (tick-by-tick)
 -> RewindDecision (only when eligible; after a completed tick)
 -> Playback ... until exchange ends
 -> Selection if fewer than N completed exchanges in cycle
 -> Planning (retain plans, HP, positions; reset cooldowns) if N complete
 -> Finished only on elimination / draw, after eligible rewind
```

Do not let a single UI button change an arbitrary phase directly. Implement explicit `Try...` mutations that check `_phase`, acting player and prerequisites and return an error without partial state changes.

**Required matching facade methods:**

- Setup: `TryPlaceCharacter`, `TryLockPlacement`, `TryChoosePerk`.
- Read: `ViewFor`, `TerrainCopy`, `SkillsFor`, `VisiblePlan`, `SelectableCharacters`, `PlanningSecondsFor`, `TacticianRevealFor`, `FinalReport`.
- Planning: `PreviewPending`, `TryConfirmAt`, `TryClearSlot`, `TryFinishPlanning`, `TryFinishFutureSight`.
- Exchange: `TrySelectForExchange`, `TryStartExchange`, `AdvanceOneTick`.
- Rewind: `TryDefyDestiny`, `TryPassRewindDecision`.

Names and return DTOs must align to the actual committed `GT_Battle_API_Contract.cs`; if a name change is required, change the contract in a separate reviewed commit **before** implementing the incompatible signature.

### Time handling

- A normal player gets **60 s** for planning. Tactician gets **120 s**. Future Sight gets an extra **20 s**.
- **UI owns wall-clock countdown display/input lock.** Engine owns game phase and whether a submitted action is accepted. There is **no `Thread.Sleep`, timer loop, or frame delta** inside damage calculation.
- At timer expiry, UI calls `TryFinishPlanning` / `TryFinishFutureSight`. If an action has only been previewed but not Enter-confirmed, it is discarded automatically because previews are never stored.
- Empty slots become `Wait`, existing confirmed plan slots remain.

## 5. Planning: two separate states, never mutate real combat

**Required UX:** pressing an action key immediately renders the potential movement or affected skill tiles; pressing **Enter** commits one step. Characters move *only as ghost/preview sprites* during planning.

For each character maintain (or derive):
1. Real `ActualPosition`.
2. Projected `ConfirmedPosition` after confirmed earlier plan slots.
3. Projected `PendingPosition`/affected tiles after the currently highlighted action (before Enter).

Call design:
- `PreviewPending(playerId, characterId, pendingAction)` is **read-only**. It recomputes the projected state from the real current position using saved plan steps, replacing the pending slot virtually for display.
- `TryConfirmAt(playerId, characterId, slot, action, out error)` commits exactly that one array cell and no other combat state.
- After changing an earlier slot, recompute the preview path from the start; do **not** add displacement on top of a previously previewed endpoint.
- Preview terrain/known friendly obstacles only. **Ignore all enemy actor positions**, whether or not they're technically known to engine memory. They must not indirectly leak through blocked-move warnings.
- Attack preview marks the predicted area; it does not simulate opponents' future movement or promise a hit. It does not need to mutate or decrement real cooldowns.
- A selected teleport action previews the exact intended landing cell along a cardinal line; if landing is outside map, explicitly show fatal risk without killing the actual character.
- The renderer shows owner characters only in private planning. A player cannot read the opponent's private plan through the ordinary plan-query method.
- On next planning cycle, begin by showing saved plans (not empty new ones) and calculate ghost paths starting from **new current actual positions**.

**REQUIRED:** Preview calculations must be *referentially safe*: calling preview 50 times produces no actual state changes, cooldown changes, RNG changes, event emissions or stats increments.

**UI detail:** The interface need not store a persistent "pending action" on the engine. It can hold pending key selection locally, call preview on every key selection and commit on Enter. That is the simplest design.

## 6. Cooldown implementation — global, persistent within cycle

**CONFIRMED:**
- Cooldown measured in whole **global combat ticks**, including ticks in exchanges with that character inactive.
- If skill used on global tick `t` and cooldown is 3, it cannot be used on ticks `t+1`, `t+2`, `t+3`; next legal use is `t+4`.
- If a queued skill appears while unavailable, the slot is **consumed**, and the actor **does nothing** (with `SkillOnCooldown` event).
- Cooldowns survive between exchanges; reset to ready when a **new planning phase** begins.
- Planning time itself does not count toward cooldown.

**Recommended implementation:**

```csharp
// _globalTick is zero-based index of the tick ABOUT TO RESOLVE.
// nextAllowedTick is initialized to 0.
if (_globalTick < actor.NextAllowedTick(skillId)) {
    Emit(SkillOnCooldown);
    // No skill effect; still consumes this actor's step.
} else {
    ApplySkill(...);
    actor.SetNextAllowedTick(skillId,
        _globalTick + skill.CooldownInTicks + 1);
}
```

Using the absolute global tick avoids accidentally decrementing new cooldowns on their activation tick; it also handles inactive characters automatically. On a new planning cycle set next-allowed values to the current `_globalTick`. **One global tick counter, not one clock per character.**

**Never validate and reject a saved plan merely because it contains skills that are on cooldown.** Failure occurs at playback, not at plan entry; that unpredictability is a game rule.

## 7. Step resolver — mandatory order and design

**MANDATORY design goal:** Do not resolve `Player 0` fully and then `Player 1`. Always read both proposed actions against a consistent **pre-step snapshot**, gather intents, and commit effects in deterministic stages.

### Suggested internal types

```csharp
record ActionIntent(int ActorId, PlannedAction Action,
                    Cell From, Cell IntendedTo);
record AppliedEffect(int OwnerPlayerId, string SkillId,
                     Cell Tile, int SignedAmount);
```

### Single `AdvanceOneTick()` behavior

```text
0. Assert phase allows playback and no unresolved rewind prompt.
1. Capture deep pre-tick snapshot (for Defy Destiny); read selected actors' plan[index] or Wait.
2. Determine each character's start-of-tick tile; mark start-of-tick damaging terrain for ALL living actors, active or inactive.
3. Plan both selected movements / teleports without changing actor positions.
4. Resolve simultaneous movement permissions and collision participant sets.
5. Commit successful movement simultaneously; handle pits, out-of-bounds teleport death and occupancy changes.
6. Generate eligible skill patterns from eligible live active casters, positioned at their current post-move coordinates.
7. From each separate attack pattern, independently split per-tile damage among enemy occupants (floor division).
8. Aggregate per-character attack + collision + starting-terrain numeric damage, compute stacked friendly defense at each recipient's post-move tile, subtract that defense per character, clamp to zero.
9. Apply HP/deaths, remove dead characters from logical occupancy immediately, update deterministic combat statistics and return events in stable order.
10. Increment _globalTick and _exchangeTick exactly once; update phase/exchange outcome and open eligible post-tick rewind decision.
11. Return TickOutcome with filtered state and events. UI decides animation duration, not engine.
```

**IMPORTANT: step 2 identifies the starting hazard before movement, but whether lethal hazard damage prevents movement was not decided.** Do not silently decide this is CONFIRMED. For a deterministic MVP use **DEFAULT H1**: compute all numeric damage and deaths at step 9, so an actor may move but still die from starting-tile damage. Request designer approval if that precise edge case is important.

### No double-application

- An active character contributes at most **one** planned action per tick.
- A dead or exhausted selected character contributes `Wait`.
- An inactive character contributes **no action** but stays on board, receives hazards/attacks/collisions, and cooldown advances in global time.
- Each collision and each attack source must be accounted exactly once.
- Each tick increments the global clock exactly once.
- If both selected action arrays are exhausted at the end of a tick, end that exchange, **not** the match unless a team is dead.

### Exchange completion

- Exchange length = `max(selectedA.Plan.Length, selectedB.Plan.Length)` in the normal case.
- If the shorter sequence ends, its character remains stationary, exposed to damage/hazards/collisions; the longer continues.
- If an active character dies, the living active one continues its steps; no substitute fighter appears mid-exchange.
- Entire side eliminated -> provisional ending until Defy Destiny opportunity is accepted/declined.
- Exchange count increments only when an exchange **commits as ended**. After N completed exchanges, begin another planning cycle, retain HP/positions/plans, clear cooldowns, reset per-exchange perk use.

## 8. Collision resolver — rule table, not magic priorities

Use **position intents** and collision groups, never scene physics. A cardinal movement is exactly **one tile**. Two hostile characters moving directly into each other's starting cells **swap successfully** (special allowed case). Allies can stack freely. Inactive characters are stationary and solid to enemies.

**Confirmed cases to implement exactly:**

| Scenario | Position outcome | Numeric damage before defense |
|---|---|---|
| Move to empty legal tile | Move succeeds | 0 |
| Friendly moves onto friendly | Both/all may overlap | 0 |
| Two enemies exchange adjacent positions simultaneously | **Both swap** | 0 from collision |
| Enemy moves into stationary enemy tile | Entrant stays; resident stays | Each inflicts fixed collision contribution (example 5) |
| Two opponents move into same empty tile | Both stay at origin | Each inflicts fixed collision contribution |
| Two allies move into same tile | Both arrive | 0 |
| Two allied entrants vs one enemy entrant to same tile | Two allies arrive; enemy bounces | Enemy takes `5+5=10`; each ally takes `floor(5/2)=2` |
| Move into wall / obstacle / off-board by ordinary Move | Stays at origin | 0 |
| Active runs out of queued steps | Waits | No movement |

**Collision algorithm for the explicitly confirmed 2-v-1 case:**
1. Group simultaneous destination claims by intended tile.
2. Within a claim, group by team. Pure allied group never collides.
3. When claimants from opposing teams contend, each actor contributes base collision damage (currently **5 in examples**, make configurable).
4. Split each actor's contribution **equally over participating hostile actors**; floor each share **before** summing. E.g. one Warrior contributes 5 against 2 friendlies → 2 damage each; each friendly contributes 5 against Warrior → Warrior 10 total.
5. Commit tile placement according to the *specific confirmed case*: in two allied entrants versus one hostile entrant, allied entrants proceed, hostile bounces.
6. Apply same numeric damage defense model as all other sources.

**OPEN collision arbitration:** Three-v-three, multiple initial occupants, directed cycles of moves, mixed stationary hostile stacks and teleport landings are not fully defined. **DEFAULT C1** for unlisted cases: resolve explicit swaps first; otherwise if hostile claims cannot be classified as one of the confirmed cases, bounce all conflicting entrants, apply the same per-actor damage-sharing formula. Do not claim this is the designer's chosen rule; write a test and flag it as a default.

**Do not conflate** skill AoE damage with collision damage. They use different source accounting but share final defense/HP handling.

## 9. Skills, attack tiles, defense tiles and damage

**No subclass explosion.** Keep one common `Character` data class, with `CharacterClass` selecting a list of `SkillDefinition`s and pattern delegates.

Recommended pattern signature:

```csharp
public delegate void SkillPattern(
    int casterX, int casterY, Cardinal direction,
    int optionalLength, int[,] signedEffectGrid
);
```

- Pattern function marks an ephemeral numeric grid. **Positive** cells cause damage to enemies; **negative** cells protect allies.
- Pattern functions **do not** change permanent terrain, characters, HP, clocks, perks or stats.
- Skill registry returns a list of descriptors for `SkillsFor(characterId)` (IDs, names, cooldowns, etc.). One stable skill ID per skill.
- Keep per-source attack effects separate until distribution, so separate attacks round down **independently**.
- Keep defense contribution separate from attack contributions (do not use a shared signed grid where positive + negative cancel before team filtering).
- Skill effects apply for **one global tick only**. No need to persist a status-effect map for these defensive patterns.
- The target occupancy map is built from **post-movement living positions**; attacks can miss targets that moved away.
- **No friendly fire**, no accidental damage to your own team from attack patterns.
- Multiple friendly defense patterns on same tile **add**.
- In each incoming attack source, split tile attack damage across its enemy occupants by integer floor division; sum per-character incoming attack components **after** this per-source split.
- Then subtract tile defense **individually for each character**, not once for the shared tile. This corrected an earlier, superseded rule.

**DEFAULT D1 for mixed numeric sources:** After computing per-source attack shares, add collision and hazard damage for that character, subtract total friendly defense **once per character for this tick**; `hpLoss = Max(0, attacks + collisions + terrain - defense)`. The designer has **not** explicitly defined the allocation of defense among multiple simultaneous sources; document this default.

### Worked test: attack distribution

Attack A contributes 11 to a tile containing 3 opponents; Attack B contributes 8 to that tile. Each takes `floor(11/3) + floor(8/3) = 3+2 = 5` attack damage before defense. If allied defense on the tile totals 2, each takes 3 actual damage.

### Worked test: collision sharing

Base collision 5; two friendly entrants vs a lone opposing entrant to same cell: the lone opponent receives 10 raw collision damage, and each friendly receives `floor(5/2) = 2`. Defenses then reduce per-character received numeric damage.

## 10. Environmental hazards, life/death, occupancy

- Nonlethal damaging terrain deals its configured numeric damage **every global tick**, including to inactive characters. The damage is based on the character's **starting tile**, so moving away that tick does **not** avoid it.
- Defensive skills reduce that numeric environmental damage under the standard per-character damage rule.
- Pits **instantly kill**, bypassing numerical defense and HP.
- **Teleport landing beyond bounds instantly kills**, even though intermediate obstacles are ignored.
- Dead characters immediately stop existing as collision/damage participants and cannot be selected. UI may play a death animation, but its visible corpse is **nonblocking decoration**, never in logical occupancy.
- A selected fighter's death does not stop the exchange if its opponent still has steps and a team has surviving characters.

**OPEN:** lethal start-of-step hazard before movement wasn't answered by designer. See DEFAULT H1 in section 7, or obtain designer's answer.

## 11. Perks: hook flags, not four parallel battle engines

Store one `Perk` on each player and expose small **capability/phase checks**. Perks alter authorized operations and/or step resolution; they do not instantiate different engine subclasses.

### 11.1 Future Sight

- First perk picker determined randomly, players must choose **different** perks.
- After both private plans locked, Future Sight owner gets **20 seconds** to view **all complete enemy sequences** and edit **any own sequences**.
- Use normal pending preview + Enter confirmation during bonus window.
- After window closes, plans lock; no opponent can read these future steps unless explicitly disclosed.
- **Do not** reveal enemy plans during ordinary planning.

### 11.2 Defy Destiny

**Semantics, mandatory:**
1. Only perk owner can request it.
2. One attempt per **exchange**; unused attempts don't stack.
3. It operates on **the immediately preceding fully resolved tick**, after its outcome including deaths was shown.
4. User replaces only the action of their **currently selected character**; opponent's recorded action unchanged.
5. Rolls **70% success / 30% failure** from match RNG; either result consumes use.
6. Success: restore the **whole pre-tick state**, recalculate that tick with replacement, then commit the revised result and events.
7. Failure: **keep the original tick outcome**, no replay/alteration; emit failure event, consume attempt.
8. This is a **one-exchange override**, not a mutation of the reusable plan array.
9. If team elimination occurred, **do not finalize** until the eligible rewind decision window has closed. A successful reversal can restore an otherwise dead last survivor.
10. The final report must count **only committed battle history**, not both the original and overwritten tick.

**Required snapshot contents:** current HP, alive flags, actual tiles, cooldown next-allowed values, both tick counters, exchange state, internal status needed by skills, pre-tick stats, and the RNG state needed for deterministic replay. **Do not shallow copy arrays/dictionaries**. Prefer a dedicated `EngineMemento` record containing deep-copied primitive state.

**IMPORTANT**: Do not advance `_globalTick` for a second time when replaying the same logical tick. Best implementation: `ResolveTick(preState, actions, seed)` yields newState/events; original and alternate calls resolve the **same** tick index. Keep RNG draws deterministic: choose a match-seeded RNG that supports state snapshot or capture draws at intent time.

**Provisional failure handling:** Failed attempt emits `RewindFailed` event but leaves original committed gameplay and statistics intact, except perk attempt counts. Success replaces original events/history/stats with replayed outcome plus `Rewound`.

**Rewind decision phase:** UI sees the outcome; only then can it ask for Defy Destiny or pass. The engine must block further `AdvanceOneTick()` calls until the window closes. If `TryPassRewindDecision()` is called, accept the previous outcome and continue, finalizing an elimination if appropriate.

### 11.3 Teleport

- Action added to owning team only.
- `Distance` can be **any positive integer**.
- Cardinal only. Teleport ignores all **intermediate** tiles and obstacles.
- Landing **outside bounds** kills immediately.
- Landing at an in-bounds pit kills; in-bounds wall or obstacle blocked (**DEFAULT T1**); occupied enemy landing obeys collision semantics (**DEFAULT T2**, needs confirmation for complex cases).
- Teleport isn't a combat attack and doesn't create a new ability for other players. Don't artificially cap distance at 2/3/4 tiles.

### 11.4 Tactician

- `PlanningSecondsFor(owner)` returns `120`; others return `60`.
- Exposes **one randomly selected opponent character's entire plan**, without edit permission.
- Use match-seeded RNG, not UI-selected/random reroll per render.
- **DEFAULT TAC1**: choose once per planning cycle and reveal during that cycle's exchanges. Exact cadence/time of reveal is not yet confirmed; make it a named configurable constant/policy.

## 12. Read-only DTOs, hidden info, and UI contract

- Return the fields declared in `GT_Battle_API_Contract.cs`. Keep methods stable.
- `ViewFor(viewer)` returns own actors and public state appropriate to current phase. During private planning, **no enemy actor data at all**, even if actual positions are known internally.
- `VisiblePlan(viewer, opponentId)` returns no data unless Future Sight authorizes it; `TacticianRevealFor` returns exactly one RNG-selected character's plan in the appropriate battle window.
- During public playback, both teams' **real positions and HP** are visible, but full unrevealed future plan arrays aren't.
- `TickOutcome.Events` is a **stable ordered list** allowing Godot to animate movement/skills/HP/deaths without re-running any gameplay rule.
- Return actual tile coordinates, not pixels; Godot handles `tile_to_world()`.
- The viewer ID must be passed to read methods that disclose private state; **don't rely on "current player" static globals**.
- Defensive-copy `TerrainCopy`, plan queries, character cooldown maps and all event DTOs. Returning readonly interfaces over mutable lists is **not sufficient**.

### Event conventions

- Include actor/target IDs when known, affected tile, numeric amount, and skill ID if relevant.
- Distinguish `Blocked`, `Collision`, `Damage`, `SkillOnCooldown`, `Hazard`, `Died`, `Teleported`, `Rewound`, `RewindFailed`, `ExchangeEnded`, `MatchEnded`.
- Events reflect **one final committed tick**. Rewinds produce a **replacement** animation/event result; UI should visually return to pre-tick state before animating the alternate tick. A rewind failure should leave the previous board as-is.
- `Get/Preview/Visible` methods never emit battle events.

## 13. Statistics: tracked incrementally and rewind-safe

Always produce a `MatchReport`, even for a draw. Required player and character counters:
- Damage dealt, damage taken, damage blocked.
- Steps/action attempts, tiles travelled, skill activations, cooldown skips.
- Collision participations, kills/deaths.
- Perk activations, successes/failures; number of exchanges and global ticks.
- Winner or draw; if mutual elimination, outcome is **draw**, statistics are presented for comparison only, not used as a tiebreaker.

**Recommended accounting default:** "damage dealt" = HP actually removed after defense, not a skill's nominal damage; count a step even if blocked, failed due to cooldown or caused a collision. Rewind must subtract/discard the original tick's stats and replace with the alternate tick's stats, not count both.

## 14. Acceptance tests — pass these before asking for integration

Run these as deterministic **C# unit tests** that instantiate the engine directly (no scene tree). At minimum:

| ID | Test | Required assertion |
|---|---|---|
| `INIT-01` | Two rosters, unique IDs, load 15x13 Sky Island | Map/IDs valid; phase starts in setup |
| `PLAN-01` | Key preview then Enter | Preview doesn't change real HP/position/clock/plan; Enter updates exactly one plan slot |
| `PLAN-02` | Change earlier slot | All later projected positions recalculate from actual current tile |
| `PLAN-03` | Enemy hidden during planning | `ViewFor(0)` contains no owner 1 actors; preview doesn't reveal enemy collision |
| `PLAN-04` | New planning cycle | Retains plans, HP and positions; cooldowns reset |
| `PLAN-05` | Timeout during pending key | Confirmed slots persist; pending not stored; empty slots become Wait |
| `TURN-01` | N exchanges | After exactly N completed exchanges return to planning; can pick same actor N times |
| `TURN-02` | Unequal lengths | Shorter script is idle while longer continues; no reset of actual position |
| `TURN-03` | Active fighter death | Surviving actor executes remainder, inactive actors remain vulnerable |
| `CD-01` | Use skill cooldown 3 | Legal at t, illegal t+1..t+3, legal t+4 |
| `CD-02` | Inactive cooldown | Cooldown advances during other pair's exchange |
| `CD-03` | Cooldown skip | Consumes slot and causes no skill effect |
| `MOVE-01` | Enemy position swap | Both move, no ordinary collision bounce |
| `MOVE-02` | Enter stationary inactive enemy | Both take collision damage, entrant stays |
| `MOVE-03` | Friendly tile overlap | Both arrive and no collision |
| `MOVE-04` | 2 allied + 1 enemy contested destination | Allies enter, enemy bounces; raw damage [2,2,10] |
| `DMG-01` | Attack 20 vs 2 sharing tile, defense 6 | Both take 4 |
| `DMG-02` | Attacks 11 and 8 vs 3 targets | Each takes 5 before defense |
| `DMG-03` | Friendly fire | Allies never damaged by friendly attack grid |
| `HAZ-01` | Starts on damage tile and moves out | Takes starting-tile hazard damage this tick |
| `HAZ-02` | Inactive on damage tile | Takes hazard damage every global tick |
| `HAZ-03` | Pit entry | Immediately dead, defense ignored, removed from occupancy |
| `PERK-01` | Unique perk draft and Future Sight | Owner sees all enemy plans for 20-second phase and can edit any own plan |
| `PERK-02` | Teleport across obstacle / off-map | Intermediate obstacle ignored; off-map kills |
| `PERK-03` | Tactician | 120-second planning, one random complete enemy plan, no edit privilege |
| `PERK-04` | Defy Destiny success | Entire preceding step replayed; original plan unchanged; no double stats |
| `PERK-05` | Defy Destiny failure | Original step outcome intact; use consumed |
| `PERK-06` | Defy Destiny after apparent defeat | Match ending delayed; a successful replay may avert defeat |
| `END-01` | Both teams eliminated | Official draw, full stats report produced |
| `END-02` | Exactly one team eliminated | Win, full stats report produced |

**Test random perk outcomes deterministically.** Do not use a floating RNG probability in a flaky unit test; inject a controlled RNG source/draw or use a predictable seed with an audited sequence.

## 15. Definition of done and collaboration protocol

The engine is **not ready** just because it compiles.

**Definition of done:**
1. Public facade and DTOs match the checked-in contract.
2. A headless test can run a complete match through planning → N exchanges → replanning → win/draw.
3. Every tick has deterministic, inspectable events; no rendering code is required to confirm correctness.
4. No private plan/enemy position leaks through views or preview.
5. Defy Destiny tests verify *whole-tick rollback*, correct chance and no duplicate statistics.
6. Collision examples, terrain rules, cooldown timeline and effect-grid damage distribution match exact expected numbers.
7. Godot can render a step entirely from `TickOutcome` without computing damage/movement for itself.
8. The developer documents any **DEFAULT / OPEN** policy used and asks for a decision if it changes gameplay in a demonstrable way.

### Required work process for collaborating developers

**Before implementing a feature:**
- Read this document and the contract.
- Identify the exact section and tests applicable.
- If ambiguous, post: `Ambiguity: [one exact rule], Current default: [x], Proposed change: [y]`. Don't silently implement a different game.

**While working:**
- Change one conceptual layer at a time (e.g., terrain/actors; plans/previews; resolver; skills; perks; rewind).
- Create focused commits with descriptive messages; push and announce the branch/commit and what behavior changed.
- Keep engine changes confined to engine code. Do not opportunistically alter scene files or the UI's contract.
- Avoid drive-by renames and refactors; do not replace a stable API because another style seems "cleaner."
- If a test is blocked by a gameplay ambiguity, mark it pending and explain why; **do not encode an unagreed assumption as confirmed behavior**.

**Pull-request checklist:**
- [ ] Exact API signatures retained (or interface change approved)
- [ ] Test(s) for new behavior included
- [ ] Headless compile/test passes
- [ ] No FIFO, thread or Godot-physics combat logic introduced
- [ ] No direct mutation of actor state outside engine
- [ ] Rewind and privacy behaviors still work
- [ ] Default/open rule called out explicitly

### Suggested build order

1. Terrain loader + DTO types + characters and teams.
2. `BattleEngine` phase transitions and read views.
3. Fixed arrays + preview/Enter confirmation + retained editing.
4. One-tick movement/collision resolver + hazards.
5. Skills, signed pattern maps, distribution, defense and cooldowns.
6. Exchanges, repeated selections, N-cycle planning.
7. Perk draft, Future Sight, Teleport, Tactician.
8. Defy Destiny deep snapshot/replay + RNG + delayed winner.
9. Statistics + tests + Godot integration.

**Stop condition:** Once these behaviors pass, stop restructuring the engine and hand the API to the UI developer. Further design changes go through review.

---

## Appendix A — Important gaps that must not be silently decided

These are the genuinely unresolved pieces from the design conversation. A deterministic MVP implementation default may be used *only if labeled as such* and accepted for the current demo:

- **H1**: Does *lethal* starting-tile hazard damage prevent movement? Suggested default: actor may move but dies in the same tick from start-tile damage.
- **TAC1**: Is Tactician's random whole-character plan sampled per cycle, exchange or match? Suggested default: once per cycle, visible during its exchanges.
- **T1/T2**: Teleport landing on walls/obstacles or enemy occupancy. Suggested default: walls/obstacles block, pits kill, enemy occupant uses standard collision.
- **C1**: Generalized collision arbitration outside designer's explicitly resolved examples. Suggested default: bounce hostile contested entrants and distribute collision contributions; never override confirmed swaps or 2-v-1 examples.
- **D1**: One character hit by *attack + collision + hazard* and protected. Suggested default: sum numeric damage, apply friendly tile defense once to that character.
- **P1**: Initial perk draft vs initial placement order; default = placement then draft.
- **R1**: Rewind response timeout; default = UI-controlled prompt with no real-time timeout, so engine never assumes a nonresponsive player passed.
- **Balance**: exact HP, hazard and class damage values, skills and class-step lengths are configuration, not architectural constants (current tentative lengths Mage=10, Warrior=15, Archer=20, Orc=7).
