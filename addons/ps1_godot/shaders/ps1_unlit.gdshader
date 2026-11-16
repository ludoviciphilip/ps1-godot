// Pre-lit: texture * vertex color * 2, no realtime lights (use with PS1Bake).
shader_type spatial;
render_mode unshaded, cull_back;
#define PS1_UNLIT
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
