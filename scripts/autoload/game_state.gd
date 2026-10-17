extends Node
## État global du dossier pénal du joueur, de la procédure et de l'horloge de jeu.

signal clock_changed

# ── Réglages de temps (demandés) ───────────────────────────────────────────
const GAV_SECONDS_PER_HOUR := 3.0        # garde à vue : 1 h = 3 s
const PRISON_SECONDS_PER_MONTH := 60.0   # prison : 1 mois = 1 min
const DELIBERE_SECONDS_PER_HOUR := 24.0  # délibéré : attente tendue

const MONTHS_FR := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
	"août", "septembre", "octobre", "novembre", "décembre"]
const DAYS_FR := ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

const FIRST_NAMES_M := ["Lucas", "Hugo", "Nathan", "Karim", "Thomas", "Yanis", "Maxime", "Julien",
	"Sofiane", "Mehdi", "Enzo", "Kevin", "Antoine", "Moussa"]
const FIRST_NAMES_F := ["Léa", "Camille", "Inès", "Sarah", "Manon", "Clara", "Chloé", "Yasmine",
	"Laura", "Océane", "Aïcha", "Julie"]
const LAST_NAMES := ["Martin", "Bernard", "Moreau", "Lefèvre", "Benali", "Garcia", "Roux",
	"Fontaine", "Diallo", "Mercier", "Lambert", "Haddad", "Girard", "Perrin", "Nguyen"]

# ── Dossier ──────────────────────────────────────────────────────────────────
var player_first := "Lucas"
var player_last := "Martin"
var player_female := false
var birth_date := "12 avril 1997"
var birth_place := "Lyon (69)"
var address := "14 rue des Tanneurs, Lyon 7e"
var record := "vierge"            # vierge | antecedents | recidive
var circumstance := "flagrant"    # flagrant | plainte | enquete
var aggravations: Array[String] = []
var selected: Array[String] = []

# ── Procédure ────────────────────────────────────────────────────────────────
var lawyer := "none"              # none | commis | choisi
var lawyer_name := "Me Claire Vasseur"
var asked_doctor := false
var asked_family := false
var signed_rights := true
var situation := ""               # cdi | interim | etudiant | chomage | ""
var admissions := 0
var denials := 0
var silences := 0
var minimizations := 0
var lies := 0
var attitude := 0                 # >0 respectueux, <0 agressif
var lawyer_bond := 0
var evidence := 0.8
var told_lawyer_truth := false
var gav_story := ""               # aveux | deni | silence | mixte
var trial_story := ""
var trial_changed_story := false
var accepted_ci := true
var last_word := ""
var detention_provisoire_months := 0
var outcome_after_gav := ""       # ci | convocation | instruction | classement | audition_libre
var verdict: Dictionary = {}
var conduct := 0
var prison_months_served := 0.0
var prison_total_months := 0
var reductions_months := 0
var released_early := false
var family_contact := false

# ── Horloge ──────────────────────────────────────────────────────────────────
var clock_minutes := 0.0          # minutes depuis 00:00 du jour 0
var start_weekday := 1            # mardi
var start_day := 14
var start_month := 2              # mars (index)
var start_year := 2026
var gav_start_minutes := 0.0
var gav_max_hours := 24


func _ready() -> void:
	_setup_inputs()
	randomize()
	random_identity()


func _setup_inputs() -> void:
	var keys := {
		"move_forward": [KEY_Z, KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_Q, KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_F],
		"advance": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		"dossier": [KEY_TAB],
		"pause": [KEY_ESCAPE],
		"choice_1": [KEY_1, KEY_KP_1, KEY_AMPERSAND],
		"choice_2": [KEY_2, KEY_KP_2, 0xE9],
		"choice_3": [KEY_3, KEY_KP_3, KEY_QUOTEDBL],
		"choice_4": [KEY_4, KEY_KP_4, KEY_APOSTROPHE],
		"crouch": [KEY_CTRL],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.keycode = k  # ZQSD (AZERTY) et WASD (QWERTY) sont tous deux mappés
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("click"):
		InputMap.add_action("click")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("click", mb)
		InputMap.action_add_event("advance", mb.duplicate())


func random_identity() -> void:
	player_female = randf() < 0.35
	player_first = (FIRST_NAMES_F if player_female else FIRST_NAMES_M).pick_random()
	player_last = LAST_NAMES.pick_random()
	var d := randi_range(1, 28)
	birth_date = "%d %s %d" % [d, MONTHS_FR.pick_random(), randi_range(1975, 2004)]


## Accord en genre : « e » si le personnage joué est une femme.
func e() -> String:
	return "e" if player_female else ""


func g(masc: String, fem: String) -> String:
	return fem if player_female else masc


static func ucfirst(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s


static func lcfirst(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1) if s != "" else s


func full_name() -> String:
	return "%s %s" % [player_first, player_last.to_upper()]


func reset_procedure() -> void:
	lawyer = "none"
	asked_doctor = false
	asked_family = false
	signed_rights = true
	situation = ""
	admissions = 0
	denials = 0
	silences = 0
	minimizations = 0
	lies = 0
	attitude = 0
	lawyer_bond = 0
	told_lawyer_truth = false
	gav_story = ""
	trial_story = ""
	trial_changed_story = false
	accepted_ci = true
	last_word = ""
	detention_provisoire_months = 0
	outcome_after_gav = ""
	verdict = {}
	conduct = 0
	prison_months_served = 0.0
	prison_total_months = 0
	reductions_months = 0
	released_early = false
	family_contact = false
	clock_minutes = 23 * 60 + 41
	gav_start_minutes = 0.0
	match circumstance:
		"flagrant": evidence = randf_range(0.82, 0.97)
		"plainte": evidence = randf_range(0.45, 0.8)
		_: evidence = randf_range(0.6, 0.9)
	gav_max_hours = compute_gav_max()


# ── Requêtes sur le dossier ──────────────────────────────────────────────────
func infractions() -> Array:
	var out := []
	for id in selected:
		var d := InfractionDB.get_by_id(id)
		if not d.is_empty():
			out.append(d)
	out.sort_custom(func(a, b): return _weight(a) > _weight(b))
	return out


func _weight(d: Dictionary) -> int:
	return d.prison * 1000 + d.fine / 100 + (100000000 if d.kind == "X" else 0)


func main_infraction() -> Dictionary:
	var l := infractions()
	return l[0] if not l.is_empty() else {}


func max_prison_months() -> int:
	var m := 0
	for d in infractions():
		m = max(m, d.prison)
	if record == "recidive" and m > 0 and m < InfractionDB.PERPETUITE:
		m = min(m * 2, InfractionDB.PERPETUITE if m >= 360 else 360)
	return m


func max_fine() -> int:
	var m := 0
	for d in infractions():
		m = max(m, d.fine)
	if record == "recidive":
		m *= 2
	return m


func kind() -> String:
	var k := "C"
	for d in infractions():
		if d.kind == "X":
			return "X"
		if d.kind == "D":
			k = "D"
	return k


func has_victim() -> bool:
	for d in infractions():
		if d.victim:
			return true
	return false


func categories() -> Array:
	var out := []
	for d in infractions():
		if not out.has(d.cat):
			out.append(d.cat)
	return out


func gav_possible() -> bool:
	# La garde à vue n'est possible que pour une infraction punie d'emprisonnement.
	return max_prison_months() > 0


func compute_gav_max() -> int:
	var h := 0
	for d in infractions():
		h = max(h, d.gav)
	if h == 0 and gav_possible():
		h = 24
	# Prolongation au-delà de 24 h seulement si la peine encourue ≥ 1 an.
	if max_prison_months() < 12:
		h = min(h, 24)
	return h


func jurisdiction() -> Dictionary:
	var k := kind()
	var m := max_prison_months()
	if k == "X":
		if m > 240 or record == "recidive":
			return {"name": "Cour d'assises", "short": "assises", "judges": 3, "jury": 6,
				"accused": "accusé" + e(), "room": "Salle des assises"}
		return {"name": "Cour criminelle départementale", "short": "ccd", "judges": 5, "jury": 0,
			"accused": "accusé" + e(), "room": "Salle d'audience criminelle"}
	if k == "D":
		return {"name": "Tribunal correctionnel", "short": "correctionnel", "judges": 3, "jury": 0,
			"accused": "prévenu" + e(), "room": "Chambre des comparutions immédiates"}
	return {"name": "Tribunal de police", "short": "police", "judges": 1, "jury": 0,
		"accused": "prévenu" + e(), "room": "Tribunal de police"}


func charges_sentence() -> String:
	var parts := []
	for d in infractions():
		parts.append(lcfirst(d.name))
	if parts.size() <= 1:
		return parts[0] if parts.size() == 1 else ""
	return ", ".join(parts.slice(0, parts.size() - 1)) + " et " + parts[-1]


func facts_text() -> String:
	var parts := []
	for d in infractions():
		parts.append("d'avoir " + d.facts)
	return " ; ".join(parts)


# ── Horloge ──────────────────────────────────────────────────────────────────
func advance_minutes(m: float) -> void:
	clock_minutes += m
	clock_changed.emit()


func clock_hm() -> String:
	var t := int(clock_minutes) % (24 * 60)
	return "%02d:%02d" % [t / 60, t % 60]


func clock_day_index() -> int:
	return int(clock_minutes) / (24 * 60)


func date_label(extra_days: int = 0) -> String:
	var dt := _date_from_days(clock_day_index() + extra_days)
	return "%s %d %s %d" % [DAYS_FR[dt.wd], dt.d, MONTHS_FR[dt.m], dt.y]


func _date_from_days(days: int) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_dict(
		{"year": start_year, "month": start_month + 1, "day": start_day, "hour": 12})
	var dd := Time.get_datetime_dict_from_unix_time(unix + days * 86400)
	# weekday : 0 = dimanche dans Godot
	var wd: int = (int(dd.weekday) + 6) % 7
	return {"d": dd.day, "m": int(dd.month) - 1, "y": dd.year, "wd": wd}


func month_year_label(months_from_now: int) -> String:
	var dt := _date_from_days(clock_day_index())
	var m: int = dt.m + months_from_now
	var y: int = dt.y + m / 12
	m = m % 12
	return "%s %d" % [MONTHS_FR[m], y]


func gav_hours_elapsed() -> float:
	return (clock_minutes - gav_start_minutes) / 60.0


func addressee(f: bool) -> String:
	return "Madame la Présidente" if f else "Monsieur le Président"
