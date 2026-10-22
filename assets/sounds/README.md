# Sound effects

One-shot effects load from this folder by fixed names. The first matching format is used (`.wav`, then `.ogg`, then `.mp3`).

| File | Plays when |
| --- | --- |
| `hurt` | A fighter loses HP during a combat tick (once per tick, with slight pitch variation) |

- `hurt.wav` is [`Punch_02.wav`](https://freesound.org/people/thefsoundman/sounds/118513/) by thefsoundman, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required but is kept here for provenance.
- Add more effects by dropping a file in with a matching name and calling `SoundEffects.Play("name")` from gameplay code.
- Effects volume and mute live in **Audio settings** on the title screen and pause menu, and are saved to `user://audio.cfg`.
