shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
#include "res://plush_common.gdshaderinc"
// The strict ghost: the same plush, pale cyan and see-through, with a cool glow on its edge. Its
// eyes and face stay dark so it reads at a glance. It is drawn after ghost_depth.gdshader, which
// keeps only its nearest surface.

uniform float opacity = 0.62;
uniform vec3 tint : source_color = vec3(0.66, 0.93, 1.0);
uniform vec3 glow : source_color = vec3(0.35, 0.85, 1.0);

void fragment() {
	vec3 base = plush_colour(UV);
	NORMAL_MAP = texture(normal_texture, UV).xyz;
	float rim = fresnel(2.2, NORMAL, VIEW);
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	float dark = 1.0 - smoothstep(0.12, 0.4, lum);
	ALBEDO = mix(mix(base, tint, 0.55), base * 0.5, dark);
	EMISSION = glow * (0.18 + 1.3 * rim) + mix(vec3(0.0), vec3(3.0), flash);
	ROUGHNESS = 0.7;
	SPECULAR = 0.5;
	ALPHA = clamp(max(opacity, dark * 0.95) + rim * 0.35, 0.0, 1.0);
}
