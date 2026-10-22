# Menu and LAN repair

## Fixes

- Mouse buttons call their exact actions directly, restored from the older working version. Hover only changes tint, never text/layout.
- Only the selected menu screen is visible. No MoveToFront or mouse-filter rewrites on every transition.
- Local Duel always closes networking, assigns Player 1, resets the match, and goes straight into local deployment.
- Host LAN stays in a waiting lobby until a guest joins; only then does it show deployment.
- Join LAN stays in a waiting lobby until the authoritative host map is received; only then does it show the arena.
- Guest disconnection sends host back to the lobby and prevents further gameplay. Server loss sends guest back to mode selection.
- Snapshot sync is accepted from the host while the client is in the lobby or arena, not from title/menu.

## Test

1. On one instance, START MATCH > LOCAL DUEL. The status must identify **LOCAL COUCH** and Player 1. Deploy P1, finish team, then deploy P2. No host/server connection is needed.
2. Relaunch the game. START MATCH > HOST LAN. It must show **WAITING ROOM**; the arena must remain inaccessible until a second instance joins.
3. In a second instance, JOIN LAN with `127.0.0.1`. Both should enter the arena after the host sync. Host sees Player 1, guest sees Player 2.
4. While hosting, close the guest. Host must return to WAITING ROOM rather than continuing solo. Rejoin to resume the lobby flow.
5. On the title/menu screens, click each button with the mouse, then try arrow keys+Enter. They should agree on the destination.

This is a source-level patch. It has not been compiled or run in Godot here.
