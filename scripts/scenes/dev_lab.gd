extends LevelBase
## Galerie de personnages (outil de développement) : --jl-scene=dev_lab


func _ready() -> void:
	setup_environment("court")
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	var floor_m := Mats.wood(Color(0.42, 0.28, 0.16), Color(0.24, 0.15, 0.08), 0.1, 0.32, "courtfloor")
	WB.box(self, Vector3(12, 0.2, 8), Vector3(0, -0.1, -2), floor_m)
	WB.box(self, Vector3(12, 4, 0.2), Vector3(0, 2, -4), Mats.panelling(Color(0.45, 0.29, 0.16), Color(0.26, 0.16, 0.08), "court"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var fill := WB.omni(self, Vector3(-2, 2.5, 2), Color(1, 0.9, 0.8), 1.2, 10)
	var roles := [["police", {"outfit": "police", "female": false, "seed": 1}],
		["magistrat", {"outfit": "magistrat", "female": true, "seed": 2, "age": 0.7}],
		["avocat", {"outfit": "avocat", "female": false, "seed": 3}],
		["civil", {"outfit": "civil", "female": true, "seed": 4}],
		["opj", {"outfit": "opj", "female": false, "seed": 5, "origin": "african"}],
		["civil", {"outfit": "civil", "female": false, "seed": 6, "age": 1.0}]]
	var cam := Camera3D.new()
	add_child(cam)
	var close_i := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--jl-close="):
			close_i = int(a.split("=")[1])
	var close := close_i >= 0
	for i in roles.size():
		var h := Human.create(roles[i][0], roles[i][1])
		add_child(h)
		h.position = Vector3(-3.75 + i * 1.5, 0, -1.5)
		h.rotation.y = PI
		h.look_target = cam
	if close:
		var x := -3.75 + close_i * 1.5
		cam.position = Vector3(x + 0.3, 1.62, -0.3)
		cam.fov = 22
		cam.look_at(Vector3(x, 1.52, -1.5))
	else:
		cam.position = Vector3(0, 1.35, 4.8)
		cam.fov = 55
		cam.look_at(Vector3(0, 1.0, -1.5))
	cam.current = true
