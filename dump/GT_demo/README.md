# Grid Tactics — Pixel RPG Battle Lab

A Godot .NET/C# playtest UI over the existing static `BattleEngine`. Supports 1–3 fighters per team, duplicate classes, mouse-driven deployment, keyboard-programmed combat, couch planning handoffs, and LAN multiplayer through ENet UDP 28461.

Open `project.godot` in a compatible Godot .NET editor. See [PLAYTEST.md](PLAYTEST.md) for detailed controls, LAN connectivity, and test cases.

Key folders:

- `scripts/Demo/`: mouse-based team selection, tactical board, pixel UI and live command preview
- `scripts/Networking/`: ENet LAN session, command RPCs, and snapshot synchronization
- `scripts/`: existing battle engine, character, player, map and skills
- `data/`: tilemap used for the playable battlefield

The host is authoritative in LAN. The joining player receives the map immediately and then synchronized battle states after connecting.

Before finalizing a roster, its team perk may be changed without removing already deployed fighters. Skills can be selected using the numpad, **aimed by clicking a valid battlefield tile**, previewed with dotted targeting/impact outlines, and then confirmed with Enter. See the final section of PLAYTEST.md for test steps.
