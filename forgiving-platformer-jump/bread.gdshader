shader_type spatial;
#include "res://noise.gdshaderinc"
// Toast and pancakes: a golden crumb with soft pores and a darker crust edge. Everything is
// worked out from the slab's own position, so it needs no textures and no UVs.

uniform vec2 half_size = vec2(1.0, 1.0);
uniform float corner = 0.2;
uniform float kind = 0.0; // 0 toast, 1 pancake
uniform float seed = 0.0;
varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

float height(vec2 p) {
	float pores = smoothstep(0.58, 0.72, fbm(p * 7.5 + seed));
	float crumb = fbm(p * 22.0 + seed * 3.0);
	return crumb * 0.35 - pores * 0.8;
}

void fragment() {
	vec2 p = opos.xz;
	float inside = -sd_round_rect(p, half_size, corner); // distance in from the edge
	float top = smoothstep(0.55, 0.9, onrm.y);
	float broad = fbm(p * 1.4 + seed * 5.0);
	vec3 crumb;
	vec3 crust;
	if (kind < 0.5) {
		// Toasted: golden in the middle, browner towards the edge, with patchy browning.
		crumb = mix(vec3(0.99, 0.86, 0.58), vec3(0.93, 0.7, 0.36), smoothstep(0.4, 0.75, broad));
		crumb = mix(crumb, vec3(0.8, 0.5, 0.2), smoothstep(0.3, 0.03, inside) * 0.7);
		crumb = mix(crumb, vec3(0.6, 0.31, 0.1), smoothstep(0.1, 0.045, inside));
		crust = vec3(0.6, 0.31, 0.1) * (0.85 + 0.3 * fbm(p * 9.0));
	} else {
		// A pancake: pale gold with a deeper brown face and a pale edge.
		crumb = mix(vec3(0.96, 0.8, 0.5), vec3(0.78, 0.46, 0.18), smoothstep(0.3, 0.75, broad));
		crumb = mix(crumb, vec3(0.99, 0.88, 0.62), smoothstep(0.1, 0.0, inside) * 0.8);
		crust = vec3(0.95, 0.78, 0.5);
	}
	float edge = smoothstep(0.17, 0.05, inside);
	float side = 1.0 - top;
	float crust_mix = clamp(max(edge * (kind < 0.5 ? 1.0 : 0.0), side), 0.0, 1.0);
	float h = height(p * (kind < 0.5 ? 1.0 : 0.6));
	vec3 col = mix(crumb * (1.0 + h * 0.35), crust, crust_mix);
	ALBEDO = clamp(col, 0.0, 1.0);
	// A soft bump from the pores, on the top face only.
	vec2 e = vec2(0.004, 0.0);
	float k = top * 0.8 * (1.0 - crust_mix);
	vec3 bump = vec3(-(height(p + e.xy) - height(p - e.xy)), 0.0, -(height(p + e.yx) - height(p - e.yx))) * k;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump * 0.9, 0.0)).xyz);
	ROUGHNESS = mix(0.62, 0.9, crust_mix);
	SPECULAR = 0.35;
	// Warm light that bounces back out of the crumb keeps the shadows from going grey.
	EMISSION = ALBEDO * 0.05;
}
