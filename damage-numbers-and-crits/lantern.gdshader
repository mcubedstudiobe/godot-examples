shader_type spatial;
#include "res://noise.gdshaderinc"
// A paper lantern: a glowing shell of thin paper over bamboo ribs. The ribs are horizontal
// rings, darker and dimmer than the paper between them. The paper glows from inside, a little
// brighter near the middle, and the edge seen at a glancing angle is a touch deeper in colour.
varying vec3 obj;

uniform vec3 paper_colour : source_color = vec3(1.0, 0.5, 0.18);
uniform float energy = 3.2;
uniform float rib_spacing = 0.075;
uniform float flicker = 0.0;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float rib_f = abs(fract(obj.y / rib_spacing + 0.5) - 0.5);
	float aa = fwidth(obj.y / rib_spacing);
	float rib = 1.0 - smoothstep(0.03, 0.03 + max(0.05, aa), rib_f);
	float fibre = vnoise(vec2(atan(obj.x, obj.z) * 22.0, obj.y * 60.0));
	float belly = 1.0 - clamp(abs(obj.y) / 0.5, 0.0, 1.0);
	vec3 colour = paper_colour * (0.88 + 0.2 * fibre);
	colour = mix(colour, colour * 0.35, rib);
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = colour * 0.55;
	ROUGHNESS = 0.8;
	EMISSION = colour * energy * (0.65 + 0.5 * belly) * (1.0 - 0.45 * rib) * (1.0 - 0.25 * edge) * (1.0 + flicker);
}
