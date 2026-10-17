extends Control
## Écran de décision / fin de parcours : verdict, peine, récapitulatif de la procédure.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UIKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Sfx.loop("drone", -14.0, 2.0)
	Transition.fade_in(1.4)


func _build() -> void:
	var gs := GameState
	var v: Dictionary = gs.verdict
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var kicker := "Décision"
	var headline := ""
	var detail := ""
	var col := UIKit.ACCENT
	var after_prison: bool = gs.prison_months_served > 0.0
	if gs.outcome_after_gav == "classement":
		kicker = "Décision du parquet"
		headline = "Classement sans suite"
		detail = "Faute d'éléments suffisants, le procureur de la République renonce aux poursuites. Vous ressortez libre du commissariat, à l'aube, avec vos lacets dans un sac en plastique."
		col = UIKit.GREEN
	elif after_prison:
		kicker = "Levée d'écrou"
		headline = "Libéré" + gs.e()
		detail = "Après %s de détention (dont %d mois de détention provisoire), vous franchissez la porte de la maison d'arrêt. Réductions de peine obtenues : %d mois." % [
			InfractionDB.prison_label(int(round(gs.prison_months_served)) + gs.detention_provisoire_months), gs.detention_provisoire_months, gs.reductions_months]
		col = UIKit.GREEN
	else:
		headline = String(v.get("headline", "—")).capitalize()
		detail = v.get("detail", "")
		if not v.get("guilty", true):
			col = UIKit.GREEN
		elif v.get("incarcerated", false):
			col = UIKit.RED

	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cc.custom_minimum_size = Vector2(0, 1080)
	sc.add_child(cc)
	var v_box := VBoxContainer.new()
	v_box.custom_minimum_size = Vector2(980, 0)
	v_box.add_theme_constant_override("separation", 14)
	cc.add_child(v_box)
	v_box.add_child(UIKit.caps(kicker + " · " + gs.jurisdiction().name, 13, col, 6.0))
	var h := UIKit.label(headline, 96, UIKit.TEXT, "serif", 500)
	v_box.add_child(h)
	var line := ColorRect.new()
	line.color = col
	line.custom_minimum_size = Vector2(0, 2)
	v_box.add_child(line)
	var d := UIKit.label(detail, 22, UIKit.TEXT, "sans", 420)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_constant_override("line_spacing", 6)
	v_box.add_child(d)
	if not after_prison:
		for ex in v.get("extras", []):
			var e := UIKit.label("•  " + ex, 17, UIKit.TEXT_DIM)
			v_box.add_child(e)
	v_box.add_child(UIKit.spacer(20))

	# Récapitulatif en cartes
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v_box.add_child(grid)
	var stats := [
		["Mis en cause", gs.full_name()],
		["Qualification", InfractionDB.kind_label(gs.kind())],
		["Peine encourue", InfractionDB.prison_label(gs.max_prison_months())],
		["Garde à vue", ("%d h" % int(max(gs.gav_hours_elapsed(), 0.0))) if gs.gav_possible() and gs.gav_start_minutes > 0 else "Audition libre"],
		["Avocat", {"none": "Aucun", "commis": "Commis d'office", "choisi": gs.lawyer_name}[gs.lawyer]],
		["Déclarations", "%d aveux · %d dénégations · %d silences" % [gs.admissions, gs.denials, gs.silences]],
		["Attitude", "Respectueuse" if gs.attitude > 1 else ("Hostile" if gs.attitude < -1 else "Neutre")],
		["Casier", {"vierge": "Vierge", "antecedents": "Antécédents", "recidive": "Récidive"}[gs.record]],
		["Détention provisoire", "%d mois" % gs.detention_provisoire_months if gs.detention_provisoire_months > 0 else "—"],
	]
	for s in stats:
		var p := PanelContainer.new()
		var sb := UIKit.box(Color(1, 1, 1, 0.03), 12, UIKit.LINE, 1, 16)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(318, 0)
		var pv := VBoxContainer.new()
		pv.add_child(UIKit.caps(s[0], 10, UIKit.TEXT_MUTED, 2.5))
		var val := UIKit.label(s[1], 17, UIKit.TEXT, "sans", 560)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv.add_child(val)
		p.add_child(pv)
		grid.add_child(p)
	v_box.add_child(UIKit.spacer(18))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v_box.add_child(row)
	var to_prison: bool = not after_prison and gs.outcome_after_gav != "classement" and v.get("incarcerated", false) and int(v.get("to_serve", 0)) > 0
	if to_prison:
		var b := UIKit.button("Entrer en détention  →", true, 18)
		b.custom_minimum_size = Vector2(320, 58)
		b.pressed.connect(func():
			Sfx.play("door", 0.0, 0.8)
			Transition.goto("res://scenes/prison.tscn", 1.2))
		row.add_child(b)
		var note := UIKit.label("Durée à purger : %s" % InfractionDB.prison_label(int(v.to_serve)), 15, UIKit.TEXT_DIM)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(note)
	else:
		var b2 := UIKit.button("Ouvrir un nouveau dossier", true, 18)
		b2.custom_minimum_size = Vector2(320, 58)
		b2.pressed.connect(func(): Transition.goto("res://scenes/dossier.tscn", 0.8))
		row.add_child(b2)
	var b3 := UIKit.button("Menu principal")
	b3.custom_minimum_size = Vector2(200, 58)
	b3.pressed.connect(func(): Transition.goto("res://scenes/main_menu.tscn", 0.8))
	row.add_child(b3)
	var disclaimer := UIKit.label("Simulation à visée immersive et pédagogique. Peines et procédures simplifiées ; ne constitue pas un conseil juridique.", 12, UIKit.TEXT_MUTED)
	v_box.add_child(UIKit.spacer(20))
	v_box.add_child(disclaimer)
	h.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(h, "modulate:a", 1.0, 1.4)
	Sfx.play("boom", -4.0)
