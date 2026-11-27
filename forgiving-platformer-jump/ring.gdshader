shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// An expanding ripple on the cocoa: a soft ring that widens and fades.
uniform float progress = 0.0;
uniform vec3 tint : source_color = vec3(0.95, 0.78, 0.6);

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = progress;
	float width = 0.05 + 0.06 * progress;
	float ring = exp(-pow((d - r) / width, 2.0));
	float inner = exp(-pow((d - r * 0.62) / (width * 1.2), 2.0)) * 0.5;
	ALBEDO = tint;
	ALPHA = (ring + inner) * (1.0 - progress) * 0.7 * step(d, 1.0);
}
