extends Control
## Constitution du dossier : identité, antécédents, circonstances et choix
## de la ou des infractions commises dans un très large catalogue.

var _cat := "all"
var _kind_filter := "all"
var _query := ""
var _grid: GridContainer
var _cat_buttons := {}
var _selected_list: VBoxContainer
var _summary: VBoxContainer
var _start: Button
var _count_label: Label
var _first: LineEdit
var _last: LineEdit
var _seg_record: Array = []
var _seg_gender: Array = []
var _seg_circ: Array = []
var _aggr_box: HFlowContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UIKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.selected.clear()
	GameState.aggravations.clear()
	_build()
	_refresh()
	Sfx.loop("drone", -16.0, 2.0)
	Transition.fade_in(0.8)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var gr := Gradient.new()
	gr.set_color(0, Color(0.886, 0.714, 0.373, 0.07))
	gr.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = gr
	glow.texture = gt
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 56)
	root.add_theme_constant_override("margin_top", 40)
	root.add_theme_constant_override("margin_bottom", 40)
	add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	root.add_child(v)

	# En-tête
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	var back := UIKit.button("←  Menu")
	back.custom_minimum_size = Vector2(120, 44)
	back.pressed.connect(func(): Transition.goto("res://scenes/main_menu.tscn", 0.6))
	head.add_child(back)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.add_child(UIKit.caps("Dossier n° %06d · Parquet" % (randi() % 999999), 11, UIKit.ACCENT, 4.0))
	tv.add_child(UIKit.label("Constitution du dossier pénal", 40, UIKit.TEXT, "serif", 500))
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	_count_label = UIKit.label("", 15, UIKit.TEXT_DIM, "mono", 450)
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_label)
	v.add_child(head)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	cols.add_child(_build_categories())
	cols.add_child(_build_catalog())
	cols.add_child(_build_case())


func _panel(min_w: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(1, 1, 1, 0.025), 18, UIKit.LINE, 1, 0)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = min_w
	return p


func _build_categories() -> Control:
	var p := _panel(300)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UIKit.caps("Catégories", 11, UIKit.TEXT_MUTED, 3.0))
	v.add_child(UIKit.spacer(8))
	var all_b := _cat_button("all", "Toutes les infractions", "◎", UIKit.ACCENT, InfractionDB.all().size())
	v.add_child(all_b)
	v.add_child(UIKit.spacer(4))
	for c in InfractionDB.CATEGORIES:
		v.add_child(_cat_button(c.id, c.name, c.icon, c.color, InfractionDB.count_in(c.id)))
	return p


func _cat_button(id: String, text: String, icon: String, col: Color, n: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var n_sb := UIKit.box(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0, 0)
	n_sb.content_margin_left = 44
	var h_sb := UIKit.box(Color(1, 1, 1, 0.05), 10, Color(0, 0, 0, 0), 0, 0)
	h_sb.content_margin_left = 44
	b.add_theme_stylebox_override("normal", n_sb)
	b.add_theme_stylebox_override("hover", h_sb)
	b.add_theme_stylebox_override("pressed", h_sb)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	b.text = text
	var ic := UIKit.label(icon, 16, col, "sans", 700)
	ic.position = Vector2(14, 10)
	b.add_child(ic)
	var cnt := UIKit.label(str(n), 12, UIKit.TEXT_MUTED, "mono", 500)
	cnt.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	cnt.position = Vector2(0, -9)
	cnt.offset_left = -40
	cnt.name = "Count"
	b.add_child(cnt)
	b.pressed.connect(func():
		_cat = id
		_refresh())
	_cat_buttons[id] = b
	return b


func _build_catalog() -> Control:
	var p := _panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher une infraction, un article… (ex. « vol », « 222-13 »)"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 46
	search.add_theme_font_size_override("font_size", 16)
	search.text_changed.connect(func(t):
		_query = t.strip_edges().to_lower()
		_refresh())
	bar.add_child(search)
	for f in [["all", "Toutes"], ["C", "Contraventions"], ["D", "Délits"], ["X", "Crimes"]]:
		var fb := UIKit.button(f[1], false, 14)
		fb.toggle_mode = true
		fb.button_pressed = f[0] == "all"
		fb.custom_minimum_size.y = 46
		fb.set_meta("kind", f[0])
		fb.pressed.connect(func():
			_kind_filter = f[0]
			for c in bar.get_children():
				if c is Button and c.has_meta("kind"):
					c.button_pressed = c.get_meta("kind") == _kind_filter
			_refresh())
		bar.add_child(fb)
	v.add_child(bar)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(_grid)
	return p


func _build_case() -> Control:
	var p := _panel(470)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)

	v.add_child(UIKit.caps("Mis en cause", 11, UIKit.TEXT_MUTED, 3.0))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 8)
	_first = LineEdit.new()
	_first.text = GameState.player_first
	_first.placeholder_text = "Prénom"
	_first.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_first.text_changed.connect(func(t): GameState.player_first = t)
	nr.add_child(_first)
	_last = LineEdit.new()
	_last.text = GameState.player_last
	_last.placeholder_text = "Nom"
	_last.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_last.text_changed.connect(func(t): GameState.player_last = t)
	nr.add_child(_last)
	var dice := UIKit.button("⟳")
	dice.tooltip_text = "Identité aléatoire"
	dice.custom_minimum_size = Vector2(46, 0)
	dice.pressed.connect(func():
		GameState.random_identity()
		_first.text = GameState.player_first
		_last.text = GameState.player_last
		for i in _seg_gender.size():
			_seg_gender[i].button_pressed = (i == 1) == GameState.player_female)
	nr.add_child(dice)
	v.add_child(nr)
	_seg_gender = _segmented(v, [["m", "Homme"], ["f", "Femme"]], "f" if GameState.player_female else "m",
		func(val): GameState.player_female = val == "f")

	v.add_child(UIKit.spacer(4))
	v.add_child(UIKit.caps("Casier judiciaire", 11, UIKit.TEXT_MUTED, 3.0))
	_seg_record = _segmented(v, [["vierge", "Vierge"], ["antecedents", "Antécédents"], ["recidive", "Récidive"]],
		GameState.record, func(val):
			GameState.record = val
			_refresh_summary())
	v.add_child(UIKit.caps("Interpellation", 11, UIKit.TEXT_MUTED, 3.0))
	_seg_circ = _segmented(v, [["flagrant", "Flagrant délit"], ["plainte", "Sur plainte"], ["enquete", "Après enquête"]],
		GameState.circumstance, func(val): GameState.circumstance = val)
	v.add_child(UIKit.caps("Circonstances aggravantes", 11, UIKit.TEXT_MUTED, 3.0))
	_aggr_box = HFlowContainer.new()
	_aggr_box.add_theme_constant_override("h_separation", 8)
	_aggr_box.add_theme_constant_override("v_separation", 8)
	for a in ["En réunion", "Avec arme", "Sous l'emprise de l'alcool", "Sur personne vulnérable", "En état d'ivresse", "Avec préméditation"]:
		var b := UIKit.button(a, false, 13)
		b.toggle_mode = true
		b.custom_minimum_size.y = 36
		b.toggled.connect(func(on):
			if on:
				GameState.aggravations.append(a)
			else:
				GameState.aggravations.erase(a)
			_refresh_summary())
		_aggr_box.add_child(b)
	v.add_child(_aggr_box)

	v.add_child(UIKit.hsep())
	v.add_child(UIKit.caps("Infractions retenues", 11, UIKit.TEXT_MUTED, 3.0))
	_selected_list = VBoxContainer.new()
	_selected_list.add_theme_constant_override("separation", 6)
	v.add_child(_selected_list)
	v.add_child(UIKit.hsep())
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override("separation", 8)
	v.add_child(_summary)
	v.add_child(UIKit.spacer(6))
	_start = UIKit.button("Commencer la procédure  →", true, 18)
	_start.custom_minimum_size.y = 58
	_start.pressed.connect(_on_start)
	v.add_child(_start)
	return p


func _segmented(parent: Control, opts: Array, current: String, cb: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var buttons := []
	for o in opts:
		var b := UIKit.button(o[1], false, 14)
		b.toggle_mode = true
		b.button_pressed = o[0] == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 40
		buttons.append(b)
		row.add_child(b)
	for i in buttons.size():
		var val: String = opts[i][0]
		buttons[i].pressed.connect(func():
			for j in buttons.size():
				buttons[j].button_pressed = j == i
			cb.call(val))
	parent.add_child(row)
	return buttons


func _matches(d: Dictionary) -> bool:
	if _cat != "all" and d.cat != _cat:
		return false
	if _kind_filter != "all" and d.kind != _kind_filter:
		return false
	if _query != "":
		var hay: String = (d.name + " " + d.article + " " + d.facts).to_lower()
		if not hay.contains(_query):
			return false
	return true


func _refresh() -> void:
	for id in _cat_buttons:
		var b: Button = _cat_buttons[id]
		var on: bool = id == _cat
		b.add_theme_color_override("font_color", UIKit.TEXT if on else UIKit.TEXT_DIM)
		var sb := UIKit.box(Color(1, 1, 1, 0.07) if on else Color(0, 0, 0, 0), 10,
			Color(UIKit.ACCENT, 0.5) if on else Color(0, 0, 0, 0), 1, 0)
		sb.content_margin_left = 44
		b.add_theme_stylebox_override("normal", sb)
		var nsel := 0
		for s in GameState.selected:
			if id == "all" or InfractionDB.get_by_id(s).cat == id:
				nsel += 1
		var cnt: Label = b.get_node("Count")
		var total := InfractionDB.all().size() if id == "all" else InfractionDB.count_in(id)
		cnt.text = ("%d/%d" % [nsel, total]) if nsel > 0 else str(total)
		cnt.add_theme_color_override("font_color", UIKit.ACCENT if nsel > 0 else UIKit.TEXT_MUTED)
	for c in _grid.get_children():
		c.queue_free()
	var n := 0
	for d in InfractionDB.all():
		if _matches(d):
			_grid.add_child(_card(d))
			n += 1
	_count_label.text = "%d infraction%s affichée%s · %d au catalogue" % [n, "s" if n > 1 else "", "s" if n > 1 else "", InfractionDB.all().size()]
	_refresh_summary()


func _card(d: Dictionary) -> Button:
	var sel := GameState.selected.has(d.id)
	var cat := InfractionDB.category(d.cat)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 118)
	var n_sb := UIKit.box(Color(UIKit.ACCENT, 0.09) if sel else Color(1, 1, 1, 0.03), 14,
		Color(UIKit.ACCENT, 0.85) if sel else Color(1, 1, 1, 0.07), 1, 0)
	var h_sb := n_sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = Color(UIKit.ACCENT, 0.13) if sel else Color(1, 1, 1, 0.06)
	h_sb.border_color = Color(UIKit.ACCENT, 1.0) if sel else Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", n_sb)
	b.add_theme_stylebox_override("hover", h_sb)
	b.add_theme_stylebox_override("pressed", h_sb)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 18)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	var kc := UIKit.chip(InfractionDB.kind_label(d.kind), InfractionDB.kind_color(d.kind), 10)
	kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(kc)
	var cl := UIKit.label(cat.icon + "  " + cat.name, 12, Color(cat.color, 0.9), "sans", 520)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(cl)
	var chk := UIKit.label("✓" if sel else "+", 18, UIKit.ACCENT if sel else UIKit.TEXT_MUTED, "sans", 800)
	top.add_child(chk)
	v.add_child(top)
	var nm := UIKit.label(d.name, 17, UIKit.TEXT, "sans", 620)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	info.add_child(UIKit.label(d.article, 12, UIKit.TEXT_MUTED, "mono", 450))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(sp)
	var pl := UIKit.label("⛓ " + InfractionDB.prison_label(d.prison), 12, UIKit.TEXT_DIM, "mono", 500)
	info.add_child(pl)
	info.add_child(UIKit.label("€ " + InfractionDB.fine_label(d.fine), 12, UIKit.TEXT_DIM, "mono", 500))
	v.add_child(info)
	for c in [top, nm, info, cl, chk, pl]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in info.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.mouse_entered.connect(func(): Sfx.play("hover", -16.0))
	b.pressed.connect(func():
		if GameState.selected.has(d.id):
			GameState.selected.erase(d.id)
			Sfx.play("ui", -8.0, 0.8)
		else:
			GameState.selected.append(d.id)
			Sfx.play("ui", -4.0, 1.2)
		_refresh())
	return b


func _refresh_summary() -> void:
	for c in _selected_list.get_children():
		c.queue_free()
	for c in _summary.get_children():
		c.queue_free()
	if GameState.selected.is_empty():
		var e := UIKit.label("Aucune infraction sélectionnée.\nCliquez sur les fiches du catalogue.", 14, UIKit.TEXT_MUTED)
		_selected_list.add_child(e)
		_start.disabled = true
		return
	_start.disabled = false
	for d in GameState.infractions():
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.color = InfractionDB.kind_color(d.kind)
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(dot)
		var l := UIKit.label(d.name, 14, UIKit.TEXT, "sans", 500)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(l)
		var x := Button.new()
		x.text = "✕"
		x.flat = true
		x.focus_mode = Control.FOCUS_NONE
		x.add_theme_color_override("font_color", UIKit.TEXT_MUTED)
		x.add_theme_font_size_override("font_size", 13)
		var id: String = d.id
		x.pressed.connect(func():
			GameState.selected.erase(id)
			_refresh())
		r.add_child(x)
		_selected_list.add_child(r)
	var j := GameState.jurisdiction()
	var k := GameState.kind()
	_sum_row("Qualification", InfractionDB.kind_label(k), InfractionDB.kind_color(k))
	_sum_row("Juridiction", j.name, UIKit.TEXT)
	_sum_row("Peine maximale", InfractionDB.prison_label(GameState.max_prison_months()), UIKit.TEXT)
	_sum_row("Amende maximale", InfractionDB.fine_label(GameState.max_fine()), UIKit.TEXT)
	if GameState.gav_possible():
		_sum_row("Garde à vue", "jusqu'à %d h" % GameState.compute_gav_max(), UIKit.ACCENT)
	else:
		_sum_row("Garde à vue", "impossible · audition libre", UIKit.GREEN)
	if GameState.record == "recidive":
		_sum_row("Récidive", "peines encourues doublées", UIKit.RED)


func _sum_row(k: String, val: String, col: Color) -> void:
	var r := HBoxContainer.new()
	var kl := UIKit.label(k, 14, UIKit.TEXT_DIM)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(kl)
	var vl := UIKit.label(val, 14, col, "sans", 620)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(vl)
	_summary.add_child(r)


func _on_start() -> void:
	if GameState.selected.is_empty():
		return
	if GameState.player_first.strip_edges() == "":
		GameState.player_first = "Lucas"
	if GameState.player_last.strip_edges() == "":
		GameState.player_last = "Martin"
	GameState.reset_procedure()
	Sfx.play("boom", -2.0)
	await Transition.fade_out(1.0)
	Sfx.stop_all_loops(0.8)
	get_tree().change_scene_to_file("res://scenes/commissariat.tscn")
