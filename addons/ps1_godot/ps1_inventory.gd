## Inventory + equipment, as data: what the player carries (id -> count), what is equipped
## (slot -> id), with signals for the HUD and to_dict()/from_dict() for saves. Items are
## described by PS1Item resources registered in `items`.
##
##   var inv := PS1Inventory.new()
##   inv.register(PS1Item.make("short_sword", "Short Sword", PS1Item.Kind.WEAPON, {stats = {damage = 1.0}}))
##   inv.add("short_sword")
##   inv.equip("short_sword")
##   inv.equipped_item("weapon").stats.damage
##
## Open PS1InventoryMenu to browse it in game (or push it into the pause menu).
class_name PS1Inventory
extends RefCounted

signal changed
signal equipped(slot: String, item: PS1Item)
signal unequipped(slot: String, item: PS1Item)

var items := {}       # id -> PS1Item (the database)
var counts := {}      # id -> int
var equipment := {}   # slot -> id

func register(item: PS1Item) -> PS1Item:
	items[item.id] = item
	return item

func item(id: String) -> PS1Item:
	return items.get(id)

func count(id: String) -> int:
	return int(counts.get(id, 0))

func has(id: String) -> bool:
	return count(id) > 0

func add(id: String, n := 1) -> int:
	var it := item(id)
	if it == null:
		push_warning("PS1Inventory: unknown item '%s'" % id)
		return 0
	var cap := it.max_stack if it.stackable else 1
	var before := count(id)
	counts[id] = mini(before + n, cap)
	changed.emit()
	return counts[id] - before

## Removes n (returns how many were removed). Removing the last one unequips it.
func remove(id: String, n := 1) -> int:
	var before := count(id)
	var after := maxi(before - n, 0)
	if after == 0:
		counts.erase(id)
		for s in equipment.keys():
			if equipment[s] == id:
				unequip(s)
	else:
		counts[id] = after
	changed.emit()
	return before - after

func equip(id: String) -> bool:
	var it := item(id)
	if it == null or it.slot == "" or not has(id):
		return false
	if equipment.get(it.slot, "") == id:
		return true
	if equipment.has(it.slot):
		unequip(it.slot)
	equipment[it.slot] = id
	equipped.emit(it.slot, it)
	changed.emit()
	return true

func unequip(slot: String) -> void:
	if not equipment.has(slot):
		return
	var it := item(equipment[slot])
	equipment.erase(slot)
	unequipped.emit(slot, it)
	changed.emit()

func equipped_item(slot: String) -> PS1Item:
	return item(equipment.get(slot, ""))

func is_equipped(id: String) -> bool:
	return equipment.values().has(id)

## Items carried, optionally only of one kind, in registration order.
func carried(kind := -1) -> Array[PS1Item]:
	var out: Array[PS1Item] = []
	for id in items:
		var it: PS1Item = items[id]
		if has(id) and (kind < 0 or it.kind == kind):
			out.append(it)
	return out

## A stat of whatever is in `slot` (or `default`).
func stat(slot: String, key: String, default = 0.0):
	var it := equipped_item(slot)
	return it.stats.get(key, default) if it else default

func to_dict() -> Dictionary:
	return {counts = counts.duplicate(), equipment = equipment.duplicate()}

func from_dict(d: Dictionary) -> void:
	counts = {}
	for k in d.get("counts", {}):
		if items.has(k):
			counts[k] = int(d.counts[k])
	equipment = {}
	for s in d.get("equipment", {}):
		var id: String = d.equipment[s]
		if has(id):
			equipment[s] = id
	changed.emit()
	for s in equipment:
		equipped.emit(s, item(equipment[s]))
