shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 faction_color : source_color = vec4(0.2, 0.65, 1.0, 1.0);
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
	float spiral = sin(angle * 7.0 - time * 3.2 + radius * 14.0) * 0.5 + 0.5;
	float rim = smoothstep(0.58, 0.96, radius);
	float core = 1.0 - smoothstep(0.0, 0.72, radius);
	vec3 edge = faction_color.rgb * (0.7 + spiral * 0.55);
	ALBEDO = mix(edge, vec3(0.004, 0.006, 0.015), core);
	EMISSION = faction_color.rgb * rim * spiral * 0.18;
	ALPHA = 1.0 - smoothstep(0.965, 1.0, radius);
}
