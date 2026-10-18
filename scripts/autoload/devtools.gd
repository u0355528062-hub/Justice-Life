extends Node
## Outils de développement :
##   F9  : accélère le temps ×10 (test)        F12 : capture d'écran (user://captures)
## Ligne de commande (tests automatisés) :
##   godot -- --jl-scene=commissariat --jl-preset=delit --jl-autoplay --jl-shots=/dossier --jl-every=4 --jl-quit=60

var time_mult := 1.0
var autoplay := false
var _shots_dir := ""
var _shot_every := 0.0
var _shot_t := 0.0
var _shot_n := 0
var _quit_at := 0.0
var _elapsed := 0.0
var _choice_policy := "first"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--jl-"):
			var kv := a.substr(5).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.is_empty():
		return
	autoplay = args.has("autoplay")
	_choice_policy = args.get("policy", "first")
	_shots_dir = args.get("shots", "")
	_shot_every = float(args.get("every", "0"))
	_quit_at = float(args.get("quit", "0"))
	time_mult = float(args.get("speed", "1"))
	if args.has("preset"):
		_apply_preset(args.preset)
	if args.has("load"):
		print("Sauvegarde chargée : ", GameState.load_detention(), " — ", GameState.save_summary())
	if args.has("scene"):
		var p := "res://scenes/%s.tscn" % args.scene
		get_tree().change_scene_to_file.call_deferred(p)


func choose(n: int) -> int:
	match _choice_policy:
		"last": return n - 1
		"random": return randi() % n
		"second": return min(1, n - 1)
	return 0


func _apply_preset(p: String) -> void:
	GameState.random_identity()
	match p:
		"contravention":
			GameState.selected = ["tapage", "ivresse_publique"]
		"crime":
			GameState.selected = ["vol_main_armee", "detention_arme_b"]
		"lourd":
			GameState.selected = ["trafic_stup", "association_malfaiteurs", "refus_obtemperer_aggrave"]
			GameState.record = "recidive"
		_:
			GameState.selected = ["vol_violence", "outrage_agent"]
			GameState.record = "antecedents"
	GameState.reset_procedure()


func _process(delta: float) -> void:
	_elapsed += delta
	if _shots_dir != "" and _shot_every > 0.0:
		_shot_t += delta
		if _shot_t >= _shot_every:
			_shot_t = 0.0
			capture(_shots_dir.path_join("shot_%03d.png" % _shot_n))
			_shot_n += 1
	if _quit_at > 0.0 and _elapsed >= _quit_at:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			time_mult = 10.0 if time_mult == 1.0 else 1.0
		elif event.keycode == KEY_F12:
			DirAccess.make_dir_recursive_absolute("user://captures")
			capture("user://captures/%d.png" % Time.get_ticks_msec())


func capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
