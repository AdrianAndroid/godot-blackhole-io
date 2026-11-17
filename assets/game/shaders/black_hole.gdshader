shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 faction_color : source_color = vec4(0.028, 0.34, 0.965, 1.0);
uniform float animation_time = -1.0;

varying vec2 hole_uv;

void vertex() {
	hole_uv = UV;
}

void fragment() {
	vec2 centered = (hole_uv - vec2(0.5)) * 2.0;
	float radius = length(centered);
	if (radius > 1.0) {
		discard;
	}
	float angle = atan(centered.y, centered.x);
	float time = animation_time >= 0.0 ? animation_time : TIME;
	float inner_wall = smoothstep(0.42, 0.84, radius);
	float rim = smoothstep(0.76, 0.91, radius);
	float hot_edge = smoothstep(0.91, 0.965, radius) * (1.0 - smoothstep(0.975, 1.0, radius));
	float shimmer = 0.92 + 0.08 * sin(angle * 5.0 + time * 1.4);
	vec3 core = mix(vec3(0.001, 0.002, 0.006), faction_color.rgb * 0.085, inner_wall);
	vec3 edge = faction_color.rgb * (0.62 + hot_edge * 0.45) * shimmer;
	vec3 cyan_edge = vec3(0.01, 0.18, 1.0) * hot_edge;
	ALBEDO = mix(core, edge + cyan_edge, rim);
	EMISSION = faction_color.rgb * (rim * 0.15 + hot_edge * 0.28) + cyan_edge * 0.15;
	ALPHA = 1.0 - smoothstep(0.985, 1.0, radius);
}
