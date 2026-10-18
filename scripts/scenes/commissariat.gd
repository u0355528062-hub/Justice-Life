extends LevelBase
## Chapitre I & II : arrivée au commissariat, notification des droits, fouille,
## signalisation, cellule de garde à vue (1 h = 3 s), entretien avocat,
## interrogatoires, décision du parquet.

const OPJ_NAME := "Lieutenant Duval"
const AGENT_NAME := "Brigadier Leroy"

var opj: Human
var agent: Human
var accueil: Human
var lawyer_npc: Human
var neighbor: Human
var doctor: Human
var glass_l: Node3D
var glass_r: Node3D
var lobby_door: Node3D
var cell_door: Node3D
var cell_light: SpotLight3D
var flicker_light: SpotLight3D
var siren_lights: Array[OmniLight3D] = []
var bench_it: Interactable
var door_it: Interactable
var sitting := false
var _t := 0.0

# Repères
const CELL_C := Vector3(7.6, 0, -16.5)
const CELL_DOOR_Z := -15.65
const OFFICE_PLAYER := Vector3(0, 0, -10.75)
const OFFICE_OPJ := Vector3(0, 0, -13.25)


func _ready() -> void:
	Transition.set_black()
	setup_environment("police_night")
	_build_exterior()
	_build_lobby()
	_build_corridor_and_cells()
	_build_office()
	_build_lawyer_room()
	_spawn_npcs()
	spawn_player(Vector3(0, 0, 8.6), 0.0)
	bench_it = Interactable.make(self, CELL_C + Vector3(1.2, 0.35, 0), Vector3(0.7, 0.6, 2.6), "S'asseoir sur le banc")
	bench_it.enabled = false
	bench_it.used.connect(_toggle_sit)
	door_it = Interactable.make(self, Vector3(6.0, 1.2, CELL_DOOR_Z), Vector3(0.3, 1.8, 0.9), "Frapper à la porte")
	door_it.enabled = false
	door_it.used.connect(_knock)
	_run()


# ═══════════════════════════════════════════════════════════════════════════
#  CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════
func _build_exterior() -> void:
	var ext := Node3D.new()
	add_child(ext)
	WB.box(ext, Vector3(40, 0.2, 18), Vector3(0, -0.12, 12), Mats.asphalt(0.85))
	WB.box(ext, Vector3(40, 0.2, 3.4), Vector3(0, -0.1, 1.7), Mats.concrete(Color(0.42, 0.42, 0.42), "sidewalk"))
	WB.box(ext, Vector3(40, 0.06, 0.25), Vector3(0, -0.02, 3.45), Mats.concrete(Color(0.6, 0.6, 0.58), "curb"), false)
	# Façade
	var facade := Mats.concrete(Color(0.72, 0.7, 0.66), "facade")
	WB.box(ext, Vector3(9.0, 8.0, 0.4), Vector3(-5.6, 4.0, 0.2), facade)
	WB.box(ext, Vector3(9.0, 8.0, 0.4), Vector3(5.6, 4.0, 0.2), facade)
	WB.box(ext, Vector3(2.2, 5.4, 0.4), Vector3(0, 5.3, 0.2), facade)
	# Auvent + enseigne
	WB.box(ext, Vector3(5.0, 0.18, 1.8), Vector3(0, 3.0, 1.1), Mats.metal(Color(0.15, 0.16, 0.18), 0.4, 0.6, "auvent"))
	var sign_bg := WB.box(ext, Vector3(4.4, 0.55, 0.1), Vector3(0, 3.45, 0.47), Mats.std("signbg", Color(0.04, 0.08, 0.2), 0.3), false)
	sign_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WB.label(ext, "HÔTEL DE POLICE", Vector3(0, 3.46, 0.53), 0.3, Color(0.9, 0.95, 1.0), 0.0, "sans", 800, true)
	var sl := WB.omni(ext, Vector3(0, 3.4, 1.4), Color(0.5, 0.65, 1.0), 1.5, 4.0)
	sl.light_volumetric_fog_energy = 1.5
	WB.label(ext, "POLICE NATIONALE", Vector3(-5.6, 5.8, 0.42), 0.38, Color(0.95, 0.95, 0.95), 0.0, "sans", 900)
	WB.label(ext, "LIBERTÉ · ÉGALITÉ · FRATERNITÉ", Vector3(-5.6, 5.3, 0.42), 0.14, Color(0.85, 0.85, 0.85), 0.0, "sans", 600)
	# Drapeau
	WB.cyl(ext, 0.03, 0.03, 3.0, Vector3(3.5, 5.2, 0.9), Mats.std("pole", Color(0.8, 0.8, 0.8), 0.3, 1.0))
	var cols := [Color(0.0, 0.14, 0.58), Color(0.95, 0.95, 0.95), Color(0.8, 0.07, 0.13)]
	for i in 3:
		WB.box(ext, Vector3(0.4, 0.8, 0.02), Vector3(3.73 + i * 0.4, 6.2, 0.9), Mats.cloth("flag%d" % i, cols[i], 0.8), false)
	# Fenêtres éclairées de la façade
	for x in [-8.0, -5.5, -3.0, 3.0, 5.5, 8.0]:
		for y in [1.6, 4.4]:
			if absf(x) < 2.5 and y < 3:
				continue
			var lit := randf() < 0.55
			var m := Mats.emissive("win_lit", Color(1.0, 0.86, 0.62), 1.6) if lit else Mats.std("win_dark", Color(0.03, 0.04, 0.06), 0.1, 0.3)
			WB.box(ext, Vector3(1.4, 1.3, 0.05), Vector3(x, y, 0.42), m, false)
	# Porte vitrée coulissante
	glass_l = Node3D.new()
	glass_r = Node3D.new()
	ext.add_child(glass_l)
	ext.add_child(glass_r)
	var frame := Mats.metal(Color(0.25, 0.26, 0.28), 0.4, 0.8, "doorframe")
	for pair in [[glass_l, -0.55], [glass_r, 0.55]]:
		var n: Node3D = pair[0]
		n.position = Vector3(pair[1], 0, 0.2)
		WB.box(n, Vector3(1.1, 2.6, 0.03), Vector3(0, 1.3, 0), Mats.glass("glassdoor", Color(0.7, 0.8, 0.85, 0.18)), true)
		WB.box(n, Vector3(1.1, 0.06, 0.06), Vector3(0, 2.6, 0), frame, false)
		WB.box(n, Vector3(1.1, 0.06, 0.06), Vector3(0, 0.03, 0), frame, false)
	WB.label(ext, "ACCUEIL DU PUBLIC 24h/24", Vector3(-1.6, 2.0, 0.42), 0.09, Color(1, 1, 1, 0.8), 0.0, "sans", 600)
	# Voiture de police
	_build_police_car(ext, Vector3(-3.2, 0, 7.4), 0.25)
	# Lampadaire
	WB.cyl(ext, 0.07, 0.09, 6.5, Vector3(5.5, 3.25, 4.0), Mats.metal(Color(0.2, 0.2, 0.22), 0.5, 0.7, "lamp"))
	WB.box(ext, Vector3(0.9, 0.12, 0.3), Vector3(5.1, 6.5, 4.0), Mats.metal(Color(0.2, 0.2, 0.22), 0.5, 0.7, "lamp"), false)
	var sod := SpotLight3D.new()
	sod.position = Vector3(4.8, 6.4, 4.0)
	sod.rotation_degrees = Vector3(-90, 0, 0)
	sod.light_color = Color(1.0, 0.68, 0.35)
	sod.light_energy = 6.0
	sod.spot_range = 12.0
	sod.spot_angle = 55.0
	sod.shadow_enabled = true
	sod.light_volumetric_fog_energy = 2.5
	ext.add_child(sod)
	# Bâtiments en face (silhouettes)
	for i in 6:
		var h := randf_range(8, 16)
		WB.box(ext, Vector3(6.5, h, 4), Vector3(-16 + i * 6.6, h * 0.5, 22), Mats.concrete(Color(0.18, 0.18, 0.2), "far"), false)
		for k in 6:
			if randf() < 0.35:
				WB.box(ext, Vector3(0.9, 1.1, 0.05), Vector3(-18 + i * 6.6 + randf_range(0, 4), randf_range(2, h - 1), 19.95),
					Mats.emissive("farwin", Color(1.0, 0.8, 0.55), 1.2), false)
	# Limites invisibles
	WB.blocker(ext, Vector3(0.4, 4, 14), Vector3(-6, 2, 7))
	WB.blocker(ext, Vector3(0.4, 4, 14), Vector3(6.5, 2, 7))
	WB.blocker(ext, Vector3(14, 4, 0.4), Vector3(0, 2, 11.5))


func _build_police_car(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = yaw
	parent.add_child(car)
	var body := Mats.std("carbody", Color(0.9, 0.9, 0.92), 0.25, 0.3)
	var blue := Mats.std("carblue", Color(0.05, 0.12, 0.45), 0.3, 0.3)
	var glassm := Mats.std("carglass", Color(0.03, 0.04, 0.05), 0.05, 0.5)
	var tire := Mats.std("tire", Color(0.03, 0.03, 0.03), 0.8)
	WB.box(car, Vector3(1.8, 0.65, 4.4), Vector3(0, 0.62, 0), body)
	WB.box(car, Vector3(1.82, 0.12, 4.42), Vector3(0, 0.55, 0), blue, false)
	WB.box(car, Vector3(1.6, 0.55, 2.2), Vector3(0, 1.2, 0.2), glassm, false)
	WB.box(car, Vector3(1.62, 0.06, 2.0), Vector3(0, 1.5, 0.2), body, false)
	WB.label(car, "POLICE", Vector3(0.92, 0.7, 0.2), 0.32, Color(0.05, 0.12, 0.45), PI / 2, "sans", 900)
	WB.label(car, "POLICE", Vector3(-0.92, 0.7, 0.2), 0.32, Color(0.05, 0.12, 0.45), -PI / 2, "sans", 900)
	for x in [-0.82, 0.82]:
		for z in [-1.4, 1.4]:
			var w := WB.cyl(car, 0.33, 0.33, 0.24, Vector3(x, 0.33, z), tire)
			w.rotation.z = PI / 2
	# Phares / feux
	for x in [-0.6, 0.6]:
		WB.box(car, Vector3(0.35, 0.12, 0.05), Vector3(x, 0.78, -2.2), Mats.emissive("headl", Color(1, 0.97, 0.9), 6.0), false)
		WB.box(car, Vector3(0.3, 0.12, 0.05), Vector3(x, 0.78, 2.2), Mats.emissive("taill", Color(1, 0.05, 0.03), 3.0), false)
	# Rampe gyrophare
	WB.box(car, Vector3(1.2, 0.1, 0.25), Vector3(0, 1.58, 0.0), Mats.std("bar", Color(0.1, 0.1, 0.12), 0.3), false)
	for x in [-0.4, 0.4]:
		WB.box(car, Vector3(0.38, 0.1, 0.22), Vector3(x, 1.64, 0.0), Mats.emissive("gyro", Color(0.15, 0.35, 1.0), 8.0), false)
		var l := WB.omni(car, Vector3(x, 1.9, 0.0), Color(0.12, 0.3, 1.0), 6.0, 14.0, false)
		l.light_volumetric_fog_energy = 4.0
		siren_lights.append(l)
	var hl := SpotLight3D.new()
	hl.position = Vector3(0, 0.8, -2.3)
	hl.light_color = Color(1, 0.96, 0.88)
	hl.light_energy = 4.0
	hl.spot_range = 16
	hl.spot_angle = 30
	hl.light_volumetric_fog_energy = 2.0
	car.add_child(hl)


func _build_lobby() -> void:
	var floor_m := Mats.tiles(Color(0.62, 0.62, 0.6), Color(0.35, 0.35, 0.34), 0.45, 0.22, "lobby")
	var wall := Mats.wall_paint(Color(0.78, 0.76, 0.7), "lobbywall")
	var ceil := Mats.wall_paint(Color(0.85, 0.85, 0.83), "ceiling")
	WB.room(self, -6, 6, -9, 0, 3.2, floor_m, wall, ceil, [
		{"side": "z1", "at": 0.0, "w": 2.2, "h": 2.6},
		{"side": "z0", "at": 4.5, "w": 1.0, "h": 2.1},
	])
	# Comptoir d'accueil
	var wood := Mats.wood(Color(0.55, 0.47, 0.38), Color(0.35, 0.29, 0.22), 0.3, 0.4, "counter")
	var top := Mats.std("countertop", Color(0.2, 0.21, 0.23), 0.25, 0.1)
	WB.box(self, Vector3(6.0, 1.05, 0.6), Vector3(0, 0.525, -6.2), wood)
	WB.box(self, Vector3(6.2, 0.05, 0.75), Vector3(0, 1.075, -6.2), top)
	WB.box(self, Vector3(6.0, 0.9, 0.02), Vector3(0, 1.55, -6.25), Mats.glass("hygiaphone", Color(0.8, 0.9, 0.95, 0.1)), true)
	WB.label(self, "ACCUEIL", Vector3(0, 2.4, -6.25), 0.2, Color(0.9, 0.92, 1.0), 0.0, "sans", 800)
	WB.blocker(self, Vector3(0.2, 2, 3.0), Vector3(-3.1, 1, -7.6))
	WB.blocker(self, Vector3(0.2, 2, 3.0), Vector3(3.1, 1, -7.6))
	# Écran derrière le comptoir
	WB.box(self, Vector3(0.5, 0.32, 0.03), Vector3(-1.2, 1.3, -6.75), Mats.emissive("screen", Color(0.55, 0.7, 0.95), 1.5), false)
	WB.box(self, Vector3(0.5, 0.32, 0.03), Vector3(1.4, 1.3, -6.75), Mats.emissive("screen", Color(0.55, 0.7, 0.95), 1.5), false)
	# Bancs
	var metal := Mats.metal(Color(0.3, 0.32, 0.35), 0.4, 0.7, "bench")
	for z in [-2.0, -4.0]:
		WB.box(self, Vector3(0.45, 0.06, 1.6), Vector3(-5.5, 0.45, z), metal)
		WB.box(self, Vector3(0.06, 0.45, 1.6), Vector3(-5.75, 0.75, z), metal, false)
	# Affiches
	WB.poster(self, Vector3(-5.82, 1.7, -6.0), PI / 2, Vector2(0.7, 1.0), Color(0.05, 0.12, 0.35), "VICTIME ?", "Composez le 17 ou rendez-vous sur masecurite.interieur.gouv.fr")
	WB.poster(self, Vector3(5.82, 1.7, -3.0), -PI / 2, Vector2(0.7, 1.0), Color(0.75, 0.75, 0.72), "PRÉ-PLAINTE EN LIGNE", "Gagnez du temps : remplissez votre déclaration avant de venir.", Color(0.1, 0.1, 0.15))
	WB.poster(self, Vector3(5.82, 1.7, -5.0), -PI / 2, Vector2(0.6, 0.85), Color(0.7, 0.12, 0.12), "3919", "Violences femmes info. Anonyme et gratuit.")
	# Lumières
	for p in [Vector3(-3, 3.2, -2.5), Vector3(3, 3.2, -2.5), Vector3(-3, 3.2, -7.0), Vector3(3, 3.2, -7.0)]:
		WB.ceiling_light(self, p, Vector2(1.2, 0.3), Color(0.92, 0.96, 1.0), 2.4, 6.0, p.z < -5.0)
	# Porte sécurisée vers les geôles
	lobby_door = WB.door(self, Vector3(4.0, 0, -9.0 + 0.08), 1.0, 2.1, Mats.metal(Color(0.35, 0.38, 0.42), 0.4, 0.6, "secdoor"))
	WB.label(self, "ACCÈS RÉSERVÉ", Vector3(4.5, 2.3, -8.8), 0.09, Color(0.9, 0.2, 0.2), 0.0, "sans", 800)
	WB.box(self, Vector3(0.12, 0.18, 0.04), Vector3(5.15, 1.3, -8.82), Mats.emissive("badge", Color(0.9, 0.1, 0.1), 3.0), false)


func _build_corridor_and_cells() -> void:
	var floor_m := Mats.lino(Color(0.42, 0.44, 0.45), Color(0.2, 0.2, 0.2), "corridor")
	var wall := Mats.wall_paint(Color(0.7, 0.72, 0.68), "corrwall")
	var ceil := Mats.wall_paint(Color(0.8, 0.8, 0.78), "ceiling2")
	var ops := [
		{"side": "z1", "at": 4.5, "w": 1.0, "h": 2.1},
		{"side": "z0", "at": 4.5, "w": 1.0, "h": 2.1},
		{"side": "x0", "at": -12.0, "w": 1.0, "h": 2.1},
		{"side": "x0", "at": -18.5, "w": 1.0, "h": 2.1},
	]
	for zc in [-13.5, -16.5, -19.5]:
		ops.append({"side": "x1", "at": zc - 0.45, "w": 1.5, "h": 2.3, "glass": true})
		ops.append({"side": "x1", "at": zc + 0.85, "w": 0.9, "h": 2.1})
	WB.room(self, 3, 6, -27, -9, 3.0, floor_m, wall, ceil, ops)
	for z in [-11.0, -15.0, -19.0, -23.5]:
		var l := WB.ceiling_light(self, Vector3(4.5, 3.0, z), Vector2(1.2, 0.25), Color(0.85, 0.95, 1.0), 2.0, 6.0, false)
		if z == -19.0:
			flicker_light = l
	WB.label(self, "GARDE À VUE", Vector3(5.83, 2.6, -16.5), 0.14, Color(0.15, 0.15, 0.18), -PI / 2, "sans", 800)
	# Poste de surveillance
	var desk := Mats.std("desk_grey", Color(0.4, 0.42, 0.45), 0.5, 0.2)
	WB.box(self, Vector3(0.7, 0.8, 1.6), Vector3(3.5, 0.4, -24.5), desk)
	for i in 3:
		WB.box(self, Vector3(0.03, 0.3, 0.45), Vector3(3.2, 1.0, -24.0 - i * 0.5), Mats.emissive("cctv", Color(0.6, 0.8, 0.7), 1.2), false)
	WB.label(self, "SORTIE — COUR DES VÉHICULES", Vector3(4.5, 2.35, -26.82), 0.08, Color(0.1, 0.6, 0.25), 0.0, "sans", 800)

	# Cellules
	var c_floor := Mats.concrete(Color(0.5, 0.5, 0.48), "cellfloor")
	var c_wall := Mats.wall_paint(Color(0.82, 0.78, 0.66), "cellwall")
	var c_ceil := Mats.concrete(Color(0.6, 0.6, 0.58), "cellceil")
	var bench := Mats.concrete(Color(0.55, 0.55, 0.52), "cellbench")
	var door_m := Mats.metal(Color(0.32, 0.36, 0.4), 0.45, 0.6, "celldoor")
	for i in 3:
		var zc: float = [-13.5, -16.5, -19.5][i]
		WB.room(self, 6, 9.2, zc - 1.5, zc + 1.5, 2.7, c_floor, c_wall, c_ceil, [
			{"side": "x0", "at": zc - 0.45, "w": 1.5, "h": 2.3, "glass": true},
			{"side": "x0", "at": zc + 0.85, "w": 0.9, "h": 2.1},
		])
		WB.box(self, Vector3(0.65, 0.45, 2.7), Vector3(8.7, 0.225, zc), bench)
		var light := WB.ceiling_light(self, Vector3(7.6, 2.7, zc), Vector2(0.5, 0.5), Color(1.0, 0.95, 0.85), 1.4, 4.0, i == 1, 80.0)
		if i == 1:
			cell_light = light
		WB.box(self, Vector3(0.56, 0.02, 0.56), Vector3(7.6, 2.66, zc), Mats.metal(Color(0.3, 0.3, 0.3), 0.5, 0.8, "grid"), false)
		var dome := WB.sphere(self, 0.09, Vector3(9.05, 2.6, zc - 1.35), Mats.std("dome", Color(0.05, 0.05, 0.06), 0.05, 0.3), Vector3(1, 0.6, 1))
		dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d := WB.door(self, Vector3(6.0, 0, zc + 0.4), 0.9, 2.1, door_m, false, 0.06, false)
		WB.box(d, Vector3(0.07, 0.35, 0.25), Vector3(0, 1.5, 0.45), Mats.glass("doorwin", Color(0.7, 0.8, 0.85, 0.2)), false)
		if i == 1:
			cell_door = d
		WB.label(self, "CELLULE %d" % (i + 1), Vector3(5.83, 2.25, zc + 0.85), 0.07, Color(0.1, 0.1, 0.12), -PI / 2, "sans", 700)
	# Graffitis gravés dans la cellule du joueur
	var gc := Color(0.35, 0.3, 0.25, 0.85)
	WB.label(self, "Y'A PAS DE JUSTICE", Vector3(9.03, 1.3, -16.0), 0.07, gc, -PI / 2, "sans", 400)
	WB.label(self, "K. 93 — 2019", Vector3(9.03, 1.05, -17.2), 0.05, gc, -PI / 2, "mono", 400)
	WB.label(self, "|||| |||| |||| ||", Vector3(9.03, 1.65, -17.4), 0.06, gc, -PI / 2, "mono", 300)
	WB.label(self, "courage frère", Vector3(7.6, 1.2, -17.84), 0.06, gc, 0.0, "serif", 400, false)
	WB.label(self, "Toute personne gardée à vue peut demander\nà être examinée par un médecin.",
		Vector3(7.6, 1.85, -17.84), 0.045, Color(0.15, 0.15, 0.18), 0.0, "sans", 600)


func _build_office() -> void:
	var floor_m := Mats.lino(Color(0.35, 0.33, 0.3), Color(0.2, 0.18, 0.16), "office")
	var wall := Mats.wall_paint(Color(0.76, 0.75, 0.72), "officewall")
	var ceil := Mats.wall_paint(Color(0.85, 0.85, 0.83), "ceiling")
	WB.room(self, -3, 3, -15, -9, 2.8, floor_m, wall, ceil, [
		{"side": "x1", "at": -12.0, "w": 1.0, "h": 2.1},
		{"side": "x0", "at": -12.0, "w": 1.8, "h": 2.1, "sill": 0.95, "glass": true},
	])
	var desk_wood := Mats.wood(Color(0.62, 0.55, 0.45), Color(0.45, 0.39, 0.3), 0.4, 0.45, "officedesk")
	var frame := Mats.metal(Color(0.2, 0.2, 0.22), 0.4, 0.7, "deskleg")
	WB.table(self, Vector3(0, 0, -12.1), Vector3(1.6, 0.75, 0.85), desk_wood, frame)
	WB.chair(self, Vector3(0, 0, -13.05), PI, Mats.fabric(Color(0.12, 0.13, 0.16), "chair"), frame)
	WB.chair(self, Vector3(0, 0, -11.15), 0.0, Mats.fabric(Color(0.2, 0.2, 0.22), "chair2"), frame)
	WB.chair(self, Vector3(0.95, 0, -11.0), -0.3, Mats.fabric(Color(0.2, 0.2, 0.22), "chair2"), frame)
	# Écran + clavier + dossiers
	var mon := Node3D.new()
	mon.position = Vector3(0.35, 0.75, -12.4)
	mon.rotation.y = PI + 0.25
	add_child(mon)
	WB.box(mon, Vector3(0.55, 0.34, 0.03), Vector3(0, 0.3, 0), Mats.std("bezel", Color(0.02, 0.02, 0.02), 0.3), false)
	WB.box(mon, Vector3(0.52, 0.31, 0.005), Vector3(0, 0.3, -0.017), Mats.emissive("pvscreen", Color(0.75, 0.82, 0.95), 1.8), false)
	WB.box(mon, Vector3(0.06, 0.15, 0.06), Vector3(0, 0.08, 0.03), Mats.std("bezel", Color(0.02, 0.02, 0.02), 0.3), false)
	var sl := WB.omni(self, Vector3(0.3, 1.1, -12.6), Color(0.6, 0.72, 1.0), 0.5, 2.0)
	sl.light_volumetric_fog_energy = 0.3
	WB.box(self, Vector3(0.42, 0.02, 0.14), Vector3(0.1, 0.76, -12.6), Mats.std("kbd", Color(0.08, 0.08, 0.08), 0.5), false)
	for i in 4:
		WB.box(self, Vector3(0.24, 0.025, 0.32), Vector3(-0.5, 0.765 + i * 0.026, -12.2), Mats.std("folder%d" % (i % 2), [Color(0.7, 0.2, 0.15), Color(0.85, 0.75, 0.45)][i % 2], 0.8), false)
	# Armoire, horloge, affiche
	WB.box(self, Vector3(0.5, 1.9, 0.6), Vector3(-2.5, 0.95, -14.4), Mats.metal(Color(0.55, 0.57, 0.58), 0.5, 0.4, "cabinet"))
	var clock := WB.cyl(self, 0.17, 0.17, 0.04, Vector3(0, 2.2, -14.82), Mats.std("clockface", Color(0.95, 0.95, 0.92), 0.4))
	clock.rotation.x = PI / 2
	WB.poster(self, Vector3(1.8, 1.6, -14.82), 0.0, Vector2(0.6, 0.8), Color(0.05, 0.1, 0.3), "BSU", "Brigade de sûreté urbaine — Groupe atteintes aux personnes")
	WB.ceiling_light(self, Vector3(0, 2.8, -12.0), Vector2(1.2, 0.3), Color(1.0, 0.96, 0.9), 1.8, 5.0, true)
	# Store vénitien (lamelles)
	for i in 10:
		WB.box(self, Vector3(0.02, 0.04, 1.8), Vector3(-2.78, 1.05 + i * 0.1, -12.0), Mats.std("blind", Color(0.75, 0.75, 0.72), 0.6), false)


func _build_lawyer_room() -> void:
	var floor_m := Mats.lino(Color(0.42, 0.44, 0.45), Color(0.2, 0.2, 0.2), "corridor")
	var wall := Mats.wall_paint(Color(0.74, 0.76, 0.74), "lawyerwall")
	var ceil := Mats.wall_paint(Color(0.8, 0.8, 0.78), "ceiling2")
	WB.room(self, 0, 3, -21, -15, 2.7, floor_m, wall, ceil, [{"side": "x1", "at": -18.5, "w": 1.0, "h": 2.1}])
	var frame := Mats.metal(Color(0.2, 0.2, 0.22), 0.4, 0.7, "deskleg")
	WB.table(self, Vector3(1.5, 0, -18.0), Vector3(0.8, 0.74, 1.2), Mats.std("formica", Color(0.85, 0.85, 0.82), 0.35), frame)
	WB.chair(self, Vector3(1.5, 0, -17.15), 0.0, Mats.std("plastic", Color(0.15, 0.3, 0.5), 0.5), frame)
	WB.chair(self, Vector3(1.5, 0, -18.85), PI, Mats.std("plastic", Color(0.15, 0.3, 0.5), 0.5), frame)
	WB.ceiling_light(self, Vector3(1.5, 2.7, -18.0), Vector2(0.6, 0.6), Color(1.0, 0.96, 0.9), 1.4, 4.0, true)
	WB.label(self, "LOCAL AVOCAT — ENTRETIEN CONFIDENTIEL", Vector3(2.83, 2.3, -17.6), 0.06, Color(0.15, 0.15, 0.2), -PI / 2, "sans", 700)


func _spawn_npcs() -> void:
	agent = Human.create("police", {"outfit": "police", "top": Color(0.07, 0.1, 0.19), "pants": Color(0.06, 0.08, 0.15), "female": false, "hair_style": "buzz", "seed": 1})
	agent.name = "Agent"
	add_child(agent)
	agent.position = Vector3(0.9, 0, 8.0)
	agent.rotation.y = 0.0
	accueil = Human.create("police", {"outfit": "police", "top": Color(0.07, 0.1, 0.19), "pants": Color(0.06, 0.08, 0.15), "seed": 7})
	accueil.name = "Accueil"
	add_child(accueil)
	accueil.position = Vector3(-1.4, 0, -7.0)
	accueil.rotation.y = PI
	opj = Human.create("opj", {"outfit": "opj", "top": Color(0.32, 0.33, 0.35), "pants": Color(0.12, 0.15, 0.22), "seed": 3})
	opj.name = "OPJ"
	add_child(opj)
	opj.position = Vector3(0.9, 0, -7.0)
	opj.rotation.y = PI
	neighbor = Human.create("detenu", {"outfit": "civil", "top": Color(0.45, 0.1, 0.1), "female": false, "seed": 11})
	neighbor.name = "Voisin"
	add_child(neighbor)
	neighbor.position = Vector3(8.6, 0, -13.2)
	neighbor.rotation.y = -PI / 2
	neighbor.set_sit(1.0)
	var drunk := Human.create("detenu2", {"outfit": "civil", "top": Color(0.2, 0.3, 0.2), "female": false, "seed": 12})
	add_child(drunk)
	drunk.position = Vector3(8.6, 0, -19.8)
	drunk.rotation.y = -PI / 2
	drunk.set_sit(1.0)
	var guard := Human.create("police", {"outfit": "police", "top": Color(0.07, 0.1, 0.19), "pants": Color(0.06, 0.08, 0.15), "seed": 21})
	add_child(guard)
	guard.position = Vector3(3.95, 0, -24.5)
	guard.rotation.y = -PI / 2
	guard.set_sit(1.0)
	guard.desk_pose = 0.6
	WB.chair(self, Vector3(3.95, 0, -24.5), -PI / 2, Mats.fabric(Color(0.12, 0.13, 0.16), "chair"), Mats.metal(Color(0.2, 0.2, 0.22), 0.4, 0.7, "deskleg"))


func _look_all(t: Node3D) -> void:
	for h in [agent, accueil, opj, neighbor, lawyer_npc, doctor]:
		if h:
			h.look_target = t


# ═══════════════════════════════════════════════════════════════════════════
#  DÉROULÉ
# ═══════════════════════════════════════════════════════════════════════════
func _run() -> void:
	_look_all(player.cam)
	Sfx.loop("rain", -14.0, 2.0)
	Sfx.loop("siren", -30.0, 2.0)
	hud.set_phase("Interpellation", "Arrivée au commissariat", "Hôtel de police · %s" % GameState.date_label())
	player.lock(true, 70.0)
	await Transition.chapter("Chapitre I", "L'interpellation",
		"%s — %s" % [GameState.date_label().capitalize(), GameState.clock_hm()], 2.4)
	Transition.fade_in(2.0)
	await wait(1.5)
	await hud.narrate("Les menottes vous cisaillent les poignets. La pluie, les gyrophares. Tout va très vite.")
	await hud.say(AGENT_NAME, "Police nationale", "Allez, on avance. Doucement. Pas de geste brusque.", agent)
	player.lock(false)
	hud.set_objective("Entrez dans le commissariat")
	agent.walk_to([Vector3(0.9, 0, 2.0)], 1.2)
	var z_door := TriggerZone.make(self, Vector3(0, 1, 3.0), Vector3(3, 2, 1.5))
	await wait_zone(z_door)
	_open_glass()
	var z_in := TriggerZone.make(self, Vector3(0, 1, -2.5), Vector3(8, 2, 2))
	agent.walk_to([Vector3(0.9, 0, -1.5), Vector3(1.4, 0, -4.4)], 1.2)
	await wait_zone(z_in)
	Sfx.set_loop_volume("rain", -28.0, 2.0)
	Sfx.stop_loop("siren", 2.0)
	Sfx.loop("hum", -24.0, 2.0)
	Sfx.loop("room", -20.0, 2.0)
	hud.set_objective("Avancez jusqu'au comptoir d'accueil")
	var z_counter := TriggerZone.make(self, Vector3(0, 1, -4.6), Vector3(5, 2, 1.4))
	await wait_zone(z_counter)
	hud.set_objective("")
	player.lock(true, 75.0)
	await player.look_at_point(opj.head_node().global_position, 0.9)
	if GameState.gav_possible():
		await _notification_gav()
	else:
		await _audition_libre()


func _open_glass() -> void:
	Sfx.play("slide", -6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(glass_l, "position:x", -1.6, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glass_r, "position:x", 1.6, 1.1).set_trans(Tween.TRANS_SINE)


# ── Notification des droits (art. 63-1 CPP) ─────────────────────────────────
func _notification_gav() -> void:
	var gs := GameState
	hud.set_phase("Garde à vue", "Notification des droits", "Hôtel de police · Accueil")
	player.set_dof(true, 2.0)
	gs.gav_start_minutes = gs.clock_minutes - 25.0
	await hud.say(OPJ_NAME, "Officier de police judiciaire", "Bonsoir. Je suis le %s, officier de police judiciaire. Vous êtes bien %s, né%s le %s ?" % [OPJ_NAME, gs.full_name(), gs.e(), gs.birth_date], opj)
	var c := await hud.ask(OPJ_NAME, "Officier de police judiciaire", "Répondez, s'il vous plaît.",
		["Oui, c'est moi.", "…Oui.", "Pourquoi je suis là ? J'ai rien fait !"], opj)
	if c == 2:
		gs.attitude -= 1
		await hud.say(OPJ_NAME, "OPJ", "On va y venir. Calmez-vous, ça ira plus vite pour tout le monde.", opj)
	var h := GameState.clock_hm()
	await hud.say(OPJ_NAME, "OPJ", "Il est %s. Je vous notifie votre placement en garde à vue, qui a débuté au moment de votre interpellation, il y a vingt-cinq minutes." % h, opj)
	await hud.say(OPJ_NAME, "OPJ", "Vous êtes soupçonné" + gs.e() + " d'avoir commis les faits suivants : [b]%s[/b]." % gs.charges_sentence(), opj)
	var dur := "Cette mesure dure 24 heures. Elle peut être prolongée sur décision du procureur de la République"
	if gs.gav_max_hours > 48:
		dur += ", jusqu'à %d heures compte tenu de la nature des faits." % gs.gav_max_hours
	elif gs.gav_max_hours > 24:
		dur += ", pour 24 heures supplémentaires."
	else:
		dur += "."
	await hud.say(OPJ_NAME, "OPJ", dur, opj)
	hud.toast("Placement en garde à vue notifié à %s" % h, "Procès-verbal")
	await hud.say(OPJ_NAME, "OPJ", "Vous avez le droit de garder le silence, de faire des déclarations ou de répondre aux questions. Vous avez aussi plusieurs droits. Je vais vous les lire.", opj)
	# Proche
	c = await hud.ask(OPJ_NAME, "OPJ", "Vous pouvez faire prévenir un proche et votre employeur. Vous souhaitez qu'on prévienne quelqu'un ?",
		["Oui, ma mère. S'il vous plaît.", "Mon frère.", "Non, personne."], opj)
	gs.asked_family = c < 2
	if gs.asked_family:
		hud.toast("Un proche sera avisé de la mesure", "Droit exercé", UIKit.GREEN)
	# Médecin
	c = await hud.ask(OPJ_NAME, "OPJ", "Vous avez le droit d'être examiné" + gs.e() + " par un médecin. Vous le souhaitez ?",
		["Oui, je préfère.", "Non, ça va."], opj)
	gs.asked_doctor = c == 0
	if gs.asked_doctor:
		hud.toast("Examen médical demandé", "Droit exercé", UIKit.GREEN)
	# Avocat
	c = await hud.ask(OPJ_NAME, "OPJ", "Vous avez le droit d'être assisté" + gs.e() + " par un avocat, dès maintenant et pendant les auditions. Vous pouvez en désigner un, ou en demander un commis d'office.",
		["Je veux un avocat commis d'office.", "J'ai mon avocate : %s." % gs.lawyer_name, "Pas besoin d'avocat."], opj)
	gs.lawyer = ["commis", "choisi", "none"][c]
	if gs.lawyer == "commis":
		gs.lawyer_name = "Me Antoine Ferrand"
	if c < 2:
		hud.toast("Avocat demandé : %s" % gs.lawyer_name, "Droit exercé", UIKit.GREEN)
		await hud.say(OPJ_NAME, "OPJ", "C'est noté. On l'avise. Il a deux heures pour venir ; on ne commencera pas votre audition avant, sauf urgence.", opj)
	else:
		await hud.say(OPJ_NAME, "OPJ", "Comme vous voulez. Vous pourrez changer d'avis à tout moment.", opj)
	await hud.say(OPJ_NAME, "OPJ", "Vous pouvez aussi consulter certains éléments de la procédure, bénéficier d'un interprète, et présenter des observations au procureur si la mesure est prolongée.", opj)
	c = await hud.ask(OPJ_NAME, "OPJ", "Signez ici, en bas du procès-verbal de notification.",
		["Signer.", "Je ne signe rien."], opj)
	gs.signed_rights = c == 0
	if c == 1:
		gs.attitude -= 1
		await hud.say(OPJ_NAME, "OPJ", "« Refuse de signer. » C'est noté, ça ne change rien à vos droits.", opj)
	else:
		Sfx.play("tick", -4.0, 0.5)
	await _fouille()


func _fouille() -> void:
	var gs := GameState
	hud.set_phase("Garde à vue", "Fouille & inventaire", "Hôtel de police · Accueil")
	await hud.say(AGENT_NAME, "Police nationale", "Videz vos poches dans le bac. Téléphone, portefeuille, clés. Et j'ai besoin de votre ceinture et de vos lacets.", agent)
	var c := await hud.ask(AGENT_NAME, "Police nationale", "Allez.",
		["(Obéir sans un mot)", "Mes lacets ? Vraiment ?", "Je vous donne rien du tout."], agent)
	if c == 0:
		gs.attitude += 1
	elif c == 1:
		await hud.say(AGENT_NAME, "Police nationale", "C'est pour votre sécurité. Tout le monde y passe.", agent)
	else:
		gs.attitude -= 2
		player.shake(0.03)
		Sfx.play("cuffs", -2.0)
		await hud.say(AGENT_NAME, "Police nationale", "On peut faire ça gentiment ou pas. Vous choisissez.", agent)
		await hud.narrate("Il vous retourne contre le comptoir. La fouille est rapide, brutale.")
	Sfx.play("cuffs", -8.0, 1.2)
	hud.toast("Téléphone · Portefeuille · Clés · Ceinture · Lacets — placés sous scellés", "Inventaire")
	await wait(1.0)
	# Signalisation
	hud.set_phase("Garde à vue", "Signalisation", "Hôtel de police · Accueil")
	await hud.say(AGENT_NAME, "Police nationale", "Maintenant la signalisation. Photos et empreintes. Regardez l'objectif.", agent)
	for t in ["De face.", "Profil gauche.", "Profil droit."]:
		hud.subtitle(t, 1.0)
		await wait(0.9)
		hud.flash()
		Sfx.play("lock", -10.0, 2.0)
		await wait(0.6)
	hud.toast("Empreintes digitales et photographies enregistrées", "Signalisation")
	await wait(0.8)
	await _escort_to_cell()


func _escort_to_cell() -> void:
	hud.set_phase("Garde à vue", "Placement en cellule", "Hôtel de police · Zone de garde à vue")
	player.set_dof(false)
	await hud.say(AGENT_NAME, "Police nationale", "Suivez-moi.", agent)
	hud.letterbox(true)
	Sfx.play("lock", -6.0)
	var tw := create_tween()
	tw.tween_property(lobby_door, "rotation:y", -PI / 2, 0.8).set_trans(Tween.TRANS_SINE)
	agent.walk_to([Vector3(4.5, 0, -7.6), Vector3(4.5, 0, -10.0), Vector3(4.5, 0, CELL_DOOR_Z + 0.2), Vector3(4.2, 0, CELL_DOOR_Z - 1.2)], 1.3)
	await wait(0.6)
	await player.auto_walk([Vector3(3.6, 0, -6.6), Vector3(4.5, 0, -8.6), Vector3(4.5, 0, -11.0), Vector3(4.6, 0, CELL_DOOR_Z + 0.8)], 1.25)
	Sfx.play("lock", -4.0)
	await _set_cell_door(true)
	agent.face_point(player.global_position)
	await player.auto_walk([Vector3(6.6, 0, CELL_DOOR_Z), Vector3(7.4, 0, -16.4)], 1.0)
	await player.look_at_point(Vector3(6.0, 1.6, CELL_DOOR_Z), 0.8)
	await hud.say(AGENT_NAME, "Police nationale", "Si vous avez besoin, vous frappez. On passe régulièrement.", agent)
	await _set_cell_door(false)
	Sfx.play("door", 0.0)
	await wait(0.25)
	Sfx.play("lock", -2.0)
	player.shake(0.02)
	agent.walk_to([Vector3(4.5, 0, -11.0), Vector3(4.5, 0, -8.0)], 1.3)
	hud.letterbox(false)
	await _gav_loop()


func _set_cell_door(open: bool) -> void:
	var tw := create_tween()
	tw.tween_property(cell_door, "rotation:y", -PI * 0.55 if open else 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ── Cellule : boucle de la garde à vue ───────────────────────────────────────
func _gav_loop() -> void:
	var gs := GameState
	hud.set_phase("Garde à vue", "Cellule n° 2", "Hôtel de police · Zone de garde à vue")
	await Transition.chapter("Chapitre II", "La garde à vue", "1 heure = 3 secondes", 1.6)
	Transition.fade_in(1.4)
	player.lock(false)
	player.speed = 1.2
	bench_it.enabled = true
	door_it.enabled = true
	hud.set_objective("Attendez. Le temps passe…")
	await hud.narrate("Quatre murs crème, un banc en béton, une caméra. Le néon ne s'éteint jamais.")
	var end_h := 20.0
	var events := []
	if gs.asked_doctor:
		events.append([1.5, "doctor"])
	if gs.lawyer != "none":
		events.append([2.5, "lawyer"])
	events.append([4.0, "audition1"])
	events.append([9.0, "meal"])
	events.append([12.0, "neighbor"])
	events.append([15.0, "audition2"])
	if gs.gav_max_hours > 24 and gs.max_prison_months() >= 60:
		events.append([23.0, "prolongation"])
		events.append([33.0, "audition3"])
		end_h = 44.0
	events.append([end_h, "end"])
	for ev in events:
		await _wait_until_hour(ev[0])
		match ev[1]:
			"doctor": await _doctor_visit()
			"lawyer": await _lawyer_meeting()
			"audition1": await _audition(1)
			"audition2": await _audition(2)
			"audition3": await _audition(3)
			"meal": await _meal()
			"neighbor": await _neighbor_event()
			"prolongation": await _prolongation()
			"end": await _end_gav()


func _wait_until_hour(h: float) -> void:
	var gs := GameState
	var remaining: float = h - gs.gav_hours_elapsed()
	if remaining <= 0.0:
		return
	await run_clock(remaining, GameState.GAV_SECONDS_PER_HOUR, func(_r):
		var e := gs.gav_hours_elapsed()
		hud.set_timer("Garde à vue", "%02dh%02d / %dh" % [int(e), int(fmod(e, 1.0) * 60.0), gs.gav_max_hours], e / float(gs.gav_max_hours),
			UIKit.RED if e > 24.0 else UIKit.ACCENT)
		player.stress = clamp(e / 48.0, 0.0, 0.6))


func _process(delta: float) -> void:
	_t += delta
	for i in siren_lights.size():
		var ph := fmod(_t * 2.6 + i * 0.5, 1.0)
		siren_lights[i].light_energy = 7.0 if ph < 0.18 or (ph > 0.3 and ph < 0.42) else 0.0
	if flicker_light:
		flicker_light.light_energy = 2.0 if fmod(_t * 7.3, 5.0) > 0.25 else randf_range(0.1, 1.2)


func _toggle_sit() -> void:
	sitting = not sitting
	if sitting:
		player.can_move = false
		player.set_eye_height(1.12)
		bench_it.prompt = "Se lever"
		var tw := create_tween()
		tw.tween_property(player, "global_position", Vector3(8.05, 0, player.global_position.z), 0.5)
	else:
		player.can_move = true
		player.set_eye_height(FPSPlayer.EYE_H)
		bench_it.prompt = "S'asseoir sur le banc"
	hud.set_prompt(bench_it.prompt)


func _knock() -> void:
	Sfx.play("door", -8.0, 1.4)
	await wait(0.4)
	var replies := ["« Quoi encore ? On arrive quand on arrive ! »", "« Patience. Votre tour viendra. »",
		"« Arrêtez de taper, sinon on vous menotte au banc. »", "(Personne ne répond.)"]
	hud.subtitle(replies[randi() % replies.size()], 3.0)
	GameState.attitude -= 0 if randf() < 0.7 else 1


func _stand_if_sitting() -> void:
	if sitting:
		_toggle_sit()


## Sort le joueur de la cellule (fondu) et le place ailleurs.
func _leave_cell_to(pos: Vector3, yaw: float, seated: bool) -> void:
	_stand_if_sitting()
	bench_it.enabled = false
	door_it.enabled = false
	hud.set_objective("")
	await Transition.fade_out(0.6)
	Sfx.play("lock", -6.0)
	player.teleport(pos, yaw)
	player.lock(true, 80.0)
	if seated:
		player.set_seated(true)
		player.set_eye_height(1.2, 0.0)
	hud.hide_timer()


func _back_to_cell() -> void:
	await Transition.fade_out(0.7)
	Sfx.stop_loop("typing", 0.3)
	player.set_dof(false)
	player.set_eye_height(FPSPlayer.EYE_H, 0.0)
	player.set_seated(false)
	player.teleport(Vector3(7.2, 0, -16.6), PI / 2)
	opj.desk_pose = 0.0
	opj.set_sit(0.0)
	opj.position = Vector3(0.9, 0, -7.0)
	if lawyer_npc:
		lawyer_npc.visible = false
	Sfx.play("door", -4.0)
	await Transition.fade_in(0.8)
	player.lock(false)
	bench_it.enabled = true
	door_it.enabled = true
	hud.set_objective("Attendez. Le temps passe…")


func _doctor_visit() -> void:
	Sfx.play("lock", -4.0)
	await _set_cell_door(true)
	doctor = Human.create("medecin", {"outfit": "medecin", "pants": Color(0.25, 0.27, 0.3), "glasses": true, "seed": 31})
	add_child(doctor)
	doctor.position = Vector3(6.3, 0, CELL_DOOR_Z)
	doctor.rotation.y = -PI / 2
	doctor.look_target = player.cam
	_stand_if_sitting()
	player.lock(true, 80.0)
	await player.look_at_point(doctor.head_node().global_position, 0.8)
	await hud.say("Dr Lemaire", "Médecin requis", "Bonsoir. Je suis médecin, je viens vérifier que votre état de santé est compatible avec la garde à vue.", doctor)
	var c := await hud.ask("Dr Lemaire", "Médecin requis", "Vous avez mal quelque part ? Un traitement à prendre ?",
		["J'ai mal aux poignets, les menottes étaient serrées.", "Je prends un traitement, il est resté chez moi.", "Non, ça va. Je suis juste à bout."], doctor)
	match c:
		0: await hud.say("Dr Lemaire", "Médecin requis", "Je vois des marques superficielles. Je le note dans mon certificat.", doctor)
		1: await hud.say("Dr Lemaire", "Médecin requis", "Je vais demander qu'on le récupère, ou vous en prescrire. C'est important.", doctor)
		2: await hud.say("Dr Lemaire", "Médecin requis", "C'est normal. Respirez. Essayez de dormir un peu, même assis.", doctor)
	await hud.say("Dr Lemaire", "Médecin requis", "Votre état est compatible avec la mesure. Bon courage.", doctor)
	hud.toast("Certificat médical : état compatible avec la garde à vue", "Examen médical", UIKit.GREEN)
	doctor.queue_free()
	doctor = null
	await _set_cell_door(false)
	Sfx.play("door", -3.0)
	player.lock(false)


func _lawyer_meeting() -> void:
	var gs := GameState
	Sfx.play("lock", -4.0)
	hud.subtitle("« %s ! Votre avocat est là. »" % gs.player_last.to_upper(), 2.5)
	await wait(1.6)
	if lawyer_npc == null:
		var fem := gs.lawyer == "choisi"
		lawyer_npc = Human.create("avocat", {"outfit": "civil", "top": Color(0.12, 0.12, 0.14), "pants": Color(0.1, 0.1, 0.12),
			"female": fem, "hair_style": "bun" if fem else "short", "glasses": not fem, "seed": 41})
		add_child(lawyer_npc)
	lawyer_npc.visible = true
	lawyer_npc.position = Vector3(1.5, 0, -17.15)
	lawyer_npc.rotation.y = 0.0
	lawyer_npc.set_sit(1.0)
	lawyer_npc.look_target = player.cam
	await _leave_cell_to(Vector3(1.5, 0, -19.0), PI, true)
	hud.set_phase("Garde à vue", "Entretien avec l'avocat", "Local avocat · 30 minutes, confidentiel")
	Transition.fade_in(0.8)
	player.set_dof(true, 1.5)
	await player.look_at_point(lawyer_npc.head_node().global_position, 0.1)
	var nm := gs.lawyer_name
	var who := "commis d'office" if gs.lawyer == "commis" else "avocate"
	await hud.say(nm, "Avocat · " + who, "Bonsoir. %s, avocat%s au barreau. On a trente minutes, et tout ce que vous me dites reste entre nous." % [nm, "e" if gs.lawyer == "choisi" else ""], lawyer_npc)
	await hud.say(nm, "Avocat", "J'ai pu lire votre notification et le certificat médical. Pas encore les PV d'audition des témoins, la loi ne me les donne pas.", lawyer_npc)
	var c := await hud.ask(nm, "Avocat", "Alors dites-moi. Qu'est-ce qui s'est passé, vraiment ?",
		["Je vous dis la vérité : je l'ai fait.", "Je n'ai rien fait, je vous le jure.", "Je préfère ne rien dire, même à vous.", "Qu'est-ce que vous me conseillez ?"], lawyer_npc)
	match c:
		0:
			gs.told_lawyer_truth = true
			gs.lawyer_bond += 2
			await hud.say(nm, "Avocat", "Merci de votre franchise. Avec ce qu'ils ont, nier serait risqué. Reconnaître et expliquer, c'est souvent ce qui pèse le plus devant un juge.", lawyer_npc)
		1:
			gs.lawyer_bond += 1 if gs.evidence < 0.7 else 0
			await hud.say(nm, "Avocat", "D'accord. Alors on tient cette ligne. Mais si vous mentez et qu'ils ont des images, ça se retournera contre vous.", lawyer_npc)
		2:
			gs.lawyer_bond -= 1
			await hud.say(nm, "Avocat", "C'est votre droit. Mais je ne peux pas vous défendre correctement à l'aveugle.", lawyer_npc)
		3:
			gs.lawyer_bond += 1
			if gs.evidence > 0.75:
				await hud.say(nm, "Avocat", "Le dossier semble solide. Mon conseil : ne pas nier l'évidence. Vous pouvez aussi garder le silence sur les points que vous ne maîtrisez pas.", lawyer_npc)
			else:
				await hud.say(nm, "Avocat", "Je ne vois pas grand-chose de solide pour l'instant. Le silence peut être une bonne stratégie, au moins jusqu'à ce qu'on en sache plus.", lawyer_npc)
	await hud.say(nm, "Avocat", "Je serai à côté de vous pendant l'audition. Si une question vous met mal à l'aise, regardez-moi.", lawyer_npc)
	await skip_time(30.0, 1.0)
	await _back_to_cell()


# ── Auditions ────────────────────────────────────────────────────────────────
func _audition(n: int) -> void:
	var gs := GameState
	hud.subtitle("« %s, on y va. Audition. »" % gs.player_last.to_upper(), 2.5)
	Sfx.play("lock", -4.0)
	await wait(1.5)
	opj.position = OFFICE_OPJ
	opj.rotation.y = PI
	opj.set_sit(1.0)
	opj.desk_pose = 1.0
	if lawyer_npc and gs.lawyer != "none":
		lawyer_npc.visible = true
		lawyer_npc.position = Vector3(0.95, 0, -11.0)
		lawyer_npc.rotation.y = -0.3
		lawyer_npc.set_sit(1.0)
	await _leave_cell_to(OFFICE_PLAYER, 0.0, true)
	hud.set_phase("Garde à vue", "Audition n° %d" % n, "Bureau de l'OPJ · Procès-verbal d'audition")
	Sfx.loop("typing", -20.0, 0.5)
	Transition.fade_in(0.8)
	player.set_dof(true, 2.0)
	await player.look_at_point(opj.head_node().global_position, 0.1)
	var infr: Array = gs.infractions()
	if n == 1:
		await hud.say(OPJ_NAME, "OPJ", "Audition de %s. Il est %s. Je vous rappelle que vous pouvez garder le silence." % [gs.full_name(), gs.clock_hm()], opj)
		var c := await hud.ask(OPJ_NAME, "OPJ", "On commence par votre situation. Vous travaillez ?",
			["Oui, en CDI.", "Je fais de l'intérim.", "Je suis étudiant%s." % gs.e(), "Je suis sans emploi en ce moment."], opj)
		gs.situation = ["cdi", "interim", "etudiant", "chomage"][c]
		for i in min(infr.size(), 2):
			await _question_infraction(infr[i])
	elif n == 2:
		await hud.say(OPJ_NAME, "OPJ", "Deuxième audition. Il est %s. On a avancé de notre côté." % gs.clock_hm(), opj)
		var d: Dictionary = infr[0]
		await hud.say(OPJ_NAME, "OPJ", Dialogues.evidence_line(d.cat), opj)
		if gs.denials > 0 or gs.silences > 0:
			var c2 := await hud.ask(OPJ_NAME, "OPJ", "Alors je vous repose la question, et réfléchissez bien : maintenez-vous vos déclarations ?",
				["Je maintiens. Ce n'est pas moi.", "…D'accord. C'est moi. Je reconnais.", "Je garde le silence."], opj)
			match c2:
				0:
					gs.denials += 1
					if gs.evidence > 0.75:
						gs.lies += 1
					await hud.say(OPJ_NAME, "OPJ", Dialogues.pick(Dialogues.OPJ_ON_DENY), opj)
				1:
					gs.admissions += 1
					gs.denials = max(0, gs.denials - 1)
					await hud.say(OPJ_NAME, "OPJ", "Je préfère ça. Vraiment. Ce sera dit au procureur.", opj)
				2:
					gs.silences += 1
					await hud.say(OPJ_NAME, "OPJ", Dialogues.pick(Dialogues.OPJ_ON_SILENCE), opj)
		else:
			await hud.say(OPJ_NAME, "OPJ", "Vos déclarations sont cohérentes avec les éléments. C'est noté.", opj)
		if infr.size() > 2:
			await _question_infraction(infr[2])
	else:
		await hud.say(OPJ_NAME, "OPJ", "Troisième audition. On a exploité votre téléphone.", opj)
		await _question_infraction(infr[0])
	var c3 := await hud.ask(OPJ_NAME, "OPJ", "Avez-vous quelque chose à ajouter ?",
		["Je regrette ce qui s'est passé.", "Je veux juste rentrer chez moi.", "Non, rien."], opj)
	if c3 == 0:
		gs.attitude += 1
	await hud.say(OPJ_NAME, "OPJ", "Relisez votre procès-verbal, et signez chaque page.", opj)
	hud.toast("Procès-verbal d'audition n° %d signé" % n, "Procès-verbal")
	gs.gav_story = "aveux" if gs.admissions > 0 and gs.denials == 0 else ("deni" if gs.denials > 0 else ("silence" if gs.silences > 0 else "mixte"))
	await skip_time(90.0, 1.5)
	await _back_to_cell()


func _question_infraction(d: Dictionary) -> void:
	var gs := GameState
	var role := "OPJ"
	await hud.say(OPJ_NAME, role, "Parlons des faits de [b]%s[/b]. %s" % [GameState.lcfirst(d.name), Dialogues.evidence_line(d.cat)], opj)
	var c := await hud.ask(OPJ_NAME, role, "Qu'avez-vous à dire ?",
		["Je reconnais les faits.", "Ce n'est pas moi. Je conteste.", "Je ne souhaite pas répondre.", Dialogues.minimize_line(d.cat)], opj)
	match c:
		0:
			gs.admissions += 1
			await hud.say(OPJ_NAME, role, Dialogues.pick(Dialogues.OPJ_ON_ADMIT), opj)
			var why := await hud.ask(OPJ_NAME, role, "Pourquoi ?",
				["Je ne sais pas. J'ai perdu les pédales.", "J'avais des problèmes d'argent.", "J'avais bu.", "Je préfère ne pas l'expliquer."], opj)
			if why == 2 and not gs.aggravations.has("Alcool (déclaré)"):
				gs.aggravations.append("Alcool (déclaré)")
		1:
			gs.denials += 1
			if gs.evidence > 0.75:
				gs.lies += 1
			await hud.say(OPJ_NAME, role, Dialogues.pick(Dialogues.OPJ_ON_DENY), opj)
		2:
			gs.silences += 1
			if lawyer_npc and lawyer_npc.visible:
				await hud.say(GameState.lawyer_name, "Avocat", GameState.g("Mon client", "Ma cliente") + " exerce son droit au silence. Merci de le noter.", lawyer_npc)
			await hud.say(OPJ_NAME, role, Dialogues.pick(Dialogues.OPJ_ON_SILENCE), opj)
		3:
			gs.minimizations += 1
			await hud.say(OPJ_NAME, role, Dialogues.pick(Dialogues.OPJ_ON_MINIMIZE), opj)


func _meal() -> void:
	Sfx.play("lock", -8.0, 1.3)
	hud.subtitle("Une barquette passe par la trappe. Raviolis réchauffés, une bouteille d'eau.", 3.0)
	await wait(2.0)
	var c := await hud.ask("", "", "[i]Le plat fume à peine. L'odeur vous soulève le cœur.[/i]", ["Manger.", "Laisser la barquette."])
	if c == 1:
		player.stress = min(player.stress + 0.1, 0.8)
		hud.toast("Repas refusé", "Registre de garde à vue", UIKit.TEXT_DIM)
	else:
		hud.toast("Repas pris à %s" % GameState.clock_hm(), "Registre de garde à vue", UIKit.TEXT_DIM)


func _neighbor_event() -> void:
	Sfx.play("door", -6.0, 1.2)
	await wait(0.3)
	Sfx.play("door", -6.0, 1.15)
	hud.subtitle("Cellule voisine : « OUVREZ ! J'ai le droit de téléphoner ! J'AI DES DROITS ! »", 3.5)
	await wait(4.0)
	hud.subtitle("« Ça fait des heures, frère… Toi aussi t'attends ton avocat ? »", 3.5)


func _prolongation() -> void:
	var gs := GameState
	Sfx.play("lock", -4.0)
	await _set_cell_door(true)
	opj.position = Vector3(6.3, 0, CELL_DOOR_Z)
	opj.rotation.y = -PI / 2
	opj.set_sit(0.0)
	opj.desk_pose = 0.0
	_stand_if_sitting()
	player.lock(true, 80.0)
	await player.look_at_point(opj.head_node().global_position, 0.8)
	await hud.say(OPJ_NAME, "OPJ", "Le procureur de la République a autorisé la prolongation de votre garde à vue pour 24 heures. Il est %s." % gs.clock_hm(), opj)
	var c := await hud.ask(OPJ_NAME, "OPJ", "Vous voulez présenter des observations au magistrat ?",
		["Je n'ai rien à cacher, je veux sortir.", "Je demande à revoir mon avocat.", "Non."], opj)
	if c == 1 and gs.lawyer != "none":
		hud.toast("Nouvel entretien avec l'avocat demandé", "Droit exercé", UIKit.GREEN)
		gs.lawyer_bond += 1
	hud.toast("Prolongation de 24 h notifiée", "Procès-verbal", UIKit.RED)
	await _set_cell_door(false)
	Sfx.play("door", -2.0)
	opj.position = Vector3(0.9, 0, -7.0)
	player.lock(false)


func _end_gav() -> void:
	var gs := GameState
	hud.hide_timer()
	Sfx.play("lock", -3.0)
	await _set_cell_door(true)
	opj.position = Vector3(6.3, 0, CELL_DOOR_Z)
	opj.rotation.y = -PI / 2
	opj.set_sit(0.0)
	opj.desk_pose = 0.0
	_stand_if_sitting()
	bench_it.enabled = false
	door_it.enabled = false
	player.lock(true, 80.0)
	await player.look_at_point(opj.head_node().global_position, 0.8)
	var e := gs.gav_hours_elapsed()
	await hud.say(OPJ_NAME, "OPJ", "Fin de la garde à vue. Il est %s, elle aura duré %d heures. J'ai eu le parquet au téléphone." % [gs.clock_hm(), int(e)], opj)
	var classement := gs.kind() != "X" and gs.evidence < 0.55 and gs.admissions == 0 and (gs.denials + gs.silences) > 0 and randf() < 0.55
	if classement:
		gs.outcome_after_gav = "classement"
		await hud.say(OPJ_NAME, "OPJ", "Le procureur classe l'affaire sans suite, faute d'éléments suffisants. Vous êtes libre. On vous rend vos affaires.", opj)
		await Transition.fade_out(1.2)
		get_tree().change_scene_to_file("res://scenes/ending.tscn")
		return
	if gs.kind() == "X":
		gs.outcome_after_gav = "instruction"
		await hud.say(OPJ_NAME, "OPJ", "Vous allez être déféré" + gs.e() + " devant un juge d'instruction. Vu la gravité des faits, une information judiciaire est ouverte.", opj)
		await Transition.fade_out(1.0)
		await Transition.card("Déferrement", "Le juge d'instruction vous met en examen.\nLe juge des libertés et de la détention ordonne votre placement en détention provisoire.", 3.6)
		gs.detention_provisoire_months = randi_range(10, 20)
		gs.advance_minutes(gs.detention_provisoire_months * 30.0 * 24 * 60)
		await Transition.card("%d mois plus tard" % gs.detention_provisoire_months, "L'instruction est close. Vous êtes renvoyé" + gs.e() + " devant la %s." % gs.jurisdiction().name.to_lower(), 3.4)
		get_tree().change_scene_to_file("res://scenes/transfer.tscn")
		return
	var ci := gs.max_prison_months() >= 24 or gs.record != "vierge" or gs.circumstance == "flagrant"
	if ci:
		gs.outcome_after_gav = "ci"
		await hud.say(OPJ_NAME, "OPJ", "Le procureur a décidé un déferrement. Vous allez être conduit%s au tribunal et jugé%s en comparution immédiate, aujourd'hui." % [gs.e(), gs.e()], opj)
		await hud.say(OPJ_NAME, "OPJ", "L'escorte arrive. Bon courage.", opj)
		await Transition.fade_out(1.0)
		get_tree().change_scene_to_file("res://scenes/transfer.tscn")
	else:
		gs.outcome_after_gav = "convocation"
		await hud.say(OPJ_NAME, "OPJ", "Vous ressortez libre, avec une convocation devant le tribunal correctionnel. Ne la ratez pas.", opj)
		hud.toast("Convocation par officier de police judiciaire (COPJ) remise", "Procès-verbal")
		await wait(1.5)
		await Transition.fade_out(1.0)
		gs.advance_minutes(62 * 24 * 60)
		await Transition.card("Deux mois plus tard", "Vous vous présentez libre au palais de justice, convocation à la main.", 3.0)
		get_tree().change_scene_to_file("res://scenes/tribunal.tscn")


# ── Audition libre (contraventions) ──────────────────────────────────────────
func _audition_libre() -> void:
	var gs := GameState
	hud.set_phase("Audition libre", "Accueil", "Hôtel de police")
	await hud.say(OPJ_NAME, "Officier de police judiciaire", "Bonsoir. Pour ces faits, pas de garde à vue : vous êtes entendu" + gs.e() + " en audition libre. Vous pouvez quitter les lieux à tout moment.", opj)
	var c := await hud.ask(OPJ_NAME, "OPJ", "Vous pouvez être assisté d'un avocat, à vos frais ou au titre de l'aide juridictionnelle. Vous en voulez un ?",
		["Oui, je veux un avocat.", "Non, finissons-en."], opj)
	gs.lawyer = "commis" if c == 0 else "none"
	if c == 0:
		gs.lawyer_name = "Me Antoine Ferrand"
	opj.walk_to([Vector3(4.5, 0, -7.5)], 1.3)
	await hud.say(OPJ_NAME, "OPJ", "Suivez-moi dans mon bureau.", opj)
	Sfx.play("lock", -6.0)
	create_tween().tween_property(lobby_door, "rotation:y", -PI / 2, 0.8)
	await Transition.fade_out(0.7)
	opj.position = OFFICE_OPJ
	opj.rotation.y = PI
	opj.set_sit(1.0)
	opj.desk_pose = 1.0
	player.teleport(OFFICE_PLAYER, 0.0)
	player.set_seated(true)
	player.set_eye_height(1.2, 0.0)
	hud.set_phase("Audition libre", "Bureau de l'OPJ", "Procès-verbal d'audition")
	Sfx.loop("typing", -20.0, 0.5)
	await Transition.fade_in(0.8)
	player.set_dof(true, 2.0)
	await player.look_at_point(opj.head_node().global_position, 0.1)
	c = await hud.ask(OPJ_NAME, "OPJ", "Votre situation professionnelle ?",
		["Salarié%s en CDI." % gs.e(), "Intérimaire.", "Étudiant%s." % gs.e(), "Sans emploi."], opj)
	gs.situation = ["cdi", "interim", "etudiant", "chomage"][c]
	for d in gs.infractions():
		await _question_infraction(d)
	await hud.say(OPJ_NAME, "OPJ", "C'est terminé. Le dossier part au parquet. Vous recevrez une convocation devant le tribunal de police.", opj)
	gs.outcome_after_gav = "audition_libre"
	await skip_time(60.0, 1.0)
	await Transition.fade_out(1.0)
	gs.advance_minutes(45 * 24 * 60)
	await Transition.card("Six semaines plus tard", "Tribunal de police. Votre convocation est pour 14 h.", 3.0)
	get_tree().change_scene_to_file("res://scenes/tribunal.tscn")
