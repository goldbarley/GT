# Linux release

Download [Premove v0.1.0](https://github.com/goldbarley/GT/releases/tag/v0.1.0). The release is a self-contained Linux x86_64 desktop build. It includes the .NET runtime and uses Godot's OpenGL compatibility renderer.

## Play

Extract `Premove-Linux-x86_64.tar.gz`, open the extracted folder, and run:

```sh
chmod +x Premove.x86_64
./Premove.x86_64
```

Keep `data_GT_linuxbsd_x86_64` beside the executable. Install neither Godot nor a separate .NET runtime to play. A Linux desktop with OpenGL 3.3 support and working audio is required.

For LAN play, both computers need the same build and network access to UDP port `28461` on the host. Reconnect/resume remains unsupported.

## Build the archive

Install Godot 4.7.2 .NET, its matching Linux export templates, and the .NET 8 SDK. From the repository root:

```sh
./tools/build_linux.sh
```

Set `GODOT_BIN` if the executable has a different name. Output:

```text
builds/Premove-Linux-x86_64.tar.gz
builds/Premove-Linux-x86_64.sha256
```

Verify the archive:

```sh
cd builds
sha256sum -c Premove-Linux-x86_64.sha256
```

The export includes map and animation JSON, bundles the .NET runtime, excludes presentation media and standalone test scripts, and omits debug symbols. The Godot AI export plugin removes its editor helper from the release.

## Fixes in this release

- Removed an Archer effect's dependency on a missing prototype class. The effect still draws the same arcs when its parent supplies the expected values.
- Aligned the basic arrow effect's origin with the bowstring nock. Damage, range, cooldowns, and timing are unchanged.
- Updated the King Crimson check and documentation to the existing 40-second rule.
- Stopped audio before quitting and allowed pending playback releases to finish, removing shutdown resource errors.
- Repaired the LAN test scenario so single-fighter bots fight to a result instead of walking indefinitely.

The battle rules and character balance are preserved.

## Validation

Validated on 24 October 2026:

| Check | Result |
| --- | --- |
| C# compilation | Pass, no compiler warnings |
| Godot resource import | Pass |
| Runtime match checks | Pass |
| Hit effects and controller forwarding | Pass |
| Archer preview transform and playback | Pass |
| Archer bowstring draw and arrow origin | Pass |
| Shared teleport playback for all three classes | Pass |
| Extracted Linux executable, headless match checks | Pass |
| Extracted Linux executable, desktop startup | Pass |
| LAN single-fighter match | Both peers agree on result, clock, and health |
| LAN three-fighter cycle | Both peers complete selection and combat |
| LAN Volcanic Ruins three-fighter cycle | Both peers complete selection and combat |
| Graceful exit after active audio | No resource cleanup errors |

The connected editor also reported no new project errors during a practice run. Historical debugger rows from before the fix can remain visible in the editor.

Normal quit and smoke-test shutdown now stop audio and drain pending playback releases before exiting. The final validation covers the scenarios above; it does not establish compatibility with every Linux distribution or graphics driver.

## Source checks

```sh
dotnet build GT.csproj --no-restore
godot-mono --headless --editor --path . --quit
godot-mono --headless --path . -- --smoke-test
godot-mono --headless --path . --script tests/test_hit_effect_gt.gd
godot-mono --headless --path . --script tests/test_archer_preview.gd
godot-mono --headless --path . --script tests/test_archer_bow_draw.gd
godot-mono --headless --path . --script tests/test_teleport_animation.gd
```

The GDScript checks are standalone `SceneTree` runners and must use `--script`; they are not suites for the editor plugin's test runner.
