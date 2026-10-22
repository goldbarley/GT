# Mouse targeting and deployment perk changes

## Updated files

- `scripts/Demo/DemoMain.cs`: roster-wide perk changes before the team is finalized, server-side perk update command, responsive buttons for selecting perks even after placing the first fighter, a click-to-aim attack handler, action range clamping, improved instructions.
- `scripts/Demo/DemoBoard.cs`: mouse attack target event, range validation based on existing SkillTable shapes, translucent hover previews, dotted cast range and affected-tile outlines. All previews are based on projected pre-slot position.
- `scripts/Demo/DemoState.cs`: `DraftPerks` in networked view snapshots so the joiner can see perk selection updates before teams are finalized.

Existing battle engine and LAN networking files remain unchanged.

## Playtest

1. Open in Godot .NET and build. Start a Local Duel.
2. Select a Mage and a perk. Click a valid tile to deploy.
3. Change the perk, e.g. King Crimson to Teleport, without removing Mage. Deploy a second Mage and click Finish Team. Repeat deployment for Player 2 with a different perk.
4. Select a Mage, press numpad 3 (Meteorite). Blue dots mark legal cast positions. Hover an eligible tile along the same row or column: the 3×3 footprint previews in blue with a dotted outline. Click the tile: the landing is aimed but not saved. Press Enter: the timeline slot is confirmed.
5. Try a fixed range move (Knight Stab: 2 tiles), a self shield (click your own tile), Quad Beam (four diagonals), and Archer Ultimate (ray to the edge).
6. Repeat in LAN. Both host and guest should see their perk selections reflected correctly; the opponent's own plan remains private.

C# build and running Godot in a real game are not verified here. The archives have been integrity-checked and source guards inspected.
