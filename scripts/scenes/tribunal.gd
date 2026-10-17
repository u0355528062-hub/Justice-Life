extends LevelBase
## Chapitre IV : l'audience. Salle d'audience complète, procès à questions
## prédéfinies et choix, réquisitions, plaidoirie, dernier mot, délibéré, verdict.

var judges: Array[Human] = []
var president: Human
var prosecutor: Human
var greffier: Human
var defense: Human
var civil_lawyer: Human
var victim: Human
var family: Human
var escorts: Array[Human] = []
var public_npcs: Array[Human] = []
var pres_f := false
var proc_f := false
var j: Dictionary
var in_box := true
var _seat_pos := Vector3.ZERO
var _seat_eye := 1.18

const BENCH_Z := -19.3
const PLATFORM_H := 0.6


func _ready() -> void:
	Transition.set_black()
	setup_environment("court")
	j = GameState.jurisdiction()
	in_box = GameState.outcome_after_gav in ["ci", "instruction"]
	pres_f = randf() < 0.5
	proc_f = randf() < 0.5
	_build_room()
	_spawn_people()
	if in_box:
		_seat_pos = Vector3(-7.4, 0.3, -12.6)
		spawn_player(_seat_pos, -PI / 2 + 0.35)
	else:
		_seat_pos = Vector3(-2.6, 0.0, -8.0)
		spawn_player(_seat_pos, 0.0)
	player.set_eye_height(_seat_eye, 0.0)
	player.lock(true, 95.0)
	_run()


# ═══════════════════════════════════════════════════════════════════════════
func _build_room() -> void:
	var parquet := Mats.wood(Color(0.42, 0.28, 0.16), Color(0.24, 0.15, 0.08), 0.1, 0.32, "courtfloor")
	var plaster := Mats.wall_paint(Color(0.86, 0.82, 0.74), "courtwall")
	var ceil := Mats.wall_paint(Color(0.9, 0.88, 0.82), "courtceil")
	var panel := Mats.panelling(Color(0.45, 0.29, 0.16), Color(0.26, 0.16, 0.08), "court")
	var wood := Mats.wood(Color(0.5, 0.33, 0.18), Color(0.28, 0.17, 0.08), 0.25, 0.35, "courtwood")
	var leather := Mats.std("leather_red", Color(0.35, 0.06, 0.06), 0.45)
	var green := Mats.fabric(Color(0.12, 0.25, 0.16), "tapis")
	WB.room(self, -9, 9, -22, 0, 7.0, parquet, plaster, ceil, [
		{"side": "x1", "at": -16.0, "w": 2.2, "h": 6.2, "sill": 3.0, "glass": true},
		{"side": "x1", "at": -10.0, "w": 2.2, "h": 6.2, "sill": 3.0, "glass": true},
		{"side": "x1", "at": -4.0, "w": 2.2, "h": 6.2, "sill": 3.0, "glass": true},
		{"side": "z1", "at": 0.0, "w": 2.4, "h": 3.0},
		{"side": "z0", "at": -5.8, "w": 1.2, "h": 2.4},
	])
	# Lambris bas sur tout le pourtour
	for d in [[Vector3(17.7, 2.6, 0.06), Vector3(0, 1.3, -21.8)], [Vector3(0.06, 2.6, 21.6), Vector3(-8.81, 1.3, -11)],
			[Vector3(0.06, 2.6, 21.6), Vector3(8.81, 1.3, -11)], [Vector3(17.7, 2.6, 0.06), Vector3(0, 1.3, -0.2)]]:
		WB.box(self, d[0], d[1], panel, false)
	# Corniche
	for d in [[Vector3(17.7, 0.12, 0.14), Vector3(0, 2.66, -21.78)], [Vector3(0.14, 0.12, 21.6), Vector3(-8.78, 2.66, -11)], [Vector3(0.14, 0.12, 21.6), Vector3(8.78, 2.66, -11)]]:
		WB.box(self, d[0], d[1], wood, false)
	# Estrade et bureau des magistrats
	WB.box(self, Vector3(14.0, PLATFORM_H, 3.4), Vector3(0, PLATFORM_H * 0.5, -20.15), wood)
	WB.box(self, Vector3(12.0, 1.25, 0.5), Vector3(0, 0.625, -18.2), panel)
	WB.box(self, Vector3(12.3, 0.07, 0.95), Vector3(0, 1.28, -18.45), wood)
	WB.box(self, Vector3(12.0, 0.02, 0.6), Vector3(0, 1.32, -18.6), green, false)
	var n := int(j.judges) + int(j.jury)
	var span: float = min(1.15 * (n - 1), 10.4)
	for i in n:
		var x: float = -span * 0.5 + (span / max(n - 1, 1)) * i if n > 1 else 0.0
		var back_h := 1.55 if i == n / 2 else 1.3
		WB.box(self, Vector3(0.7, back_h, 0.12), Vector3(x, PLATFORM_H + 0.45 + back_h * 0.5, BENCH_Z - 0.35), leather, false)
		WB.box(self, Vector3(0.6, 0.1, 0.55), Vector3(x, PLATFORM_H + 0.46, BENCH_Z), leather, false)
		# micro
		WB.cyl(self, 0.006, 0.006, 0.3, Vector3(x + 0.2, 1.47, -18.45), Mats.std("mic", Color(0.05, 0.05, 0.05), 0.3), false)
	# Mur du fond : médaillon RF, devise, horloge
	var gold := Mats.std("gold", Color(0.85, 0.66, 0.32), 0.3, 1.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.82
	tm.rings = 64
	ring.mesh = tm
	ring.material_override = gold
	ring.position = Vector3(0, 4.7, -21.8)
	ring.rotation.x = PI / 2
	add_child(ring)
	WB.label(self, "RF", Vector3(0, 4.7, -21.78), 0.8, Color(0.85, 0.66, 0.32), 0.0, "serif", 700)
	WB.label(self, "LIBERTÉ  ·  ÉGALITÉ  ·  FRATERNITÉ", Vector3(0, 3.55, -21.78), 0.17, Color(0.8, 0.62, 0.32), 0.0, "serif", 600)
	WB.label(self, j.name.to_upper(), Vector3(0, 6.3, -21.78), 0.22, Color(0.3, 0.25, 0.2), 0.0, "serif", 600)
	var clock := WB.cyl(self, 0.32, 0.32, 0.06, Vector3(-5.0, 4.4, -21.78), Mats.std("clockface", Color(0.95, 0.95, 0.92), 0.4))
	clock.rotation.x = PI / 2
	# Draperies bleu-blanc-rouge discrètes
	for i in 3:
		var c: Color = [Color(0.05, 0.12, 0.42), Color(0.9, 0.9, 0.9), Color(0.65, 0.06, 0.1)][i]
		WB.box(self, Vector3(0.5, 3.2, 0.04), Vector3(4.2 + i * 0.5, 4.6, -21.78), Mats.cloth("drape%d" % i, c, 0.8), false)
	# Greffier
	WB.box(self, Vector3(1.6, 1.0, 0.7), Vector3(7.0, 0.5, -17.0), wood)
	WB.box(self, Vector3(0.4, 0.28, 0.03), Vector3(7.0, 1.15, -17.2), Mats.emissive("greffescreen", Color(0.7, 0.8, 0.95), 1.0), false)
	# Parquet (procureur) – estrade latérale
	WB.box(self, Vector3(2.8, PLATFORM_H, 4.0), Vector3(7.5, PLATFORM_H * 0.5, -12.5), wood)
	WB.box(self, Vector3(0.45, 1.15, 3.4), Vector3(6.25, 0.575, -12.5), panel)
	WB.box(self, Vector3(0.85, 0.07, 3.6), Vector3(6.4, 1.2, -12.5), wood)
	WB.box(self, Vector3(0.6, 1.3, 0.12), Vector3(7.85, PLATFORM_H + 1.1, -12.5), leather, false)
	# Barre
	WB.box(self, Vector3(1.2, 1.05, 0.12), Vector3(0, 0.525, -14.2), wood)
	WB.box(self, Vector3(1.3, 0.06, 0.28), Vector3(0, 1.08, -14.2), wood)
	WB.cyl(self, 0.006, 0.006, 0.35, Vector3(0.25, 1.25, -14.25), Mats.std("mic", Color(0.05, 0.05, 0.05), 0.3), false)
	# Banc de la défense & de la partie civile
	WB.box(self, Vector3(3.0, 0.95, 0.55), Vector3(-3.6, 0.475, -13.6), wood)
	WB.box(self, Vector3(3.0, 0.95, 0.55), Vector3(3.6, 0.475, -13.6), wood)
	for x in [-4.4, -3.0, 2.8, 4.2]:
		WB.box(self, Vector3(0.5, 0.45, 0.5), Vector3(x, 0.225, -12.6), leather)
	# Box des prévenus vitré
	if true:
		var glassm := Mats.glass("boxglass", Color(0.8, 0.88, 0.9, 0.1), 0.02)
		WB.box(self, Vector3(3.3, 0.3, 5.2), Vector3(-7.2, 0.15, -12.5), wood)
		WB.box(self, Vector3(0.25, 0.9, 5.2), Vector3(-5.55, 0.75, -12.5), panel)
		WB.box(self, Vector3(0.02, 1.6, 5.2), Vector3(-5.55, 2.0, -12.5), glassm)
		WB.box(self, Vector3(3.3, 0.9, 0.12), Vector3(-7.2, 0.75, -15.05), panel)
		WB.box(self, Vector3(3.3, 1.6, 0.02), Vector3(-7.2, 2.0, -15.05), glassm)
		WB.box(self, Vector3(3.3, 0.9, 0.12), Vector3(-7.2, 0.75, -9.95), panel)
		WB.box(self, Vector3(3.3, 1.6, 0.02), Vector3(-7.2, 2.0, -9.95), glassm)
		WB.box(self, Vector3(0.5, 0.45, 4.6), Vector3(-8.4, 0.525, -12.5), wood)
		WB.label(self, "BOX", Vector3(-5.42, 1.1, -12.5), 0.08, Color(0.85, 0.7, 0.4), PI / 2, "sans", 700)
	# Bancs du public
	for z in [-8.0, -6.4, -4.8, -3.2, -1.6]:
		for side in [-1, 1]:
			WB.box(self, Vector3(5.4, 0.08, 0.45), Vector3(side * 4.1, 0.45, z), wood)
			WB.box(self, Vector3(5.4, 0.55, 0.06), Vector3(side * 4.1, 0.75, z + 0.24), wood, false)
			WB.box(self, Vector3(5.4, 0.45, 0.06), Vector3(side * 4.1, 0.225, z - 0.15), wood, false)
	for sx in [-1, 1]:
		WB.box(self, Vector3(7.2, 1.0, 0.1), Vector3(sx * 4.6, 0.5, -9.6), wood)
	# Lustres
	for p in [Vector3(-4, 5.4, -15), Vector3(4, 5.4, -15), Vector3(-4, 5.4, -5), Vector3(4, 5.4, -5)]:
		WB.cyl(self, 0.01, 0.01, 1.6, p + Vector3(0, 0.8, 0), Mats.std("chain", Color(0.6, 0.5, 0.3), 0.3, 1.0), false)
		WB.cyl(self, 0.45, 0.25, 0.25, p, gold, false)
		for k in 6:
			var a := TAU * k / 6.0
			WB.sphere(self, 0.06, p + Vector3(cos(a) * 0.42, 0.18, sin(a) * 0.42), Mats.emissive("bulb", Color(1.0, 0.85, 0.6), 6.0))
		var l := WB.omni(self, p + Vector3(0, -0.1, 0), Color(1.0, 0.82, 0.6), 1.6, 9.0, false)
		l.light_volumetric_fog_energy = 0.4
	# Soleil par les hautes fenêtres
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 62, 0)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.light_volumetric_fog_energy = 2.4
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	# Extérieur derrière les fenêtres
	WB.box(self, Vector3(0.5, 12, 30), Vector3(16, 6, -10), Mats.concrete(Color(0.8, 0.78, 0.72), "outside"), false)
	# Tapis central
	WB.box(self, Vector3(1.6, 0.012, 7.0), Vector3(0, 0.006, -5.0), Mats.fabric(Color(0.4, 0.08, 0.08), "rug"), false)


func _spawn_people() -> void:
	var gs := GameState
	var n := int(j.judges) + int(j.jury)
	var span: float = min(1.15 * (n - 1), 10.4)
	var center := n / 2
	for i in n:
		var x: float = -span * 0.5 + (span / max(n - 1, 1)) * i if n > 1 else 0.0
		var is_judge := absi(i - center) <= int(j.judges) / 2 if int(j.jury) > 0 else true
		var cfg := {"outfit": "magistrat" if is_judge else "civil", "seed": 100 + i}
		if i == center:
			cfg["female"] = pres_f
			cfg["glasses"] = true
			cfg["hair_style"] = "bun" if pres_f else "short"
			cfg["hair"] = Color(0.55, 0.55, 0.55)
		var h := Human.create("magistrat" if is_judge else "jure", cfg)
		add_child(h)
		h.set_meta("seat", Vector3(x, PLATFORM_H, BENCH_Z))
		h.position = Vector3(-5.8 + i * 0.05, PLATFORM_H, -21.6)
		h.visible = false
		judges.append(h)
		if i == center:
			president = h
	prosecutor = Human.create("procureur", {"outfit": "procureur", "female": proc_f, "seed": 201})
	add_child(prosecutor)
	prosecutor.position = Vector3(7.75, PLATFORM_H, -12.5)
	prosecutor.rotation.y = PI / 2
	prosecutor.set_sit(1.0)
	greffier = Human.create("greffier", {"outfit": "magistrat", "seed": 202})
	add_child(greffier)
	greffier.position = Vector3(7.0, 0, -16.3)
	greffier.rotation.y = 0.0
	greffier.rotation.y = PI
	greffier.set_sit(1.0)
	greffier.desk_pose = 0.8
	if gs.lawyer != "none":
		defense = Human.create("avocat", {"outfit": "avocat", "female": gs.lawyer == "choisi", "hair_style": "bun" if gs.lawyer == "choisi" else "short", "seed": 41})
		add_child(defense)
		defense.position = Vector3(-3.6, 0, -12.6)
		defense.set_sit(1.0)
	if gs.has_victim():
		civil_lawyer = Human.create("avocat", {"outfit": "avocat", "seed": 301})
		add_child(civil_lawyer)
		civil_lawyer.position = Vector3(2.8, 0, -12.6)
		civil_lawyer.set_sit(1.0)
		victim = Human.create("victime", {"outfit": "civil", "seed": 302})
		add_child(victim)
		victim.position = Vector3(4.2, 0, -12.6)
		victim.set_sit(1.0)
	if in_box:
		for p in [Vector3(-8.3, 0.3, -11.0), Vector3(-8.3, 0.3, -14.2)]:
			var e := Human.create("police", {"outfit": "police", "top": Color(0.07, 0.1, 0.19), "pants": Color(0.06, 0.08, 0.15), "seed": 400 + escorts.size()})
			add_child(e)
			e.position = p
			e.rotation.y = -PI / 2
			escorts.append(e)
	# Public
	var slots := []
	for z in [-8.0, -6.4, -4.8, -3.2, -1.6]:
		for side in [-1, 1]:
			for k in 4:
				slots.append(Vector3(side * (1.6 + k * 1.3), 0, z + 0.05))
	slots.shuffle()
	var count := 11
	if gs.asked_family:
		family = Human.create("famille", {"outfit": "civil", "female": true, "hair": Color(0.5, 0.5, 0.5), "hair_style": "bob", "top": Color(0.3, 0.12, 0.2), "seed": 501})
		add_child(family)
		family.position = Vector3(-1.6, 0, -8.0 + 0.05) if in_box else Vector3(-4.2, 0, -8.0 + 0.05)
		family.set_sit(1.0)
	for i in count:
		var p: Vector3 = slots[i]
		if family and p.distance_to(family.position) < 0.8:
			continue
		if not in_box and p.distance_to(_seat_pos) < 0.9:
			continue
		var h2 := Human.create("public", {"outfit": "civil", "seed": 600 + i})
		add_child(h2)
		h2.position = p
		h2.set_sit(1.0)
		public_npcs.append(h2)


func _everyone() -> Array:
	var a: Array = []
	a.append_array(judges)
	a.append_array([prosecutor, greffier, defense, civil_lawyer, victim, family])
	a.append_array(escorts)
	a.append_array(public_npcs)
	return a.filter(func(x): return x != null)


func _all_stand(up: bool) -> void:
	for h in _everyone():
		if h in escorts or h in judges:
			continue
		h.set_sit(0.0 if up else 1.0, randf_range(0.6, 1.1))
	player.set_eye_height(FPSPlayer.EYE_H if up else _seat_eye, 0.9)


func _pres_title() -> String:
	return "Madame la présidente" if pres_f else "Monsieur le président"


func _role_pres() -> String:
	return "Président%s · %s" % ["e" if pres_f else "", j.name]


func _proc_name() -> String:
	if j.short == "assises":
		return "Madame l'avocate générale" if proc_f else "Monsieur l'avocat général"
	return "Madame la procureure" if proc_f else "Monsieur le procureur"


# ═══════════════════════════════════════════════════════════════════════════
func _run() -> void:
	var gs := GameState
	for h in _everyone():
		h.look_target = player.cam
	if gs.outcome_after_gav in ["ci", "instruction"]:
		gs.clock_minutes = floor(gs.clock_minutes / 1440.0) * 1440.0 + (16 * 60 + 40 if gs.outcome_after_gav == "ci" else 9 * 60 + 30)
	else:
		gs.clock_minutes = floor(gs.clock_minutes / 1440.0) * 1440.0 + 14 * 60 + 5
	hud.set_phase("Audience", j.room, "Palais de justice · %s" % j.name)
	Sfx.loop("crowd", -20.0, 2.0)
	Sfx.loop("room", -24.0, 2.0)
	await Transition.chapter("Chapitre IV", "L'audience", "%s · %s" % [j.name, GameState.date_label().capitalize()], 2.0)
	Transition.fade_in(2.0)
	await wait(1.2)
	if in_box:
		await hud.narrate("Le box vitré. Derrière vous, deux policiers. Devant, la salle se remplit. Vous cherchez un visage connu.")
	else:
		await hud.narrate("Vous êtes assis au premier rang du public, convocation pliée dans la poche. Vos mains tremblent.")
	if family:
		await player.look_at_point(family.head_node().global_position, 1.2)
		await hud.narrate("Votre mère est là. Elle vous fait un petit signe, les yeux rouges.")
	await player.look_at_point(Vector3(0, 1.8, -19), 1.2)
	await wait(1.0)
	# Entrée de la cour
	Sfx.play("gavel", -2.0)
	var call := "La Cour !" if j.short in ["assises", "ccd"] else "Le Tribunal !"
	hud.subtitle("Huissier : « %s »" % call, 2.2)
	Sfx.set_loop_volume("crowd", -34.0, 0.8)
	_all_stand(true)
	await wait(1.4)
	for h in judges:
		h.visible = true
		var seat: Vector3 = h.get_meta("seat")
		h.walk_to([Vector3(-5.8, PLATFORM_H, -20.6), Vector3(seat.x, PLATFORM_H, -20.6), seat], 1.4)
		await wait(0.35)
	await wait(4.0)
	for h in judges:
		h.position = h.get_meta("seat")
		h.rotation.y = 0.0
	await hud.say(GameState.ucfirst(_pres_title()), _role_pres(), "Veuillez vous asseoir. L'audience est ouverte.", president)
	for h in judges:
		h.set_sit(1.0, 0.8)
	_all_stand(false)
	await wait(1.0)
	await _trial()


func _stand_player() -> void:
	player.set_eye_height(FPSPlayer.EYE_H, 0.8)
	if not in_box:
		hud.set_objective("")
		player.lock(true)
		await player.auto_walk([Vector3(-0.6, 0, -9.5), Vector3(0, 0, -13.5)], 1.1)
		await player.look_at_point(president.head_node().global_position, 0.8)
		player.lock(true, 80.0)


func _trial() -> void:
	var gs := GameState
	var acc: String = j.accused
	var P := GameState.ucfirst(_pres_title())
	var R := _role_pres()
	await hud.say(P, R, "Nous appelons l'affaire du ministère public contre %s. %s, levez-vous%s." % [gs.full_name(), GameState.ucfirst(acc), " et avancez à la barre" if not in_box else ""], president)
	await _stand_player()
	player.set_dof(true, 9.0)
	var c := await hud.ask(P, R, "Vous êtes bien %s, né%s le %s à %s, demeurant %s ?" % [gs.full_name(), gs.e(), gs.birth_date, gs.birth_place, gs.address],
		["Oui, %s." % _pres_title(), "Oui.", "(Hocher la tête)"], president)
	if c == 0:
		gs.attitude += 1
	elif c == 2:
		await hud.say(P, R, "Répondez à voix haute, pour la greffière.", president)
	if gs.outcome_after_gav == "ci":
		await hud.say(P, R, "Vous comparaissez selon la procédure de comparution immédiate. Vous avez le droit d'être jugé" + gs.e() + " aujourd'hui, ou de demander un délai pour préparer votre défense.", president)
		c = await hud.ask(P, R, "Acceptez-vous d'être jugé%s aujourd'hui ?" % gs.e(),
			["J'accepte d'être jugé%s aujourd'hui." % gs.e(), "Je demande un délai pour préparer ma défense."], president)
		if c == 1:
			gs.accepted_ci = false
			await hud.say(P, R, "Le tribunal renvoie l'affaire à quatre semaines et, sur réquisitions du parquet, vous place en détention provisoire jusqu'à l'audience.", president)
			Sfx.play("gavel", -2.0)
			await Transition.fade_out(1.0)
			gs.detention_provisoire_months += 1
			gs.advance_minutes(28 * 24 * 60)
			await Transition.card("Quatre semaines plus tard", "Maison d'arrêt, puis retour dans le même box.", 2.8)
			if defense:
				gs.lawyer_bond += 1
			await Transition.fade_in(1.2)
	# Rappel des faits
	await hud.say(P, R, "Il vous est reproché %s." % gs.facts_text(), president)
	var arts := []
	for d in gs.infractions():
		arts.append(d.article)
	await hud.say(P, R, "Faits prévus et réprimés par %s." % ", ".join(arts), president)
	if gs.aggravations.size() > 0:
		await hud.say(P, R, "Avec cette circonstance retenue par le parquet : %s." % ", ".join(gs.aggravations).to_lower(), president)
	# Reconnaissance
	c = await hud.ask(P, R, "Reconnaissez-vous les faits ?",
		["Oui, je les reconnais entièrement.", "En partie seulement.", "Non, je les conteste.", "Je ne souhaite pas m'exprimer."], president)
	gs.trial_story = ["aveux", "mixte", "deni", "silence"][c]
	gs.trial_changed_story = gs.gav_story != "" and gs.gav_story != gs.trial_story
	if c == 0:
		gs.admissions += 1
		if gs.gav_story == "deni":
			await hud.say(P, R, "Pourtant, en garde à vue, vous contestiez. Qu'est-ce qui a changé ?", president)
			await hud.ask(P, R, "Le tribunal vous écoute.", ["J'ai eu le temps de réfléchir. J'avais honte.", "Mon avocat m'a conseillé de dire la vérité."], president)
	elif c == 2:
		gs.denials += 1
		if gs.gav_story == "aveux":
			await hud.say(P, R, "En garde à vue, vous avez pourtant reconnu les faits, et votre procès-verbal est signé. Le tribunal en prend note.", president)
			gs.lies += 1
		elif gs.evidence > 0.75:
			await hud.say(P, R, "Le dossier comporte des éléments sérieux. %s" % Dialogues.evidence_line(gs.main_infraction().cat), president)
	elif c == 3:
		gs.silences += 1
		await hud.say(P, R, "C'est votre droit. Le tribunal statuera sur les éléments du dossier.", president)
	# Explication
	if c < 2:
		c = await hud.ask(P, R, "Alors expliquez-nous. Comment en êtes-vous arrivé là ?",
			["Je n'ai pas d'excuse. J'ai fait une erreur et je l'assume.", "J'étais dans une mauvaise passe. L'argent, la famille…", "C'est pas vraiment de ma faute, on m'a poussé.", "Je ne sais pas."], president)
		match c:
			0: gs.attitude += 2
			1: gs.attitude += 1
			2: gs.attitude -= 1
	# Situation
	var sit_txt := {"cdi": "salarié%s en CDI" % gs.e(), "interim": "intérimaire", "etudiant": "étudiant" + gs.e(), "chomage": "sans emploi", "": "sans situation déclarée"}
	await hud.say(P, R, "Votre situation personnelle. Vous avez déclaré être %s." % sit_txt.get(gs.situation, "sans situation déclarée"), president)
	c = await hud.ask(P, R, "Avez-vous des perspectives ? Un logement, un projet ?",
		["J'ai un emploi qui m'attend, et un logement.", "Je veux me soigner, j'ai pris rendez-vous.", "Je vis chez ma mère, je cherche du travail.", "Pas vraiment."], president)
	match c:
		0: gs.attitude += 1
		1: gs.attitude += 1
		3: gs.attitude -= 1
	# Casier
	match gs.record:
		"vierge": await hud.say(P, R, "Votre casier judiciaire ne porte mention d'aucune condamnation.", president)
		"antecedents": await hud.say(P, R, "Votre casier judiciaire porte trois mentions, dont une pour des faits de même nature.", president)
		"recidive": await hud.say(P, R, "Votre casier porte sept mentions. Vous êtes en état de récidive légale : les peines encourues sont doublées.", president)
	# Assesseur
	if int(j.judges) >= 3:
		var asr := judges[max(0, judges.find(president) - 1)]
		var c2 := await hud.ask("Assesseur", "Magistrat du siège", "Une question. Si le tribunal vous laissait repartir ce soir, qu'est-ce qui garantit que vous ne recommencerez pas ?",
			["Je ne veux plus jamais revivre ces dernières heures.", "Je vais être suivi, je l'accepte.", "Rien. Je ne peux rien garantir."], asr)
		if c2 == 1:
			gs.attitude += 1
	# Partie civile
	if civil_lawyer:
		await hud.say("Avocat de la partie civile", "Barreau", "Ma cliente ne dort plus. Elle sursaute au moindre bruit. Nous sollicitons des dommages et intérêts au titre du préjudice moral et matériel.", civil_lawyer)
		c = await hud.ask(P, R, "Avez-vous quelque chose à dire à la partie civile ?",
			["Je vous demande pardon. Sincèrement.", "Je n'ai rien à lui dire.", "Elle exagère."], president)
		match c:
			0:
				gs.attitude += 2
				if victim:
					victim.face_point(player.global_position)
			2:
				gs.attitude -= 2
				Sfx.set_loop_volume("crowd", -18.0, 0.3)
				await wait(1.0)
				Sfx.set_loop_volume("crowd", -34.0, 1.0)
				await hud.say(P, R, "Silence dans la salle !", president)
	# Réquisitions
	Sfx.loop("heart", -26.0, 3.0)
	prosecutor.set_sit(0.0, 0.9)
	await wait(0.8)
	var req := Sentencing.requisitions(gs)
	var pn := GameState.ucfirst(_proc_name())
	await player.look_at_point(prosecutor.head_node().global_position, 1.0)
	await hud.say(pn, "Ministère public", "%s, ce dossier est simple. Les faits sont graves, ils sont établis%s." % [_pres_title(), ", et d'ailleurs reconnus" if gs.admissions > 0 and gs.denials == 0 else ""], prosecutor)
	if gs.record != "vierge":
		await hud.say(pn, "Ministère public", "Et ce n'est pas un premier passage devant la justice. Les avertissements n'ont servi à rien.", prosecutor)
	if gs.attitude < 0:
		await hud.say(pn, "Ministère public", "L'attitude de l'%s, depuis le début de la procédure, dit tout de sa prise de conscience." % acc, prosecutor)
	await hud.say(pn, "Ministère public", "Je requiers [b]%s[/b]." % req.text, prosecutor)
	hud.toast("Réquisitions : %s" % req.text, "Ministère public", UIKit.RED)
	prosecutor.set_sit(1.0, 0.9)
	Sfx.set_loop_volume("heart", -18.0, 1.0)
	player.stress = 0.45
	hud.set_stress(0.25)
	# Plaidoirie
	if defense:
		defense.set_sit(0.0, 0.9)
		await player.look_at_point(defense.head_node().global_position, 1.0)
		var dn := gs.lawyer_name
		var plea := []
		plea.append("%s, je ne vais pas vous dire que %s est %s. Je vais vous dire qui %s est." % [_pres_title(), gs.g("mon client", "ma cliente"), gs.g("un saint", "une sainte"), gs.g("il", "elle")])
		if gs.admissions > 0 and gs.denials == 0:
			plea.append(gs.g("Il", "Elle") + " a reconnu les faits. Dès la garde à vue. Combien de prévenus ont ce courage ?")
		elif gs.denials > 0 and gs.evidence < 0.7:
			plea.append("Ce dossier est fragile. Pas d'aveux, pas d'image nette, des témoignages qui se contredisent. Le doute doit lui profiter.")
		else:
			plea.append(gs.g("Il", "Elle") + " a fait usage de ses droits. Ce n'est pas une faute, c'est la loi.")
		if gs.situation in ["cdi", "interim", "etudiant"]:
			plea.append(gs.g("Il", "Elle") + " a un avenir. Un emploi, une formation. La prison les détruirait en quelques semaines.")
		if gs.record == "vierge":
			plea.append("Son casier est vierge. Vierge ! Une première fois doit être jugée comme une première fois.")
		plea.append("Je vous demande une peine qui lui laisse une chance. Je vous remercie.")
		for line in plea:
			await hud.say(dn, "Défense", line, defense)
		defense.set_sit(1.0, 0.9)
		gs.lawyer_bond += 1 if gs.told_lawyer_truth else 0
	else:
		await hud.say(P, R, "Vous n'êtes pas assisté d'un avocat. Souhaitez-vous ajouter quelque chose pour votre défense ?", president)
	# Dernier mot
	await player.look_at_point(president.head_node().global_position, 0.8)
	c = await hud.ask(P, R, "%s, vous avez la parole en dernier." % GameState.ucfirst(acc),
		["Je regrette profondément. Je ne recommencerai pas.", "Je suis innocent%s. C'est tout ce que j'ai à dire." % gs.e(), "Je demande pardon à la victime.", "Faites ce que vous voulez, de toute façon c'est joué d'avance.", "(Garder le silence)"], president)
	gs.last_word = ["regrets", "innocence", "victime", "provocation", "silence"][c]
	if c == 3:
		Sfx.set_loop_volume("crowd", -18.0, 0.3)
	# Délibéré
	await hud.say(P, R, "Le %s se retire pour délibérer." % ("tribunal" if j.short in ["correctionnel", "police"] else "cour"), president)
	Sfx.play("gavel", -2.0)
	_all_stand(true)
	for h in judges:
		h.set_sit(0.0, 0.6)
	await wait(1.0)
	for h in judges:
		h.walk_to([Vector3(h.position.x, PLATFORM_H, -20.6), Vector3(-5.8, PLATFORM_H, -20.6), Vector3(-5.8, PLATFORM_H, -21.9)], 1.4)
	await wait(2.0)
	_all_stand(false)
	await _deliberation()


func _deliberation() -> void:
	var gs := GameState
	hud.set_phase("Délibéré", "Attente de la décision", j.room)
	Sfx.set_loop_volume("crowd", -22.0, 2.0)
	player.lock(true, 100.0)
	hud.set_objective("Attendez la décision…")
	var hours := randf_range(0.9, 1.6) if j.short in ["correctionnel", "police"] else randf_range(3.0, 5.0)
	var rate: float = GameState.DELIBERE_SECONDS_PER_HOUR if hours < 2.0 else GameState.DELIBERE_SECONDS_PER_HOUR / 3.0
	var said := [false, false, false]
	await run_clock(hours, rate, func(r):
		var e: float = r * hours
		hud.set_timer("Délibéré", "%dh%02d" % [int(e), int(fmod(e, 1.0) * 60.0)], r, UIKit.BLUE)
		hud.set_stress(0.15 + r * 0.35)
		Sfx.set_loop_volume("heart", -20.0 + r * 10.0, 0.1)
		if r > 0.2 and not said[0]:
			said[0] = true
			if defense:
				hud.subtitle("%s (à voix basse) : « Ça peut aller dans les deux sens. Respirez. »" % gs.lawyer_name, 4.0)
			else:
				hud.subtitle("Un policier de l'escorte bâille. Pour lui, c'est une journée comme une autre.", 4.0)
		if r > 0.5 and not said[1]:
			said[1] = true
			if family:
				hud.subtitle("Votre mère murmure quelque chose. Vous ne l'entendez pas, mais vous comprenez.", 4.0)
			else:
				hud.subtitle("Dans le public, quelqu'un consulte son téléphone. Un autre s'endort.", 4.0)
		if r > 0.8 and not said[2]:
			said[2] = true
			hud.subtitle("Une porte grince derrière l'estrade. Votre cœur s'arrête.", 3.0))
	hud.hide_timer()
	hud.set_objective("")
	await _verdict()


func _verdict() -> void:
	var gs := GameState
	var P := GameState.ucfirst(_pres_title())
	var R := _role_pres()
	Sfx.play("gavel", 0.0)
	hud.subtitle("Huissier : « %s »" % ("La Cour !" if j.short in ["assises", "ccd"] else "Le Tribunal !"), 2.0)
	Sfx.set_loop_volume("crowd", -40.0, 0.5)
	_all_stand(true)
	for h in judges:
		var seat: Vector3 = h.get_meta("seat")
		h.walk_to([Vector3(-5.8, PLATFORM_H, -20.6), Vector3(seat.x, PLATFORM_H, -20.6), seat], 1.6)
	await wait(4.5)
	for h in judges:
		h.position = h.get_meta("seat")
		h.rotation.y = 0.0
	await player.look_at_point(president.head_node().global_position, 1.0)
	hud.letterbox(true)
	player.cam.fov = 72.0
	create_tween().tween_property(player.cam, "fov", 52.0, 14.0).set_trans(Tween.TRANS_SINE)
	var v := Sentencing.decide(gs)
	gs.verdict = v
	var who := "tribunal" if j.short in ["correctionnel", "police"] else "cour"
	await hud.say(P, R, "Le %s, statuant publiquement, contradictoirement et en premier ressort, après en avoir délibéré conformément à la loi…" % who, president)
	Sfx.set_loop_volume("heart", -6.0, 0.5)
	hud.set_stress(0.7)
	await wait(1.4)
	if not v.guilty:
		await hud.say(P, R, "…renvoie %s des fins de la poursuite. Vous êtes %s." % [gs.full_name(), ("acquitté" if gs.kind() == "X" else "relaxé") + gs.e()], president)
		Sfx.play("boom", -2.0)
		hud.flash()
	else:
		await hud.say(P, R, "…déclare %s [b]coupable[/b] des faits qui lui sont reprochés." % gs.full_name(), president)
		Sfx.play("boom", -1.0)
		player.shake(0.04)
		await hud.say(P, R, v.detail, president)
		for ex in v.extras:
			await hud.say(P, R, ex + ".", president)
		if v.incarcerated:
			await hud.say(P, R, "Escorte, vous pouvez emmener %s." % gs.g("le condamné", "la condamnée"), president)
			Sfx.play("cuffs", -1.0)
			if family:
				hud.subtitle("Un cri étouffé dans le public. Votre mère.", 3.0)
	Sfx.stop_loop("heart", 2.0)
	hud.set_stress(0.0)
	await hud.say(P, R, "Vous disposez d'un délai de dix jours pour faire appel de cette décision. L'audience est levée.", president)
	Sfx.play("gavel", -2.0)
	await wait(1.0)
	await Transition.fade_out(1.6)
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
