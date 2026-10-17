class_name Mats
extends RefCounted
## Fabrique de matériaux (cache). Les surfaces architecturales utilisent le shader
## procédural ; personnages et objets utilisent StandardMaterial3D.

static var _cache := {}
static var _shader: Shader
static var _fabric_normal: NoiseTexture2D


static func surface(key: String, params: Dictionary) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	if _shader == null:
		_shader = load("res://shaders/surface.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	for p in params:
		var v = params[p]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		m.set_shader_parameter(p, v)
	_cache[key] = m
	return m


static func std(key: String, col: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m


static func emissive(key: String, col: Color, energy: float = 4.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_cache[key] = m
	return m


static func glass(key: String = "glass", tint: Color = Color(0.75, 0.85, 0.9, 0.12), rough: float = 0.04) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = 0.1
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


static func fabric_normal() -> NoiseTexture2D:
	if _fabric_normal == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.12
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 3.0
		t.noise = n
		_fabric_normal = t
	return _fabric_normal


static func cloth(key: String, col: Color, rough: float = 0.9) -> StandardMaterial3D:
	if _cache.has("cloth_" + key):
		return _cache["cloth_" + key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.normal_enabled = true
	m.normal_texture = fabric_normal()
	m.normal_scale = 0.35
	m.uv1_scale = Vector3(6, 6, 6)
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	_cache["cloth_" + key] = m
	return m


static func skin(col: Color) -> StandardMaterial3D:
	var key := "skin_%s" % col.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.52
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.45
	m.subsurf_scatter_skin_mode = true
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.8
	m.clearcoat_enabled = true
	m.clearcoat = 0.12
	m.clearcoat_roughness = 0.5
	_cache[key] = m
	return m


# ── Préréglages architecturaux ───────────────────────────────────────────────
static func wall_paint(col: Color, key: String = "") -> ShaderMaterial:
	return surface("paint_" + (key if key != "" else col.to_html()),
		{"pattern": 0, "albedo": col, "roughness_base": 0.82, "dirt": 0.35, "bump": 0.6, "scuff": 0.8, "scuff_height": 0.4})


static func concrete(col: Color = Color(0.55, 0.55, 0.53), key: String = "concrete") -> ShaderMaterial:
	return surface(key, {"pattern": 2, "albedo": col, "roughness_base": 0.88, "dirt": 0.5, "bump": 1.6, "scuff": 0.6})


static func tiles(col: Color, grout_col: Color, size: float = 0.3, rough: float = 0.28, key: String = "") -> ShaderMaterial:
	return surface("tiles_" + (key if key != "" else col.to_html()),
		{"pattern": 1, "albedo": col, "albedo2": col.darkened(0.1), "grout_color": grout_col, "scale": size,
		"roughness_base": rough, "grout": 0.004, "dirt": 0.3, "bump": 0.9})


static func wood(light: Color, dark: Color, plank: float = 0.18, rough: float = 0.45, key: String = "") -> ShaderMaterial:
	return surface("wood_" + (key if key != "" else light.to_html()),
		{"pattern": 3, "albedo": light, "albedo2": dark, "scale": plank, "roughness_base": rough, "dirt": 0.1, "bump": 0.8})


static func panelling(light: Color, dark: Color, key: String = "panel") -> ShaderMaterial:
	return surface("lambris_" + key,
		{"pattern": 7, "albedo": light, "albedo2": dark, "grout_color": dark.darkened(0.5), "scale": 0.6,
		"aspect": Vector2(1.6, 1.0), "grout": 0.012, "roughness_base": 0.42, "dirt": 0.08, "bump": 1.4})


static func metal(col: Color, rough: float = 0.35, metal_v: float = 0.9, key: String = "") -> ShaderMaterial:
	return surface("metal_" + (key if key != "" else col.to_html()),
		{"pattern": 4, "albedo": col, "roughness_base": rough, "metallic_base": metal_v, "dirt": 0.2, "bump": 0.4})


static func lino(col: Color, speck: Color, key: String = "") -> ShaderMaterial:
	return surface("lino_" + (key if key != "" else col.to_html()),
		{"pattern": 5, "albedo": col, "albedo2": speck, "roughness_base": 0.35, "dirt": 0.35, "bump": 0.3})


static func asphalt(wet_v: float = 0.8) -> ShaderMaterial:
	return surface("asphalt", {"pattern": 6, "albedo": Color(0.09, 0.09, 0.1), "roughness_base": 0.75,
		"wet": wet_v, "dirt": 0.2, "bump": 1.2})


static func fabric(col: Color, key: String = "") -> ShaderMaterial:
	return surface("fabric_" + (key if key != "" else col.to_html()),
		{"pattern": 8, "albedo": col, "roughness_base": 0.95, "dirt": 0.15, "bump": 0.5})
