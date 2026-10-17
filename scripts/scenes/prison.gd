extends LevelBase
## Chapitre V : la détention (version simplifiée : une cellule).
## 1 mois = 1 minute. Événements aléatoires, comportement, réductions de peine.

var door: Node3D
var tally: Label3D
var calendar: Label3D
var window_light: SpotLight3D
var sun: DirectionalLight3D
var bed_it: Interactable
var window_it: Interactable
var table_it: Interactable
var door_it: Interactable
var sink_it: Interactable
var lying := false
var guard: Human
var _busy := false
var _months_total := 0.0
var _served := 0.0
var _next_event := 2.0
var _last_year_check := 0
var _letters := 0


func _ready() -> void:
	Transition.set_black()
	setup_environment("prison")
	_build()
	spawn_player(Vector3(1.3, 0, -0.6), PI)
	player.speed = 1.1
	player.lock(true, 90.0)
	var gs := GameState
	if gs.verdict.is_empty():
		gs.verdict = {"to_serve": 8, "incarcerated": true}
	_months_total = float(gs.verdict.get("to_serve", 6))
	gs.prison_total_months = int(_months_total)
	_run()


func _build() -> void:
	# Cellule 2,6 × 3,8 m (≈ 9 m²) — x 0..2.6, z -3.8..0
	var floor_m := Mats.lino(Color(0.48, 0.44, 0.38), Color(0.25, 0.22, 0.18), "cellprison")
	var lower := Mats.wall_paint(Color(0.32, 0.42, 0.36), "prisonlow")
	var upper := Mats.wall_paint(Color(0.86, 0.83, 0.74), "prisonup")
	var ceil := Mats.wall_paint(Color(0.8, 0.78, 0.72), "prisonceil")
	WB.room(self, 0, 2.6, -3.8, 0, 2.7, floor_m, upper, ceil, [
		{"side": "z0", "at": 1.3, "w": 0.7, "h": 1.8, "sill": 1.35},
		{"side": "z1", "at": 1.3, "w": 0.85, "h": 2.0},
	])
	# Soubassement peint (bas des murs)
	for d in [[Vector3(2.3, 1.2, 0.01), Vector3(1.3, 0.6, -3.63)], [Vector3(0.01, 1.2, 3.5), Vector3(0.17, 0.6, -1.9)], [Vector3(0.01, 1.2, 3.5), Vector3(2.43, 0.6, -1.9)]]:
		WB.box(self, d[0], d[1], lower, false)
	# Fenêtre à barreaux + caillebotis
	var bars := Mats.metal(Color(0.18, 0.18, 0.2), 0.5, 0.8, "bars")
	for i in 6:
		WB.box(self, Vector3(0.025, 0.45, 0.025), Vector3(1.0 + i * 0.12, 1.575, -3.72), bars)
	for y in [1.4, 1.75]:
		WB.box(self, Vector3(0.7, 0.03, 0.03), Vector3(1.3, y, -3.72), bars, false)
	WB.box(self, Vector3(0.7, 0.45, 0.02), Vector3(1.3, 1.575, -3.85), Mats.glass("prisonwin", Color(0.85, 0.9, 0.95, 0.15), 0.2), false)
	# Mur d'enceinte au loin
	WB.box(self, Vector3(30, 10, 1), Vector3(1.3, 3, -14), Mats.concrete(Color(0.6, 0.6, 0.58), "enceinte"), false)
	WB.box(self, Vector3(30, 0.4, 0.4), Vector3(1.3, 8.2, -13.6), bars, false)
	WB.box(self, Vector3(30, 0.2, 40), Vector3(1.3, -1.0, -20), Mats.concrete(Color(0.45, 0.45, 0.43), "cour"), false)
	# Porte en acier
	door = WB.door(self, Vector3(0.875, 0, -0.08), 0.85, 2.0, Mats.metal(Color(0.28, 0.34, 0.4), 0.45, 0.7, "pdoor"), true, 0.08, false)
	WB.box(door, Vector3(0.06, 0.03, 0.03), Vector3(0.42, 1.55, -0.05), Mats.std("oeilleton", Color(0.05, 0.05, 0.05), 0.2, 0.8), false)
	WB.box(door, Vector3(0.35, 0.18, 0.02), Vector3(0.42, 1.05, -0.05), Mats.metal(Color(0.22, 0.27, 0.32), 0.5, 0.7, "passeplat"), false)
	# Lit métallique
	var frame := Mats.metal(Color(0.3, 0.32, 0.35), 0.45, 0.7, "bedframe")
	WB.box(self, Vector3(0.8, 0.05, 1.95), Vector3(2.1, 0.42, -2.6), frame)
	for x in [1.73, 2.47]:
		for z in [-1.65, -3.55]:
			WB.box(self, Vector3(0.04, 0.42, 0.04), Vector3(x, 0.21, z), frame, false)
	WB.box(self, Vector3(0.76, 0.12, 1.9), Vector3(2.1, 0.5, -2.6), Mats.fabric(Color(0.32, 0.38, 0.5), "mattress"), false)
	WB.box(self, Vector3(0.78, 0.04, 1.3), Vector3(2.1, 0.58, -2.3), Mats.fabric(Color(0.4, 0.4, 0.38), "blanket"), false)
	WB.box(self, Vector3(0.5, 0.1, 0.32), Vector3(2.1, 0.61, -3.35), Mats.fabric(Color(0.85, 0.85, 0.82), "pillow"), false)
	# Table + chaise + étagère
	WB.table(self, Vector3(0.5, 0, -2.4), Vector3(0.6, 0.72, 0.9), Mats.std("formica2", Color(0.7, 0.66, 0.55), 0.4), frame)
	WB.chair(self, Vector3(0.9, 0, -2.4), PI / 2, Mats.std("plasticg", Color(0.2, 0.35, 0.3), 0.5), frame)
	WB.box(self, Vector3(0.3, 0.03, 0.9), Vector3(0.32, 1.7, -2.4), Mats.std("shelf", Color(0.7, 0.66, 0.55), 0.5))
	for i in 4:
		WB.box(self, Vector3(0.18, 0.22 + randf() * 0.06, 0.04), Vector3(0.3, 1.83, -2.1 - i * 0.06), Mats.std("book%d" % i, Color.from_hsv(randf(), 0.4, 0.4), 0.7), false)
	WB.box(self, Vector3(0.08, 0.12, 0.08), Vector3(0.45, 0.8, -2.65), Mats.std("cup", Color(0.9, 0.9, 0.88), 0.3), false)
	# Petit téléviseur
	WB.box(self, Vector3(0.4, 0.28, 0.25), Vector3(0.35, 2.05, -3.35), Mats.std("tv", Color(0.05, 0.05, 0.05), 0.3))
	# Sanitaires inox derrière un muret
	var inox := Mats.metal(Color(0.75, 0.76, 0.78), 0.2, 1.0, "inox")
	WB.box(self, Vector3(0.06, 1.1, 0.9), Vector3(0.95, 0.55, -0.55), Mats.wall_paint(Color(0.86, 0.83, 0.74), "prisonup"))
	WB.box(self, Vector3(0.45, 0.4, 0.5), Vector3(0.4, 0.2, -0.6), inox)
	WB.box(self, Vector3(0.38, 0.05, 0.3), Vector3(0.4, 0.85, -1.2), inox)
	# Plafonnier
	var l := WB.ceiling_light(self, Vector3(1.3, 2.7, -1.9), Vector2(0.5, 0.25), Color(1.0, 0.95, 0.85), 1.0, 4.0, true)
	l.light_volumetric_fog_energy = 0.3
	# Lumière du jour
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 10, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.light_volumetric_fog_energy = 3.0
	add_child(sun)
	# Marques et calendrier
	tally = WB.label(self, "", Vector3(2.585, 1.5, -1.0), 0.05, Color(0.25, 0.22, 0.2, 0.9), -PI / 2, "mono", 400)
	tally.width = 900
	tally.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	WB.box(self, Vector3(0.32, 0.42, 0.01), Vector3(0.35, 1.35, -3.64), Mats.std("calpaper", Color(0.95, 0.94, 0.9), 0.8), false)
	calendar = WB.label(self, "", Vector3(0.35, 1.35, -3.63), 0.04, Color(0.15, 0.15, 0.18), 0.0, "sans", 700)
	WB.label(self, "N° d'écrou 26-%04d" % (randi() % 9999), Vector3(1.3, 2.25, -0.17), 0.05, Color(0.2, 0.2, 0.22), PI, "mono", 500)
	# Interactions
	bed_it = Interactable.make(self, Vector3(2.1, 0.6, -2.6), Vector3(0.8, 0.4, 1.9), "S'allonger")
	bed_it.used.connect(_toggle_bed)
	window_it = Interactable.make(self, Vector3(1.3, 1.6, -3.6), Vector3(0.8, 0.6, 0.2), "Regarder dehors")
	window_it.used.connect(_look_window)
	table_it = Interactable.make(self, Vector3(0.5, 0.8, -2.4), Vector3(0.6, 0.2, 0.9), "Écrire une lettre")
	table_it.used.connect(_write_letter)
	door_it = Interactable.make(self, Vector3(1.3, 1.2, -0.12), Vector3(0.85, 1.8, 0.15), "Appeler le surveillant")
	door_it.used.connect(_call_guard)
	sink_it = Interactable.make(self, Vector3(0.4, 0.9, -1.2), Vector3(0.4, 0.2, 0.35), "Se passer de l'eau sur le visage")
	sink_it.used.connect(func():
		Sfx.play("slide", -14.0, 2.0)
		hud.subtitle("L'eau est tiède. Le miroir en inox vous renvoie un visage flou.", 3.0))
	for it in [bed_it, window_it, table_it, door_it, sink_it]:
		it.enabled = false


func _run() -> void:
	var gs := GameState
	guard = Human.create("surveillant", {"outfit": "surveillant", "top": Color(0.1, 0.13, 0.25), "pants": Color(0.08, 0.1, 0.18), "seed": 700})
	add_child(guard)
	guard.position = Vector3(1.3, 0, 0.9)
	guard.rotation.y = 0.0
	guard.look_target = player.cam
	hud.set_phase("Détention", "Maison d'arrêt", "Quartier arrivants · Cellule 214")
	Sfx.loop("room", -20.0, 2.0)
	await Transition.chapter("Chapitre V", "La détention", "1 mois = 1 minute", 2.0)
	door.rotation.y = -PI * 0.55
	Transition.fade_in(1.6)
	await wait(1.0)
	await player.look_at_point(guard.head_node().global_position, 0.8)
	await hud.say("Surveillant", "Administration pénitentiaire", "Voilà. Cellule 214. Le paquetage arrivant est sur le lit : draps, kit d'hygiène, un peu de vaisselle.", guard)
	await hud.say("Surveillant", "Administration pénitentiaire", "Promenade le matin, douches trois fois par semaine. Pour le reste, vous remplirez des requêtes. On se reverra.", guard)
	var tw := create_tween()
	tw.tween_property(door, "rotation:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	await tw.finished
	Sfx.play("door", 2.0, 0.85)
	await wait(0.25)
	Sfx.play("lock", 0.0, 0.8)
	player.shake(0.03)
	guard.visible = false
	await wait(1.2)
	await hud.narrate("Le bruit de la serrure. Vous l'entendrez des milliers de fois. La première, on ne l'oublie pas.")
	player.lock(false)
	for it in [bed_it, window_it, table_it, door_it, sink_it]:
		it.enabled = true
	hud.set_objective("Purgez votre peine. Votre conduite compte.")
	await _serve()


func _serve() -> void:
	var gs := GameState
	var rate := GameState.PRISON_SECONDS_PER_MONTH
	while _served < _months_total:
		await get_tree().process_frame
		if _busy:
			continue
		var dt := get_process_delta_time() * Devtools.time_mult
		var dm := dt / rate * (2.0 if lying else 1.0)
		_served += dm
		gs.prison_months_served = _served
		gs.advance_minutes(dm * 30.0 * 24.0 * 60.0)
		_update_hud()
		if _served >= _next_event:
			_next_event = _served + randf_range(1.5, 3.5)
			await _random_event()
		var yr := int(_served / 12.0)
		if yr > _last_year_check:
			_last_year_check = yr
			await _sentence_review()
		if not gs.released_early and _months_total >= 24 and _served >= _months_total * 0.5 and _served < _months_total * 0.5 + 0.2:
			await _parole_hearing()
	await _release()


func _update_hud() -> void:
	var gs := GameState
	var m := int(_served)
	var left: float = max(_months_total - _served, 0.0)
	hud.set_timer("Détention", "Mois %d / %d" % [m + 1, int(ceil(_months_total))], _served / max(_months_total, 0.01), UIKit.BLUE)
	var days := int(_served * 30.0)
	var t := ""
	for i in days / 7:
		t += "||||| " if i % 4 == 3 else "|||| "
	tally.text = t
	calendar.text = gs.month_year_label(0).to_upper()
	var day := fmod(_served * 30.0, 1.0)
	sun.light_energy = clamp(sin(day * PI) * 2.6, 0.05, 2.6)
	sun.rotation_degrees = Vector3(-15 - sin(day * PI) * 35.0, lerp(-40.0, 40.0, day), 0)
	hud.set_objective("Libération prévue : %s" % gs.month_year_label(int(ceil(left))))


func _toggle_bed() -> void:
	lying = not lying
	if lying:
		player.can_move = false
		player.set_eye_height(0.75)
		bed_it.prompt = "Se lever"
		hud.toast("Le temps passe deux fois plus vite allongé.", "Repos", UIKit.TEXT_DIM)
	else:
		player.can_move = true
		player.set_eye_height(FPSPlayer.EYE_H)
		bed_it.prompt = "S'allonger"
	hud.set_prompt(bed_it.prompt)


func _look_window() -> void:
	var lines := ["Un mur gris, des barbelés. Au-dessus, un rectangle de ciel.", "Des pigeons sur les filins anti-hélicoptère.",
		"Quelqu'un crie un prénom depuis une autre fenêtre. Personne ne répond.", "La cour de promenade est vide. Le béton brille sous la pluie."]
	hud.subtitle(lines[randi() % lines.size()], 3.5)


func _write_letter() -> void:
	if _busy:
		return
	_busy = true
	var c := await hud.ask("", "", "[i]Une feuille, un stylo. À qui écrire ?[/i]",
		["À ma famille.", "À mon avocat, pour préparer la suite.", "À la victime, pour m'excuser.", "Ranger la feuille."])
	match c:
		0:
			_letters += 1
			GameState.conduct += 1
			hud.toast("Lettre envoyée à votre famille", "Courrier", UIKit.GREEN)
		1:
			GameState.conduct += 1
			hud.toast("Courrier adressé à votre avocat", "Courrier", UIKit.GREEN)
		2:
			GameState.conduct += 2
			hud.toast("Lettre d'excuses transmise via le SPIP", "Courrier", UIKit.GREEN)
	_busy = false


func _call_guard() -> void:
	Sfx.play("door", -10.0, 1.5)
	hud.subtitle(["« Surveillant ! »  …  « Quoi ? »", "Personne ne vient.", "« C'est pas l'heure. Remplissez une requête. »"][randi() % 3], 3.0)


func _random_event() -> void:
	var gs := GameState
	_busy = true
	var roll := randi() % 6
	match roll:
		0:
			if gs.asked_family or _letters > 0:
				Sfx.play("lock", -8.0, 1.4)
				hud.toast("Une lettre de votre mère : « On pense à toi tous les jours. Tiens bon. »", "Courrier", UIKit.ACCENT)
				gs.family_contact = true
			else:
				hud.toast("Pas de courrier aujourd'hui. Ni hier.", "Courrier", UIKit.TEXT_DIM)
		1:
			Sfx.play("lock", -2.0)
			Sfx.play("door", -4.0)
			var c := await hud.ask("Surveillant", "Administration pénitentiaire", "Fouille de cellule ! Face au mur, mains visibles.",
				["(Obéir)", "Encore ? Vous l'avez faite la semaine dernière !", "(Refuser de bouger)"])
			if c == 0:
				gs.conduct += 1
			elif c == 2:
				gs.conduct -= 2
				hud.toast("Compte rendu d'incident rédigé", "Discipline", UIKit.RED)
		2:
			var c2 := await hud.ask("", "", "[i]Une proposition de travail aux ateliers : conditionnement, 5 heures par jour, quelques euros.[/i]",
				["Accepter.", "Refuser."])
			if c2 == 0:
				gs.conduct += 2
				hud.toast("Classé aux ateliers", "Travail pénitentiaire", UIKit.GREEN)
		3:
			hud.subtitle("Bruits de bagarre dans la coursive. Des cris, des pas qui courent, une alarme.", 4.0)
			Sfx.play("siren", -16.0)
			await wait(1.0)
			var c3 := await hud.ask("", "", "[i]À la promenade, un codétenu vous demande de « garder » un paquet pour lui.[/i]",
				["Refuser.", "Accepter, pour ne pas avoir d'ennuis."])
			if c3 == 1:
				if randf() < 0.5:
					gs.conduct -= 3
					hud.toast("Objet illicite découvert en cellule — 10 jours de quartier disciplinaire", "Discipline", UIKit.RED)
				else:
					hud.toast("Personne n'a rien vu. Cette fois.", "Promenade", UIKit.TEXT_DIM)
			else:
				gs.conduct += 1
		4:
			var c4 := await hud.ask("", "", "[i]Le SPIP propose une formation qualifiante (CAP) et un suivi addictologie.[/i]",
				["M'inscrire.", "Non merci."])
			if c4 == 0:
				gs.conduct += 2
				hud.toast("Inscrit en formation", "Réinsertion", UIKit.GREEN)
		5:
			if gs.asked_family:
				hud.toast("Parloir : 45 minutes derrière une table. Elle a apporté du linge propre.", "Parloir", UIKit.ACCENT)
				gs.conduct += 1
			else:
				hud.toast("Jour de parloir. Votre nom n'est pas appelé.", "Parloir", UIKit.TEXT_DIM)
	_busy = false


func _sentence_review() -> void:
	var gs := GameState
	_busy = true
	var red: int = clamp(1 + gs.conduct, 0, 6)
	if red > 0:
		gs.reductions_months += red
		_months_total = max(_months_total - red, _served + 0.5)
		hud.toast("Le juge de l'application des peines vous accorde %d mois de réduction de peine." % red, "Commission d'application des peines", UIKit.GREEN)
	else:
		hud.toast("Aucune réduction de peine accordée cette année (comportement).", "Commission d'application des peines", UIKit.RED)
	_busy = false


func _parole_hearing() -> void:
	var gs := GameState
	_busy = true
	gs.released_early = true
	await hud.say("Juge de l'application des peines", "Débat contradictoire", "Vous avez effectué la moitié de votre peine. Vous sollicitez une libération conditionnelle. Quel est votre projet ?")
	var c := await hud.ask("Juge de l'application des peines", "JAP", "Je vous écoute.",
		["Une promesse d'embauche et un hébergement chez ma famille.", "Je n'ai rien de concret, mais je veux sortir.", "Je préfère aller au bout de ma peine."])
	if c == 0 and gs.conduct >= 1:
		hud.toast("Libération conditionnelle accordée", "Jugement du JAP", UIKit.GREEN)
		_months_total = _served + 0.5
	elif c == 2:
		hud.toast("Demande retirée", "JAP", UIKit.TEXT_DIM)
	else:
		hud.toast("Libération conditionnelle refusée : projet de sortie insuffisant", "Jugement du JAP", UIKit.RED)
	_busy = false


func _release() -> void:
	hud.hide_timer()
	hud.set_objective("")
	if lying:
		_toggle_bed()
	for it in [bed_it, window_it, table_it, door_it, sink_it]:
		it.enabled = false
	Sfx.play("lock", 0.0)
	await wait(0.6)
	guard.visible = true
	var tw := create_tween()
	tw.tween_property(door, "rotation:y", -PI * 0.55, 1.0)
	await tw.finished
	player.lock(true, 90.0)
	await player.look_at_point(guard.head_node().global_position, 0.8)
	await hud.say("Surveillant", "Administration pénitentiaire", "%s. Prenez vos affaires. Vous sortez aujourd'hui." % GameState.player_last.to_upper(), guard)
	await hud.narrate("Vous ne savez pas quoi emporter. Vous ne savez plus vraiment qui vous attend.")
	await Transition.fade_out(1.6)
	get_tree().change_scene_to_file("res://scenes/ending.tscn")
