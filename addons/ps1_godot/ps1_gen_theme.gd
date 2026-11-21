## Which pieces PS1LevelGen builds with. Any field left empty is skipped (no ceiling scene =
## open sky, no torch = no torches...). Markers left empty become plain Marker3D nodes in the
## groups "ps1_gen_start", "ps1_gen_end" and "ps1_gen_spawn", so your game can find them.
@tool
@icon("res://addons/ps1_godot/icons/grid_level.svg")
class_name PS1GenTheme
extends Resource

@export var floor_scene: PackedScene
## Open ground (Ruins style). Empty = floor_scene.
@export var ground_scene: PackedScene
@export var wall_scene: PackedScene
## Doorway between a room and a corridor (an arch, a door frame...).
@export var door_scene: PackedScene
@export var ceiling_scene: PackedScene
@export var pillar_scene: PackedScene
## Wall torch (edge piece).
@export var torch_scene: PackedScene
## Free-standing light placed in the middle of big rooms.
@export var brazier_scene: PackedScene
## Clutter placed along room walls (picked at random).
@export var prop_scenes: Array[PackedScene] = []
## Fills the burial niches dug along corridors (Catacombs style), e.g. a coffin.
@export var niche_scene: PackedScene
@export_group("Markers")
## Player start (e.g. a spawn point or a bonfire). Empty = Marker3D in group "ps1_gen_start".
@export var start_scene: PackedScene
## The far end of the map (boss, exit, treasure). Empty = Marker3D in group "ps1_gen_end".
@export var end_scene: PackedScene
## Enemies (picked at random). Empty = Marker3D nodes in group "ps1_gen_spawn".
@export var enemy_scenes: Array[PackedScene] = []

const _S := "res://addons/ps1_godot/starter_pieces/"

## The toolkit's starter pieces. With a level, its auto_wall / auto_ceiling are used for walls
## and ceilings, so painting by hand afterwards keeps managing them.
static func starter(level: PS1GridLevel = null) -> PS1GenTheme:
	var t := PS1GenTheme.new()
	t.floor_scene = load(_S + "1_structure/floor.tscn")
	t.wall_scene = level.auto_wall if level and level.auto_wall else load(_S + "1_structure/wall.tscn")
	t.door_scene = load(_S + "1_structure/wall_door.tscn")
	t.ceiling_scene = level.auto_ceiling if level and level.auto_ceiling else load(_S + "1_structure/ceiling.tscn")
	t.pillar_scene = load(_S + "1_structure/pillar.tscn")
	t.torch_scene = load(_S + "3_lights/wall_torch.tscn")
	t.brazier_scene = load(_S + "3_lights/brazier.tscn")
	t.prop_scenes = [load(_S + "2_props/block.tscn")]
	t.niche_scene = load(_S + "2_props/coffin.tscn")
	return t
