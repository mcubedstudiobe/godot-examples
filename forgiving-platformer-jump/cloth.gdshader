shader_type spatial;
#include "res://noise.gdshaderinc"
// A gingham tablecloth, soft red checks over cream, with a faint weave. The checks are filtered by
// how much of the cloth one pixel covers, so they stay smooth at a flat angle instead of breaking
// into blocks.
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// A square wave of period 1, softened over the width of a pixel.
float checker(float x) {
	float w = fwidth(x) * 0.75 + 0.02;
	return smoothstep(0.5 - w, 0.5 + w, abs(fract(x * 0.5) - 0.5) * 2.0);
}

void fragment() {
	vec2 g = world_pos.xz / 1.6;
	float a = checker(g.x);
	float b = checker(g.y);
	float checks = (a + b) * 0.5; // 0 cream, 0.5 light red, 1 dark red
	vec3 cream = vec3(0.92, 0.8, 0.66);
	vec3 red = vec3(0.86, 0.5, 0.42);
	vec3 pattern = mix(cream, red, checks);
	float far = smoothstep(14.0, 40.0, length(VERTEX));
	ALBEDO = mix(pattern, mix(cream, red, 0.3), far) * (0.95 + 0.05 * vnoise(world_pos.xz * 4.0)) * 0.6;
	ROUGHNESS = 0.9;
}
