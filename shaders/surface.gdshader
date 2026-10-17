// Surfaces procédurales PBR en projection monde (triplanaire dominante).
// Aucune texture requise : carrelage, béton, bois, peinture, métal brossé, lino, asphalte mouillé.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.7);
uniform vec3 albedo2 : source_color = vec3(0.5);
uniform vec3 grout_color : source_color = vec3(0.35);
uniform int pattern = 0; // 0 peinture, 1 carrelage, 2 béton, 3 bois, 4 métal, 5 lino, 6 asphalte, 7 lambris, 8 tissu
uniform float scale = 0.3;
uniform vec2 aspect = vec2(1.0, 1.0);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.7;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.0;
uniform float dirt : hint_range(0.0, 1.0) = 0.25;
uniform float bump : hint_range(0.0, 4.0) = 1.0;
uniform float grout = 0.004;
uniform float checker = 0.0;
uniform float wet = 0.0;
uniform float scuff_height = 0.35;
uniform float scuff = 0.0;
uniform float rotate_uv = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}
float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.1 + vec2(3.1, 1.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Évalue la surface : couleur, hauteur, rugosité, métal
void surf(vec2 uv, float y, out vec3 col, out float h, out float r, out float m) {
	m = metallic_base;
	r = roughness_base;
	col = albedo;
	h = 0.0;
	if (pattern == 0) {
		// Peinture sur plâtre
		float n = fbm(uv * 2.2);
		col = albedo * (0.94 + 0.1 * n);
		h = vnoise(uv * 180.0) * 0.15 + fbm3(uv * 30.0) * 0.25;
		r = roughness_base + 0.08 * (n - 0.5);
	} else if (pattern == 1 || pattern == 7) {
		// Carrelage (1) ou lambris bois (7)
		vec2 c = uv / (scale * aspect);
		if (pattern == 7) { c.x += step(1.0, mod(floor(c.y), 2.0)) * 0.5; }
		vec2 id = floor(c);
		vec2 f = fract(c);
		vec2 gw = grout / (scale * aspect);
		float ex = min(f.x, 1.0 - f.x) / gw.x;
		float ey = min(f.y, 1.0 - f.y) / gw.y;
		float g = 1.0 - smoothstep(0.6, 1.4, min(ex, ey));
		float tv = hash(id);
		vec3 tcol = mix(albedo, albedo2, checker * mod(id.x + id.y, 2.0));
		if (pattern == 7) {
			float grain = sin((uv.x * 3.0 + fbm(uv * vec2(1.5, 14.0) + tv * 10.0) * 4.0) * 6.2831 * 2.0);
			tcol = mix(albedo, albedo2, 0.5 + 0.35 * grain + 0.2 * (tv - 0.5));
		} else {
			tcol *= 0.93 + 0.12 * tv;
		}
		col = mix(tcol, grout_color, g);
		float bev = smoothstep(0.0, 3.0, min(ex, ey));
		h = bev * 0.8 + vnoise(uv * 90.0) * 0.05;
		r = mix(roughness_base * (0.85 + 0.3 * tv), 0.95, g);
	} else if (pattern == 2) {
		// Béton
		float n = fbm(uv * 1.3);
		float spots = smoothstep(0.62, 0.7, fbm(uv * 6.0 + 4.0));
		col = albedo * (0.72 + 0.42 * n) * (1.0 - 0.18 * spots);
		h = fbm(uv * 14.0) * 0.6 + vnoise(uv * 120.0) * 0.25 - spots * 0.3;
		r = roughness_base + 0.1 * (n - 0.5);
	} else if (pattern == 3) {
		// Bois massif (veinage)
		vec2 c = uv / (scale * aspect);
		float plank = floor(c.y);
		float pv = hash(vec2(plank, 3.0));
		float seam = 1.0 - smoothstep(0.0, 0.04, min(fract(c.y), 1.0 - fract(c.y)));
		float rings = fbm(vec2(uv.x * 0.8 + pv * 20.0, uv.y * 9.0)) * 6.0;
		float grain = 0.5 + 0.5 * sin((uv.y * 18.0 + rings) * 3.14159);
		float fine = vnoise(vec2(uv.x * 4.0, uv.y * 260.0));
		col = mix(albedo2, albedo, grain * 0.7 + fine * 0.3) * (0.88 + 0.24 * pv);
		col *= 1.0 - seam * 0.55;
		h = grain * 0.15 + fine * 0.1 - seam * 0.5;
		r = roughness_base + 0.06 * fine;
	} else if (pattern == 4) {
		// Métal brossé / peint
		float br = vnoise(vec2(uv.x * 2.0, uv.y * 420.0));
		float n = fbm(uv * 3.0);
		col = albedo * (0.9 + 0.15 * n);
		h = br * 0.1;
		r = roughness_base + 0.12 * (br - 0.5) + 0.1 * smoothstep(0.6, 0.8, n);
	} else if (pattern == 5) {
		// Linoléum moucheté
		float n = fbm(uv * 1.5);
		float sp = step(0.86, hash(floor(uv * 160.0)));
		float sp2 = step(0.93, hash(floor(uv * 110.0) + 7.0));
		col = albedo * (0.92 + 0.12 * n);
		col = mix(col, albedo2, sp * 0.6);
		col = mix(col, vec3(0.9), sp2 * 0.25);
		h = vnoise(uv * 80.0) * 0.1;
		r = roughness_base + 0.1 * (n - 0.5);
	} else if (pattern == 6) {
		// Asphalte (mouillé si wet > 0)
		float n = fbm(uv * 0.6);
		float g = hash(floor(uv * 260.0));
		float puddle = smoothstep(0.52, 0.6, fbm(uv * 0.35 + 11.0)) * wet;
		col = albedo * (0.7 + 0.5 * n) * (0.85 + 0.3 * g);
		col *= 1.0 - puddle * 0.55;
		h = g * 0.5 + fbm3(uv * 8.0) * 0.4;
		h *= 1.0 - puddle;
		r = mix(roughness_base, 0.03, puddle);
		r = mix(r, r * 0.55, wet);
	} else if (pattern == 8) {
		// Tissu (trame croisée)
		vec2 c = uv * 260.0;
		float wv = sin(c.x) * sin(c.y);
		float n = fbm(uv * 4.0);
		col = albedo * (0.9 + 0.12 * n + 0.05 * wv);
		h = wv * 0.3;
		r = roughness_base;
	}
	// Salissures larges
	float d = smoothstep(0.45, 0.85, fbm(uv * 0.45 + 17.0));
	col *= 1.0 - dirt * 0.3 * d;
	r = clamp(r + dirt * 0.1 * d, 0.02, 1.0);
	// Traces au bas des murs (plinthes usées)
	float sc = (1.0 - smoothstep(0.0, scuff_height, y)) * scuff;
	col *= 1.0 - 0.35 * sc * (0.6 + 0.4 * fbm(uv * 8.0));
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 an = abs(n);
	vec2 uv;
	vec3 T;
	vec3 B;
	if (an.y > an.x && an.y > an.z) {
		uv = wpos.xz; T = vec3(1.0, 0.0, 0.0); B = vec3(0.0, 0.0, 1.0);
	} else if (an.x > an.z) {
		uv = wpos.zy; T = vec3(0.0, 0.0, 1.0); B = vec3(0.0, 1.0, 0.0);
	} else {
		uv = wpos.xy; T = vec3(1.0, 0.0, 0.0); B = vec3(0.0, 1.0, 0.0);
	}
	if (rotate_uv > 0.5) { uv = uv.yx; vec3 tmp = T; T = B; B = tmp; }
	vec3 col;
	float h;
	float r;
	float m;
	surf(uv, wpos.y, col, h, r, m);
	float e = 0.0015;
	vec3 c2; float h2; float r2; float m2;
	surf(uv + vec2(e, 0.0), wpos.y, c2, h2, r2, m2);
	vec3 c3; float h3; float r3; float m3;
	surf(uv + vec2(0.0, e), wpos.y, c3, h3, r3, m3);
	float k = bump * 0.0025 / e;
	vec3 pn = normalize(n - k * ((h2 - h) * T + (h3 - h) * B));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = r;
	METALLIC = m;
	SPECULAR = 0.5;
}
