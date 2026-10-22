# GT Pixel RPG Demo — Playtest Guide

## Requirements

- Godot **.NET/C#** edition compatible with the project (`GT.csproj` currently targets Godot.NET.Sdk/4.7.2)
- .NET 8 SDK
- Two instances or two LAN computers for multiplayer

Open `project.godot` in the Godot .NET editor, build C#, then press F5. Use the updated project directory, not the old demo folder.

## Local hotseat

1. **START MATCH → LOCAL DUEL**.
2. Player 1 clicks one of the four **class cards** and one **perk card**. Click a green-highlighted tile in the northern half to place a fighter. Repeat up to 3 times, including duplicate classes. Use **REMOVE LAST FIGHTER** if needed.
3. Click **FINISH TEAM**. Player 2 repeats in the southern half. The board shows both teams' original spawn positions.
4. The planner opens for **Player 1 only**. Click a fighter tab, press an arrow for a pending move or numpad 1–9 for an ability. Adjust aim with arrows and range with +/-; **Enter commits** the pending action. The map previews pending actions before Enter, translucent markers show saved moves, and the slot strip distinguishes confirmed moves from EMPTY slots.
5. Click **LOCK PLAN** (or F). Player 2 plans next and locks.
6. If King Crimson was selected, its owner gets **30 seconds** of Future Sight. Tab cycles through editable slots; Enter overwrites the highlighted slot.
7. Each player clicks a fighter tab and **SELECT THIS FIGHTER FOR BATTLE**. Player 1 clicks **START EXCHANGE**. Combat advances automatically every 0.42 seconds.
8. If Defy Destiny was chosen, **after the entire exchange** the board highlights all tiles used, with tick numbers. Click a marked tile to choose its latest historical tick, then choose a replacement action using arrow/numpad and press Enter. The remaining exchange automatically replays after a successful 70% roll. Press P to leave history unchanged.

The keyboard is for **action programming**; class, perk, spawn tile, and teammate selection are mouse-driven.

## Keyboard (planning)

| Key | Meaning |
| --- | --- |
| Arrow keys | Preview movement; aim when a skill or teleport is selected |
| Numpad 1–9 | Choose a class skill (must be a skill number that exists for the class) |
| Numpad 0 | Mark end of script |
| T | Prepare teleport, if the team has the Teleport perk |
| +/- | Adjust attack range / teleport distance |
| Enter (main or numpad) | **Confirm** pending action into the highlighted slot |
| Backspace | Undo/clear a slot |
| Esc | Cancel a pending preview |
| F | Lock planning |
| Tab | Cycle action slots during Future Sight |

Key processing now uses the early `_Input` stage, not `_UnhandledKeyInput` where GUI scroll containers can intercept arrows. The join-address field releases keyboard focus when entering the arena. Numpad detection checks both logical and physical keycodes.

## LAN test

**Host** opens START MATCH → HOST LAN DUEL. **Guest** opens START MATCH → enters the host's local IPv4 → JOIN LAN DUEL. Both are on the same network and the host allows inbound **UDP 28461**. You can test both windows on one computer by connecting to `127.0.0.1`.

The guest must see the entire battlefield **even while connecting**. Class/perk cards unlock after the host's first authoritative snapshot arrives. The guest explicitly requests that snapshot upon joining; the host also retransmits current state every half-second while connected. Both users can **deploy and plan simultaneously on LAN**; the host resolves actions and sends each client their own plan and a battlefield view.

Quick verification:

1. Host creates match, guest joins. Host should report Player 2 connected; guest should show the map and then the roster controls.
2. Guest selects ARCHER and TELEPORT with the mouse, clicks a valid southern tile. Both screens should show the guest's square within roughly half a second.
3. Host and guest each deploy at least one fighter and finish their team.
4. Guest presses Up then Enter. Its translucent planned destination and slot 1 should update. The host **should not** see private guest commands unless permitted by an intel perk.
5. Each user locks independently. Select a fighter and begin the exchange from the host. Both screens should display the resulting positions.

If LAN is still not receiving snapshots, check the Godot debugger on both machines for RPC errors, confirm the host IPv4 and inbound UDP firewall rule, and check that both instances are running this **same version**. LAN has not been runtime-verified in this environment.

## Changes in this version

- Mouse-operated class/perk cards, roster, and character switching
- Highlighted legal deployment half; forbidden locations visibly darkened
- Removed dependence on arrow/keyboard deployment
- Early-stage keyboard event capture for action preview and numpad skills
- Guest loads the base map while connecting; receives full host state on join + periodic updates
- Network command validation uses the connected peer ID instead of hardcoding peer 2
- Keeps 1–3 characters, duplicate classes, couch sequential planning, LAN parallel planning, 30-second Future Sight and Tab editing

## Limitations

This is a playtest demo. The package passed file/static checks, but **C# compilation, actual keyboard input, and ENet behavior were not executed here** because Godot .NET and .NET SDK are unavailable in this environment. If the first build reports errors, capture the exact diagnostic and line number.

## Perk switching and mouse attack targeting

- On deployment, select a perk card and place a fighter. **Before** pressing FINISH TEAM, choose a different perk card. The roster remains deployed and all its fighters adopt the new team perk. You can add another fighter without removing the first. Perks already reserved by the other team are disabled.
- Once **both** teams finish deployment and it is your planning phase, press **Numpad 1** for an attack. Dotted pale-blue markers show targetable positions. A dotted gold outline surrounds the predicted impact tiles (including a single tile, a 3×3 area, or a piercing line). Hovering an allowed target previews that impact in pale blue.
- **Click** a target tile to set direction and range, then press **Enter** to add the skill to the next action slot. Clicking does not commit a slot. Arrow-key aiming is still available.
- Fixed-range moves only accept their specified landing distance. Knight Plunge accepts 2 or 3 tiles; Archer Double Shot hits both the 4th and 5th tiles. Self-shields target your own tile. Quad Beam highlights all four diagonals and can be selected via any affected diagonal tile.
- These are cardinal-targeted attacks; Fireball, Meteorite and other directed attacks require a tile in the same row or column as the caster. Clicking an invalid tile gives an explanatory status message.

**Quick regression test:** Start a local game. Choose Tactician, deploy a Mage, change the perk to Teleport, then deploy a second Mage. Finish the team. After the opponent finishes their team, press Numpad 3 to select Meteorite, hover a tile three rows above your Mage, click it, observe the dotted 3×3 impact outline, and press Enter. Check slot 1 and the saved translucent impact area. Repeat in both host and guest LAN instances.


See `REPLAY_CHANGES.md` for the new exchange/replay rules and tests.
