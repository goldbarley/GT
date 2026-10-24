# Presentation media

- `title.png`, `characters.png`, `deployment.png`, `planning.png`, `combat.png`: real 1440 × 900 game captures.
- `planning-guide.svg`: a vector tutorial with numbered controls and an embedded planning capture.
- `premove-gameplay.gif`: a looping movement tutorial at 960 × 720 and 15 fps. It shows previewing and confirming a left-then-up route, locking the plan, and executing it. Setup and opponent planning are omitted from this excerpt; gameplay runs at its original speed.
- [Full MP4](../../assets/presentation/premove-demo.mp4): a real-time screen recording with game audio, an animated input guide, and captions below the game screen. The game itself is captured at 1440 × 900 and 30 fps; the final frame is 1440 × 1080 to accommodate the guide.

## What the demo teaches

1. During deployment, WASD moves the placement marker and Enter places the fighter.
2. During planning, WASD previews a movement step and Enter adds it to the sequence.
3. A → Enter → W → Enter queues a left-then-up route.
4. Number keys choose skills; arrow keys aim them; Enter confirms.
5. 0 ends the sequence; Space locks the plan.
6. Both plans execute together after both players lock.

The recording uses the ordinary whole-map camera option so the grid stays fixed while the fighters move. A labeled movement-detail inset magnifies the same live footage; it does not synthesize or retime character motion.

## Recording and editing

`tools/record_demo.gd` drives normal keyboard and mouse events through setup, private planning, and combat. It uses the normal game clock and leaves gameplay rules untouched.

```sh
godot-mono --path . --windowed --position 0,0 --resolution 1440x900 --script tools/record_demo.gd
```

The runner writes `/tmp/premove-recording.ready` and waits for `/tmp/premove-recording.start`. Remove stale marker files before another take. Start a window capture with FFmpeg or a desktop recorder, then create the start marker. Record only the Premove window and its audio. The runner writes timestamped instructions to `/tmp/premove-recording-events.jsonl` and exits after the exchange.

Add the animated key guide and generate the GIF:

```sh
python3 tools/edit_demo.py /path/to/raw-recording.mp4 /tmp/premove-recording-events.jsonl
```

Use `--offset` to match the delay between capture start and the start marker; the default is 0.7 seconds. The editor uses FFmpeg and its ASS subtitle renderer to animate key highlights and captions below the unobscured game screen. The GIF combines the movement-planning and execution portions of the same take.

## Tutorial stills

The tutorial stills use the repository's `--capture-menu` sample-state scenario. Phase announcement cards were omitted in a temporary capture build so the board is visible. The recording retains the ordinary phase transitions.

```sh
godot-mono --path . --quit-after 180 -- --capture-menu
```

The command saves preview images to `/tmp/premove-*.png`.
