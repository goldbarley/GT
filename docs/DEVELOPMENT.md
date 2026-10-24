# Development notes

Premove uses Godot 4.7.2 .NET. Desktop builds target .NET 8; Android targets .NET 9.

## Project layout

| Path | Purpose |
| --- | --- |
| `scripts/` | C# battle engine, character rules, skills, and map loading |
| `scripts/Game/` | Playable interface, match flow, and LAN sessions |
| `scripts/Animation/` | Shared animation runtime |
| `scenes/` | Godot scenes; `Premove.tscn` is the entry point |
| `data/` | Arena JSON |
| `assets/characters/` | Integrated rigs, sprites, and effects |
| `dump/` | Reference prototypes, excluded from compilation and Godot scanning |

## Build and checks

Run from the repository root:

```sh
dotnet build GT.csproj
godot-mono --headless --editor --path . --quit
godot-mono --headless --path . -- --smoke-test
```

The runtime checks exercise combat rules and match flow, including cooldowns, collisions, unsafe teleport, private handoffs, future sight, rewind, and skirmish cycles.

For a local network integration check, run these in separate terminals:

```sh
godot-mono --headless --path . -- --lan-test-host
godot-mono --headless --path . -- --lan-test-join
```

The two bots should agree on the outcome, clock, and health. LAN uses ENet over UDP port `28461`, with host-driven combat ticks. Interrupted matches cannot be resumed.

## Match behavior

Players deploy one to three fighters, choose a team perk, plan privately, and select a fighter for simultaneous resolution. In skirmishes, unused living fighters act first; a survivor fills a fallen teammate's remaining exchange before the next planning cycle. Health, position, and cooldowns persist.

Local multiplayer uses handoff screens to keep plans private. During planning, enemy markers show their original deployment tiles. Regular planning has no timer; King Crimson's edit window lasts 40 seconds.

Movement resolves before attacks. Walls stop walking, collisions cause damage, and chasms kill instantly. Using a skill while it is on cooldown skips that action. End terminates a sequence and discards later commands when locking.

Knight, Mage, and Archer are selectable. Orc remains unavailable in the interface.

## Audio and presentation

The title, battle, victory, and defeat music slots are bundled. Music crossfades between screens. Separate music and effects settings persist in `user://audio.cfg`. See [music notes](../assets/music/README.md) and [sound notes](../assets/sounds/README.md).

The camera follows the active pair during combat. The pause menu offers a whole-map view. The interface supports mouse and keyboard input, skill tooltips, and terrain markings.

See [presentation media](media/README.md) for the capture command and screenshot provenance.

## Animation asset limits

The Knight left-view rig has a smaller authored sword and combined body, shield, and cape pieces. Independent articulation differs between perspectives; additional separated artwork would be needed to make every view equivalent.
