shader_type spatial;
#include "res://noise.gdshaderinc"
render_mode diffuse_burley;
// Leafy blobs for the hedge and the tree: dappled greens, lighter on top, with a little light
// coming through at the edges. Works on any smooth sphere.
varying vec3 obj;
varying vec3 world_pos;

uniform vec3 deep : source_color = vec3(0.09, 0.28, 0.08);
uniform vec3 light : source_color = vec3(0.42, 0.66, 0.16);

void vertex() {
	obj = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float leaves = fbm(world_pos.xy * 7.0 + world_pos.zz * 3.0);
	float fine = vnoise(world_pos.xy * 34.0 + world_pos.zz * 13.0);
	vec3 colour = mix(deep, light, clamp(leaves * 1.2 + world_pos.y * 0.05 + fine * 0.25 - 0.1, 0.0, 1.0));
	ALBEDO = colour;
	ROUGHNESS = 0.85;
	BACKLIGHT = light * 0.25;
}
