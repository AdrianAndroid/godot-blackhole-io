shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 faction_color : source_color = vec4(0.2, 0.65, 1.0, 1.0);
uniform float strength = 1.0;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float halo = (1.0 - smoothstep(0.48, 1.0, radius)) * smoothstep(0.28, 0.60, radius);
	ALBEDO = faction_color.rgb;
	EMISSION = faction_color.rgb * 0.7;
	ALPHA = halo * 0.24 * strength;
}
