# Keyboard planning repair

The key-detection indicator was working, but the first arrow key could never stage a movement. `pendingStep` uses `int.MinValue` as the `no pending action` sentinel; the old code treated every negative number as a skill, including `int.MinValue`, so the first arrow modified the aim direction without creating a move.

The normal planning and Defy Destiny handlers now distinguish the sentinel from real negative skill codes. A pending action is also shown in the selected timeline box in gold, suffixed with `?`; after Enter confirms, the permanent slot is rendered green. The board continues to show the pending move/attack as its brighter preview.

## Test in Godot

1. Open the project in Godot .NET. Deploy at least one character for each player and click Finish Team for both.
2. When the banner says PLANNING, press Up. The input indicator should say `ACCEPTED` and `PENDING: UP`. The selected action box should display `UP ?` and the board should highlight the intended destination.
3. Press Enter. The action box should change to a committed `UP` without `?`, and the translucent route should stay on the board. The next empty slot becomes selected.
4. Press numpad 1 to stage the first ability. A gold `SKILL 1 ?` should show; arrow keys now aim that skill instead of replacing it with a movement action. Press Enter to save.
5. Press Backspace to undo, then try another direction. Repeat for Player 2 during local hotseat planning. In LAN, each player plans concurrently.

If the indicator says `NOT ACTIVE`, the game is not in the editable planning phase (e.g., another player's couch turn, undeployed teams, a locked plan, or combat). If it says `ACCEPTED` and `PENDING: UP` but the board is blank, check the Godot debugger for `_Draw` errors in DemoBoard.cs.

This patch changes `scripts/Demo/DemoMain.cs` and `scripts/Demo/ActionTimeline.cs`. It does not change engine actions or LAN RPCs. Source and archives have been inspected, but Godot/.NET build and runtime are not available in this environment.
