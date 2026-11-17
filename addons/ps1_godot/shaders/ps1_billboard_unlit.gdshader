// Unlit alpha-tested sprite always facing the camera (fire, particles, effects).
shader_type spatial;
render_mode unshaded, cull_disabled;
#define PS1_UNLIT
#define PS1_CUTOUT
#define PS1_BILLBOARD
#include "res://addons/ps1_godot/shaders/ps1_lit.gdshaderinc"
