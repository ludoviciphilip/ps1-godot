// Lit screen-door transparency (ghosts, water, glass).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;
#define PS1_DITHER_ALPHA
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
