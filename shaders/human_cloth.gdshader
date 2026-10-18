// Vêtements posés sur le « collant » MakeHuman : haut, manches, bas, longueur,
// textures de tissu procédurales (coton, maille, jean, toile, chemise), ceinture.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 top_color : source_color = vec3(0.3);
uniform vec3 bottom_color : source_color = vec3(0.12, 0.14, 0.2);
uniform float has_top = 1.0;
uniform float sleeves = 1.0;
uniform float has_bottom = 1.0;
uniform float long_pants = 1.0;
uniform int top_style = 0;     // 0 coton, 1 maille, 2 chemise, 3 uniforme, 4 sweat
uniform int bottom_style = 0;  // 0 pantalon, 1 jean, 2 jogging
uniform float belt = 1.0;
uniform vec3 belt_color : source_color = vec3(0.06, 0.05, 0.045);
uniform float wear = 0.3;

varying vec4 reg;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	reg = COLOR;
	VERTEX += NORMAL * 0.0025;
}

void fragment() {
	float top = (reg.r + reg.g * sleeves) * has_top;
	float bot = (reg.b + reg.a * long_pants) * has_bottom;
	if (max(top, bot) < 0.5) {
		discard;
	}
	bool is_top = top >= bot;
	vec2 p = UV2;
	vec3 col;
	float rough = 0.92;
	float h = 0.0;
	if (is_top) {
		col = top_color;
		if (top_style == 1) {          // maille
			float k = sin(p.x * 900.0 + sin(p.y * 1100.0) * 1.2) * sin(p.y * 1100.0);
			h = k * 0.5;
			col *= 0.92 + 0.08 * k;
		} else if (top_style == 2) {   // chemise : fil fin + boutonnière
			h = sin(p.x * 2600.0) * sin(p.y * 2600.0) * 0.3;
			rough = 0.8;
			float placket = smoothstep(0.012, 0.009, abs(p.x));
			float buttons = smoothstep(0.0055, 0.004, length(vec2(p.x, mod(p.y, 0.085) - 0.04)));
			col = mix(col, col * 0.92, placket * 0.5);
			col = mix(col, col * 0.75 + vec3(0.12), buttons * placket);
		} else if (top_style == 3) {   // uniforme : sergé
			h = sin((p.x + p.y) * 1800.0) * 0.4;
			rough = 0.85;
		} else if (top_style == 4) {   // sweat molletonné
			h = (vn(p * 900.0) - 0.5) * 0.6;
			col *= 0.94 + 0.12 * vn(p * 40.0);
		} else {
			h = sin(p.x * 2200.0) * sin(p.y * 2200.0) * 0.25;
		}
	} else {
		col = bottom_color;
		if (bottom_style == 1) {       // jean : sergé diagonal + délavage
			float tw = sin((p.x * 0.7 + p.y) * 2400.0);
			h = tw * 0.5;
			float fade = vn(p * vec2(6.0, 2.0)) * 0.5 + vn(p * 25.0) * 0.2;
			col = mix(col, col * 1.6 + vec3(0.05, 0.07, 0.1), fade * wear * 0.6);
			col *= 0.9 + 0.1 * tw;
			rough = 0.95;
		} else if (bottom_style == 2) {
			h = (vn(p * 900.0) - 0.5) * 0.5;
		} else {
			h = sin((p.x - p.y) * 1600.0) * 0.3;
			rough = 0.82;
		}
		// ceinture à la taille
		float waist = smoothstep(0.35, 0.5, reg.b) * smoothstep(0.35, 0.5, reg.r + 0.3) * belt;
		col = mix(col, belt_color, waist * 0.0);
	}
	// usure / plis larges
	float folds = vn(p * vec2(30.0, 9.0));
	col *= 0.9 + 0.14 * folds;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	vec3 n = normalize(vec3(dFdx(h) * 2.0, dFdy(h) * 2.0, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	BACKLIGHT = col * 0.15;
}
