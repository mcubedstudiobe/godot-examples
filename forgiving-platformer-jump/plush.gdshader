shader_type spatial;
#include "res://plush_common.gdshaderinc"
// The solid plush. The glow on the edge of the fabric is Tibo's.

void fragment() {
	ALBEDO = plush_colour(UV);
	NORMAL_MAP = texture(normal_texture, UV).xyz;
	EMISSION = mix(vec3(1.0), ALBEDO, 0.75) * clamp(smoothstep(0.6, 0.7, fresnel(1.0, NORMAL, VIEW)) * NORMAL.y, 0.0, 1.0) * 2.0;
	EMISSION = mix(EMISSION, vec3(3.0), flash);
	ALBEDO = mix(ALBEDO, vec3(0.0), flash);
	ROUGHNESS = 0.7;
	SPECULAR = 0.8;
}
