# Sound effects

One-shot effects load from this folder by fixed names. The first matching format is used (`.wav`, then `.ogg`, then `.mp3`).

| File | Plays when |
| --- | --- |
| `hurt` | A fighter loses HP during a combat tick (once per tick, with slight pitch variation) |
| `sword_hit` | A Knight's Slash or Plunge connects, replacing `hurt` for that tick |
| `fireball` | A Mage casts Fireball (the first half of the source clip) |

- `hurt.wav` is [`Punch_02.wav`](https://freesound.org/people/thefsoundman/sounds/118513/) by thefsoundman, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required but is kept here for provenance.
- `sword_hit.wav` is [Sword Stab Body Hit](https://freesound.org/s/718259/) by -GeorgeDiamond-, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). It is used unmodified; credit is required when distributing the game.
- `fireball.wav` is the first half of [Fire Spell 01](https://freesound.org/s/275608/) by DiscoverSound, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Credit is required when distributing the game.
- Add more effects by dropping a file in with a matching name and calling `SoundEffects.Play("name")` from gameplay code.
- Effects volume and mute live in **Audio settings** on the title screen and pause menu, and are saved to `user://audio.cfg`.
