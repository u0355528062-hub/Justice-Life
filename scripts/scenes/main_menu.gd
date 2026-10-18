extends LevelBase
## Menu principal : fond 3D (salle d'audience plongée dans la pénombre,
## rai de lumière volumétrique) et caméra en lent travelling.

var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _help: PanelContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	setup_environment("menu")
	_build_scene()
	_build_ui()
	Sfx.loop("drone", -10.0, 3.0)
	Sfx.loop("room", -26.0, 3.0)
	Transition.fade_in(2.0)


func _build_scene() -> void:
	var wood := Mats.wood(Color("5a3a22"), Color("2e1c10"), 0.22, 0.38, "menu_wood")
	var panel := Mats.panelling(Color("4b301c"), Color("2a1a0e"), "menu")
	var floor_m := Mats.wood(Color("3a2616"), Color("1f140b"), 0.12, 0.3, "menu_floor")
	var plaster := Mats.wall_paint(Color(0.55, 0.52, 0.47), "menu_plaster")
	WB.box(self, Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), floor_m)
	WB.box(self, Vector3(16, 3.0, 0.3), Vector3(0, 1.5, -6), panel)
	WB.box(self, Vector3(16, 6.0, 0.3), Vector3(0, 6.0, -6.05), plaster)
	# Estrade + bureau des juges
	WB.box(self, Vector3(10, 0.6, 3), Vector3(0, 0.3, -4.4), wood)
	WB.box(self, Vector3(8, 1.15, 0.6), Vector3(0, 1.17, -3.2), wood)
	WB.box(self, Vector3(8.2, 0.08, 0.8), Vector3(0, 1.78, -3.25), wood)
	# Fauteuils
	for x in [-2.2, 0.0, 2.2]:
		WB.box(self, Vector3(0.8, 1.6, 0.15), Vector3(x, 1.75 + (0.2 if x == 0.0 else 0.0), -5.2), Mats.std("leather", Color(0.18, 0.05, 0.05), 0.5))
	# Emblème RF
	var gold := Mats.std("gold", Color(0.85, 0.66, 0.32), 0.3, 1.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 0.9
	tm.rings = 64
	ring.mesh = tm
	ring.material_override = gold
	ring.position = Vector3(0, 4.6, -5.85)
	ring.rotation.x = PI / 2
	add_child(ring)
	WB.label(self, "RF", Vector3(0, 4.6, -5.84), 0.9, Color(0.9, 0.72, 0.38), 0.0, "serif", 700)
	WB.label(self, "LIBERTÉ · ÉGALITÉ · FRATERNITÉ", Vector3(0, 3.35, -5.84), 0.16, Color(0.85, 0.7, 0.45), 0.0, "sans", 600)
	# Colonnes
	for x in [-6.5, 6.5]:
		WB.cyl(self, 0.35, 0.4, 9.0, Vector3(x, 4.5, -5.4), Mats.wall_paint(Color(0.62, 0.6, 0.55), "column"))
	# Marteau sur le bureau
	var g := Node3D.new()
	g.position = Vector3(0.6, 1.86, -3.1)
	g.rotation.y = 0.5
	add_child(g)
	var h := WB.cyl(g, 0.045, 0.045, 0.2, Vector3.ZERO, wood)
	h.rotation.z = PI / 2
	var handle := WB.cyl(g, 0.012, 0.014, 0.32, Vector3(0, 0, 0.16), wood)
	handle.rotation.x = PI / 2
	WB.cyl(self, 0.09, 0.1, 0.03, Vector3(0.35, 1.835, -3.05), wood)
	# Rai de lumière
	var sl := SpotLight3D.new()
	sl.position = Vector3(2.5, 9.0, 1.5)
	sl.look_at_from_position(sl.position, Vector3(0, 1.8, -3.5))
	sl.light_color = Color(1.0, 0.86, 0.66)
	sl.light_energy = 22.0
	sl.spot_range = 20.0
	sl.spot_angle = 24.0
	sl.shadow_enabled = true
	sl.light_volumetric_fog_energy = 3.0
	add_child(sl)
	var em := SpotLight3D.new()
	em.position = Vector3(-1.5, 8.5, -1.0)
	em.look_at_from_position(em.position, Vector3(0, 4.4, -5.8))
	em.light_color = Color(1.0, 0.82, 0.6)
	em.light_energy = 9.0
	em.spot_range = 14.0
	em.spot_angle = 20.0
	em.light_volumetric_fog_energy = 1.2
	add_child(em)
	var fill := WB.omni(self, Vector3(-4, 3, 2), Color(0.4, 0.5, 0.8), 0.4, 12.0)
	fill.light_volumetric_fog_energy = 0.2
	_cam = Camera3D.new()
	_cam.fov = 50
	_cam.position = Vector3(-1.5, 1.9, 3.0)
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 9.0
	attrs.dof_blur_far_transition = 6.0
	attrs.dof_blur_amount = 0.05
	_cam.attributes = attrs
	add_child(_cam)
	_cam.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UIKit.theme()
	layer.add_child(_ui)
	# dégradé latéral
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.02, 0.025, 0.035, 0.96))
	gr.set_color(1, Color(0.02, 0.025, 0.035, 0.0))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.anchor_bottom = 1.0
	grad.offset_right = 1100
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(grad)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var om := ShaderMaterial.new()
	om.shader = load("res://shaders/overlay.gdshader")
	om.set_shader_parameter("vignette", 0.75)
	overlay.material = om
	_ui.add_child(overlay)
	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grain.gdshader")
	grain.material = gm
	_ui.add_child(grain)

	var m := MarginContainer.new()
	m.anchor_bottom = 1.0
	m.add_theme_constant_override("margin_left", 120)
	m.add_theme_constant_override("margin_top", 120)
	m.add_theme_constant_override("margin_bottom", 90)
	_ui.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size.x = 560
	m.add_child(v)
	v.add_child(UIKit.caps("République française · Simulation", 13, UIKit.ACCENT, 6.0))
	v.add_child(UIKit.spacer(18))
	var t1 := UIKit.label("Justice", 128, UIKit.TEXT, "serif", 500)
	t1.add_theme_constant_override("line_spacing", -40)
	v.add_child(t1)
	var t2 := UIKit.label("Life", 128, UIKit.ACCENT, "serif", 500)
	t2.add_theme_font_override("font", UIKit.font("serif", 500, true))
	t2.position.y = -30
	v.add_child(t2)
	v.add_child(UIKit.spacer(10))
	var tag := UIKit.label("De la garde à vue à la cellule.\nChaque mot que vous prononcez sera consigné.", 21, UIKit.TEXT_DIM, "sans", 380)
	tag.add_theme_constant_override("line_spacing", 6)
	v.add_child(tag)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	if GameState.has_save():
		var rb := UIKit.button("Reprendre la détention", true, 19)
		rb.custom_minimum_size = Vector2(400, 60)
		rb.pressed.connect(func():
			if GameState.load_detention():
				Transition.goto("res://scenes/prison.tscn", 0.8))
		v.add_child(rb)
		var rs := UIKit.label(GameState.save_summary(), 14, UIKit.TEXT_DIM, "mono", 450)
		v.add_child(rs)
		v.add_child(UIKit.spacer(12))
	var b1 := UIKit.button("Ouvrir un nouveau dossier", not GameState.has_save(), 19)
	b1.custom_minimum_size = Vector2(400, 60)
	b1.pressed.connect(_on_new)
	v.add_child(b1)
	v.add_child(UIKit.spacer(12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var b2 := UIKit.button("Comment jouer")
	b2.custom_minimum_size = Vector2(194, 52)
	b2.pressed.connect(func(): _help.visible = not _help.visible)
	row.add_child(b2)
	var b3 := UIKit.button("Quitter")
	b3.custom_minimum_size = Vector2(194, 52)
	b3.pressed.connect(func(): get_tree().quit())
	row.add_child(b3)
	v.add_child(row)
	v.add_child(UIKit.spacer(40))
	v.add_child(UIKit.caps("Prototype · Étape 1 — Garde à vue, procès, détention", 10, UIKit.TEXT_MUTED, 3.0))

	_help = PanelContainer.new()
	_help.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.offset_right = -110
	_help.custom_minimum_size = Vector2(520, 0)
	var sb := UIKit.box(Color(0.04, 0.05, 0.07, 0.9), 16, UIKit.LINE, 1, 32)
	_help.add_theme_stylebox_override("panel", sb)
	_help.visible = false
	_ui.add_child(_help)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	_help.add_child(hv)
	hv.add_child(UIKit.label("Commandes", 30, UIKit.TEXT, "serif", 600))
	for pair in [["Z Q S D / W A S D", "Se déplacer"], ["Souris", "Regarder"], ["E", "Interagir"],
			["Espace / clic", "Continuer un dialogue"], ["1 – 4 / clic", "Choisir une réponse"],
			["Tab", "Consulter son dossier (PV)"], ["Échap", "Pause"]]:
		var r := HBoxContainer.new()
		var k := UIKit.label(pair[0], 16, UIKit.ACCENT, "mono", 500)
		k.custom_minimum_size.x = 210
		r.add_child(k)
		r.add_child(UIKit.label(pair[1], 16, UIKit.TEXT_DIM))
		hv.add_child(r)
	hv.add_child(UIKit.hsep())
	var info := UIKit.label("Garde à vue : 1 heure = 3 secondes.\nDétention : 1 mois = 1 minute.\nVos réponses influencent le procès et la peine.", 16, UIKit.TEXT_DIM)
	info.add_theme_constant_override("line_spacing", 5)
	hv.add_child(info)


func _on_new() -> void:
	Transition.goto("res://scenes/dossier.tscn", 0.8)


func _process(delta: float) -> void:
	_t += delta
	if _cam:
		var a := _t * 0.05
		_cam.position = Vector3(-1.2 + sin(a) * 1.6, 1.9 + sin(a * 0.7) * 0.15, 3.2 + cos(a) * 0.5)
		_cam.look_at(Vector3(0.3, 2.2, -4.0))
