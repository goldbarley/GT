# Music

Drop one looping track per name into this folder. The game looks for these exact names and plays the first matching format (`.ogg`, then `.wav`, then `.mp3`):

| File | Plays during |
| --- | --- |
| `title` | Title screen, LAN lobby, map select, tutorial backdrop |
| `battle` | Deployment, planning, foresight, selection, combat and rewind |
| `victory` | Result screen when the local player wins |
| `defeat` | Result screen when the local player loses or the match is a mutual defeat |

- Tracks loop automatically and crossfade over 0.9 seconds when the screen changes.
- Missing files are skipped: the game stays silent and prints one hint per missing track.
- OGG Vorbis is recommended for size. Keep an eye on the import settings if a track should not loop on its own; the game forces looping at runtime.
- Volume and mute live in the pause menu and title screen under **Audio settings**, and are saved to `user://audio.cfg`.

All four slots are bundled: `title`, `battle`, `victory` and `defeat`. Replace any of them by dropping a different file with the same name (and deleting the stale `.import` file if you change the extension).
