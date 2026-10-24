# Presentation media

- `title.png`, `characters.png`, `deployment.png`, `planning.png`, `combat.png`: real 1440 × 900 game captures.
- `planning-guide.svg`: a vector tutorial with numbered controls and an embedded planning capture.
- `premove-gameplay.gif`: a looping nine-second combat excerpt, 864 × 540 at 15 fps, at the original gameplay speed.
- [Full MP4](../../assets/presentation/premove-demo.mp4): a continuous screen recording at 1440 × 900 and 30 fps, with game audio. It replaces the earlier screenshot slideshow.

## Recording

`tools/record_demo.gd` drives normal keyboard and mouse events through team setup, private planning, and combat. It uses the normal game clock and leaves gameplay rules untouched. Launch it with a visible display:

```sh
godot-mono --path . --windowed --position 0,0 --resolution 1440x900 --script tools/record_demo.gd
```

The runner writes `/tmp/premove-recording.ready` and waits for `/tmp/premove-recording.start`. Remove stale marker files before another take. Start a window capture with FFmpeg or a desktop recorder, then create the start marker. Record the Premove window only. The runner exits after the combat exchange.

Create the GIF from the MP4 with FFmpeg:

```sh
ffmpeg -ss 30 -t 9 -i assets/presentation/premove-demo.mp4 \
  -vf 'fps=15,scale=864:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' \
  -loop 0 docs/media/premove-gameplay.gif
```

The GIF plays inline in the README. The MP4 preserves the full-resolution recording and audio.

## Tutorial stills

The tutorial stills use the repository's `--capture-menu` sample-state scenario. Phase announcement cards were omitted in a temporary capture build so the board is visible. The recording retains the ordinary phase transitions.

```sh
godot-mono --path . --quit-after 180 -- --capture-menu
```

The command saves preview images to `/tmp/premove-*.png`.
