# Repository Guidelines

## Project Structure & Module Organization

Premove is a Godot 4.7 .NET tactical game. `scripts/` contains the existing C# battle engine, character rules, skills, and map loader. `scripts/Game/` contains the playable interface and match flow; `scripts/Animation/` contains the shared animation runtime. `scenes/` holds Godot scenes, `data/` holds map JSON, and `assets/characters/` contains integrated character rigs and effects. `dump/` holds reference prototypes and is excluded from compilation and Godot scanning.

## Build, Test, and Development Commands

- `dotnet build GT.csproj`: compile the C# project using its pinned Godot SDK.
- `godot-mono --editor --path .`: open the project with the Godot .NET editor.
- `godot-mono --path .`: launch Premove locally.
- `godot-mono --headless --editor --path . --quit`: import resources and check script loading.

Use the .NET edition of Godot. The project targets .NET 8 on desktop and .NET 9 on Android. Generated `.godot/` files should remain untracked.

## Coding Style & Naming Conventions

Match nearby code: C# uses four spaces and braces on separate lines; GDScript uses tabs and snake_case functions. Keep class names and filenames aligned. Preserve existing engine APIs, including their lower camelCase methods. `.editorconfig` specifies UTF-8; no additional formatter is configured.

Keep structural changes small. Add code comments only for otherwise obscure constants or properties. Put gameplay explanations and controls in documentation or the interface.

## Testing Guidelines

No dedicated unit testing framework or coverage threshold is configured. `tests/MatchChecks.cs` supplies runtime checks; run `godot-mono --headless --path . -- --smoke-test`. Build C# and check Godot resource loading after changes. For gameplay changes, exercise deployment, private planning, targeting, cooldowns, simultaneous combat, perks, defeat, and rematches. Document commands and manual checks in pull requests.

## Commit & Pull Request Guidelines

History uses short informal descriptions without a fixed prefix scheme. Prefer clear imperative subjects such as `Fix Knight plunge playback`. Keep changes focused. Describe behavior changes, validation, and known asset limitations; link relevant issues and include screenshots or recordings for UI and animation changes.
