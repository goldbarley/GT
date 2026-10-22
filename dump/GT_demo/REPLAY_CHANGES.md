# Exchange playback / Defy Destiny update

## Changes

- The global planning cursor no longer leaks across couch-player handoffs. Each player's selected fighter keeps its own action-slot cursor; the other player's first fighter begins at slot 1.
- Exchanges auto-run at 0.42 seconds per tick. There is no manual tick step or Defy Destiny interruption between ticks.
- At the end of an exchange, if either player holds Defy Destiny, the host pauses *before* finalizing the exchange. Both players can see the tiles used by movement, attempted movement and skill effect grids. Only the perk owner can select a rewind tile.
- Every highlighted tile has a `T##` label denoting its most recent use in this exchange. If a tile was used multiple times, clicking it selects the latest tick.
- The Defy Destiny owner clicks one of these highlighted tiles, chooses a replacement action using the usual arrow / numpad input, optionally aims an attack by clicking its landing tile, and presses Enter. `P` or **Accept Exchange** declines to rewind.
- The chance of success remains 70%. On success the host restores the *pre-tick snapshot* for that time, removes later snapshot nodes and traced tiles from the old timeline, executes the replacement action for the perk owner's selected fighter at that tick, and auto-replays the later actions from both fighters. On failure the original exchange remains as it was.
- The consumed Defy Destiny attempt remains consumed after loading a snapshot, so replay cannot repeatedly open the choice screen.
- Rewind choices are sent through the existing `LanSession` host-authoritative commands. No extra ports or network process.

## How to playtest

1. Open `GT_demo/project.godot` in the matching Godot .NET editor, build C#, and start a **LOCAL DUEL**.
2. Deploy one Mage for Player 1 and one Archer for Player 2. Pick Defy Destiny for one side and another perk for the other.
3. Give Player 1 several arrow / Enter movements and lock their plan. When Player 2's planning opens, verify their FIRST character's highlighted slot is **01**, not the index where Player 1 finished. Enter several actions and lock.
4. Select one living fighter on both teams and start an exchange. The battle should tick automatically every 0.42 seconds. No rewind prompt should appear in the middle.
5. At exchange end, translucent dotted overlays with `T01`, `T02`, etc. should mark affected battlefield tiles. Click one while viewing the Defy Destiny owner's controls.
6. Select a replacement action: an arrow for movement, a numpad number for an ability, or Numpad 0 to do nothing at the selected tick. Mouse-aim an attack if needed. Press Enter to attempt the rewind.
7. On the 70% success outcome, combat starts again from the selected past tick and automatically resolves the remaining exchange. On failure, the original outcome stands. You can also decline with **P**.
8. Repeat with HOST LAN / JOIN LAN on two processes; only the host should advance combat, while both should see the traces and the Defy Destiny owner should be able to issue the rewind from either client.

## Limitations / conventions

- Clicking a tile picks its most recent use in the exchange. The current UI does not offer choosing among multiple older uses of the *same* tile.
- Selecting a tile chooses **when** to rewind, not a teleport destination. The replacement action is explicitly selected and confirmed with Enter; otherwise rewinding unchanged actions would have little tactical effect.
- Playback currently uses instantaneous tile-to-tile jumps every 0.42 seconds, rather than interpolated character animations.
- The source/ZIP has been checked for syntax structure and packaging. A C# compile and Godot runtime/LAN test were not possible in this environment.
