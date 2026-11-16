// PS1 lit material: vertex snapping (jitter), affine texture mapping, per-vertex lighting,
// nearest filtering without mipmaps. Global params live in Project Settings > Shader Globals.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
