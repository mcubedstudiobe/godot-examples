shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://noise.gdshaderinc"
// The morning kitchen behind the table: a warm wall that is lighter at the top, a window's glow to
// one side, and soft round lights scattered through the haze. It is drawn flat; the camera's blur
// turns the lights into the soft discs of a defocused background.

uniform vec3 low_colour : source_color = vec3(0.95, 0.72, 0.56);
uniform vec3 high_colour : source_color = vec3(1.0, 0.92, 0.78);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xy;
	float up = smoothstep(-4.0, 22.0, p.y);
	vec3 col = mix(low_colour, high_colour, up);
	// The window: a big soft blob of light up and to the left.
	float window = exp(-length((p - vec2(-6.0, 12.0)) * vec2(0.09, 0.07)) * 2.4);
	col += vec3(1.0, 0.92, 0.75) * window * 0.35;
	// Soft round lights: one per cell, in a random place, some bigger than others.
	vec2 cell = floor(p / 4.2);
	float glints = 0.0;
	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			float r = hash21(c + 7.0);
			vec2 centre = (c + vec2(hash21(c + 1.3), hash21(c + 5.1))) * 4.2;
			float radius = 0.7 + 1.1 * hash21(c + 9.7);
			float d = length(p - centre);
			glints += smoothstep(radius, radius * 0.7, d) * step(0.45, r) * (0.18 + 0.2 * hash21(c + 3.3));
		}
	}
	col += vec3(1.0, 0.9, 0.7) * glints;
	ALBEDO = col;
}
