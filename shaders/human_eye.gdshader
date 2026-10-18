// Œil : sclérotique, iris fibreux, anneau limbique, pupille, cornée humide.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 iris_color : source_color = vec3(0.25, 0.16, 0.08);
uniform float iris_size = 0.52;
uniform float pupil = 0.2;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = UV2;
	float d = length(p);
	vec3 sclera = vec3(0.93, 0.9, 0.87);
	if (d > 3.0) {
		ALBEDO = sclera * 0.8;
		ROUGHNESS = 0.3;
	} else {
		float a = atan(p.y, p.x);
		float fib = 0.5 + 0.5 * sin(a * 60.0 + h21(vec2(floor(a * 30.0))) * 6.0);
		vec3 iris = iris_color * (0.6 + 0.7 * fib * smoothstep(pupil, iris_size, d));
		iris = mix(iris * 1.6, iris, smoothstep(pupil, pupil + 0.15, d));
		float ring = smoothstep(iris_size - 0.08, iris_size, d);
		iris = mix(iris, iris * 0.25, ring);
		vec3 c = mix(iris, sclera, smoothstep(iris_size - 0.01, iris_size + 0.02, d));
		c = mix(vec3(0.01), c, smoothstep(pupil - 0.02, pupil + 0.01, d));
		// veines légères en périphérie
		c = mix(c, vec3(0.85, 0.6, 0.58), smoothstep(0.75, 1.0, d) * 0.35);
		ALBEDO = c;
		ROUGHNESS = 0.04;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.02;
	}
	SPECULAR = 0.8;
}
