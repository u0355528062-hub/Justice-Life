// Vignettage cinématographique + pulsation de stress (rouge) en surimpression.
shader_type canvas_item;
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float stress : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 c = (uv - 0.5) * vec2(1.6, 1.0);
	float d = length(c);
	float v = smoothstep(0.42, 1.05, d) * vignette;
	float pulse = stress * (0.55 + 0.45 * sin(TIME * (5.0 + stress * 3.0)));
	vec3 col = mix(vec3(0.0), vec3(0.28, 0.0, 0.01), clamp(pulse * 1.2, 0.0, 1.0));
	float a = clamp(v + pulse * 0.35 * smoothstep(0.2, 1.0, d), 0.0, 1.0);
	col = mix(col, vec3(1.0), flash);
	a = max(a, flash);
	COLOR = vec4(col, a);
}
