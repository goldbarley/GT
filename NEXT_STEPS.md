# Premove — Next Steps

## Latest UI direction — screenshot feedback

- Fix the actual Knight/Mage visual origin; both still render outside their showcase in the supplied screenshots. Keep sprite art inside its assigned space at every scale.
- Replace oversized empty panels with purposeful proportions: larger character art, readable options, and a useful party sidebar, without overlaps.
- Title screen: Premove and buttons on one side; a slowly scrolling decorative assortment of Grassland and Volcanic tiles on the other. This is scenery, not a playable map.
- Improve game-facing labels; keep instructions short, contextual, and understandable. Do not fill the screen with explanations.
- Add HP bars alongside readable health values, plus missing selection/status feedback.
- Research visual hierarchy, grouping, and accessible game UI before implementation. Keep pixel RPG styling, brown as the base, and red/green/blue accents.
- No builds, tests, imports, or previews: the user performs validation.

Research: [NN/g visual hierarchy](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/) recommends meaningful scale/contrast and restrained grouping; [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/) recommends plain language, consistent input, and reinforcing important text with visuals. Apply these through large character art, compact grouped actions, health bars with numbers, and optional detail in tooltips.

### Paused at user request — credits running low

**Latest UI pass is incomplete and unverified. Do not describe it as finished. No builds, tests, imports, or previews were run. The user reserves testing for themselves.**

#### Changes written so far

- Found a likely centering cause: `BuildFigure` called `configure` before attaching the figure to the scene tree. Animation playback could write the rig position before `ChoreoPlayer._ready()` cached its centered origin. The screenshot offsets match this failure (Knight above its panel; Mage below/right).
- `Premove.BuildFigure` now configures on the figure's `Ready` signal. `FighterVisual.gd` also caches a player created outside the tree before playback. These fixes have not been observed running.
- Showcase figures now reparent into the stage Control, use local stage-center coordinates, and are clipped by the stage. Refresh reparents cached figures back to their holder before freeing UI nodes.
- Added `fit_display(area)` using visible resting bounds and whole-number scaling. The character-screen process fits the figure to the stage with a safety margin.
- Enlarged the stage and sidebar; party cards expand into available space instead of leaving a large spacer. Empty slots have a plus marker; selected cards use larger portraits and health bars.
- Added `HealthDisplay` with a bar and numeric HP. It is used for the character preview, selected party members, and battle-header team health. BattleBoard already has individual unit health bars.
- Shortened several labels: How to play, Choose an arena, Build your party, Choose fighter, Ready to fight. Moved the LAN King Crimson explanation into a tooltip.
- Added `scripts/Game/TitleTiles.cs`: a decorative, slowly scrolling patchwork of both terrain themes using existing textures. **It is not yet connected to the title screen.**

#### Resume here, in order

1. Read the latest `Premove.cs`, `FighterVisual.gd`, and `TitleTiles.cs` edits. No compilation has been attempted. Inspect C# event/reparent lifecycle, layout sizing, and GDScript initialization before adding more changes.
2. Finish the title screen: replace its current centered stack with Premove/buttons on the left and an expanding `TitleTiles` panel on the right. Provide a small pause-motion control using `TitleTiles.Moving`. Do not put a playable map or gameplay controls in this decoration.
3. Finish responsive character layout. Current stage/sidebar minimum sizes are larger; make sure the page can fit smaller windows instead of assuming the larger game window. Prefer proportional container sizing or a compact breakpoint. Keep the title, art, health, options, and party in separate non-overlapping areas.
4. Ask the user to review actual centering after the initialization fix. If it still fails, trace `_rest_target_pos`, rig position, sprite bounds, and transforms; do not add per-character screen offsets. Verify the cache survives switching characters and opening/closing placement menus.
5. Review the expanded party-card proportions for team sizes 1, 2, and 3. Make portrait/name/health/removal controls readable without huge empty cards or vertical overflow.
6. Finish label cleanup and contextual guidance. Avoid duplicate map names, technical status labels, and always-visible paragraphs. Keep core keys nearby and longer explanations in tooltips/the short tutorial. Existing skill/cooldown UI should be reviewed for clarity before adding redundant panels.
7. User validation is still required for the earlier LAN selection timeout, replicated random deployment, simultaneous planning, automatic fighter rotation, premove limits, and menu layers. Do not run checks without the user's permission.

#### Relevant files

- `scripts/Game/Premove.cs`: `BuildFigure`, `Refresh`, `CharacterScreen`, `_Process`, `HealthDisplay`, `Menu`.
- `scripts/Game/FighterVisual.gd`: `show_direction`, `_visible_bounds`, `fit_display`.
- `scripts/Animation/choreo_player.gd`: `_ready`, `_cache_rig`, `_rest_target_pos`, `apply_pose`.
- `scripts/Game/TitleTiles.cs`: new decorative control, not yet instantiated.
- `scripts/Game/MatchSession.cs`, `NetworkMatch.cs`, `scripts/Character.cs`: previous LAN/premove changes, still awaiting user validation.

Keep the supplied screenshot feedback as the reference: the Mage overlaps the name/controls below the blue stage, the Knight overlaps the heading above the red stage, and the sidebar has excessive empty space. The changes above aim to address these defects but are not visually confirmed.

## Requested next — character selection and simultaneous LAN flow

- Center Knight and Mage within the actual character showcase, removing character-specific screen offsets.
- Move selected party members into a bordered sidebar with visible slots and removal controls.
- Give both LAN players the same 60-second character-selection window. Both can choose simultaneously; no opponent-turn or perk-order deadlock.
- Start planning immediately when both players confirm. At the deadline, randomly fill unchosen character slots and randomly deploy those additions on legal, unoccupied tiles.
- Keep planning simultaneous. When both players lock their plans, advance immediately into combat with an available fighter selected automatically.
- Limit premoves to 5–10; use a host-selected match setting, default 8.
- Strengthen borders and panel contrast. Brown remains the main color, with distinct muted red, green, and blue backgrounds and accents.
- Do not run tests, builds, or previews for this work. The user will validate it.

### Implemented in this pass — untested

- Showcase placement follows the actual stage rectangle every frame, without Mage/Knight-specific offsets. Selection uses a framed main panel and vertical party sidebar with all slots visible.
- Stronger square borders, a darker brown backdrop, blue controls, green party/ready panels, and red character/action panels provide separation. Label outlines were removed to improve small-text clarity.
- Both LAN players choose concurrently for 60 seconds. Default valid, distinct perks remove the disabled-ready deadlock. Ready players retain their party screen; both confirmations immediately open planning.
- A match seed is sent with Start. Deadline additions choose Knight/Mage and legal unoccupied spawn tiles using the same seed on both peers; existing selections remain intact.
- Planning clocks run for both players under the host's replicated updates. Both locks immediately start combat; available fighters rotate automatically in party order. Planning deadlines lock only the unfinished player's plan.
- Premoves are selected on the map screen from 5–10, default 8; +/- also adjusts them. The host sends the setting. Both playable classes receive that many steps. The engine still accepts legacy class-sized plans for existing callers.
- Party removal is now replicated. Confirmed parties cannot be edited. LAN rewind waits use the same phase on both peers; leaving LAN clears LAN mode before couch play.

### Explicit LAN behavior

King Crimson is not offered in LAN because its extra post-lock planning window conflicts with immediate combat. It remains available in couch/practice. Teleport, Defy Destiny, and Tactician remain available; Tactician retains its longer planning clock. Manual fighter selection remains in couch/practice; LAN automatically chooses the next available fighter.

### Remaining work for user validation

No builds, tests, imports, or previews were run for this pass, per instruction. The changes are implemented but unverified at runtime. Both machines must use the updated code because the Start message now carries premove count and random seed.

- Try both ready before timeout, one ready/one unfinished, both unfinished, and removing a fighter before confirming. Compare automatic roster additions and spawn coordinates across machines.
- Try both early planning locks, one planning timeout, Tactician's longer timer, subsequent fighter exchanges/cycles, rewind decisions, rematches, and switching from LAN to couch.
- Review both character centers, all three sidebar slots, popup layering, keyboard navigation, and contrast at the actual window sizes used.
- Full independent left-facing Knight limb/cape/shield motion still requires separated artwork. Other incomplete characters remain Coming Soon.
- Earlier combat/animation polish and LAN reliability checks below remain pending unless separately validated by the user.

## Current handoff — 2026-10-22

This section supersedes older implementation and validation notes below.

### Completed in the latest passes

- Battle board uses actual map dimensions and the selected terrain theme. Sprite centering uses resting bounds; camera movement preserves spell target positions.
- Offensive animation contact, visible health changes, and damage feedback share an impact point. Fireball uses its own animation; Meteorite plays its complete timeline.
- Restored the Knight right-view torso beneath the arm, corrected the back shoulder pivot, and removed stray pixels below the back-view body region.
- Knight attacks now have brief pixel slash arcs, thrust trails, and impact sparks. Gameplay timing, damage, and range remain unchanged.
- Spawn selection includes a color legend and explains unavailable tiles.
- Placement, pause, and tutorial popups use a dedicated canvas layer above fighters and their effects.
- Animation details and research links are in `COMBAT_PRESENTATION.md`.

### Remaining work, in priority order

1. Review placement, pause, tutorial, and nested menus during live attacks, including LAN matches that continue behind menus. Confirm keyboard focus and dismissal restore the previous screen.
2. Review every Knight skill in all four directions through anticipation, impact, and recovery. Check the new trails at battle zoom and ensure they do not suggest extra attack range. Left-view independent limbs and full cape/shield articulation still require separated artwork.
3. Exercise simultaneous combat, defeat, rewind, cooldowns, rematches, and camera framing with widely separated fighters. Review spell effect size against affected tiles.
4. Play a complete match on two LAN machines; verify disconnect handling, private plans, and synchronization. Older checks below are historical results, not verification of these latest changes.
5. Finish the remaining UI polish against the requested pixel RPG direction: simple full-screen selections, pastel red/green/blue accents, small tutorial, readable statistics and keyboard overlays. Preserve Coming Soon for characters lacking usable assets.
6. Replace placement-map legacy fixed geometry with shared map dimensions when adding maps of different sizes; current supplied maps use the existing dimensions.

### Validation scope

The preceding combat pass built successfully with three existing warnings and produced error-free render previews. The latest legend/menu-layer/trail changes also compile successfully with the same three warnings. They have not had gameplay or LAN tests. Do not treat visual captures as gameplay assertions.

## Earlier handoff (historical)

## User direction

Keep the existing engine and project structure. Use the supplied pixel art, crisp pixel rendering, and pastel red/green/blue accents. Take layout inspiration from Undertale/Deltarune. Avoid dashboard/editor layouts, modern SaaS styling, and unnecessary code comments.

- Separate full-screen title, map, party, and fighter selections.
- LAN multiplayer is the primary title option; couch multiplayer is secondary.
- Character selection: large animated character in the center, Left/Right browsing, selected party at bottom right, selection effects.
- Battle: large, zoomed map; simple statistics bar with explanatory tooltips; translucent keyboard/numpad overlay; executed keys glow; last-move messages.
- Keyboard-first controls and a small tutorial.
- Sprites must fit their tiles and look visually centered in every perspective.
- Knight animation must use correct rigging and convincing anticipation, strikes, and recovery.

## Implemented

- Full-screen setup screens and a three-page tutorial.
- Sky Island selection; one- or two-character parties. Knight/Mage playable; Archer/Orc marked Coming soon.
- Enlarged battlefield, smooth camera tracking of the active pair, and a whole-map camera option in the pause menu.
- Statistics, translucent numpad/movement key displays, cooldown indicators, execution highlighting, and last-move messages.
- Keyboard character browsing, party confirmation, planning, aiming, range adjustment, fighter selection, and menus.
- Rebuilt the incomplete Knight front rig from complete source pieces in `dump/Game/sprites/warrior/front/`. The old cleaned sheet contained only part of the character. The rebuilt character is visibly whole.
- Perspective-specific Knight slash, stab, plunge, guard, and front walking poses. Existing Knight ultimate effects remain integrated.
- Sprite centering uses each perspective's visible resting pixel bounds. Board actors sit at tile centres; rigs animate around that centred rest pose.
- The key overlay sits in its own panel beside the map, so the board is never covered by text.
- The window is light brown: tan window and panels, dark brown text, and the pastel green/blue/red kept for highlights. The focus outline has no shadow, so a focused button does not darken.
- The Knight front rig can also be assembled from its parts without the packed scene: `modular_rig.gd` reads per-piece textures.

## LAN multiplayer

Reworked so that a real two-machine match works, not just the transport.

- `MatchSession` keeps a separate editor per player (fighter, slot, direction, range, pending action). Every mutating call has a `...As(viewer, ...)` form, so a command can be applied to either side.
- `MatchSession.Lan` and `MatchSession.Local` mark a networked session and say which player this machine controls. `MyTurn` reports whether the local player may act; the interface shows an "opponent's turn" screen when it may not.
- Both players set up their own party and their own perk in parallel, then plan privately at the same time. King Crimson opens only on the owner's screen. Fighter selection and the Defy Destiny decision are private to their owner.
- `NetworkMatch` replicates every command to the other machine and applies the mirrored command locally, so both copies of the battle engine stay identical. The host's clock advances the ticks for both.
- Verified end to end by two headless instances on one machine (`--lan-test-host` and `--lan-test-join`): both sides reached the same outcome, clock and health.

## Latest changes

- Parties of one to three fighters, and a team may field the same class twice.
- Placing a fighter opens a small pop-up map that only offers safe, free tiles in the player's own half. WASD moves the marker, Enter or a click places, and every fighter in the party has a Remove button.
- The character preview sits in the middle of the party screen and is cached, so it no longer lands in a corner and switching classes no longer stutters.
- The character preview is cached, so switching between the Knight and the Mage no longer stutters.
- Planning is preview first: a move or a skill shows a shaded yellow square, the dotted squares mark where the skill can land, the mouse aims, and the confirmed action turns green.
- The courtyard grid is measured off the island texture (origin 47.6, 47.4, tile 23.9), so the overlay and the fighters sit on the painted tiles. `data/sky_island_tilemap.json` carries the same numbers.
- The Mage's fireball no longer throws the projectile clip: the staff raises instead, so no stray pit is left on the map.

- The courtyard grid is measured off the island texture (origin 47.6, 47.4, tile 23.9), so the tile overlay, the terrain markings and the fighters sit on the painted tiles instead of a few pixels to the side. `data/sky_island_tilemap.json` carries the same numbers.
- Fighters are placed by the player: pick a class with Enter, then move the marker with the arrow keys and press Enter, or click a tile in your own half.
- A team may only field a class once; the party screen says which fighters are already taken.
- The opponent's deployment marker stays hidden while both sides are placing their fighters.
- In LAN one player is picked at random to choose their team perk first; the other waits for that choice.
- The Mage's fireball no longer throws the projectile clip: the staff raises instead, so no stray pit is left on the map.

## Next priorities

### 1. Check LAN on two real machines

The automated test covers the rules, not the human part. On two computers with the same build, check the lobby (host address shown, join, disconnect), the parallel party screen, the planning windows, the private selection screen, the rewind prompt, the result screen and a rematch.

Watch for phase drift when a player locks a plan at the same moment as the other, and for a command that arrives a frame after a phase change.

### 2. Review alignment and animation in motion

The last visual correction was centring. Inspect both characters on real tiles in all four directions, standing and moving, and confirm that attacks return to exactly the same resting alignment and that the camera causes no drift.

Review Knight slash/stab/plunge/guard/ultimate in motion: wrist attachment, front sword grip, left-view sword movement, back-view depth ordering, foot planting and transitions. A rendered pose sheet looks coherent, but static poses do not prove animation quality.

### 3. Finish keyboard and layout polish

Walk through every screen without the mouse: focus after rebuilding menus, Escape/back behaviour, numpad Enter, number-row fallback, missing or dead fighter selection, and the smallest supported window size.

Current controls: arrows browse/aim; Enter adds a character or action and confirms a fighter; Space confirms a party and locks plans; P cycles perks; Backspace removes a party member or returns to the previous plan slot; WASD adds movement; numpad 1–5 selects skills; +/- adjusts range; T selects teleport; 0 ends a sequence; Tab switches the planned fighter; G toggles tiles; Escape opens the menu.

Check tooltip legibility over the map, camera framing when fighters are far apart, and executed-key timing against animation impact. Avoid adding more permanent explanatory panels.

### 4. Small cleanups left

`BattleBoard` still supports a replay frame that no screen sets, and `MatchSession.Replay` is only used to build it. Either expose a replay on the result screen or drop the support. `tests/LanBot.cs` is a test aid and can stay.

## Files to start with

- `scripts/Game/Premove.cs`: screens, input, HUD, tutorial, render gallery.
- `scripts/Game/BattleBoard.cs`: map drawing, camera transform, actors, tile targeting.
- `scripts/Game/FighterVisual.gd`: perspective rigs, visible-bound centring, animation playback and effects.
- `assets/characters/Knight/Knight_front/`: restored front rig and parts.
- `assets/characters/Knight/Anim/clips/`: choreography.
- `scripts/Game/MatchSession.cs`: phases, per-player editors, `MyTurn`.
- `scripts/Game/NetworkMatch.cs`, `LanSession.cs`: command replication and transport.
- `tests/MatchChecks.cs`: runtime checks.
- `tests/LanBot.cs`: two-process LAN bot.

## Build and preview status

```sh
dotnet build GT.csproj --no-restore
godot-mono --headless --path . -- --smoke-test
godot-mono --path . --quit-after 200 -- --capture-menu
```

The smoke test passes: damage, defence, cooldowns, collisions, unsafe teleport, snapshot copies, future sight, rewind, private handoffs, planning clocks, skirmish cycles, sprite scale and alignment, then the practice and couch match modes.

The render gallery writes `/tmp/premove-menu.png`, `premove-map.png`, `premove-characters.png`, `premove-deployment.png`, `premove-planning.png`, `premove-selection.png`, `premove-combat.png` and `premove-knight-poses.png`. These are development previews, not gameplay assertions; the gallery ends on the Knight pose sheet.

The LAN check runs two instances:

```sh
godot-mono --headless --path . -- --lan-test-host
godot-mono --headless --path . -- --lan-test-join
```

GUI launches need the environment's approval mechanism. Headless editor import reports sandbox-related debugger socket errors; normal GUI previews render through the Intel OpenGL fallback.

## Preserve existing work

The repository already had substantial user changes in `BattleEngine.cs`, `Character.cs`, `Player.cs` and `SkillTable.cs`; do not reset them. The original prototypes remain in `dump/`, excluded from compilation and resource scanning. Many game and asset files are still untracked. Do not treat them as disposable generated output.
