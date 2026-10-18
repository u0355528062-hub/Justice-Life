class_name RealBody
extends Node3D
## Humain réaliste (maillages MakeHuman CC0 générés par tools/humans/build_humans.py) :
## sélection de morphologie, peau, yeux, cheveux et barbe en couches, vêtements par
## tenue, accessoires attachés aux os, animation procédurale du squelette
## (marche, assis, bureau, regard, respiration, clignements, parole).

const DIR := "res://assets/humans/"
# nom, femme, origine, âge (0 jeune → 1 senior), corpulence
const VARIANTS := [
	["m_young", false, "caucasian", 0.0, "normal"],
	["m_athletic", false, "mixed", 0.2, "athletic"],
	["m_african", false, "african", 0.3, "normal"],
	["m_mediter", false, "mediter", 0.4, "thin"],
	["m_heavy", false, "caucasian", 0.6, "heavy"],
	["m_senior", false, "caucasian", 1.0, "normal"],
	["m_asian", false, "asian", 0.1, "thin"],
	["f_young", true, "caucasian", 0.0, "normal"],
	["f_african", true, "african", 0.3, "normal"],
	["f_mid", true, "caucasian", 0.6, "normal"],
	["f_senior", true, "caucasian", 1.0, "normal"],
	["f_asian", true, "asian", 0.1, "thin"],
]
const TONES := {
	"caucasian": [Color("e9c2a6"), Color("dfb092"), Color("f0cdb6"), Color("d8a583")],
	"mediter": [Color("c99470"), Color("bd8661"), Color("d09d78")],
	"african": [Color("6e432b"), Color("5a3523"), Color("80513a"), Color("4a2b1c")],
	"asian": [Color("e8c4a0"), Color("dcb58e"), Color("efd0b0")],
	"mixed": [Color("b07a55"), Color("c18c66"), Color("a06c4a")],
}
const SURF_BODY := 0
const SURF_TIGHTS := 1
const SURF_EYES := 2
const SURF_LASHES := 3
const SURF_TEETH := 4
const SURF_TONGUE := 5
const SURF_SKIRT := 6

static var _skin_shader: Shader
static var _cloth_shader: Shader
static var _eye_shader: Shader
static var _hair_shader: Shader
static var _tex := {}
static var _hide_mat: ShaderMaterial
static var _hair_mat: ShaderMaterial
static var _scenes := {}

var skel: Skeleton3D
var body: MeshInstance3D
var head_att: BoneAttachment3D
var b := {}
var rest := {}
var bs_mouth := -1
var bs_blink_l := -1
var bs_blink_r := -1
var bs_smile := -1
var bs_brows := -1
var pelvis_rest := Vector3.ZERO
var robe_stand: Node3D
var robe_sit: Node3D
var _skin_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


static func available() -> bool:
	return ResourceLoader.exists(DIR + "m_young.glb")


static func _load_tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name) if ResourceLoader.exists(DIR + name) else null
	return _tex[name]


static func _scene(v: String) -> PackedScene:
	if not _scenes.has(v):
		_scenes[v] = load(DIR + v + ".glb")
	return _scenes[v]


func setup(h: Human) -> void:
	var cfg := h.cfg
	_rng.seed = hash(str(cfg.get("seed", 0)) + h.role + h.name)
	var fem: bool = cfg.get("female", _rng.randf() < 0.42)
	var variant := _pick_variant(fem, cfg)
	var ps := _scene(variant[0])
	var inst := ps.instantiate()
	add_child(inst)
	for n in inst.find_children("*", "Skeleton3D", true, false):
		skel = n
	if skel == null:
		return
	var meshes := {}
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		meshes[n.name] = n
	body = meshes.get("Corps")
	var scalp: MeshInstance3D = meshes.get("Cheveux")
	var beard_mi: MeshInstance3D = meshes.get("Barbe")
	for bn in ["Root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r",
			"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r", "thigh_l", "thigh_r",
			"calf_l", "calf_r", "foot_l", "foot_r"]:
		b[bn] = skel.find_bone(bn)
		if b[bn] >= 0:
			rest[bn] = skel.get_bone_global_rest(b[bn]).origin
	pelvis_rest = skel.get_bone_rest(b["pelvis"]).origin
	if body:
		bs_mouth = body.find_blend_shape_by_name("mouth_open")
		bs_blink_l = body.find_blend_shape_by_name("blink_l")
		bs_blink_r = body.find_blend_shape_by_name("blink_r")
		bs_smile = body.find_blend_shape_by_name("smile")
		bs_brows = body.find_blend_shape_by_name("brows_up")
	head_att = BoneAttachment3D.new()
	head_att.bone_name = "head"
	skel.add_child(head_att)
	var anchor := Node3D.new()
	anchor.position = Vector3(0, 0.1, -0.06)
	anchor.name = "Visage"
	head_att.add_child(anchor)

	# ── Apparence ───────────────────────────────────────────────────────────
	var origin: String = variant[2]
	var tones: Array = TONES.get(origin, TONES["caucasian"])
	var skin: Color = cfg.get("skin", tones[_rng.randi() % tones.size()])
	var age: float = variant[3]
	var hair_col: Color = cfg.get("hair", _hair_color(origin, age))
	var style: String = cfg.get("hair_style", _hair_style(fem, age))
	var beard: float = cfg.get("beard_amount", 0.0 if fem else (_rng.randf() * 0.9 if _rng.randf() < 0.55 else 0.15))
	if cfg.get("beard", false):
		beard = 1.0
	_apply_skin(skin, hair_col, beard if not fem else 0.0, fem, age)
	_apply_eyes(origin)
	_apply_hair(scalp, hair_col, style, fem)
	_apply_beard(beard_mi, hair_col, beard if not fem else 0.0)
	_apply_outfit(cfg.get("outfit", "civil"), cfg, fem)
	if cfg.get("glasses", _rng.randf() < 0.18):
		_add_glasses(anchor)
	var hs: float = cfg.get("height_scale", _rng.randf_range(0.97, 1.03))
	scale = Vector3.ONE * hs


func _pick_variant(fem: bool, cfg: Dictionary) -> Array:
	var want_age: float = cfg.get("age", -1.0)
	var want_origin: String = cfg.get("origin", "")
	var cands := []
	for v in VARIANTS:
		if v[1] != fem:
			continue
		var score := _rng.randf()
		if want_age >= 0.0:
			score += 2.0 - absf(v[3] - want_age) * 3.0
		if want_origin != "" and v[2] == want_origin:
			score += 3.0
		if cfg.has("body") and v[0] == cfg.body:
			score += 100.0
		cands.append([score, v])
	cands.sort_custom(func(a, c): return a[0] > c[0])
	return cands[0][1]


func _hair_color(origin: String, age: float) -> Color:
	if age > 0.85 and _rng.randf() < 0.8:
		return [Color("9a9a98"), Color("c9c7c2"), Color("7d7a76")][_rng.randi() % 3]
	if origin in ["african", "asian", "mediter"]:
		return [Color("0e0a08"), Color("17110d"), Color("1f1611")][_rng.randi() % 3]
	return [Color("2b1d14"), Color("4a3020"), Color("6e4a2c"), Color("a27b4f"), Color("1b1310"), Color("c9a46b")][_rng.randi() % 6]


func _hair_style(fem: bool, age: float) -> String:
	if fem:
		return ["long", "bun", "bob", "long", "ponytail"][_rng.randi() % 5]
	if age > 0.85 and _rng.randf() < 0.4:
		return "bald"
	return ["short", "short", "buzz", "short", "medium"][_rng.randi() % 5]


func _apply_skin(skin: Color, hair_col: Color, beard: float, fem: bool, age: float) -> void:
	if _skin_shader == null:
		_skin_shader = load("res://shaders/human_skin.gdshader")
		_cloth_shader = load("res://shaders/human_cloth.gdshader")
		_eye_shader = load("res://shaders/human_eye.gdshader")
		_hair_shader = load("res://shaders/human_hair.gdshader")
		_hide_mat = ShaderMaterial.new()
		var hs := Shader.new()
		hs.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() { discard; }\n"
		_hide_mat.shader = hs
	_skin_mat = ShaderMaterial.new()
	_skin_mat.shader = _skin_shader
	_skin_mat.set_shader_parameter("skin_tone", skin)
	_skin_mat.set_shader_parameter("hair_color", hair_col)
	_skin_mat.set_shader_parameter("beard", beard)
	_skin_mat.set_shader_parameter("brow", 0.85 if fem else 1.1)
	_skin_mat.set_shader_parameter("makeup", _rng.randf_range(0.2, 0.6) if fem else 0.0)
	_skin_mat.set_shader_parameter("aging", age)
	_skin_mat.set_shader_parameter("flush", _rng.randf() * 0.6)
	_skin_mat.set_shader_parameter("masks", _load_tex("skin_masks.png"))
	_skin_mat.set_shader_parameter("beard_mask", _load_tex("skin_beard.png"))
	_skin_mat.set_shader_parameter("pores", _load_tex("skin_pores_n.png"))
	_skin_mat.set_shader_parameter("variation", _load_tex("skin_variation.png"))
	if body:
		body.set_surface_override_material(SURF_BODY, _skin_mat)
		var lashes := StandardMaterial3D.new()
		lashes.albedo_color = hair_col.darkened(0.5)
		lashes.roughness = 0.8
		lashes.cull_mode = BaseMaterial3D.CULL_DISABLED
		body.set_surface_override_material(SURF_LASHES, lashes)
		var teeth := StandardMaterial3D.new()
		teeth.albedo_color = Color(0.88, 0.85, 0.78)
		teeth.roughness = 0.25
		body.set_surface_override_material(SURF_TEETH, teeth)
		var tongue := StandardMaterial3D.new()
		tongue.albedo_color = Color(0.6, 0.25, 0.27)
		tongue.roughness = 0.35
		body.set_surface_override_material(SURF_TONGUE, tongue)
		body.set_surface_override_material(SURF_SKIRT, _hide_mat)


func _apply_eyes(origin: String) -> void:
	if body == null:
		return
	var m := ShaderMaterial.new()
	m.shader = _eye_shader
	var irises := [Color("3b2618"), Color("5a3a22"), Color("2e1d12")]
	if origin == "caucasian":
		irises += [Color("3d5a6e"), Color("4d5b3a"), Color("6a8aa0")]
	m.set_shader_parameter("iris_color", irises[_rng.randi() % irises.size()])
	body.set_surface_override_material(SURF_EYES, m)


func _apply_hair(scalp: MeshInstance3D, col: Color, style: String, fem: bool) -> void:
	if scalp == null:
		return
	if style == "bald":
		scalp.visible = false
		return
	if _hair_mat == null:
		_hair_mat = ShaderMaterial.new()
		_hair_mat.shader = _hair_shader
	var layers := 4 if style == "buzz" else 9
	var length := 0.003 if style == "buzz" else (0.014 if style in ["short", "medium"] else 0.012)
	if style == "medium":
		length = 0.02
	var parent := scalp.get_parent()
	for i in layers:
		var mi: MeshInstance3D = scalp if i == 0 else scalp.duplicate()
		if i > 0:
			parent.add_child(mi)
		mi.material_override = _hair_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i == layers - 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("layer", float(i) / max(layers - 1, 1))
		mi.set_instance_shader_parameter("hair_color", col)
		mi.set_instance_shader_parameter("hair_len", length)
		mi.set_instance_shader_parameter("density", 0.95 if style != "buzz" else 0.7)
		mi.set_instance_shader_parameter("coarse", 0.35 if style != "buzz" else 1.0)
	# Volumes de cheveux longs (attachés à la tête)
	if style in ["long", "bob", "bun", "ponytail"]:
		var card := StandardMaterial3D.new()
		card.albedo_color = col
		card.roughness = 0.55
		card.anisotropy_enabled = true
		card.anisotropy = 0.6
		card.cull_mode = BaseMaterial3D.CULL_DISABLED
		card.normal_enabled = true
		card.normal_texture = _strand_normal()
		card.uv1_scale = Vector3(14, 1, 1)
		var root := Node3D.new()
		root.position = Vector3(0, 0.1, 0.0)
		head_att.add_child(root)
		if style in ["long", "bob"]:
			var len_y := 0.3 if style == "long" else 0.13
			var mi2 := MeshInstance3D.new()
			mi2.mesh = BodyMesh.open_tube("hairback_%s" % style, [[0.03, 0.098, 0.1], [0.0, 0.1, 0.105], [-0.06, 0.098, 0.1],
				[-len_y * 0.6, 0.094, 0.085], [-len_y, 0.088 if style == "long" else 0.096, 0.07]], -0.35, PI + 0.35, 18)
			mi2.material_override = card
			mi2.position = Vector3(0, -0.02, 0.012)
			root.add_child(mi2)
		elif style == "bun":
			WB.sphere(root, 0.048, Vector3(0, 0.03, 0.1), card)
		elif style == "ponytail":
			WB.sphere(root, 0.03, Vector3(0, -0.01, 0.105), card)
			var tail := WB.capsule(root, 0.028, 0.24, Vector3(0, -0.13, 0.12), card)
			tail.rotation.x = 0.15


func _strand_normal() -> Texture2D:
	if not _tex.has("_strands"):
		var n := FastNoiseLite.new()
		n.frequency = 0.08
		n.fractal_octaves = 2
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 64
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 6.0
		t.noise = n
		_tex["_strands"] = t
	return _tex["_strands"]


func _apply_beard(mi: MeshInstance3D, col: Color, amount: float) -> void:
	if mi == null:
		return
	if amount < 0.6:
		mi.visible = false
		return
	if _hair_mat == null:
		_hair_mat = ShaderMaterial.new()
		_hair_mat.shader = _hair_shader
	var layers := 5
	var parent := mi.get_parent()
	for i in layers:
		var m2: MeshInstance3D = mi if i == 0 else mi.duplicate()
		if i > 0:
			parent.add_child(m2)
		m2.material_override = _hair_mat
		m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m2.set_instance_shader_parameter("layer", float(i) / (layers - 1))
		m2.set_instance_shader_parameter("hair_color", col)
		m2.set_instance_shader_parameter("hair_len", 0.006 * amount)
		m2.set_instance_shader_parameter("density", 0.5)
		m2.set_instance_shader_parameter("coarse", 1.0)


# ── Tenues ───────────────────────────────────────────────────────────────────
func _cloth(top: Color, bottom: Color, top_style: int, bottom_style: int, sleeves: bool = true, long_pants: bool = true) -> void:
	if body == null:
		return
	var m := ShaderMaterial.new()
	m.shader = _cloth_shader
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("bottom_color", bottom)
	m.set_shader_parameter("top_style", top_style)
	m.set_shader_parameter("bottom_style", bottom_style)
	m.set_shader_parameter("sleeves", 1.0 if sleeves else 0.0)
	m.set_shader_parameter("long_pants", 1.0 if long_pants else 0.0)
	m.set_shader_parameter("wear", _rng.randf_range(0.1, 0.8))
	body.set_surface_override_material(SURF_TIGHTS, m)
	_skin_mat.set_shader_parameter("cover", Vector4(1.0, 1.0 if sleeves else 0.0, 1.0, 1.0 if long_pants else 0.0))


func _att(bone: String, offset: Vector3 = Vector3.ZERO) -> Node3D:
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	skel.add_child(a)
	var n := Node3D.new()
	n.position = offset
	a.add_child(n)
	return n


func _apply_outfit(outfit: String, cfg: Dictionary, fem: bool) -> void:
	var top: Color = cfg.get("top", Color.from_hsv(_rng.randf(), _rng.randf_range(0.1, 0.5), _rng.randf_range(0.15, 0.6)))
	var pants: Color = cfg.get("pants", Color.from_hsv(_rng.randf_range(0.55, 0.65), _rng.randf_range(0.15, 0.45), _rng.randf_range(0.12, 0.35)))
	var shoe_kind := "sneaker"
	var shoe_col := Color(0.06, 0.055, 0.05)
	var sw: float = absf(rest["upperarm_l"].x - rest["upperarm_r"].x) / 0.41
	var neck_y: float = rest["neck_01"].y
	var sp_y: float = rest["spine_01"].y
	match outfit:
		"police":
			_cloth(Color(0.07, 0.1, 0.19), Color(0.06, 0.08, 0.15), 3, 0)
			shoe_kind = "boot"
			_police_gear(sw, neck_y, sp_y, "POLICE")
		"surveillant":
			_cloth(Color(0.55, 0.68, 0.85), Color(0.08, 0.1, 0.18), 2, 0)
			shoe_kind = "boot"
			_police_gear(sw, neck_y, sp_y, "")
			var keys := _att("pelvis", Vector3(0.17 * sw, 0.0, -0.02))
			var ring := WB.cyl(keys, 0.02, 0.02, 0.004, Vector3.ZERO, Mats.std("keyring", Color(0.7, 0.7, 0.68), 0.3, 1.0))
			ring.rotation.z = PI / 2
			for k in 4:
				WB.box(keys, Vector3(0.004, 0.06, 0.012), Vector3(0.0, -0.035, -0.01 + k * 0.007), Mats.std("key", Color(0.75, 0.68, 0.4), 0.3, 1.0), false)
		"opj":
			_cloth(cfg.get("top", Color(0.3, 0.31, 0.33)), cfg.get("pants", Color(0.14, 0.18, 0.28)), 1, 1)
			var arm := _att("upperarm_l", Vector3(0, -0.11, 0))
			var band := WB.cyl(arm, 0.062, 0.062, 0.075, Vector3.ZERO, Mats.cloth("brassard", Color(1.0, 0.42, 0.05), 0.6))
			WB.label(band, "POLICE", Vector3(0, 0, -0.064), 0.017, Color.WHITE, PI, "sans", 900)
		"magistrat", "procureur", "avocat":
			_cloth(Color(0.03, 0.03, 0.035), Color(0.05, 0.05, 0.06), 3, 0)
			shoe_kind = "dress"
			_robe(outfit, sw, neck_y, sp_y)
		"medecin":
			_cloth(Color(0.55, 0.68, 0.75), pants, 0, 0)
			var coat_root := _att("spine_01", Vector3(0, 0, 0))
			var coat := MeshInstance3D.new()
			coat.mesh = BodyMesh.coat(sw)
			coat.material_override = Mats.cloth("whitecoat", Color(0.93, 0.93, 0.92), 0.85)
			coat.position = Vector3(0, neck_y - sp_y - 0.5, 0.0)
			coat_root.add_child(coat)
		"detenu":
			_cloth(Color(0.42, 0.43, 0.45), Color(0.3, 0.31, 0.33), 4, 2)
		_:
			var styles := [0, 1, 2, 4]
			var ts: int = cfg.get("top_style", styles[_rng.randi() % styles.size()])
			_cloth(top, pants, ts, 1 if _rng.randf() < 0.6 else 0, _rng.randf() < 0.75 or ts == 2)
			if cfg.get("jacket", _rng.randf() < 0.35):
				_jacket(sw, neck_y, sp_y, Color.from_hsv(_rng.randf(), 0.2, _rng.randf_range(0.08, 0.3)))
			shoe_kind = "sneaker" if _rng.randf() < 0.6 else "dress"
			shoe_col = [Color(0.06, 0.055, 0.05), Color(0.85, 0.85, 0.83), Color(0.25, 0.15, 0.08)][_rng.randi() % 3]
	_shoes(shoe_kind, shoe_col)


func _shoes(kind: String, col: Color) -> void:
	var m := Mats.std("shoe_%s_%s" % [kind, col.to_html()], col, 0.3 if kind == "dress" else 0.6, 0.0)
	var sole := Mats.std("sole", Color(0.04, 0.04, 0.04), 0.8)
	for side in ["l", "r"]:
		var foot: Vector3 = rest["foot_" + side]
		var root := _att("foot_" + side, Vector3(0, -foot.y + 0.048, -0.035))
		var s := MeshInstance3D.new()
		s.mesh = BodyMesh.shoe("sneaker" if kind == "sneaker" else "dress")
		s.material_override = m
		s.rotation.x = PI / 2
		s.scale = Vector3(1.05, 1.0, 1.05) if kind != "boot" else Vector3(1.08, 1.0, 1.15)
		root.add_child(s)
		WB.box(root, Vector3(0.1, 0.018, 0.29), Vector3(0, -0.043, -0.06), sole, false)
		if kind == "boot":
			WB.cyl(root, 0.052, 0.056, 0.12, Vector3(0, 0.05, 0.02), m)


func _jacket(sw: float, neck_y: float, sp_y: float, col: Color) -> void:
	var root := _att("spine_01", Vector3.ZERO)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BodyMesh.tube("jacket_%.2f" % sw, [[0.5, 0.11, 0.08], [0.45, 0.2 * sw, 0.125], [0.3, 0.19 * sw, 0.13, 0.05],
		[0.05, 0.175 * sw, 0.125], [-0.12, 0.18 * sw, 0.13]], 28, 0.01, 0.0, 6)
	mesh.material_override = Mats.cloth("jacket_" + col.to_html(), col, 0.8)
	mesh.position = Vector3(0, neck_y - sp_y - 0.5, 0.0)
	root.add_child(mesh)
	for side in ["l", "r"]:
		var arm := _att("upperarm_" + side)
		var sl := MeshInstance3D.new()
		sl.mesh = BodyMesh.tube("jsleeve", [[0.03, 0.062, 0.064], [-0.29, 0.05, 0.052]], 16, 0.02, 0.0)
		sl.material_override = mesh.material_override
		arm.add_child(sl)
		var fa := _att("lowerarm_" + side)
		var sl2 := MeshInstance3D.new()
		sl2.mesh = BodyMesh.tube("jsleeve2", [[0.03, 0.05, 0.052], [-0.24, 0.042, 0.044]], 16, 0.0, 0.0)
		sl2.material_override = mesh.material_override
		fa.add_child(sl2)


func _police_gear(sw: float, neck_y: float, sp_y: float, text: String) -> void:
	var dark := Mats.std("gear", Color(0.025, 0.025, 0.03), 0.45)
	# Gilet tactique
	if text != "":
		var root := _att("spine_02", Vector3.ZERO)
		var off_y: float = neck_y - rest["spine_02"].y
		var vest := MeshInstance3D.new()
		vest.mesh = BodyMesh.tube("vest_%.2f" % sw, [[off_y - 0.04, 0.16 * sw, 0.13], [off_y - 0.12, 0.185 * sw, 0.15, 0.12],
			[off_y - 0.3, 0.175 * sw, 0.14, 0.08], [off_y - 0.45, 0.17 * sw, 0.13]], 28, 0.0, 0.0)
		vest.material_override = Mats.cloth("vest", Color(0.05, 0.06, 0.1), 0.75)
		root.add_child(vest)
		WB.label(root, text, Vector3(0, off_y - 0.2, 0.152), 0.075, Color(0.95, 0.95, 0.95), 0.0, "sans", 900)
		WB.label(root, text, Vector3(0.06, off_y - 0.14, -0.168), 0.03, Color(0.95, 0.95, 0.95), PI, "sans", 900)
		# radio, caméra-piéton
		WB.box(root, Vector3(0.05, 0.08, 0.03), Vector3(-0.08, off_y - 0.13, -0.165), dark, false)
		WB.cyl(root, 0.004, 0.004, 0.07, Vector3(-0.07, off_y - 0.06, -0.165), dark)
		var cam := WB.box(root, Vector3(0.05, 0.07, 0.03), Vector3(0.06, off_y - 0.24, -0.16), dark, false)
		WB.sphere(cam, 0.004, Vector3(0.015, 0.02, -0.016), Mats.emissive("bodycam", Color(1, 0.1, 0.1), 3.0))
	# Ceinturon + équipements
	var hip := _att("pelvis", Vector3.ZERO)
	var belt := MeshInstance3D.new()
	belt.mesh = BodyMesh.tube("dutybelt_%.2f" % sw, [[0.045, 0.165 * sw, 0.115], [0.0, 0.165 * sw, 0.115]], 28, 0.0, 0.0)
	belt.material_override = dark
	hip.add_child(belt)
	WB.box(hip, Vector3(0.06, 0.15, 0.09), Vector3(0.17 * sw, -0.04, 0.0), dark, false)
	WB.box(hip, Vector3(0.05, 0.06, 0.04), Vector3(-0.15 * sw, 0.02, -0.08), dark, false)
	WB.box(hip, Vector3(0.05, 0.07, 0.04), Vector3(-0.17 * sw, 0.02, 0.04), dark, false)
	# Épaulettes + écusson
	for side in ["l", "r"]:
		var c := _att("clavicle_" + side, Vector3.ZERO)
		var s := -1.0 if side == "l" else 1.0
		WB.box(c, Vector3(0.09, 0.012, 0.05), Vector3(s * 0.08, 0.035, 0.0), Mats.std("epaul", Color(0.04, 0.05, 0.1), 0.7), false)
	var arm := _att("upperarm_l", Vector3(-0.055, -0.08, 0.0))
	for i in 3:
		var col: Color = [Color(0.1, 0.2, 0.6), Color.WHITE, Color(0.8, 0.1, 0.12)][i]
		WB.box(arm, Vector3(0.004, 0.035, 0.012), Vector3(0, 0, -0.012 + i * 0.012), Mats.std("flag%d" % i, col, 0.6), false)


func _robe(outfit: String, sw: float, neck_y: float, sp_y: float) -> void:
	var robe_mat := Mats.cloth("robe", Color(0.025, 0.025, 0.03), 0.62)
	var white := Mats.cloth("whitecloth", Color(0.93, 0.93, 0.92), 0.85)
	var root := _att("spine_01", Vector3.ZERO)
	var y0: float = neck_y - sp_y - 0.5
	var len_scale: float = clamp((neck_y - 0.13) / 1.37, 0.8, 1.15)
	robe_stand = MeshInstance3D.new()
	(robe_stand as MeshInstance3D).mesh = BodyMesh.robe(false, sw)
	(robe_stand as MeshInstance3D).material_override = robe_mat
	robe_stand.position = Vector3(0, y0 + 0.5 - 0.5 * len_scale, 0.0)
	robe_stand.scale = Vector3(1.0, len_scale, 1.0)
	root.add_child(robe_stand)
	robe_sit = MeshInstance3D.new()
	(robe_sit as MeshInstance3D).mesh = BodyMesh.robe(true, sw)
	(robe_sit as MeshInstance3D).material_override = robe_mat
	robe_sit.position = Vector3(0, y0, 0.0)
	robe_sit.visible = false
	root.add_child(robe_sit)
	# manches larges
	for side in ["l", "r"]:
		var ua := _att("upperarm_" + side)
		var m1 := MeshInstance3D.new()
		m1.mesh = BodyMesh.tube("robesleeve_u", [[0.0, 0.052, 0.056], [-0.1, 0.058, 0.062], [-0.29, 0.068, 0.07]], 18, 0.025, 0.0)
		m1.material_override = robe_mat
		ua.add_child(m1)
		var la := _att("lowerarm_" + side)
		var m2 := MeshInstance3D.new()
		m2.mesh = BodyMesh.tube("robesleeve_l", [[0.03, 0.07, 0.072], [-0.12, 0.085, 0.09], [-0.22, 0.1, 0.105]], 18, 0.0, 0.0)
		m2.material_override = robe_mat
		la.add_child(m2)
	# rabat blanc
	var neck := _att("spine_03", Vector3.ZERO)
	var ny: float = neck_y - rest["spine_03"].y
	var rabat := Node3D.new()
	rabat.position = Vector3(0, ny - 0.035, -0.112)
	neck.add_child(rabat)
	for s in [-1, 1]:
		var r := WB.box(rabat, Vector3(0.034, 0.12, 0.005), Vector3(s * 0.019, -0.055, 0), white, false)
		r.rotation.x = 0.1
	WB.box(neck, Vector3(0.12, 0.03, 0.13), Vector3(0, ny - 0.015, -0.035), white, false)
	if outfit == "avocat":
		var ep := WB.box(neck, Vector3(0.07, 0.42, 0.012), Vector3(-0.11, ny - 0.24, -0.125), robe_mat, false)
		ep.rotation.x = 0.06
		WB.box(neck, Vector3(0.072, 0.07, 0.014), Vector3(-0.11, ny - 0.46, -0.138), white, false)
	else:
		var sash := MeshInstance3D.new()
		sash.mesh = BodyMesh.tube("sash_%.2f" % sw, [[0.06, 0.2 * sw, 0.14], [0.0, 0.2 * sw, 0.14]], 28, 0.0, 0.0)
		sash.material_override = Mats.cloth("sash", Color(0.04, 0.04, 0.045), 0.35)
		sash.position = Vector3(0, 0.0, 0.0)
		root.add_child(sash)


func _add_glasses(anchor: Node3D) -> void:
	var gm := Mats.std("glassesframe", Color(0.05, 0.05, 0.05), 0.3, 0.4)
	var lens := Mats.glass("lens", Color(0.9, 0.95, 1.0, 0.08), 0.02)
	for s in [-1, 1]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.02
		tm.outer_radius = 0.0235
		ring.mesh = tm
		ring.material_override = gm
		ring.position = Vector3(s * 0.033, -0.035, -0.045)
		ring.rotation.x = PI / 2
		anchor.add_child(ring)
		var glass := WB.cyl(anchor, 0.02, 0.02, 0.002, ring.position, lens)
		glass.rotation.x = PI / 2
		var arm := WB.box(anchor, Vector3(0.003, 0.003, 0.1), Vector3(s * 0.066, -0.032, 0.005), gm, false)
		arm.rotation.y = s * 0.08
	WB.box(anchor, Vector3(0.022, 0.003, 0.003), Vector3(0, -0.03, -0.046), gm, false)


# ── Animation ────────────────────────────────────────────────────────────────
func _rot(bone: String, e: Vector3) -> void:
	var i: int = b.get(bone, -1)
	if i >= 0:
		skel.set_bone_pose_rotation(i, Quaternion.from_euler(e))


func animate(h: Human, delta: float, t: float, phase: float, head_yaw: float, head_pitch: float, blink: float) -> void:
	if skel == null:
		return
	var sit := h.sit_amount
	var breath := sin(t * 1.7)
	var swing := sin(phase) if h.walking else 0.0
	var bob := absf(cos(phase)) * 0.02 if h.walking else 0.0
	# Bassin
	var p := pelvis_rest
	var seat_y := 0.5
	p.y = lerpf(pelvis_rest.y + bob - 0.01, seat_y, sit)
	p.z = lerpf(pelvis_rest.z, pelvis_rest.z + 0.06, sit)
	skel.set_bone_pose_position(b["pelvis"], p)
	_rot("pelvis", Vector3(0, 0, 0.015 * sin(t * 0.45) * (1.0 - sit)))
	_rot("spine_01", Vector3(0.01 * breath * (1.0 - sit) - h.desk_pose * 0.06 + sit * 0.05, 0, 0))
	_rot("spine_02", Vector3(0.008 * breath - h.desk_pose * 0.06, 0, 0))
	_rot("spine_03", Vector3(0.012 * breath, 0, 0))
	for i in 2:
		var side := "l" if i == 0 else "r"
		var s := -1.0 if i == 0 else 1.0
		var leg := swing * 0.42 * s
		var kb: float = maxf(0.0, -sin(phase + (0.0 if s > 0 else PI))) * 0.7 if h.walking else 0.0
		_rot("thigh_" + side, Vector3(lerpf(leg, PI / 2.0 - 0.06, sit), 0, s * 0.03 * sit))
		_rot("calf_" + side, Vector3(lerpf(-kb, -PI / 2.0 + 0.08, sit), 0, 0))
		_rot("foot_" + side, Vector3(lerpf(kb * 0.3, 0.05, sit), 0, 0))
		var arm := -swing * 0.3 * s
		var ax := lerpf(arm * (1.0 - sit) + 0.25 * sit, 0.8, h.desk_pose)
		ax = lerpf(ax, -0.3, h.hands_back)
		var az := lerpf(s * 0.04 * (1.0 - sit) + s * 0.1 * sit, s * 0.18, h.hands_back)
		_rot("upperarm_" + side, Vector3(ax, 0, az))
		var ex := lerpf(0.15 + 0.75 * sit, 0.95, h.desk_pose)
		ex = lerpf(ex, 0.25, h.hands_back)
		if h.desk_pose > 0.5 and not h.talking:
			ex += sin(t * (9.0 + i * 3.0)) * 0.03
		_rot("lowerarm_" + side, Vector3(ex, 0, 0))
		_rot("hand_" + side, Vector3(0.1 * sit, 0, 0))
	# Tête et cou
	_rot("neck_01", Vector3(head_pitch * 0.35, head_yaw * 0.35, 0))
	_rot("head", Vector3(head_pitch * 0.65, head_yaw * 0.65, sin(t * 0.23) * 0.025))
	# Robe debout / assis
	if robe_stand:
		robe_stand.visible = sit < 0.5
		robe_sit.visible = sit >= 0.5
	# Visage
	if body:
		if bs_blink_l >= 0:
			var bl := sin(blink * PI) if blink > 0.0 else 0.0
			body.set_blend_shape_value(bs_blink_l, bl)
			body.set_blend_shape_value(bs_blink_r, bl)
		if bs_mouth >= 0:
			var o := 0.0
			if h.talking:
				o = absf(sin(t * 12.0)) * (0.35 + 0.45 * absf(sin(t * 3.3)))
			body.set_blend_shape_value(bs_mouth, lerpf(body.get_blend_shape_value(bs_mouth), o, clampf(delta * 18.0, 0.0, 1.0)))
		if bs_brows >= 0:
			body.set_blend_shape_value(bs_brows, 0.25 * absf(sin(t * 1.1)) if h.talking else 0.0)
