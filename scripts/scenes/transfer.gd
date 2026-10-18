extends LevelBase
## Transfert en fourgon cellulaire vers le palais de justice :
## cellule individuelle exiguë, lumières de la ville qui défilent, roulis.

var _street_lights: Array[OmniLight3D] = []
var _van: Node3D
var _t := 0.0
var _driving := true


func _ready() -> void:
	Transition.set_black()
	setup_environment("van")
	_build()
	spawn_player(Vector3(0, 0.0, 0), 0.0)
	player.lock(true, 75.0)
	player.set_eye_height(1.18, 0.0)
	player.set_seated(true)
	hud.show_clock(true)
	_run()


func _build() -> void:
	_van = Node3D.new()
	add_child(_van)
	var metal := Mats.metal(Color(0.62, 0.64, 0.66), 0.45, 0.7, "vanmetal")
	var dark := Mats.metal(Color(0.2, 0.21, 0.23), 0.5, 0.6, "vandark")
	# Cellule individuelle (0,8 × 1,1 m)
	WB.box(_van, Vector3(1.0, 0.1, 1.4), Vector3(0, -0.05, -0.1), Mats.std("vanfloor", Color(0.1, 0.1, 0.1), 0.7))
	WB.box(_van, Vector3(1.0, 0.1, 1.4), Vector3(0, 1.85, -0.1), metal)
	WB.box(_van, Vector3(0.05, 1.9, 1.4), Vector3(-0.5, 0.9, -0.1), metal)
	WB.box(_van, Vector3(0.05, 1.9, 1.4), Vector3(0.5, 0.9, -0.1), metal)
	WB.box(_van, Vector3(1.0, 1.9, 0.05), Vector3(0, 0.9, 0.55), metal)
	# Porte avant avec grille
	WB.box(_van, Vector3(1.0, 0.9, 0.05), Vector3(0, 0.45, -0.8), dark)
	WB.box(_van, Vector3(1.0, 0.5, 0.05), Vector3(0, 1.65, -0.8), dark)
	for i in 7:
		WB.box(_van, Vector3(0.015, 0.5, 0.015), Vector3(-0.45 + i * 0.15, 1.15, -0.8), dark, false)
	for i in 4:
		WB.box(_van, Vector3(1.0, 0.015, 0.015), Vector3(0, 0.92 + i * 0.13, -0.8), dark, false)
	# Banc
	WB.box(_van, Vector3(0.9, 0.06, 0.45), Vector3(0, 0.45, 0.28), Mats.std("vanseat", Color(0.25, 0.25, 0.27), 0.5))
	# Petite vitre dépolie (côté gauche)
	WB.box(_van, Vector3(0.06, 0.2, 0.5), Vector3(-0.5, 1.45, -0.1), Mats.glass("frosted", Color(0.8, 0.85, 0.9, 0.35), 0.5), false)
	# Couloir central du fourgon visible derrière la grille
	WB.box(_van, Vector3(1.2, 1.9, 0.05), Vector3(0, 0.9, -1.9), metal)
	WB.box(_van, Vector3(0.05, 1.9, 1.2), Vector3(-0.6, 0.9, -1.3), metal)
	WB.box(_van, Vector3(0.05, 1.9, 1.2), Vector3(0.6, 0.9, -1.3), metal)
	var l := WB.ceiling_light(_van, Vector3(0, 1.84, -1.3), Vector2(0.4, 0.15), Color(0.8, 0.9, 1.0), 0.6, 3.0, true)
	l.light_volumetric_fog_energy = 1.5
	var esc := Human.create("police", {"outfit": "police", "top": Color(0.07, 0.1, 0.19), "pants": Color(0.06, 0.08, 0.15), "seed": 51})
	_van.add_child(esc)
	esc.position = Vector3(0.25, 0, -1.55)
	esc.rotation.y = PI / 2
	esc.set_sit(1.0)
	esc.look_target = null
	# Lumières de rue qui défilent (vues à travers la vitre)
	for i in 4:
		var o := WB.omni(self, Vector3(-1.4, 1.6, -6.0 + i * 4.0), Color(1.0, 0.65, 0.3), 3.0, 3.5)
		o.light_volumetric_fog_energy = 2.0
		_street_lights.append(o)


func _process(delta: float) -> void:
	_t += delta
	if _driving:
		for o in _street_lights:
			o.position.z += delta * 9.0
			if o.position.z > 6.0:
				o.position.z = -10.0
				o.light_color = [Color(1.0, 0.65, 0.3), Color(0.9, 0.95, 1.0), Color(1.0, 0.2, 0.15)][randi() % 3]
		_van.rotation.z = sin(_t * 1.3) * 0.012 + sin(_t * 3.1) * 0.004
		_van.rotation.x = sin(_t * 0.9) * 0.006
		if player:
			player.head.position.y += sin(_t * 17.0) * 0.0015


func _run() -> void:
	var gs := GameState
	hud.set_phase("Transfert", "Fourgon cellulaire", "Escorte vers le palais de justice")
	Sfx.loop("van", -8.0, 1.0)
	if gs.outcome_after_gav == "instruction":
		await Transition.chapter("Chapitre III", "L'extraction", "Maison d'arrêt → Palais de justice", 1.8)
	else:
		await Transition.chapter("Chapitre III", "Le déferrement", "Hôtel de police → Palais de justice", 1.8)
	Transition.fade_in(1.6)
	await wait(2.5)
	await hud.narrate("Une boîte de métal à peine plus large que vos épaules. Les virages vous projettent contre la paroi.")
	await skip_time(12.0, 4.0)
	await hud.narrate("Par la vitre dépolie, la ville défile en taches de lumière. Quelqu'un, dehors, vit une journée normale.")
	await skip_time(15.0, 4.0)
	await hud.say("Escorte", "Police nationale", "On arrive. Vous restez assis jusqu'à ce qu'on vienne vous chercher.")
	_driving = false
	Sfx.stop_loop("van", 2.0)
	await wait(2.0)
	Sfx.play("door", -4.0, 0.9)
	await wait(1.0)
	await Transition.fade_out(1.0)
	gs.advance_minutes(150.0)
	await Transition.card("Les geôles du palais", "Trois heures d'attente sous terre, avant d'être appelé à l'audience.", 2.6)
	get_tree().change_scene_to_file("res://scenes/tribunal.tscn")
