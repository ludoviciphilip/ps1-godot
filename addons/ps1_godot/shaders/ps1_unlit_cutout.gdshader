// Pre-lit + alpha test.
shader_type spatial;
render_mode unshaded, cull_disabled;
#define PS1_UNLIT
#define PS1_CUTOUT
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
