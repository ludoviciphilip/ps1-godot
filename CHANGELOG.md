# Changelog

## 1.14.1
- **Fix PS1Audio.music going silent** after quick switches: A -> B -> C within a fade reused A's
  player while its fade-out (ending in stop()) still ran, so the new track was faded out and
  stopped. One tween per player now (walking from a bonfire through a boss fog did it).
- PS1Events: nodes in group `PS1Events.FREEZE_GROUP` (`ps1_freeze_in_events`) stop while any
  event runs and resume after — enemies no longer attack a player frozen by a cutscene/dialog.

## 1.14.0
- PS1Collapse `tremor(parent, at, radius, duration, shake, ceiling)`: the ground shakes, dust
  and grit sift down from the ceiling in falling sheets, a few pebbles drop and nothing stays — a
  warning that a place may give way. Cave-ins (`spawn`) now sift dust too (`dust_streams`).
- Events: **Scene/Tremor** command (PS1CmdTremor). Particles: `dust_fall` preset.

## 1.13.0
- PS1Backdrop `stitch(images, blend)`: joins pictures side by side (scaled to one height,
  cross-faded seams) into one wide panorama. A single painting covers ~90–120°: paint the land
  to its left and right and stitch them, so turning the camera never reaches the edge.

## 1.12.0
- PS1Backdrop `fog_panorama(pano, color, amount, height, patchy, drift, scale)`: drifting fog
  banks over a picture panorama — denser at the bottom, broken into slow patches, 4 dithered
  steps on the low-res grid, lit by lightning. The landmarks stay visible above it.
- Panorama shader: its edge dither now follows the low-res grid (it was at native pixels).

## 1.11.0
- **PS1FootLock** (new): planted feet for characters that code moves (lunges, attack steps,
  knockback). A SkeletonModifier3D that pins each planted foot to the floor and, once the body
  has moved `stride` away, takes a quick step (lift, arc, plant) to where the animation wants
  it — one foot at a time. Feet the animation lifts itself (kicks, steps) follow it. Analytic
  two-bone IK keeps the knee where the animation had it. `PS1FootLock.attach(skeleton, body)`,
  `enable(true/false)` (fades).
- **PS1BladeTrail** (new): the ribbon a blade sweeps, Catmull-Rom smoothed between frames,
  white-hot edge line, colored body fading toward the hilt and with age, wind streaks, sparks
  shed from the tip and an optional light riding the tip; PS1 additive blend, dithered alpha
  steps, 5-bit color. Looks: `steel`, `ember`, `blood`, `arcane` or your own Dictionary.
  Freezes with hitstop (time scale).

## 1.10.0
- `add_panorama()`: `order` (behind the ridges and mist sea, or in front of every far layer),
  `side_fade` / `bottom_fade` — the picture's edges dither away so it melts into the scenery
  instead of reading as a framed rectangle.
- `panorama_texture()`: despill (no green fringe around the land after keying the sky out).

## 1.9.0
- PS1Backdrop `add_panorama(texture, direction, arc, radius, bottom, top)`: a picture wrapped
  on a band around the horizon, drawn like the far layers (lightning flashes it), and
  `panorama_texture(image, width, levels, sky_key)`: any painting/render to the PS1 look
  (downscale, ordered-dither color cut) with the sky keyed out so the live sky shows above.
- PS1Gothic `dais()`: collides as one sloped frustum through the step nosings — bodies walk up
  it like a ramp from any side (climbing the box steps one by one looked like teleporting).

## 1.8.1
- PS1Backdrop: `citadel()` stands on a real crag (flat top, cliffs falling into the mist) instead
  of loose rocks — it no longer looks like it floats. New `foothills()` (broken hills whose feet
  sink into the mist) for the valley floor between you and the far scenery.
- PS1Sky: the horizon glow stays on the horizon (it bled below it and painted the valley orange).

## 1.8.0
- **PS1Backdrop reveal kit**: `citadel()` (a cathedral city on a crag facing the viewer: twin
  west towers, rose window and lit door, one immense crossing spire, lit town windows),
  `colossus()` (a kneeling stone giant on a planted sword), `broken_bridge()`,
  `add_lightning()` / `strike()` (flashes sky, clouds, far layers and an optional light, draws a
  bolt, emits `lightning` for your thunder) and `add_birds()` (crows circling a point).
- PS1Sky: `moon_size`, `moon_halo`, a glowing patch of horizon (`glow_color`,
  `glow_direction`, `glow_spread`, `glow_height`) and `set_flash()`.
- **PS1Shot** (new): `await PS1Shot.fly(owner, keys, back)` — a scripted camera flies through
  keyed points looking at targets and glides back to the game camera.
- **PS1Audit** (new): `missing_collision()` finds walls you can see but walk through (visible
  meshes vs. colliders, on the reachable navmesh only).
- PS1Gothic: `sconce()` (wall lantern with a real cage, optionally on a post over a parapet);
  `rampart()`'s wall body now collides (the yard below walks along it); `steps()` is solid
  from the sides (one box per step under the ramp).

## 1.7.1
- PS1Navigation `steer()`: never aims at `path[0]`. That point is only the spot on the mesh
  nearest the body; when the body stood a little off the mesh (wide bodies along railings) it lay
  behind it, and the body flipped direction every frame — a sideways shuffle along sewer
  walkways. Measured on the sewer canal: ~40 direction flips/s -> none.

## 1.7.0
- **PS1Step** (new): step climbing for any CharacterBody3D. `climb(body, visual)` before
  `move_and_slide()` lifts the body onto a low ledge; `smooth(body, visual, dt)` after it lets
  the model glide up instead of popping (climbing used to look like a teleport). Enemies can
  use it too, so they follow the player up a dais.
- PS1Navigation: the clear-way test sweeps a sphere as wide as the body (two thin rays missed
  pillars and wide bodies grazed plinths). Wide bodies (radius > agent + 0.12) path on a second
  navmesh baked at `wide_radius` (0.72), falling back to the normal mesh where it is too tight.
  New `body_radius(body)`. Flooded-hall A/B (pillars with plinths): stuck 7/16 -> 0/16.

## 1.6.2
- `dais()`: default `rise` 0.34 (a 1 m platform gets 3 tiers, not 4).

## 1.6.1
- PS1Gothic `dais()`: a raised platform ringed by tiers of steps, climbable from any side.
- PS1Gothic `valve_wheel()`: a solid iron wheel (rim, spokes with handles, hub) for sluices,
  gates and winches.

## 1.6.0
- New creature presets: `PS1Creature.leech()` (legless segmented body, new `head_style = "maw"`:
  a round mouth ringed with teeth), `PS1Biped.drowned()` (bloated, bald, huge belly) and
  `PS1Biped.hanged()` (gaunt, too-long arms with long fingers, sack hood).
- PS1Biped: `belly` and `arm_length` exports; unarmed idle pose (weapon "none"); four new
  default animations: `spew` (rear back, heave and hold — vomit/breath attacks), `claw` (both
  arms over the head and raked down), `hang` (dangling from the ceiling by the hands, loop) and
  `drop` (let go, fall, land in a crouch). `add_animation()` now only replaces the animation of
  the same name; the other defaults stay.
- PS1Particles presets: `bile` (a jet of sick; set `direction`, or `rate` for a stream) and
  `splash` (something breaking a water surface).
- PS1Water: `glow_color` / `glow_energy` (the fake reflection was hard-coded sky blue, which
  turned sewer water blue).
- Creature demo shows the three new presets.

## 1.5.2
- PS1Navigation: bodies no longer get stuck on door jambs. `agent_radius` 0.25 -> 0.32 (paths
  keep off the walls; 1.2 m arches still connect), `steer()` aims at the farthest waypoint the
  body fits through (width-checked rays) instead of the first one, and a stuck body slides along
  the wall it is pressing instead of pushing in place. Crypt A/B: enemies stuck while chasing
  11/33 -> 0/33 trials.

## 1.5.1
- PS1InventoryMenu: `required_slots` (slots that can be swapped but never left empty, e.g. the
  only weapon).

## 1.5.0
- **PS1Navigation**: runtime navmesh for code-built levels (bakes the static colliders),
  `steer()` that walks straight when clear and follows the path around walls (with a stuck
  detector), `can_see()`, `reachable()`, `rebake()`.
- **PS1Inventory / PS1Item / PS1InventoryMenu**: items as Resources with free-form `stats`,
  counts, equipment slots, signals, save dictionaries, and a menu page in the toolkit's style.
- **PS1FX** + **PS1Aura**: ground sweep arcs (`sweep()`) and glowing weapon auras (`aura()`,
  level-driven, with sparks and an optional light). New shaders `ps1_sweep` and `ps1_aura`.
- PS1Gothic: `heater_shield()`.

## 1.4.0
- **PS1Biped**: procedural low-poly humanoid with a baked AnimationPlayer; poses are keyed as
  limb directions in model space. Preset `archer()` (bow with a live string, quiver, nocked
  arrow; `released` signal), `ghoul()`.
- **PS1Projectile**: arrows/bolts with gravity that stick in walls; `aim()` solves the arc.
- **PS1Sequence** + event command *Puzzle/Sequence Step*: ordered-sequence puzzles with saved
  progress and a solved variable.
- Event command *Scene/Animate Node* (`PS1CmdAnimate`): swing, shake, rotate by, move by.
- PS1Creature: `wing_span`, `horns`, animations `perch`, `wake`, `pounce`; preset `gargoyle()`.
- PS1Gothic: `rampart()`, `belfry()`, `bell()`, `lathe()`.

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
