class_name Human
extends Node3D
## Personnage non-joueur.
## Par défaut : humanoïde procédural animé (respiration, clignements, regard,
## parole, marche, position assise). Si un modèle « res://assets/characters/<role>.glb »
## existe, il est utilisé à la place (animations « idle », « walk », « sit », « talk »
## jouées si présentes dans son AnimationPlayer).

signal arrived

const SKIN_TONES := [Color("f1c7a5"), Color("e7b48f"), Color("d29b74"), Color("b97c55"),
	Color("8d5a3b"), Color("6b4129"), Color("f6d3bb"), Color("c48a65")]
const HAIR_COLORS := [Color("1b1310"), Color("2b1d14"), Color("4a3020"), Color("6e4a2c"),
	Color("a77d4f"), Color("d0b080"), Color("8a8a8a"), Color("cfcfcf"), Color("0e0b0a")]

var role := "civil"
var cfg := {}
var look_target: Node3D
var talking := false
var walking := false
var sit_amount := 0.0
var desk_pose := 0.0
var hands_back := 0.0
var walk_speed := 1.25

var _glb: Node3D
var _anim: AnimationPlayer
var _t := 0.0
var _phase := 0.0
var _blink_t := 2.0
var _blink := 0.0
var _rng := RandomNumberGenerator.new()

# articulations
var hips: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var chest_mesh: MeshInstance3D
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []
var hip_j: Array[Node3D] = []
var knees: Array[Node3D] = []
var lids: Array[MeshInstance3D] = []
var mouth: MeshInstance3D
var robe: MeshInstance3D
var _robe_full_h := 1.38
var _robe_last := -1.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _hip_h := 0.98


static func create(p_role: String, p_cfg: Dictionary = {}) -> Human:
	var h := Human.new()
	h.role = p_role
	h.cfg = p_cfg
	return h


func _ready() -> void:
	_rng.seed = hash(name + role + str(cfg.get("seed", 0)))
	_blink_t = _rng.randf_range(1.0, 4.0)
	_t = _rng.randf_range(0.0, 10.0)
	var path := "res://assets/characters/%s.glb" % role
	if ResourceLoader.exists(path):
		_load_glb(path)
	else:
		_build()


func _load_glb(path: String) -> void:
	var ps := load(path) as PackedScene
	_glb = ps.instantiate()
	add_child(_glb)
	_anim = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play("idle")


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim) and _anim.current_animation != anim:
		_anim.play(anim, 0.3)


# ── Construction procédurale ────────────────────────────────────────────────
func _c(key: String, def):
	return cfg.get(key, def)


func _build() -> void:
	var skin_col: Color = _c("skin", SKIN_TONES[_rng.randi() % SKIN_TONES.size()])
	var hair_col: Color = _c("hair", HAIR_COLORS[_rng.randi() % HAIR_COLORS.size()])
	var top_col: Color = _c("top", Color.from_hsv(_rng.randf(), _rng.randf_range(0.1, 0.5), _rng.randf_range(0.15, 0.6)))
	var pants_col: Color = _c("pants", Color.from_hsv(_rng.randf_range(0.55, 0.65), _rng.randf_range(0.1, 0.4), _rng.randf_range(0.1, 0.35)))
	var shoe_col: Color = _c("shoes", Color(0.06, 0.055, 0.05))
	var outfit: String = _c("outfit", "civil")
	var fem: bool = _c("female", _rng.randf() < 0.4)
	var height: float = _c("height", _rng.randf_range(1.62, 1.72) if fem else _rng.randf_range(1.72, 1.88))
	var build: float = _c("build", _rng.randf_range(0.92, 1.12))
	var hair_style: String = _c("hair_style", ["long", "bun", "bob"][_rng.randi() % 3] if fem else ["short", "short", "buzz", "bald", "short"][_rng.randi() % 5])
	scale = Vector3.ONE * (height / 1.78)

	var skin := Mats.skin(skin_col)
	var top := Mats.cloth("top_" + top_col.to_html(), top_col)
	var pants := Mats.cloth("pants_" + pants_col.to_html(), pants_col)
	var shoes := Mats.std("shoe_" + shoe_col.to_html(), shoe_col, 0.35)
	var hair := Mats.std("hair_" + hair_col.to_html(), hair_col, 0.75)
	var robe_mat := Mats.cloth("robe", Color(0.025, 0.025, 0.03), 0.7)
	var white := Mats.cloth("whitecloth", Color(0.93, 0.93, 0.92), 0.85)
	var sleeve := top
	var forearm_mat := top
	if outfit in ["magistrat", "avocat", "procureur"]:
		top = robe_mat
		sleeve = robe_mat
		forearm_mat = robe_mat
		pants = robe_mat
	elif outfit == "medecin":
		sleeve = white
		forearm_mat = white
	if _c("short_sleeves", false):
		forearm_mat = skin

	var sw := (0.92 if fem else 1.0) * build
	hips = Node3D.new()
	hips.position.y = _hip_h
	add_child(hips)
	WB.sphere(hips, 0.17, Vector3(0, 0.0, 0), pants, Vector3(sw * (1.05 if fem else 0.98), 0.62, 0.76))

	spine = Node3D.new()
	spine.position.y = 0.05
	hips.add_child(spine)
	var torso := WB.capsule(spine, 0.165, 0.56, Vector3(0, 0.25, 0), top)
	torso.scale = Vector3(1.08 * sw, 1.0, 0.66)
	chest_mesh = WB.sphere(spine, 0.185, Vector3(0, 0.36, -0.005), top, Vector3(1.12 * sw, 0.72, 0.7 if not fem else 0.76))
	for s in [-1, 1]:
		WB.sphere(spine, 0.068, Vector3(s * 0.2 * sw, 0.44, 0.0), sleeve)

	neck = Node3D.new()
	neck.position.y = 0.5
	spine.add_child(neck)
	WB.capsule(neck, 0.052 if fem else 0.058, 0.16, Vector3(0, 0.05, 0.005), skin)
	head = Node3D.new()
	head.position.y = 0.075
	neck.add_child(head)
	_build_head(skin, hair, hair_col, hair_style, fem, skin_col)

	# Bras
	for s in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.205 * sw, 0.43, 0)
		spine.add_child(sh)
		shoulders.append(sh)
		WB.capsule(sh, 0.05 * build, 0.32, Vector3(0, -0.14, 0), sleeve)
		var el := Node3D.new()
		el.position.y = -0.29
		sh.add_child(el)
		elbows.append(el)
		var fr := 0.044
		if outfit in ["magistrat", "avocat", "procureur"]:
			fr = 0.068
		WB.capsule(el, fr, 0.27, Vector3(0, -0.12, 0), forearm_mat)
		if forearm_mat != skin:
			WB.capsule(el, 0.034, 0.08, Vector3(0, -0.25, 0), skin)
		var hand := WB.sphere(el, 0.045, Vector3(0, -0.31, 0), skin, Vector3(0.55, 1.05, 0.9))
		hand.rotation.y = s * 0.2
		var thumb := WB.capsule(el, 0.013, 0.06, Vector3(s * -0.01, -0.29, -0.03), skin)
		thumb.rotation.x = 0.5
		if outfit == "opj" and s == -1:
			var band := WB.cyl(sh, 0.058, 0.058, 0.07, Vector3(0, -0.1, 0), Mats.cloth("brassard", Color(1.0, 0.42, 0.05), 0.6))
			WB.label(band, "POLICE", Vector3(0, 0, -0.06), 0.016, Color.WHITE, PI, "sans", 900)

	# Jambes
	for s in [-1, 1]:
		var hj := Node3D.new()
		hj.position = Vector3(s * 0.092 * sw, -0.02, 0)
		hips.add_child(hj)
		hip_j.append(hj)
		WB.capsule(hj, 0.074 * build, 0.47, Vector3(0, -0.22, 0), pants)
		var kn := Node3D.new()
		kn.position.y = -0.45
		hj.add_child(kn)
		knees.append(kn)
		WB.capsule(kn, 0.056 * build, 0.45, Vector3(0, -0.21, 0), pants)
		var an := Node3D.new()
		an.position.y = -0.46
		kn.add_child(an)
		var shoe := WB.capsule(an, 0.048, 0.27, Vector3(0, -0.015, -0.055), shoes)
		shoe.rotation.x = PI / 2
		shoe.scale = Vector3(1.05, 1.0, 0.75)

	_build_outfit(outfit, fem, sw, robe_mat, white, top_col)


func _build_head(skin: Material, hair: Material, hair_col: Color, style: String, fem: bool, skin_col: Color) -> void:
	var jaw_w: float = _c("jaw", _rng.randf_range(0.88, 1.0) if fem else _rng.randf_range(0.95, 1.08))
	WB.sphere(head, 0.104, Vector3(0, 0.095, 0.005), skin, Vector3(0.9, 1.08, 1.0))
	WB.sphere(head, 0.083, Vector3(0, 0.03, -0.025), skin, Vector3(jaw_w, 0.92, 1.0))
	# pommettes
	for s in [-1, 1]:
		WB.sphere(head, 0.03, Vector3(s * 0.05, 0.065, -0.07), skin, Vector3(1.0, 0.8, 0.8))
	# nez
	var nose := WB.capsule(head, 0.016, 0.06, Vector3(0, 0.07, -0.097), skin)
	nose.rotation.x = -0.35
	WB.sphere(head, 0.017, Vector3(0, 0.046, -0.104), skin, Vector3(1.25, 0.8, 1.0))
	# oreilles
	for s in [-1, 1]:
		WB.sphere(head, 0.024, Vector3(s * 0.093, 0.085, 0.005), skin, Vector3(0.38, 1.0, 0.7))
	# yeux
	var eye_white := Mats.std("eyewhite", Color(0.92, 0.9, 0.87), 0.15)
	var iris_col: Color = _c("eyes", [Color("3b2618"), Color("5a3a22"), Color("3d5a6e"), Color("4d5b3a"), Color("231812")][_rng.randi() % 5])
	var iris := Mats.std("iris_" + iris_col.to_html(), iris_col, 0.1)
	var pupil := Mats.std("pupil", Color(0.01, 0.01, 0.01), 0.05)
	var brow := Mats.std("brow_" + hair_col.to_html(), hair_col.darkened(0.2), 0.9)
	var lid_mat := Mats.skin(skin_col.darkened(0.06))
	for s in [-1, 1]:
		var ep := Vector3(s * 0.034, 0.1, -0.082)
		WB.sphere(head, 0.016, ep, eye_white)
		WB.sphere(head, 0.0085, ep + Vector3(0, 0, -0.011), iris, Vector3(1, 1, 0.5))
		WB.sphere(head, 0.004, ep + Vector3(0, 0, -0.0145), pupil, Vector3(1, 1, 0.4))
		var lid := WB.sphere(head, 0.0185, ep + Vector3(0, 0.002, 0.001), lid_mat, Vector3(1.05, 0.35, 1.05))
		lid.position.y = ep.y + 0.011
		lids.append(lid)
		var b := WB.box(head, Vector3(0.036, 0.007 if fem else 0.01, 0.012), Vector3(s * 0.036, 0.124, -0.088), brow, false)
		b.rotation.z = s * -0.12
	# bouche
	var lip := Mats.std("lip_" + skin_col.to_html(), skin_col.darkened(0.28).lerp(Color(0.6, 0.25, 0.25), 0.35), 0.4)
	WB.box(head, Vector3(0.042, 0.007, 0.012), Vector3(0, 0.032, -0.098), lip, false)
	mouth = WB.box(head, Vector3(0.036, 0.012, 0.008), Vector3(0, 0.022, -0.096), Mats.std("mouthin", Color(0.12, 0.03, 0.03), 0.6), false)
	mouth.scale.y = 0.15
	WB.box(head, Vector3(0.038, 0.008, 0.012), Vector3(0, 0.014, -0.095), lip, false)
	# cheveux
	if style != "bald":
		var hm := hair if style != "buzz" else Mats.std("buzz_" + hair_col.to_html(), skin_col.lerp(hair_col, 0.55), 0.85)
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.112
		sm.height = 0.112
		sm.is_hemisphere = true
		sm.radial_segments = 32
		sm.rings = 12
		cap.mesh = sm
		cap.material_override = hm
		cap.position = Vector3(0, 0.1, 0.012)
		cap.rotation.x = -0.32
		cap.scale = Vector3(0.95, 1.08, 1.05)
		head.add_child(cap)
		var back := WB.sphere(head, 0.104, Vector3(0, 0.085, 0.022), hm, Vector3(0.93, 0.95, 0.9))
		back.position.z = 0.03
		if style == "long":
			var l := WB.capsule(head, 0.1, 0.34, Vector3(0, -0.04, 0.05), hm)
			l.scale = Vector3(1.0, 1.0, 0.55)
		elif style == "bun":
			WB.sphere(head, 0.045, Vector3(0, 0.17, 0.08), hm)
		elif style == "bob":
			var l2 := WB.capsule(head, 0.11, 0.2, Vector3(0, 0.04, 0.025), hm)
			l2.scale = Vector3(1.0, 1.0, 0.85)
	if _c("beard", (not fem) and _rng.randf() < 0.3):
		var bm := Mats.std("beard_" + hair_col.to_html(), skin_col.lerp(hair_col, 0.75), 0.95)
		WB.sphere(head, 0.08, Vector3(0, 0.02, -0.03), bm, Vector3(jaw_w * 1.04, 0.85, 1.02))
		WB.box(head, Vector3(0.05, 0.012, 0.012), Vector3(0, 0.041, -0.1), bm, false)
	if _c("glasses", _rng.randf() < 0.2):
		var gm := Mats.std("glassesframe", Color(0.05, 0.05, 0.05), 0.3, 0.4)
		for s in [-1, 1]:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.019
			tm.outer_radius = 0.023
			ring.mesh = tm
			ring.material_override = gm
			ring.position = Vector3(s * 0.034, 0.1, -0.103)
			ring.rotation.x = PI / 2
			head.add_child(ring)
		WB.box(head, Vector3(0.022, 0.004, 0.004), Vector3(0, 0.104, -0.104), gm, false)


func _build_outfit(outfit: String, fem: bool, sw: float, robe_mat: Material, white: Material, top_col: Color) -> void:
	match outfit:
		"police", "surveillant":
			var belt := Mats.std("belt", Color(0.03, 0.03, 0.03), 0.4)
			var b := WB.cyl(hips, 0.165, 0.165, 0.06, Vector3(0, 0.05, 0), belt)
			b.scale = Vector3(1.05 * sw, 1, 0.8)
			WB.box(hips, Vector3(0.06, 0.14, 0.09), Vector3(0.19 * sw, -0.02, 0.0), belt, false)
			WB.box(hips, Vector3(0.05, 0.07, 0.05), Vector3(-0.17 * sw, 0.03, -0.06), belt, false)
			var txt := "POLICE" if outfit == "police" else "PÉNITENTIAIRE"
			WB.label(spine, txt, Vector3(0, 0.36, 0.13), 0.075 if outfit == "police" else 0.04, Color(0.95, 0.95, 0.95), 0.0, "sans", 900)
			WB.label(spine, txt, Vector3(0.085, 0.4, -0.132), 0.022, Color(0.95, 0.95, 0.95), PI, "sans", 900)
			# écusson tricolore
			var fl := Node3D.new()
			fl.position = Vector3(-0.255 * sw, 0.33, 0)
			spine.add_child(fl)
			for i in 3:
				var c: Color = [Color(0.1, 0.2, 0.6), Color.WHITE, Color(0.8, 0.1, 0.12)][i]
				WB.box(fl, Vector3(0.004, 0.035, 0.012), Vector3(-0.002, 0, -0.012 + i * 0.012), Mats.std("flag%d" % i, c, 0.6), false)
			for s in [-1, 1]:
				WB.box(spine, Vector3(0.09, 0.012, 0.05), Vector3(s * 0.15 * sw, 0.485, 0), Mats.std("epaul", top_col.darkened(0.3), 0.7), false)
		"magistrat", "avocat", "procureur":
			robe = MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.2 * sw
			cm.bottom_radius = 0.33 * sw
			cm.height = _robe_full_h
			cm.radial_segments = 28
			robe.mesh = cm
			robe.material_override = robe_mat
			robe.scale = Vector3(1, 1, 0.78)
			robe.position = Vector3(0, -0.12, 0)
			spine.add_child(robe)
			# rabat blanc
			var rabat := Node3D.new()
			rabat.position = Vector3(0, 0.47, -0.125)
			spine.add_child(rabat)
			for s in [-1, 1]:
				var r := WB.box(rabat, Vector3(0.034, 0.12, 0.006), Vector3(s * 0.019, -0.055, 0), white, false)
				r.rotation.x = 0.12
			WB.box(spine, Vector3(0.11, 0.025, 0.12), Vector3(0, 0.49, -0.07), white, false)
			if outfit == "avocat":
				var ep := WB.box(spine, Vector3(0.07, 0.4, 0.01), Vector3(-0.12, 0.27, -0.13), robe_mat, false)
				ep.rotation.x = 0.08
				WB.box(spine, Vector3(0.072, 0.07, 0.012), Vector3(-0.12, 0.05, -0.135), white, false)
			else:
				var sash := Mats.cloth("sash", Color(0.04, 0.04, 0.045), 0.35)
				var s2 := WB.cyl(spine, 0.205 * sw, 0.205 * sw, 0.08, Vector3(0, 0.05, 0), sash)
				s2.scale = Vector3(1.04, 1, 0.74)
		"medecin":
			var coat := MeshInstance3D.new()
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.2 * sw
			cm2.bottom_radius = 0.26 * sw
			cm2.height = 0.95
			coat.mesh = cm2
			coat.material_override = white
			coat.scale = Vector3(1, 1, 0.75)
			coat.position = Vector3(0, 0.06, 0)
			spine.add_child(coat)
			var st := Mats.std("stetho", Color(0.1, 0.1, 0.1), 0.3)
			var tm := TorusMesh.new()
			tm.inner_radius = 0.1
			tm.outer_radius = 0.11
			var ring := MeshInstance3D.new()
			ring.mesh = tm
			ring.material_override = st
			ring.position = Vector3(0, 0.45, -0.03)
			ring.rotation.x = 1.1
			spine.add_child(ring)
		"detenu":
			pass


# ── API ───────────────────────────────────────────────────────────────────────
func set_sit(v: float, t: float = 0.0) -> void:
	if t <= 0.0:
		sit_amount = v
	else:
		var tw := create_tween()
		tw.tween_property(self, "sit_amount", v, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished


func face_point(p: Vector3, t: float = 0.4) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.01:
		return
	var target_yaw := atan2(-d.x, -d.z)
	var cur := rotation.y
	var diff := wrapf(target_yaw - cur, -PI, PI)
	if t <= 0.0:
		rotation.y = cur + diff
		return
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", cur + diff, t).set_trans(Tween.TRANS_SINE)
	await tw.finished


func walk_to(points: Array, speed: float = -1.0) -> void:
	if speed > 0:
		walk_speed = speed
	walking = true
	_play("walk")
	for p in points:
		var target: Vector3 = p
		var dist := global_position.distance_to(target)
		if dist < 0.02:
			continue
		face_point(target, 0.25)
		var tw := create_tween()
		tw.tween_property(self, "global_position", target, dist / walk_speed)
		await tw.finished
	walking = false
	_play("idle")
	arrived.emit()


func say_anim(on: bool) -> void:
	talking = on
	if on:
		_play("talk")
	else:
		_play("idle")


func head_node() -> Node3D:
	return head if head else self


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _glb:
		if look_target:
			pass
		return
	if hips == null:
		return
	# Respiration / balancement
	var breath := sin(_t * 1.7)
	chest_mesh.scale.y = 0.72 + 0.012 * breath
	spine.rotation.x = 0.015 * breath * (1.0 - sit_amount) - desk_pose * 0.12
	hips.rotation.z = 0.012 * sin(_t * 0.45) * (1.0 - sit_amount)

	# Marche
	var swing := 0.0
	if walking:
		_phase += delta * walk_speed * 5.2
		swing = sin(_phase)
	else:
		_phase = lerp(_phase, round(_phase / PI) * PI, delta * 6.0)
	var bob := absf(cos(_phase)) * 0.025 if walking else 0.0
	hips.position.y = lerp(_hip_h + bob, 0.53, sit_amount)
	hips.position.z = lerp(0.0, 0.08, sit_amount)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var leg := swing * 0.42 * s
		hip_j[i].rotation.x = lerp(leg, PI / 2.0 - 0.04, sit_amount)
		var kb: float = max(0.0, -sin(_phase * 1.0 + (0.0 if s > 0 else PI))) * 0.7 if walking else 0.0
		knees[i].rotation.x = lerp(-kb, -PI / 2.0 + 0.04, sit_amount)
		var arm := -swing * 0.32 * s
		var rest_z := s * (0.07 + 0.03 * sit_amount)
		shoulders[i].rotation.x = lerp(arm * (1.0 - sit_amount) + 0.15 * sit_amount, 0.75, desk_pose)
		shoulders[i].rotation.x = lerp(shoulders[i].rotation.x, -0.35, hands_back)
		shoulders[i].rotation.z = lerp(rest_z, s * 0.15, hands_back)
		elbows[i].rotation.x = lerp(0.12 + 0.55 * sit_amount, 0.75, desk_pose)
		elbows[i].rotation.x = lerp(elbows[i].rotation.x, 0.2, hands_back)
		if desk_pose > 0.5 and talking == false:
			elbows[i].rotation.x += sin(_t * (9.0 + i * 3.0)) * 0.03
	if robe and absf(_robe_last - sit_amount) > 0.001:
		_robe_last = sit_amount
		var hh := lerpf(_robe_full_h, 0.62, sit_amount)
		(robe.mesh as CylinderMesh).height = hh
		robe.position.y = 0.5 - hh * 0.5

	# Regard
	var yaw := 0.0
	var pitch := 0.0
	if look_target and is_instance_valid(look_target):
		var lp := neck.to_local(look_target.global_position)
		if lp.length() > 0.1:
			var dir := lp.normalized()
			yaw = clamp(atan2(-dir.x, -dir.z), -1.05, 1.05)
			pitch = clamp(asin(clamp(dir.y, -1.0, 1.0)), -0.45, 0.35)
			if abs(atan2(-dir.x, -dir.z)) > 1.9:
				yaw = 0.0
				pitch = 0.0
	yaw += sin(_t * 0.31) * 0.05
	_head_yaw = lerp(_head_yaw, yaw, clamp(delta * 3.0, 0.0, 1.0))
	_head_pitch = lerp(_head_pitch, pitch, clamp(delta * 3.0, 0.0, 1.0))
	head.rotation = Vector3(_head_pitch, _head_yaw, sin(_t * 0.23) * 0.03)

	# Clignements
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 1.0
		_blink_t = _rng.randf_range(2.0, 5.5)
	_blink = max(0.0, _blink - delta * 7.0)
	var lid_s := 0.35 + 0.75 * (sin(_blink * PI) if _blink > 0.0 else 0.0)
	for l in lids:
		l.scale.y = lid_s
		l.position.y = 0.1 + 0.011 - 0.009 * (lid_s - 0.35)

	# Parole
	if talking:
		var o: float = abs(sin(_t * 13.0)) * (0.5 + 0.5 * abs(sin(_t * 3.7)))
		mouth.scale.y = 0.2 + o * 1.4
	else:
		mouth.scale.y = lerp(mouth.scale.y, 0.15, delta * 10.0)
