// Lit alpha-tested, double-sided (fences, grass, leaves).
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;
#define PS1_CUTOUT
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
