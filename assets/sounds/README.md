# Sound effects

One-shot effects load from this folder by fixed names. The first matching format is used (`.wav`, then `.ogg`, then `.mp3`).

| File | Plays when |
| --- | --- |
| `hurt` | A fighter loses HP during a combat tick (once per tick, with slight pitch variation) |
| `sword_hit` | A Knight performs Slash, even when it misses; a connecting Slash replaces `hurt` for that tick |
| `plunge` | A Knight's Plunge connects, replacing `hurt` for that tick |
| `fireball` | A Mage casts Fireball (trimmed and faded to fit one combat tick) |
| `fireball_hit` | A Mage's Fireball connects, replacing `hurt` for that tick |
| `sword_draw` | A Knight begins Knight's Edge (the opening sword draw) |
| `flame_sword` | Knight's Edge reaches its fiery strike (the second part of the ultimate) |
| `meteorite` | A Mage's Meteorite drops, whether or not it damages a fighter; it replaces `hurt` for that tick |
| `quad_beam` | A Mage's Quad Beam fires its four diagonal rays; it replaces `hurt` for that tick |
| `archer_basic` | An Archer performs the basic shot |
| `twinstring` | An Archer performs the twinstring (Double) two-arrow attack |
| `archer_piercer` | An Archer performs the piercing ultimate (piercer) |
| `archer_godray` | The Archer's godray charged shot (reserved for the Archer) |
| `hover` | The mouse enters an enabled button (played quietly) |

- `hurt.wav` is [`Punch_02.wav`](https://freesound.org/people/thefsoundman/sounds/118513/) by thefsoundman, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required but is kept here for provenance.
- `sword_hit.wav` is [Sword Stab Body Hit](https://freesound.org/s/718259/) by -GeorgeDiamond-, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). It is used unmodified; credit is required when distributing the game.
- `plunge.wav` is an edited excerpt of [Door Smash 1](https://freesound.org/s/218890/) by qubodup, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Attribution is not required but is kept here for provenance.
- `fireball.wav` is an edited excerpt of [Fire Spell 01](https://freesound.org/s/275608/) by DiscoverSound (first 1.2 s, with a short fade-out), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Credit is required when distributing the game.
- `fireball_hit.wav` is an edited excerpt of [Simulated Small Explosion in Small Room 1](https://freesound.org/s/132098/) by tcpp (trimmed and faded), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Credit is required when distributing the game.
- `flame_sword.wav` is [Sword_Fire01.wav](https://freesound.org/s/649361/) by SonoFxAudio, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). It is used unmodified; credit is required when distributing the game.
- `sword_draw.wav` is an edited excerpt of [Sword draw unsheathe](https://freesound.org/s/581594/) by SamsterBirdies, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Trimmed to fit the opening of Knight's Edge, with a short fade-out.
- `meteorite.wav` is an edited excerpt of [custom rock boulder impact sounds part 3](https://freesound.org/s/829272/) by Artninja, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The first impact is trimmed to 1.5 s, lowered 3 dB, and faded out; credit is required when distributing the game. The creator's source list includes an NC-licensed sample, so clear commercial use with the author.
- `quad_beam.wav` is an edited excerpt of [DStorsions_Basstard_suonho.wav](https://freesound.org/s/6477/) by suonho, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The first blast is trimmed to 1.1 s, lowered 10 dB, and faded in and out; credit is required when distributing the game.
- `twinstring.wav` is an edited excerpt of [Arrow Release and Hit](https://freesound.org/s/179996/) by calvarychurchatlanta, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Leading and trailing silence is trimmed and the end faded out. Attribution is not required but is kept here for provenance.
- `archer_basic.wav` is an edited excerpt of [Arrow Loose](https://freesound.org/s/394185/) by saturdaysoundguy, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Trimmed to the bowstring release, with the level raised and the end faded out. Attribution is not required but is kept here for provenance.
- `archer_piercer.wav` is an edited excerpt of [Electric Shot, Or Death Sound Effect](https://freesound.org/s/476469/) by LilMati, released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Trimmed to 1.15 s, lowered 3 dB, and faded in and out. Attribution is not required but is kept here for provenance.
- `archer_godray.wav` is extracted from the user-provided `Pixel Archer Animation.mkv`, time-fitted to the 2.58 s godray clip, with a short fade-out. Confirm the source video's license before distributing the game.
- `hover.wav` is an edited excerpt of [btn402.mp3](https://freesound.org/s/26777/) by junggle, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Leading silence is trimmed; credit is required when distributing the game.
- Add more effects by dropping a file in with a matching name and calling `SoundEffects.Play("name")` from gameplay code.
- Effects volume and mute live in **Audio settings** on the title screen and pause menu, and are saved to `user://audio.cfg`.
