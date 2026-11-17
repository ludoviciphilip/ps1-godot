# Changelog

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
