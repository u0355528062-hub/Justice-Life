class_name LevelBase
extends Node3D
## Base commune des niveaux : environnement de rendu, joueur, HUD et horloge.

var player: FPSPlayer
var hud: HUD
var env: Environment
var world_env: WorldEnvironment
var clock_rate := 0.0
var _sdfgi_base := -1


func setup_environment(preset: String) -> void:
	env = Environment.new()
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.1
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.1
	env.sdfgi_energy = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.9, 0.9, 0.92)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	match preset:
		"police_night":
			env.background_color = Color(0.01, 0.015, 0.03)
			env.ambient_light_color = Color(0.25, 0.3, 0.4)
			env.ambient_light_energy = 0.12
			env.tonemap_exposure = 1.0
			env.adjustment_saturation = 0.85
			env.volumetric_fog_density = 0.018
		"van":
			env.background_color = Color(0.0, 0.0, 0.0)
			env.ambient_light_color = Color(0.3, 0.32, 0.4)
			env.ambient_light_energy = 0.05
			env.volumetric_fog_density = 0.03
			env.sdfgi_enabled = false
		"court":
			var sky := Sky.new()
			var sm := ProceduralSkyMaterial.new()
			sm.sky_top_color = Color(0.32, 0.45, 0.65)
			sm.sky_horizon_color = Color(0.75, 0.72, 0.68)
			sm.ground_horizon_color = Color(0.6, 0.55, 0.5)
			sm.sun_angle_max = 20.0
			sky.sky_material = sm
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.ambient_light_energy = 0.35
			env.tonemap_exposure = 1.05
			env.volumetric_fog_density = 0.02
			env.volumetric_fog_albedo = Color(1.0, 0.95, 0.88)
			env.adjustment_saturation = 0.95
		"prison":
			var sky2 := Sky.new()
			var sm2 := ProceduralSkyMaterial.new()
			sm2.sky_top_color = Color(0.45, 0.55, 0.7)
			sm2.sky_horizon_color = Color(0.7, 0.72, 0.75)
			sky2.sky_material = sm2
			env.sky = sky2
			env.background_mode = Environment.BG_SKY
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.5, 0.55, 0.6)
			env.ambient_light_energy = 0.12
			env.volumetric_fog_density = 0.025
			env.adjustment_saturation = 0.78
		"menu":
			env.background_color = Color(0.0, 0.0, 0.0)
			env.ambient_light_color = Color(0.4, 0.38, 0.35)
			env.ambient_light_energy = 0.08
			env.volumetric_fog_density = 0.035
			env.volumetric_fog_albedo = Color(1.0, 0.92, 0.8)
	apply_quality()
	if RenderingServer.get_rendering_device() == null:  # rendu Compatibility
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false
		env.ssil_enabled = false


## Applique le niveau de qualité choisi (menu pause) à l'environnement courant.
func apply_quality() -> void:
	if env == null:
		return
	var q := GameState.quality
	var full := RenderingServer.get_rendering_device() != null
	if _sdfgi_base < 0:
		_sdfgi_base = 1 if env.sdfgi_enabled else 0
	env.sdfgi_enabled = full and q == 0 and _sdfgi_base == 1
	env.ssil_enabled = full and q <= 1
	env.ssr_enabled = q <= 1
	env.volumetric_fog_enabled = full and q <= 1
	env.ssao_enabled = true
	get_viewport().scaling_3d_scale = 1.0 if q <= 1 else 0.77
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == 0 else Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if q == 0 else Viewport.SCREEN_SPACE_AA_FXAA


func spawn_player(pos: Vector3, yaw: float) -> FPSPlayer:
	player = FPSPlayer.new()
	player.name = "Player"
	add_child(player)
	player.teleport(pos, yaw)
	hud = HUD.new()
	add_child(hud)
	hud.player = player
	player.hud = hud
	return player


## Avance l'horloge de `hours` heures de jeu à la cadence « secondes par heure ».
## Le rappel optionnel reçoit l'avancement (0..1) à chaque image.
func run_clock(hours: float, seconds_per_hour: float, on_tick: Callable = Callable()) -> void:
	var total := hours * 60.0
	var done := 0.0
	while done < total:
		await get_tree().process_frame
		var dt := get_process_delta_time() * Devtools.time_mult
		var step: float = min(dt / seconds_per_hour * 60.0, total - done)
		done += step
		GameState.advance_minutes(step)
		if on_tick.is_valid():
			on_tick.call(done / total)


## Fait passer du temps « hors champ » rapidement (ellipse visible sur l'horloge).
func skip_time(minutes: float, dur: float = 1.2) -> void:
	var done := 0.0
	var t := 0.0
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		var target := minutes * clampf(t / dur, 0.0, 1.0)
		GameState.advance_minutes(target - done)
		done = target


func wait(sec: float) -> void:
	if Devtools.autoplay:
		sec = min(sec, 0.3)
	await get_tree().create_timer(sec).timeout


## Attend que le joueur utilise un objet interactif.
func wait_use(it: Interactable) -> void:
	it.enabled = true
	if Devtools.autoplay:
		await get_tree().create_timer(0.3).timeout
	else:
		await it.used
	it.enabled = false


## Attend que le joueur entre dans une zone.
func wait_zone(z: TriggerZone) -> void:
	if Devtools.autoplay:
		await get_tree().create_timer(0.3).timeout
		return
	if z.get_overlapping_bodies().any(func(b): return b is FPSPlayer):
		return
	await z.entered
