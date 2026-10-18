// Cheveux / barbe en couches (« shell texturing ») : chaque couche est une copie
// du maillage gonflée le long des normales, percée selon une densité de mèches.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

instance uniform float layer = 0.0;
instance uniform vec3 hair_color : source_color = vec3(0.1, 0.07, 0.05);
instance uniform float hair_len = 0.01;
instance uniform float density = 0.85;
instance uniform float coarse = 1.0;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

varying float edge;

void vertex() {
	edge = COLOR.r;
	float lift = layer * hair_len * (0.35 + 0.65 * edge);
	VERTEX += NORMAL * (lift + 0.0008);
	// les couches externes retombent un peu (gravité)
	VERTEX.y -= layer * layer * hair_len * 0.35;
}

void fragment() {
	vec2 cell = UV2 * vec2(1300.0, 1300.0 * coarse) / max(coarse, 0.3);
	float strand = h21(floor(cell));
	float thin = layer * 0.85 + (1.0 - edge) * 0.9;
	if (strand > density * (1.05 - thin)) {
		discard;
	}
	float shade = mix(0.45, 1.15, layer) * (0.85 + 0.3 * strand);
	ALBEDO = hair_color * shade;
	ROUGHNESS = 0.55;
	SPECULAR = 0.45;
	ANISOTROPY = 0.7;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = hair_color * 0.4;
}
