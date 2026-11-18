## Builds the starter pieces for PS1GridLevel (structure + lights) in
## res://addons/ps1_godot/starter_pieces/. Re-run to regenerate:
##   godot --headless --path . -s res://addons/ps1_godot/tools/make_starter_pieces.gd
## Use them as they are, or as templates for your own (swap the meshes for Blender models and keep
## the metadata ps1_slot / ps1_edge on the root).
## (BoxMesh lays the texture out as a 3x2 atlas: uv_scale (3, 2) = one repeat per face.)
## Cell = 2 m, layer = 1 m, walls and ceiling at 4 m. Cada peça é uma .tscn comum: dá para abrir e
## editar no Godot ou trocar a malha por um modelo do Blender (mantendo as metas ps1_slot/ps1_edge).
extends SceneTree

const DIR := "res://addons/ps1_godot/starter_pieces"
var _mats := {}

func _init() -> void:
	for d in ["_tex", "1_structure", "2_props", "3_lights"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR.path_join(d)))
	_materiais()
	_salvar("1_structure/floor", _corpo("floor", false, [_caixa(Vector3(2, 1, 2), Vector3(0, -0.5, 0), "piso", Vector3i(3, 0, 3))]))
	_salvar("1_structure/wall", _corpo("wall", true, [_caixa(Vector3(2, 4, 0.5), Vector3(0, 2, -1), "parede", Vector3i(3, 5, 0))]))
	_salvar("1_structure/wall_door", _corpo("wall", true, [
		_caixa(Vector3(0.4, 4, 0.5), Vector3(-0.8, 2, -1), "parede", Vector3i(0, 5, 0)),
		_caixa(Vector3(0.4, 4, 0.5), Vector3(0.8, 2, -1), "parede", Vector3i(0, 5, 0)),
		_caixa(Vector3(1.2, 1.4, 0.5), Vector3(0, 3.3, -1), "parede", Vector3i(2, 1, 0))]))
	_salvar("1_structure/pillar", _corpo("pillar", false, [_caixa(Vector3(0.6, 4, 0.6), Vector3(0, 2, 0), "pilar", Vector3i(0, 5, 0))]))
	_salvar("1_structure/ceiling", _corpo("ceiling", false, [_caixa(Vector3(2, 0.3, 2), Vector3(0, 4.15, 0), "teto", Vector3i(3, 0, 3))]))
	_salvar("1_structure/iron_fence", _corpo("wall", true, [_caixa(Vector3(2, 4, 0.08), Vector3(0, 2, -1), "grade", Vector3i(0, 0, 0))]))
	_salvar("1_structure/stairs", _escada())
	_salvar("2_props/block", _corpo("prop", false, [_caixa(Vector3(2, 1, 2), Vector3(0, 0.5, 0), "parede", Vector3i(3, 1, 3))]))
	_salvar("2_props/coffin", _corpo("prop", false, [
		_caixa(Vector3(1.0, 0.75, 2.0), Vector3(0, 0.375, 0), "pedra_clara", Vector3i(1, 1, 3)),
		_caixa(Vector3(1.15, 0.18, 2.15), Vector3(0, 0.84, 0), "pedra_clara", Vector3i(1, 0, 3))]))
	_salvar("3_lights/wall_torch", _tocha())
	_salvar("3_lights/brazier", _braseiro())
	print("STARTER PIECES OK")
	quit()

func _materiais() -> void:
	var tex := {
		pedra = PS1Textures.stone_bricks(), musgo = PS1Textures.mossy_rock(), metal = PS1Textures.metal(),
		grade = PS1Textures.iron_fence(), chama = PS1Textures.flame_sheet()}
	for k in tex:
		ResourceSaver.save(tex[k], DIR.path_join("_tex/%s.res" % k))
	var t := func(k): return load(DIR.path_join("_tex/%s.res" % k))
	var defs := {
		parede = [t.call("pedra"), {color = Color(0.62, 0.6, 0.58), uv_scale = Vector2(3, 4)}],
		piso = [t.call("musgo"), {color = Color(0.5, 0.5, 0.47), uv_scale = Vector2(3, 2)}],
		teto = [t.call("pedra"), {color = Color(0.4, 0.38, 0.37), uv_scale = Vector2(3, 2)}],
		pilar = [t.call("pedra"), {color = Color(0.62, 0.6, 0.58), uv_scale = Vector2(1, 4)}],
		pedra_clara = [t.call("pedra"), {color = Color(0.85, 0.82, 0.76), uv_scale = Vector2(3, 2)}],
		ferro = [t.call("metal"), {color = Color(0.5, 0.5, 0.5)}],
		grade = [t.call("grade"), {mode = "cutout", uv_scale = Vector2(3, 4)}],
	}
	for k in defs:
		var m: ShaderMaterial = PS1Convert.make(defs[k][0], defs[k][1])
		ResourceSaver.save(m, DIR.path_join("_tex/%s.tres" % k))
		_mats[k] = load(DIR.path_join("_tex/%s.tres" % k))

func _caixa(tam: Vector3, pos: Vector3, mat: String, sub: Vector3i) -> Array:
	return [tam, pos, mat, sub]

## Static body made of boxes (subdivided meshes for vertex lighting + one collider per box).
func _corpo(slot: String, borda: bool, caixas: Array) -> StaticBody3D:
	var c := StaticBody3D.new()
	c.set_meta("ps1_slot", slot)
	if borda:
		c.set_meta("ps1_edge", true)
	for i in caixas.size():
		var cx: Array = caixas[i]
		var mi := MeshInstance3D.new()
		mi.name = "Malha%d" % i
		var bm := BoxMesh.new()
		bm.size = cx[0]
		var sub: Vector3i = cx[3]
		bm.subdivide_width = sub.x; bm.subdivide_height = sub.y; bm.subdivide_depth = sub.z
		mi.mesh = bm
		mi.material_override = _mats[cx[2]]
		mi.position = cx[1]
		c.add_child(mi)
		var col := CollisionShape3D.new()
		col.name = "Colisao%d" % i
		var bs := BoxShape3D.new()
		bs.size = cx[0]
		col.shape = bs
		col.position = cx[1]
		c.add_child(col)
	return c

## Stairs: climbs one layer (1 m) going north (-Z); visual steps + a collision ramp.
func _escada() -> StaticBody3D:
	var caixas := [_caixa(Vector3(2, 1, 2), Vector3(0, -0.5, 0), "piso", Vector3i(3, 0, 3))]
	for i in 4:
		var h := 0.25 * (i + 1)
		caixas.append(_caixa(Vector3(2, h, 0.5), Vector3(0, h / 2.0, 0.75 - 0.5 * i), "parede", Vector3i(2, 0, 0)))
	var c := _corpo("floor", false, [])
	for i in caixas.size():
		var cx: Array = caixas[i]
		var mi := MeshInstance3D.new()
		mi.name = "Malha%d" % i
		var bm := BoxMesh.new(); bm.size = cx[0]
		bm.subdivide_width = cx[3].x; bm.subdivide_depth = cx[3].z
		mi.mesh = bm; mi.material_override = _mats[cx[2]]; mi.position = cx[1]
		c.add_child(mi)
	var col := CollisionShape3D.new(); col.name = "Base"
	var bs := BoxShape3D.new(); bs.size = Vector3(2, 1, 2); col.shape = bs; col.position = Vector3(0, -0.5, 0)
	c.add_child(col)
	var rampa := CollisionShape3D.new(); rampa.name = "Rampa"
	var rs := BoxShape3D.new(); rs.size = Vector3(2, 0.2, sqrt(5.0)); rampa.shape = rs
	rampa.rotation.x = atan2(1.0, 2.0)
	rampa.position = Vector3(0, 0.5 - 0.1 / cos(atan2(1.0, 2.0)), 0)
	c.add_child(rampa)
	return c

func _chama(tam: Vector2, pos: Vector3) -> PS1Sprite:
	var s := PS1Sprite.new()
	s.name = "Chama"
	s.texture = load(DIR.path_join("_tex/chama.res"))
	s.hframes = 4
	s.fps = 10.0
	s.lit = false
	s.size = tam
	s.position = pos
	return s

## Wall torch (edge piece): bracket, sprite flame and a light (baked into the level and still
## lighting characters in real time).
func _tocha() -> Node3D:
	var r := Node3D.new()
	r.set_meta("ps1_slot", "light")
	r.set_meta("ps1_edge", true)
	var sup := MeshInstance3D.new()
	sup.name = "Suporte"
	var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.5, 0.12)
	sup.mesh = bm; sup.material_override = _mats.ferro
	sup.position = Vector3(0, 2.1, -0.68)
	sup.set_meta("ps1_no_cast", true)
	r.add_child(sup)
	r.add_child(_chama(Vector2(0.4, 0.55), Vector3(0, 2.32, -0.66)))
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = Color(1.0, 0.5, 0.2)
	luz.light_energy = 4.0
	luz.omni_range = 9.0
	luz.omni_attenuation = 0.9
	luz.position = Vector3(0, 2.5, -0.2)
	r.add_child(luz)
	return r

func _braseiro() -> Node3D:
	var r := StaticBody3D.new()
	r.set_meta("ps1_slot", "prop")
	var perna := MeshInstance3D.new(); perna.name = "Pe"
	var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.15; cm.height = 0.8; cm.radial_segments = 6
	perna.mesh = cm; perna.material_override = _mats.ferro; perna.position.y = 0.4
	perna.set_meta("ps1_no_cast", true)
	r.add_child(perna)
	var bacia := MeshInstance3D.new(); bacia.name = "Bacia"
	var bc := CylinderMesh.new(); bc.top_radius = 0.45; bc.bottom_radius = 0.22; bc.height = 0.3; bc.radial_segments = 8
	bacia.mesh = bc; bacia.material_override = _mats.ferro; bacia.position.y = 0.92
	bacia.set_meta("ps1_no_cast", true)
	r.add_child(bacia)
	var col := CollisionShape3D.new(); col.name = "Colisao"
	var cs := CylinderShape3D.new(); cs.radius = 0.4; cs.height = 1.1; col.shape = cs; col.position.y = 0.55
	r.add_child(col)
	r.add_child(_chama(Vector2(0.8, 1.0), Vector3(0, 1.0, 0)))
	var luz := OmniLight3D.new(); luz.name = "Luz"
	luz.light_color = Color(1.0, 0.5, 0.2); luz.light_energy = 4.5; luz.omni_range = 10.0; luz.omni_attenuation = 0.9
	luz.position.y = 1.7
	r.add_child(luz)
	return r

func _salvar(nome: String, raiz: Node) -> void:
	raiz.name = nome.get_file().capitalize().replace(" ", "")
	for c in raiz.find_children("*", "", true, false):
		c.owner = raiz
	var ps := PackedScene.new()
	ps.pack(raiz)
	var err := ResourceSaver.save(ps, DIR.path_join(nome + ".tscn"))
	print("  ", nome, " ", "ok" if err == OK else "ERRO %d" % err)
	raiz.free()
