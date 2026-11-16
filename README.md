# PS1 Souls (codinome)

Souls-like dark fantasy com estética PS1, em Godot 4.7.

## Estrutura
- `ps1/` — toolkit PS1 reutilizável (a nossa "engine")
  - `shaders/ps1_lit.gdshader` — material base: vertex jitter, texturas affine, luz por vértice, nearest
  - `shaders/ps1_post.gdshader` — profundidade de cor 15 bits + dithering Bayer 4x4
  - `ps1.gd` — autoload `PS1`: pós-processamento global, `PS1.material(...)`, atalhos de debug
  - `ps1_textures.gd` — texturas procedurais placeholder
- `scenes/demo/` — cena de teste do visual

## Configuração
- Resolução base 320x240 (alarga em widescreen), upscale nearest. Janela 1280x720.
- Parâmetros globais em Project Settings > Shader Globals (`ps1_*`).

## Atalhos (debug)
F1 jitter · F2 affine · F3 dither · F4 resolução (240p/360p/480p) · F5 níveis de cor · TAB câmera livre (WASD, Q/E, mouse) · ESC sair

## Roadmap
1. [x] Visual PS1 (shaders, pós, cena de teste)
2. [ ] Movimento: controlador do personagem + câmera com lock-on
3. [ ] Combate: ataques, hitboxes por frame, stamina, esquiva com i-frames, 1 inimigo
4. [ ] Loop: morte, checkpoint (fogueira), 1 chefe
