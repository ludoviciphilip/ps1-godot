# Changelog

## 1.3.4
- Fix: PS1Gothic `room()` doorways had no floor under the wall thickness: two rooms joined at
  a door left a gap the player fell into. Doors now get a threshold slab.

## 1.3.3
- PS1Gothic `sewer()`: bridges get stone curbs and an invisible railing on both sides (crossing
  at an angle could drop you into the channel).

## 1.3.2
- PS1Gothic `sewer()`: iron grates close both ends of the channel (`end_grates`, on by default,
  `grate_surface` for their material). Before, you could walk from the connected rooms straight
  into the trench and never get out.

## 1.3.1
- Fix: an event freed while running (a command changed the scene, e.g. a cave-in that sends the
  player to another area) left `PS1Events.running` stuck at 1, so games that block the pause menu
  during events never opened it again. PS1Event now releases the count in `_exit_tree`.
- PS1Gothic: tombstones, crosses and grave swords now have collision (`props_collide = false`
  turns it off).

## 1.3.0
- **PS1Creature**: procedural low-poly creatures with baked animations (idle, walk, run, attack,
  slam, spin, hit, die) in a regular AnimationPlayer. Segmented bodies, leg pairs, human-arm legs,
  snout or face heads, tails, ring clusters. Presets `rat()`, `crawler()`, `rat_king()`.
- **PS1Collapse** + event command **Scene/Collapse**: cave-ins with falling rocks, dust, rubble and
  camera shake (group `ps1_shake`).
- PS1Gothic: `sewer()`, `room()`, `rock()`, `spindle()`, `limb()`, `quad_away()/quad_toward()`.
- Textures: `PS1Textures.fur()`, `skin()`.
- Fix: vertex paint (AO, gradients) dropped the per-surface materials of multi-material meshes
  (PS1Gothic pieces lost their textures after baking with `ao_strength`).
- Demo `demo/creature_demo.tscn`.

## 1.2.0
- **PS1Gothic**: low-poly gothic/medieval architecture built in code — walls with battlements,
  towers, spires, gables, pointed doorways (`portal`, walkable collision) and arch moldings, lancet
  and rose windows with tracery/mullions, buttresses, columns (whole or broken), steps (ramp
  collision), ruined towers, braziers, pinnacles, and graveyard props (tombstones, crosses, grave
  swords, dead trees). Subdivided faces for vertex lighting, world-space UVs, named surfaces with
  one material each, `build()` returns a StaticBody3D with box/cylinder collision.
- **PS1Backdrop**: panoramas past the far plane — silhouettes that fade into the haze by layer,
  valley mist with a moonlit `add_mist_sea()`, lit windows from `glow` surfaces, procedural
  mountain `ridge()`s.
- Textures: `PS1Textures.ashlar()`, `flagstones()`, `slate_roof()`, `banner()` (cutout).
- Demo `demo/gothic_demo.tscn`.

## 1.1.1
- Fix: crash on quit ("double free") in projects using the settings/pause menus, events or audio:
  the PS1 autoload now empties the toolkit's static registries/caches when the game closes
  (`PS1.release_statics()`).

## 1.1.0
- **PS1Mist**: soft animated mist (fog walls, fog banks): stacked translucent layers with flowing
  noise, soft edges and soft contact with walls/floor, opacity in a few dithered steps on the
  low-res grid (stays clean with the CRT on), optional motes.
- **PS1Shockwave**: a dust ring that rolls out over the ground from an impact and is also the hit
  area: `reached(body)` once per body in `target_group` that the front passes on the ground
  (`min_radius`, `width`, `height`). For boss slams, explosions, falling boulders.
- **PS1Anim.graft()**: give hand-made upper-body animations real footwork by grafting the legs/hips
  of another animation of the same rig, time-warped so the key moments line up; per-bone weights,
  fade in/out back to the original pose. `PS1Anim.lower_body(skeleton)` lists hips + legs.

## 1.0.3
- CRT keeps text readable: while it's on, CanvasLayers with `layer >= PS1.crt_ui_layer` (2) — HUD,
  dialog boxes, menus — draw over the tube, sharp (the CRT samples the picture on the low-res
  grid, which broke text drawn at native resolution). `PS1.crt_covers_ui = true` restores the
  old behavior.

## 1.0.2
- Fix: no "Couldn't find the given section bindings" error on the first run (no saved bindings yet).

## 1.0.1
- Fix: the bake and ambient occlusion no longer error when the level is regenerated or freed while
  they are still running (they spread over frames); a bake interrupted that way isn't cached.

## 1.0.0
- Renamed to **PS1 Maker** (the addon folder stays `addons/ps1_godot/`, so existing projects keep
  working). First Asset Store release; semantic versioning from here on.
- Requires Godot 4.5+.

## 0.12.0
- Works on Godot 4.5+ (test suite and editor self-tests pass on 4.5.1, 4.6 and 4.7.1).
- **PS1Settings**: options as descriptors (`add_option`, `add_binding`, `hide`, `remove_option`),
  saved to `user://ps1_settings.cfg` and re-applied at startup. Built in: window mode/size, V-Sync,
  FPS limit, internal resolution, jitter, affine, dithering, color depth, CRT, composite,
  brightness; master/music/SFX/voice volumes (new `Voice` bus); mouse/stick sensitivity, invert Y;
  key + gamepad rebinding with conflict swap; language.
- **PS1SettingsMenu**: ready-made tabbed screen built from the descriptors (keyboard, gamepad,
  mouse, hold-to-repeat sliders, rebinding, reset per tab).
- **PS1PauseMenu**: pause menu with your own entries (`RESUME`, `SETTINGS`, callables, sub-pages
  with `push()`, `toast()`).
- **PS1Locale**: gettext-style translations from one CSV (key = the original text); event texts,
  choices and prompts are translated automatically and keep `{variables}`; `PS1Locale.mark()`;
  *Project > Tools > PS1: Update translation CSV* collects every event text and `tr()` call,
  keeps existing translations and registers the files (also `--ps1-update-translations`).
  The toolkit's own UI ships in en/pt/es/fr/de.

## 0.11.0
- **On-signal event pages** (RPG Maker "on defeated"): trigger `ON_SIGNAL` with `signal_source`
  (default the parent) + `signal_name`; the signal's Node argument becomes `ctx.source`. Panel:
  signal dropdown. 3D toolbar **+ Event**: adds an event under the selection, pre-set to the
  node's death signal. Editor self-test `--ps1-drop-selftest`.
- Commands: **Spawn Scene (drop)**, **Random Chance**, Node **Move to source**; Show Text expands
  `{variables}`.
- **PS1Loader**: threaded scene loading behind a PS1 loading screen that waits for runtime bakes
  and the `ps1_loading` group; `run_job()`; customizable; demo `loader_demo.tscn`.
- Bake and ambient occlusion yield every `PS1Bake.frame_budget_ms` (worst frame of a runtime
  bake 2.6 s -> 0.36 s); `PS1Bake.progress`.
- PS1LevelGen option `start_near`.
- Tests: fixed a crash at exit (a test lambda stayed connected to the static event signals).

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
