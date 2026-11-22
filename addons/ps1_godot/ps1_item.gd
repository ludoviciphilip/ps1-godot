## One kind of thing the player can carry: a weapon, a shield, a key, a consumable...
## The inventory stores counts by `id`; everything else here is description. Put your game's
## numbers in `stats` (damage multiplier, block cost, heal amount...) and read them when the
## item is equipped or used.
@tool
class_name PS1Item
extends Resource

enum Kind { WEAPON, SHIELD, ARMOR, RING, CONSUMABLE, KEY, MISC }

@export var id := ""
@export var name := ""
@export_multiline var description := ""
@export var kind := Kind.MISC
## Equipment slot ("weapon", "shield", "ring"...). Empty = can't be equipped.
@export var slot := ""
@export var icon: Texture2D
@export var stackable := false
@export var max_stack := 99
@export var stats: Dictionary = {}
## Optional model to show when equipped (your game attaches it).
@export var model: PackedScene

static func make(id_: String, name_: String, kind_: Kind, d := {}) -> PS1Item:
	var it := PS1Item.new()
	it.id = id_
	it.name = name_
	it.kind = kind_
	it.slot = {Kind.WEAPON: "weapon", Kind.SHIELD: "shield", Kind.ARMOR: "armor", Kind.RING: "ring"}.get(kind_, "")
	it.stackable = kind_ == Kind.CONSUMABLE or kind_ == Kind.MISC
	for k in d:
		it.set(k, d[k])
	return it

static func kind_name(k: Kind) -> String:
	return ["Weapons", "Shields", "Armor", "Rings", "Consumables", "Key items", "Misc"][k]
