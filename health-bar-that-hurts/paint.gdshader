shader_type spatial;
#include "res://noise.gdshaderinc"
// Painted wood: a coat of paint over visible grain, with a few chips near the edges.
varying vec3 obj;

uniform vec3 paint_colour : source_color = vec3(0.96, 0.94, 0.88);
uniform vec3 wood_colour : source_color = vec3(0.55, 0.38, 0.22);
uniform float grain_scale = 22.0;
uniform float wear = 0.5;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float grain = fbm(vec2(obj.x * 6.0, obj.y * grain_scale));
	vec3 colour = paint_colour * (0.9 + 0.12 * grain);
	float chip = smoothstep(0.78 - wear * 0.1, 0.8, fbm(vec2(obj.x, obj.y) * 14.0 + 5.0));
	colour = mix(colour, wood_colour * (0.7 + 0.5 * grain), chip * wear);
	ALBEDO = colour;
	ROUGHNESS = 0.7;
}
