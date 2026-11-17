// Lit alpha-tested sprite turning around Y (trees, sprite characters).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;
#define PS1_CUTOUT
#define PS1_BILLBOARD_Y
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
