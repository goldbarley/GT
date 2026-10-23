# Premove

A pixel RPG tactics game where both players program their moves before combat resolves. Built with Godot 4.7 .NET and the existing C# battle engine.

## Run

Install the **.NET edition of Godot 4.7.2** and a .NET SDK that supports `net8.0` (Android targets `net9.0`). From this folder:

```sh
dotnet build GT.csproj
godot-mono --path .
```

The executable may be called `godot` on your system. Open `project.godot` in the .NET editor to edit scenes or run with F6/F5. The main scene is `scenes/Premove.tscn`.

## Playing

- Choose **LAN multiplayer**, **Couch multiplayer**, or **Practice**. Select Sky Island and a party of one to three fighters; a team may field the same class more than once.
- Browse characters with Left/Right, then press Enter or use **Place on the map** to open a small map. Only safe, free tiles in your own half are offered: move the marker with WASD and press Enter, or click a tile. Each fighter in the party has a Remove button. Choose a perk with P and enter the arena with Space. Archer and Orc remain Coming soon.
- Program each fighter's sequence. Choose a skill, click a tile along a row or column to aim, and confirm. The highlighted tiles show its exact effect.
- Lock all plans, then choose a fighter. Both sides execute their selected sequences simultaneously. In skirmishes, unused living fighters act first; a survivor fills a fallen teammate's remaining exchange before the next planning cycle.
- Health and position persist. Skill cooldowns reset at the start of a new cycle. Defeat the enemy party to win. The result screen offers a rematch.

Local matches use private handoff screens. During planning, enemy markers show their original deployment tiles, rather than live positions. Practice uses a computer opponent that navigates safe terrain and chooses skills by range and cooldown.

| Input | Action |
| --- | --- |
| WASD | Move the placement marker / preview a move (planning) |
| Numpad 1–5 / number row 1–5 | Select a class skill |
| Arrow keys | Aim; browse fighters on selection screens |
| + / - | Change skill range |
| Tab | Switch the fighter being programmed |
| Space | Lock plans / confirm a completed party |
| Numpad 0 / 0 | End the sequence |
| Click a map tile | Aim the selected skill |
| Enter | Place a fighter, confirm the previewed action, or confirm a fighter |
| T | Select teleport with the Teleport perk |
| Backspace | Remove the last placed fighter / select the previous slot |
| G / Tile view | Toggle terrain markings |
| Escape | Pause / resume locally; open menu in LAN (match continues) |
| F11 | Toggle fullscreen |

Programming works as a preview: pressing a move or a skill shows what it will do, the dotted squares mark the tiles the skill can reach, and the aim can be set with the mouse by clicking a tile along the row or column. The preview is a shaded yellow square and turns green once the action is confirmed with Enter. Click any sequence slot to replace it. **End** terminates the sequence; later commands are discarded when locking. Guard and Quad Beam target automatically. Repeating a skill while it is on cooldown skips that action. Hover a skill button for damage, range, and cooldown details. Movement resolves before attacks; walls stop walking, collisions deal damage, and chasms kill instantly. Teleporting onto unsafe terrain is fatal.

## LAN play

Use the same game version on two computers on the same network. On the first, choose **LAN multiplayer → Host game**. On the second, enter the host's LAN IPv4 address and choose **Join game**. Once connected, the host chooses the map and party size. Traffic uses UDP port `28461`; allow that port through the host firewall if needed.

Both players set up at the same time: each picks their own fighters and places them on their own half of the island, then picks their team perk, then presses Space. Each player only sees their own deployment. Each side only ever sees its own plan; the other side is hidden until the plans are locked. Planning, fighter selection, and the Defy Destiny decision are private to the player they belong to, and the other player waits on an "opponent's turn" screen. The host's clock drives the ticks, so both machines resolve the same exchange in the same order. Disconnecting returns both players to the lobby; reconnect/resume is not implemented. The transport is intended for trusted local play, not competitive anti-cheat.

## Interface

The window is light brown, with tan panels, dark brown text and pastel green, blue and red kept for highlights. Setup uses separate full-screen selections. The battle view has a statistics bar, a translucent numpad, and last-action messages. Executed skill and movement keys glow green. Hover skills and statistics for details; the three-page tutorial gives the essentials. The camera tracks the midpoint of the active fighters and widens its framing when they separate. The design follows the [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/) on consistent keyboard access, concise help, and an option to disable camera tracking.

## Music and audio

Music loads from `assets/music/`: `title`, `battle`, `victory` and `defeat` are all bundled, and each slot can be replaced with an `.ogg`, `.wav` or `.mp3` file of the same name; see [`assets/music/README.md`](assets/music/README.md). The game crossfades between the title, battle and result themes and prints one hint per missing track.

Combat hit sounds come from `assets/sounds/`; `hurt.wav` plays once per tick whenever a fighter loses HP, Knight Slashes use `sword_hit.wav` even when they miss, Plunge hits use `plunge.wav`, Mage Fireball casts use `fireball.wav`, Fireball impacts use `fireball_hit.wav`, and Knight's Edge draws with `sword_draw.wav` before striking with `flame_sword.wav`. See [`assets/sounds/README.md`](assets/sounds/README.md).

**Audio settings** on the title screen and in the pause menu controls music and effects volume and mute independently. Choices are saved to `user://audio.cfg` and restored on the next run. Enabled buttons play a quiet `hover.wav` beep when the mouse enters them.

## Team perks

- **King Crimson:** after both teams lock, inspect enemy plans and edit your own during a 20-second window.
- **Defy Destiny:** once per exchange, attempt a replacement for the previous action with a 70% success chance.
- **Teleport:** program cardinal teleports with a chosen distance.
- **Tactician:** 120 seconds to plan and one enemy fighter's sequence revealed before selection.

A perk can only belong to one team. In a LAN match one player is picked at random to choose their perk first; the other waits for that choice before picking. Other planning windows last 60 seconds; the timer locks plans when it expires.

## Characters and assets

**Mage** and **Knight** are playable, using the modular rigs, choreography, and effects from `dump/Game`. The incomplete Knight front sheet has been replaced with the complete supplied body, plume, shield, arm, sword, and boot pieces. Its shoulder/wrist hierarchy and perspective-specific slash, stab, plunge, guard, and front gait use anticipation, impact, and recovery poses. **Archer** is marked Coming soon because its controller only supports one combat perspective and its attack set is incomplete. **Orc** awaits character art and animations. Standing sprites are scaled proportionally to one tile. Each perspective is centered using the visible pixel bounds of its resting pose. Attacks animate around that center. The camera follows the active pair in combat; the pause menu can switch to a whole-map view. Six arenas are available: Grassland 1–3 and Volcanic Ruins 1–3. The original Sky Island map is also included as "Sky Island".; its JSON determines terrain and grid alignment.

`scripts/Game/` contains the interface and match flow. `scripts/Animation/` contains the shared animation runtime. `assets/characters/` holds the integrated art. The source prototypes remain in `dump/`, excluded from C# compilation and Godot resource scanning. LAN reuses the prototype ENet transport with ordered host-relayed commands and a host clock. No music or sound recordings were supplied.

## Checks

```sh
dotnet build GT.csproj --no-restore
godot-mono --headless --editor --path . --quit
godot-mono --headless --path . -- --smoke-test
```

The runtime checks cover damage, defense, cooldowns, collisions, unsafe teleport, snapshot copies, future sight, rewind, private handoffs, planning timers, and skirmish cycles, then exercise both match modes with the active board and rigs.

A networked match can be checked from one machine by running two instances at once:

```sh
godot-mono --headless --path . -- --lan-test-host
godot-mono --headless --path . -- --lan-test-join
```

Both bots pick a party, choose a perk, plan, select a fighter, answer the rewind decision and fight to a result. Each side prints its own outcome, clock and health; they must agree. `--capture-menu` renders a preview gallery of the title, map, party, planning, fighter selection, and combat screens in `/tmp`; use `--quit-after 180` to exit afterwards. It does not run the gameplay checks.

## Credits

- [Nilabhro Mondal](https://github.com/goldbarley)
- [Abhinav Mishra](https://github.com/Mishra-4455)
- [Aditya Raj](https://github.com/adiambassador)
- [DeployedReject](https://github.com/deployedreject)

The Terminus bitmap font is by Dimitar Toshkov Zhekov, licensed under the SIL Open Font License; see `assets/fonts/Terminus.LICENSE.txt`.
