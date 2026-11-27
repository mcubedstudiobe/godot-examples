shader_type spatial;
#include "res://noise.gdshaderinc"
// A waffle: a grid of square pockets between raised ridges, golden on the ridges and toasted
// deep in the pockets, with a little glossy syrup left in them. The surface is worked out from the
// slab's own position, and the pocket walls are lit with a normal taken from the profile's slope.

uniform vec2 half_size = vec2(1.0, 1.0);
uniform float corner = 0.2;
uniform float cell = 0.3;
uniform float seed = 0.0;
varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

// 0 on a ridge, 1 in the middle of a pocket: a smooth step down over the pocket wall.
float profile(float r) {
	return smoothstep(0.43, 0.3, r);
}

void fragment() {
	vec2 p = opos.xz;
	float inside = -sd_round_rect(p, half_size, corner);
	float top = smoothstep(0.55, 0.9, onrm.y);
	vec2 g = p / cell;
	vec2 f = fract(g) - 0.5;
	float r = max(abs(f.x), abs(f.y));
	float pocket = profile(r) * top;
	// The wall slopes towards the pocket's centre: the normal leans along the dominant axis.
	float slope = (profile(r + 0.01) - profile(r - 0.01)) / 0.02; // negative on the wall
	vec2 lean = abs(f.x) > abs(f.y) ? vec2(sign(f.x), 0.0) : vec2(0.0, sign(f.y));
	vec3 bump = vec3(lean.x, 0.0, lean.y) * slope * 0.14 * top;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
	float broad = fbm(p * 1.7 + seed * 7.0);
	vec3 ridge_col = mix(vec3(0.96, 0.74, 0.38), vec3(0.88, 0.56, 0.22), smoothstep(0.3, 0.7, broad));
	vec3 pocket_col = mix(vec3(0.78, 0.45, 0.16), vec3(0.55, 0.27, 0.08), smoothstep(0.3, 0.8, broad));
	vec3 col = mix(ridge_col, pocket_col, pocket);
	// The crust: the sides and the very edge, a deeper brown.
	float edge = smoothstep(0.1, 0.0, inside);
	col = mix(col, vec3(0.5, 0.26, 0.09), max(edge * 0.8, 1.0 - top));
	// Ambient occlusion in the corners of the pockets.
	col *= 1.0 - 0.32 * pocket * smoothstep(0.1, 0.32, r);
	// Syrup pooled in some of the pockets: darker amber and glossy, with a bright glint.
	float syrup = pocket * smoothstep(0.52, 0.66, fbm(p * 2.2 + seed * 3.0 + 4.0));
	col = mix(col, vec3(0.62, 0.28, 0.05), syrup * 0.75);
	ALBEDO = col;
	ROUGHNESS = mix(0.7, 0.07, syrup);
	SPECULAR = mix(0.5, 0.9, syrup);
	EMISSION = col * 0.05;
}
