# Changelog

## 0.10.0
- **Procedural levels** (`PS1LevelGen` + `PS1GenTheme`): Dungeon, Catacombs, Caves, Maze, Ruins;
  size, seed, rooms, loops, props, lights, enemies; start/end/spawn markers; always connected;
  ASCII and image previews. Editor: "Generate..." in the PS1 Pieces panel with live preview,
  one undo step (+ `--ps1-gen-selftest`). `gen_theme` on PS1GridLevel. Demo `procgen_demo.tscn`.
- Bake: each mesh only evaluates the lights whose range reaches it (same result, faster on big
  levels: a 32x32 maze went from 31 s to 17 s).

## 0.9.0
- **CRT pass at native resolution** (`PS1.set_crt`, F10): beam-width scanlines, aperture grille,
  curvature; the PS1 picture is sampled on the low-res grid so it doesn't change.
  Dithering in materials/particles/water stays on the low-res grid.
- **Vertex paint** (`PS1VertexPaint`): raycast ambient occlusion, height gradient, grime, fill,
  clear; `PS1BakedLevel` *Vertex paint* options applied at bake time and cached; bake multiplies
  light by paint; "PS1 Paint" toolbar menu (undoable) + editor self-test.
- `PS1Bake.bake_scene_cached(..., extra_sig, before_bake)`.
- **Asset Library ready**: icon, LICENSE inside the addon, export-ignore so the download is just
  the addon; shader globals missing from older projects are added at runtime.

## 0.8.0
- **PS1Particles**: CPU particles in one MultiMesh, 15-bit stepped colors, choppy update rate,
  snapped vertices, additive or dithered blending, code-made sprite sheets, 11 presets,
  `spawn()` one-shots that free themselves, editor preview. Demo `demo/particles_demo.tscn`.
- **PS1Audio**: Music/SFX buses (reverb + low-pass), `play()` with pitch variation, variants
  (`name_1..n`) and voice limit, `loop()`, `music()` crossfade, `set_reverb()`.
- `PS1DialogBox` optional blip / move / confirm sounds.
- Fix: `PS1.flash()` skipped nothing and spammed "material is null" on surfaces without a shader
  material (and Label3D); now only shader-material geometry is flashed.
- Fix: bake cache signature now includes node class and albedo texture, so swapping a piece
  re-bakes instead of applying stale meshes to the wrong nodes.

## 0.7.0
- **Events (RPG Maker style)**: `PS1Event` (pages with condition / trigger Interact-Touch-Autorun /
  graphic / command list), commands Show Text, Show Choices, Conditional Branch, Control Variable
  (`$local` self switches), Wait, Exit, Comment, Node (show/hide/delete/collision), Play Sound,
  Call Method; `PS1Command` base for project commands (auto-listed); `PS1Events` variables + signals;
  default `PS1DialogBox` (typewriter, choices, configurable input actions).
- **"PS1 Events" editor panel**: page tabs, trigger/condition/prompt/graphic, indented command tree,
  add menu by category, Inspector editing, delete/move/duplicate, full undo/redo.
- Events self-test (`--ps1-events-selftest=`) and runtime tests.

## 0.6.0
- **Auto walls / ceilings** on `PS1GridLevel` (`auto_wall`, `auto_ceiling`, `auto_floor_slot`;
  `update_auto()`, `rebuild_auto()`) and the painter's **Auto walls** toggle (one undo step with the floor).
- Fix: coming back to a level with a piece still picked lost its preview (and its slot).
- Fix: slot cache collided for scenes created in code (no resource path).
- Grid demo built with `rebuild_auto()`; painter self-test checks the auto walls.

## 0.5.0
- **Level painter**: `PS1GridLevel` (a `PS1BakedLevel` with a grid) and the **PS1 Pieces** bottom panel:
  palette with auto-rendered thumbnails, paint/drag/erase in the 3D viewport, edge pieces snap to the
  nearest cell edge, layers, rotation, one undo step per stroke, "Hide ceilings", "Test here"
  (`PS1.take_test_spawn()`). Code API: `place`, `erase`, `pieces_at`, `paint_ascii`.
- Starter piece kit (`starter_pieces/`) + its generator (`tools/make_starter_pieces.gd`).
- `demo/grid_level_demo.tscn` (+ `build_grid_demo.gd`).
- Lights with meta `ps1_no_bake` stay out of the bake (lights that change at runtime).
- `PS1BakedLevel` is now `@tool` (subclasses can run in the editor).
- Editor self-test: `godot -e -- --ps1-painter-selftest=SCENE`.

## 0.4.0
- `PS1BakedLevel` node + **PS1 Bake** button in the 3D editor toolbar (bakes in a headless
  process, saves to `res://ps1_bake_cache/`); `--ps1-bake-only` / `--ps1-bake-force` flags.
- `PS1Sprite` and the `billboard` / `billboard_unlit` materials (Y-axis or full billboards,
  sprite-sheet frames via the `ps1_uv_rect` instance uniform). `PS1Textures.flame_sheet()`, `pine()`.
- Composite video filter in the post-process (`PS1.set_composite()`, F9).
- Unlit materials only use vertex colors when `use_vertex_color` is on (default on for
  `unlit`/`unlit_cutout`, which PS1Bake also sets).

## 0.3.0
- `PS1Bake.bake_scene_cached()`: saves baked meshes to a resource and reuses them while the scene
  is unchanged (signature of meshes, transforms, lights). Stable keys by child-index path.
- Screen palette: `PS1.set_screen_palette()`, `PS1.palette_from_screen(n)`, `clear_screen_palette()`
  (nearest-color lookup in the post-process, with ordered dithering).
- `PS1Palette.palette(..., unique = true)`: distinct-color k-means that keeps small bright areas.
- `PS1Sky` (gradient into fog, clouds, stars, moon) and `PS1Water` (waves, two scrolling affine
  layers, screen-door transparency).
- `PS1.set_global()` / `get_global()`.
- Fix: debug keys F1-F5 never worked in a running game (they used
  `RenderingServer.global_shader_parameter_get()`, which is editor-only).

## 0.2.0
- Material modes: `cutout` (alpha test), `dither_alpha` (screen-door transparency), `unlit`,
  `unlit_cutout`; `PS1.make(tex, opts)` with every option; `PS1Convert` maps Godot transparency
  and vertex colors to them.
- `PS1Palette`: k-means texture palettes (PS1 CLUT look), optional ordered dithering, editor tool.
- `texture_color_levels`: cheap per-channel texture quantization in the shader.
- `PS1LOD` node and `PS1.draw_distance()`: per-object draw distance and LOD with complementary
  dithered cross-fades.
- `PS1Bake`: bakes lights + raycast shadows into vertex colors, PS1-style 2x modulation.
- Headless regression tests (`tests/`), new demo features (F6 baked lighting, F7 palettes).
- Fix: `PS1Palette.quantize` no longer modifies the source texture.

## 0.1.0
- Vertex jitter, affine textures, vertex lighting, low-res output, 15-bit color with dithering.
- Material converter + import script, per-instance hit flash.
