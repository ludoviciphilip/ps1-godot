# Contributing to PS1 Maker

Thanks for considering a contribution! This is a small, focused Godot 4 addon — keep changes
scoped and in the style of the existing code.

## Setup

1. Clone the repo and open the folder in Godot 4.5+ (the editor reads `project.godot` at the root).
2. *Project Settings > Plugins*: make sure **PS1 Maker** is enabled.
3. Restart the editor once (shader globals are only picked up on startup).

## Running the tests

```
godot --headless --path . res://tests/test_toolkit.tscn     # bake, palette, LOD, converter
godot --path . res://tests/lod_visual.tscn                   # visual LOD check
godot -e --path . -- --ps1-painter-selftest=res://demo/grid_level_demo.tscn   # painter in the real editor
godot --headless --path . res://tests/baked_level_test.tscn -- --ps1-bake-only --ps1-bake-force
```

Run `tests/test_toolkit.tscn` headless before opening a PR; it should pass with no errors.

## Code style

- Pure GDScript, no C++/GDExtension.
- Follow the naming already used in `addons/ps1_godot/` (`PS1*` classes, `ps1_*` shader globals).
- Add or update a demo scene under `demo/` when a feature is easiest to show rather than describe.
- Update `CHANGELOG.md` and the README for anything user-facing.

## Pull requests

- One topic per PR; describe what changed and why in the description.
- Keep the addon folder at `addons/ps1_godot/` and the repository name `ps1-godot` (existing
  projects depend on both paths).
- Don't bump the version in `plugin.cfg` — that's done at release time.

## Reporting bugs / requesting features

Use the issue templates. For security issues, see [SECURITY.md](SECURITY.md) instead of a public
issue.
