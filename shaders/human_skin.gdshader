// Peau humaine : teinte, lèvres, paupières, sourcils et barbe (masques cuits),
// pores en carte de normales, diffusion sous-surfacique.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 skin_tone : source_color = vec3(0.82, 0.62, 0.5);
uniform vec3 hair_color : source_color = vec3(0.12, 0.08, 0.05);
uniform vec3 lip_tint : source_color = vec3(0.72, 0.38, 0.38);
uniform float beard : hint_range(0.0, 1.0) = 0.0;
uniform float brow : hint_range(0.0, 1.5) = 1.0;
uniform float makeup : hint_range(0.0, 1.0) = 0.0;
uniform float aging : hint_range(0.0, 1.0) = 0.0;
uniform float flush : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cover = vec4(0.0);
uniform sampler2D masks : hint_default_black, filter_linear_mipmap;
uniform sampler2D beard_mask : hint_default_black, filter_linear_mipmap;
uniform sampler2D pores : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D variation : hint_default_white, filter_linear_mipmap, repeat_enable;

void vertex() {
	// rentre légèrement la peau sous les vêtements (évite qu'elle traverse le tissu)
	float k = clamp(dot(COLOR, cover), 0.0, 1.0);
	VERTEX -= NORMAL * 0.006 * k;
}

void fragment() {
	vec4 m = vec4(texture(masks, UV).rgb, texture(beard_mask, UV).r);
	float v = texture(variation, UV * 7.0).r;
	float v2 = texture(variation, UV * 1.3 + 0.37).r;
	vec3 base = skin_tone * (0.9 + 0.2 * v) * (0.94 + 0.12 * v2);
	base = mix(base, base * vec3(1.08, 0.88, 0.86), flush * 0.4);
	// lèvres
	vec3 lips = mix(base * lip_tint * 1.55, vec3(0.55, 0.12, 0.16), makeup * 0.6);
	base = mix(base, lips, clamp(m.r * 1.2, 0.0, 1.0));
	// paupières (plus sombres, fard léger si maquillage)
	base = mix(base, base * mix(vec3(0.86, 0.76, 0.76), vec3(0.55, 0.45, 0.5), makeup), m.g * 0.55);
	// sourcils
	base = mix(base, hair_color * 0.85, clamp(m.b * brow, 0.0, 1.0) * 0.92);
	// barbe naissante
	base = mix(base, base * 0.55 + hair_color * 0.3, m.a * beard * (0.55 + 0.45 * v));
	ALBEDO = base;
	ROUGHNESS = mix(mix(0.5, 0.62, aging), 0.32, m.r) + 0.08 * (v - 0.5);
	SPECULAR = 0.4;
	NORMAL_MAP = texture(pores, UV * 34.0).rgb;
	NORMAL_MAP_DEPTH = 0.45 + aging * 0.6;
	SSS_STRENGTH = 0.42;
	BACKLIGHT = skin_tone * vec3(0.5, 0.18, 0.1) * 0.25;
}
