# Changelog

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
