# AGENTS.md

Godot 4.7 idle RPG (TBH-like taskbar game). Full spec: `docs/DESIGN.md` — read it before any work; it is the source of truth for numbers and scope.

## Rules

- GDScript only, static typing everywhere (`var x: int`, typed arrays, return types). No C#.
- Game logic lives in `core/` as pure `RefCounted`/static functions with no scene-tree dependency, so it can be tested headless. Nodes only render and call into `core/`.
- Art: only Duelyst CC0 assets under `res://addons/duelyst_animated_sprites/`, copied via `tools/import_duelyst.ps1` from the list in `tools/duelyst_assets.txt`. Never copy anything else from `D:\Tools\Godot_v4.7.1\asset-pack\` (other packs forbid redistribution; this repo is public). Never modify files under `addons/godot_mcp/`.
- User-facing text: Traditional Chinese.
- Do not edit `project.godot` by hand when a Godot setting can be set; if you must, keep existing keys intact.
- Do not commit or push. The reviewer commits after acceptance.

## Commands

- Godot: `D:\Tools\Godot_v4.7.1\Godot_v4.7.1-stable_win64_console.exe`
- Import/refresh project (after adding assets or scripts): `<godot> --headless --path . --import`
- Tests: `<godot> --headless --path . -s res://tests/run_tests.gd` (must exit 0)
- Smoke-run main scene for N frames: `<godot> --headless --path . --quit-after 600`

Before finishing any task: run import, run tests, run the smoke-run, and confirm there are no `SCRIPT ERROR` / `ERROR` lines in the output.
