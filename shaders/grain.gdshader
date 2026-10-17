// Grain de film animé.
shader_type canvas_item;
uniform float amount : hint_range(0.0, 0.2) = 0.045;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = floor(FRAGCOORD.xy / 1.5);
	float n = h(p + fract(TIME * 7.13) * 917.0);
	COLOR = vec4(vec3(n), amount);
}
