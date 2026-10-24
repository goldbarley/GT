#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
godot_bin="${GODOT_BIN:-godot-mono}"
release_dir="$project_root/builds/linux"
mkdir -p "$release_dir"
dotnet build GT.csproj -c Release
"$godot_bin" --headless --editor --path "$project_root" --quit
"$godot_bin" --headless --path "$project_root" --export-release Premov_Linux "$release_dir/Premove.x86_64"
cp assets/fonts/Terminus.LICENSE.txt "$release_dir/Terminus.LICENSE.txt"
cat > "$release_dir/README.txt" <<'NOTES'
Premove — Linux x86_64

Extract the entire archive, then run ./Premove.x86_64.
Keep data_GT_linuxbsd_x86_64 next to the executable.
If necessary, run chmod +x Premove.x86_64 first.

The .NET runtime is included. Godot and the .NET SDK are not required.
A Linux x86_64 desktop with OpenGL 3.3 support and working audio is required.

Practice: play against the computer.
Couch multiplayer: share one computer using private handoff screens.
LAN: host on one computer and join from another on the same network.
Allow UDP 28461 on the host if required. Use the same build on both machines.

Controls: WASD move; 1-5 skills; arrows aim; +/- range; Enter confirm;
Tab switch fighter; 0 end sequence; Space lock; Escape menu; F11 fullscreen.
NOTES
tar -czf builds/Premove-Linux-x86_64.tar.gz -C builds/linux README.txt Terminus.LICENSE.txt Premove.x86_64 data_GT_linuxbsd_x86_64
(cd builds && sha256sum Premove-Linux-x86_64.tar.gz > Premove-Linux-x86_64.sha256)
printf 'Release: %s/builds/Premove-Linux-x86_64.tar.gz\n' "$project_root"
