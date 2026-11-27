shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// A soft round darkening, strongest in the middle and gone at the edge: where a floating platform
// shades the cocoa under it.

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	ALBEDO = vec3(0.1, 0.04, 0.02);
	ALPHA = pow(clamp(1.0 - d, 0.0, 1.0), 1.6) * 0.38;
}
