shader_type canvas_item;

uniform vec2 light_center = vec2(640.0, 360.0);
uniform float light_radius : hint_range(32.0, 420.0) = 165.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.91;

void fragment() {
	float distance_to_light = distance(FRAGCOORD.xy, light_center) / max(light_radius, 1.0);
	float visibility = smoothstep(0.72, 1.08, distance_to_light);
	float flicker = 1.0 + sin(TIME * 7.0) * 0.018;
	COLOR = vec4(0.005, 0.012, 0.018, darkness * visibility * flicker);
}