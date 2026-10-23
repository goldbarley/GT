# Sound effects

One-shot effects load from this folder by fixed names. The first matching format is used (`.wav`, then `.ogg`, then `.mp3`).

| File | Plays when |
| --- | --- |
| `hurt` | A fighter loses HP during a combat tick (once per tick, with slight pitch variation) |
| `sword_hit` | A Knight's Slash connects, replacing `hurt` for that tick |
| `plunge` | A Knight's Plunge connects, replacing `hurt` for that tick |
| `fireball` | A Mage casts Fireball (trimmed and faded to fit one combat tick) |
| `fireball_hit` | A Mage's Fireball connects, replacing `hurt` for that tick |
| `flame_sword` | A Knight casts Knight's Edge (the flame sword ultimate) |
| `hover` | The mouse enters an enabled button (played quietly) |

- `hurt.wav` is [`Punch_02.wav`](https://freesound.org/people/thefsoundman/sounds/118513/) by thefsoundman, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required but is kept here for provenance.
- `sword_hit.wav` is [Sword Stab Body Hit](https://freesound.org/s/718259/) by -GeorgeDiamond-, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). It is used unmodified; credit is required when distributing the game.
- `plunge.wav` is an edited excerpt of [Door Smash 1](https://freesound.org/s/218890/) by qubodup, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required but is kept here for provenance.
- `fireball.wav` is an edited excerpt of [Fire Spell 01](https://freesound.org/s/275608/) by DiscoverSound (first 1.2 s, with a short fade-out), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Credit is required when distributing the game.
- `fireball_hit.wav` is an edited excerpt of [Simulated Small Explosion in Small Room 1](https://freesound.org/s/132098/) by tcpp (trimmed and faded), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Credit is required when distributing the game.
- `flame_sword.wav` is [Sword_Fire01.wav](https://freesound.org/s/649361/) by SonoFxAudio, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). It is used unmodified; credit is required when distributing the game.
- `hover.wav` is an edited excerpt of [btn402.mp3](https://freesound.org/s/26777/) by junggle, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Leading silence is trimmed; credit is required when distributing the game.
- Add more effects by dropping a file in with a matching name and calling `SoundEffects.Play("name")` from gameplay code.
- Effects volume and mute live in **Audio settings** on the title screen and pause menu, and are saved to `user://audio.cfg`.
