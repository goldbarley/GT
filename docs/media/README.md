# Presentation media

- `title.png`, `characters.png`, `deployment.png`, `planning.png`, `combat.png`: real 1440 × 900 game captures.
- `planning-guide.svg`: a vector tutorial layout with the planning capture embedded, numbered highlights, and matching instructions.
- `premove-demo.mp4`: a 30-second, silent H.264 walkthrough with five captioned screenshot scenes. It is edited presentation footage, not a continuous gameplay recording.

The capture scenario is available with:

```sh
godot-mono --path . --quit-after 180 -- --capture-menu
```

It saves preview images to `/tmp/premove-*.png`. It constructs sample states automatically. For these presentation stills, phase announcement cards were disabled in a temporary copy of the project so they did not obscure the board. The repository's transition behavior is unchanged.

The video uses the five PNG files in the order listed above, six seconds each, with a separate caption area. It contains no audio and requires no external video host. GitHub may offer a download instead of inline playback for a repository MP4 link.
