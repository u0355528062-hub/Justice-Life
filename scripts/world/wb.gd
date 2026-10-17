class_name WB
extends RefCounted
## « World Builder » : primitives de construction des décors (pièces, murs, portes,
## mobilier simple, éclairages) avec collisions.

const T := 0.16  # épaisseur des murs


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide: bool = true, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, collide: bool = false, seg: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = max(r_top, r_bot)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func capsule(parent: Node, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = max(h, r * 2.0)
	cm.radial_segments = 24
	cm.rings = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func blocker(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb


static func label(parent: Node, text: String, pos: Vector3, size: float = 0.1, col: Color = Color.WHITE,
		rot_y: float = 0.0, kind: String = "sans", weight: int = 700, emissive: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIKit.font(kind, weight)
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation.y = rot_y
	l.shaded = not emissive
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	parent.add_child(l)
	return l


## Pièce rectangulaire : sol, plafond, 4 murs (intérieurs au rectangle) avec ouvertures.
## openings : [{"side": "x0"|"x1"|"z0"|"z1", "at": coord_centre, "w": largeur, "h": hauteur,
##              "sill": 0.0 (allège), "glass": bool}]
static func room(parent: Node, x0: float, x1: float, z0: float, z1: float, h: float,
		floor_mat: Material, wall_mat: Material, ceil_mat: Material, openings: Array = [],
		skip_sides: Array = []) -> Node3D:
	var r := Node3D.new()
	parent.add_child(r)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var w := x1 - x0
	var d := z1 - z0
	if floor_mat:
		box(r, Vector3(w, 0.2, d), Vector3(cx, -0.1, cz), floor_mat)
	if ceil_mat:
		box(r, Vector3(w, 0.2, d), Vector3(cx, h + 0.1, cz), ceil_mat)
	for side in ["x0", "x1", "z0", "z1"]:
		if side in skip_sides:
			continue
		var ops := []
		for o in openings:
			if o.side == side:
				ops.append(o)
		_wall(r, side, x0, x1, z0, z1, h, wall_mat, ops)
	return r


static func _wall(parent: Node, side: String, x0: float, x1: float, z0: float, z1: float, h: float,
		mat: Material, ops: Array) -> void:
	var along_x := side == "z0" or side == "z1"
	var a0: float
	var a1: float
	var fixed: float
	if along_x:
		a0 = x0 + T
		a1 = x1 - T
		fixed = z0 + T * 0.5 if side == "z0" else z1 - T * 0.5
	else:
		a0 = z0
		a1 = z1
		fixed = x0 + T * 0.5 if side == "x0" else x1 - T * 0.5
	ops.sort_custom(func(a, b): return a.at < b.at)
	var cur := a0
	for o in ops:
		var ow: float = o.get("w", 1.0)
		var oh: float = o.get("h", 2.1)
		var sill: float = o.get("sill", 0.0)
		var s: float = o.at - ow * 0.5
		var e: float = o.at + ow * 0.5
		if s > cur:
			_seg(parent, along_x, cur, s, fixed, 0.0, h, mat)
		if sill > 0.0:
			_seg(parent, along_x, s, e, fixed, 0.0, sill, mat)
		if oh < h:
			_seg(parent, along_x, s, e, fixed, oh, h, mat)
		if o.get("glass", false):
			var gpos := Vector3(o.at, (sill + oh) * 0.5, fixed) if along_x else Vector3(fixed, (sill + oh) * 0.5, o.at)
			var gsize := Vector3(ow, oh - sill, 0.02) if along_x else Vector3(0.02, oh - sill, ow)
			box(parent, gsize, gpos, Mats.glass(), true)
		cur = e
	if cur < a1:
		_seg(parent, along_x, cur, a1, fixed, 0.0, h, mat)


static func _seg(parent: Node, along_x: bool, a: float, b: float, fixed: float, y0: float, y1: float, mat: Material) -> void:
	var len := b - a
	if len <= 0.001 or y1 - y0 <= 0.001:
		return
	var c := (a + b) * 0.5
	var y := (y0 + y1) * 0.5
	if along_x:
		box(parent, Vector3(len, y1 - y0, T), Vector3(c, y, fixed), mat)
	else:
		box(parent, Vector3(T, y1 - y0, len), Vector3(fixed, y, c), mat)


## Plafonnier : dalle émissive + spot vers le bas.
static func ceiling_light(parent: Node, pos: Vector3, size: Vector2 = Vector2(0.6, 0.6),
		col: Color = Color(1.0, 0.97, 0.92), energy: float = 3.0, rng: float = 7.0, shadow: bool = true,
		angle: float = 70.0) -> SpotLight3D:
	var panel := box(parent, Vector3(size.x, 0.03, size.y), pos + Vector3(0, -0.015, 0),
		Mats.emissive("ceil_%s" % col.to_html(), col, 5.0), false)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(parent, Vector3(size.x + 0.06, 0.04, size.y + 0.06), pos + Vector3(0, 0.005, 0),
		Mats.std("lightframe", Color(0.8, 0.8, 0.8), 0.4, 0.5), false)
	var sl := SpotLight3D.new()
	sl.position = pos + Vector3(0, -0.05, 0)
	sl.rotation_degrees = Vector3(-90, 0, 0)
	sl.light_color = col
	sl.light_energy = energy
	sl.spot_range = rng
	sl.spot_angle = angle
	sl.spot_angle_attenuation = 0.6
	sl.spot_attenuation = 0.9
	sl.shadow_enabled = shadow
	sl.shadow_blur = 1.5
	sl.light_volumetric_fog_energy = 0.6
	sl.light_size = 0.4
	parent.add_child(sl)
	return sl


static func omni(parent: Node, pos: Vector3, col: Color, energy: float, rng: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	parent.add_child(l)
	return l


## Porte battante : retourne le pivot (rotation.y pour ouvrir).
static func door(parent: Node, hinge: Vector3, w: float, h: float, mat: Material, along_x: bool = true,
		thickness: float = 0.05, handle: bool = true) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hinge
	parent.add_child(pivot)
	var leaf_pos := Vector3(w * 0.5, h * 0.5, 0) if along_x else Vector3(0, h * 0.5, w * 0.5)
	var leaf_size := Vector3(w, h, thickness) if along_x else Vector3(thickness, h, w)
	box(pivot, leaf_size, leaf_pos, mat, true)
	if handle:
		var hm := Mats.std("handle", Color(0.75, 0.75, 0.72), 0.25, 1.0)
		var hp := Vector3(w - 0.1, 1.0, 0.06) if along_x else Vector3(0.06, 1.0, w - 0.1)
		var hs := Vector3(0.13, 0.025, 0.025) if along_x else Vector3(0.025, 0.025, 0.13)
		box(pivot, hs, hp, hm, false)
		box(pivot, hs, Vector3(hp.x, hp.y, -hp.z) if along_x else Vector3(-hp.x, hp.y, hp.z), hm, false)
	return pivot


static func chair(parent: Node, pos: Vector3, rot_y: float, seat_mat: Material, frame_mat: Material) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = rot_y
	parent.add_child(c)
	box(c, Vector3(0.46, 0.05, 0.44), Vector3(0, 0.46, 0), seat_mat, true)
	box(c, Vector3(0.46, 0.45, 0.04), Vector3(0, 0.72, 0.21), seat_mat, false)
	for x in [-0.2, 0.2]:
		for z in [-0.18, 0.18]:
			box(c, Vector3(0.025, 0.46, 0.025), Vector3(x, 0.23, z), frame_mat, false)
	return c


static func table(parent: Node, pos: Vector3, size: Vector3, top_mat: Material, leg_mat: Material) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	parent.add_child(t)
	box(t, Vector3(size.x, 0.04, size.z), Vector3(0, size.y - 0.02, 0), top_mat, true)
	for x in [-1, 1]:
		for z in [-1, 1]:
			box(t, Vector3(0.04, size.y - 0.04, 0.04),
				Vector3(x * (size.x * 0.5 - 0.05), (size.y - 0.04) * 0.5, z * (size.z * 0.5 - 0.05)), leg_mat, false)
	return t


## Affiche murale (cadre + texte)
static func poster(parent: Node, pos: Vector3, rot_y: float, size: Vector2, bg: Color, title: String,
		body: String = "", title_col: Color = Color.WHITE) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = rot_y
	parent.add_child(p)
	box(p, Vector3(size.x, size.y, 0.01), Vector3.ZERO, Mats.std("poster_%s" % bg.to_html(), bg, 0.7), false)
	label(p, title, Vector3(0, size.y * 0.32, 0.007), size.x * 0.11, title_col, 0.0, "sans", 800)
	if body != "":
		var l := label(p, body, Vector3(0, -size.y * 0.05, 0.007), size.x * 0.05, Color(title_col, 0.85), 0.0, "sans", 500)
		l.width = size.x * 0.85 / l.pixel_size
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return p
