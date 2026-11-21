# Asset Store listing — PS1 Maker

## Asset Name
PS1 Maker

## Asset Summary (≈430 / 500)
Make PlayStation 1-style 3D games in Godot 4. Authentic PS1 rendering (vertex jitter, affine textures, 15-bit dithered color, baked vertex lighting, CRT/composite) plus the tools to build a whole game: an RPG Maker-style grid level painter, procedural dungeons, visual events with drops, PS1 particles and audio, a loading screen, settings and pause menus, and CSV translations. Born from — and tested in — a real souls-like.

## Detailed Description (Markdown)

**PS1 Maker** is a drop-in toolkit for making PlayStation 1-style 3D games in Godot 4 (tested on 4.7). It started as the engine side of a souls-like I'm building, and every feature exists because the game needed it — so it's made to ship games, not just to look retro.

### The PS1 look
- **Vertex jitter**, **affine texture warping**, per-vertex (Gouraud) lighting, nearest filtering
- **Low internal resolution** (320×240 base, widens on 16:9) with **15-bit color + Bayer dithering**
- **Baked lighting**: lights and raycast shadows baked into vertex colors (Silent Hill / RE style), cached to disk, baked in the background behind a loading screen
- **Vertex paint**: fake ambient occlusion, height gradients and grime, no hand painting
- Fog and short draw distance with dithered LOD fades, screen-door transparency, alpha-tested foliage
- 4/8-bit CLUT palettes, fixed screen palettes
- **Composite video** (chroma bleed, line jitter, grain) and a **CRT** pass at native resolution (scanlines, aperture grille, curvature)
- Billboard sprites, sky dome (clouds, stars, moon) and PS1 water

### Tools to build the game
- **Level painter (RPG Maker style)**: paint modular pieces on a grid right in the 3D viewport — auto-edge walls, layers, undo, "Test here". Starter piece kit included.
- **Procedural levels**: dungeons, catacombs, caves, mazes and ruins from your own pieces, with size, seed, loops, props, lights and enemies. Live preview in the editor, or generate at runtime (endless dungeons).
- **Events (RPG Maker style)**: pages, conditions, triggers, text and choices, variables, sounds, movement and custom commands, edited in a dedicated panel.
- **"On defeated" events**: one click on an enemy creates an event that runs when it dies — drop items (with chance and spread), show a message, set a variable, open a door… anything you can put in an event.
- **PS1 particles** (11 presets: embers, dust, blood, mist, souls…) and **PS1 audio** (SPU-like buses, pitch-varied one-shots, music crossfades).
- **Loading screen**: threaded scene loading with a PS1 "NOW LOADING" screen that waits for bakes.

### Ready-made game menus
- **Settings screen** with tabs for video, audio, controls and language: window, resolution, FPS, every PS1 effect, volumes, mouse/stick sensitivity, invert Y and **key + gamepad rebinding**. Saved automatically. Add your own options in one line.
- **Pause menu** with your own entries (status pages, save, quit…).
- Everything works with keyboard, mouse and gamepad.

### Translations
Write your game in your own language, run *Project > Tools > PS1: Update translation CSV*, fill in the columns. Event texts, choices and prompts translate themselves — `{variables}` included. The toolkit's own menus ship in English, Portuguese, Spanish, French and German.

### Quality
- Pure GDScript, no C++/GDExtension, MIT license
- Automated test suite plus editor self-tests
- Demo scenes for every feature
- Full documentation in the README

**Install:** add the addon, enable **PS1 Godot** in *Project Settings > Plugins*, restart the editor. Recommended project settings are in the README.

## Tags (first 5 are the ones shown)
ps1, psx, retro, shaders, level-editor, procedural-generation, rpg-maker, low-poly, events, 3d

## Type / License
Addon (tools, assets, etc...) / MIT

## Source Code URL
https://github.com/ludoviciphilip/ps1-godot

## Documentation URL
https://github.com/ludoviciphilip/ps1-godot/blob/main/README.md

## AI Usage Explanation
The code and documentation were written with an AI coding assistant (Claude) under my direction. I decide the features — each one comes from a real need in my own game — and every feature is checked by the toolkit's automated tests and used in that game. No AI-generated images, models or audio are included: the textures, icon and starter pieces are generated procedurally by the toolkit's own code.

## Media (suggested order)
1. docs/demo.png — overall look
2. docs/painter.png — level painter
3. docs/procgen.png — procedural levels
4. docs/events.png — event editor
5. docs/on_defeated.png — drops / on defeated
6. docs/baked.png — baked lighting
7. docs/crt.png — CRT
8. docs/settings.png — settings menu
9. docs/particles.png — particles
