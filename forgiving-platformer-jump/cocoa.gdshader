shader_type spatial;
#include "res://noise.gdshaderinc"
render_mode specular_schlick_ggx;
// Hot cocoa: a creamy milk-chocolate surface, glossy, with slow ripples, drifting swirls of milk
// and a soft cream foam where it meets the bowl. The ripples are a few travelling waves whose slope
// is worked out exactly, so the surface is smooth at any distance, with no mesh facets. The sky and
// the platforms are reflected off it by the engine.

uniform vec3 deep : source_color = vec3(0.2, 0.105, 0.065);
uniform vec3 milk : source_color = vec3(0.42, 0.27, 0.18);
uniform vec3 foam : source_color = vec3(0.93, 0.82, 0.68);
uniform vec2 bowl_centre = vec2(0.0, -2.0);
uniform float bowl_radius = 10.3;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The slope (d/dx, d/dz) of one wave of the given direction, wavelength and speed.
vec2 wave(vec2 p, vec2 dir, float wavelength, float amplitude, float speed) {
	float k = 6.2831853 / wavelength;
	float phase = dot(p, normalize(dir)) * k + TIME * speed;
	return normalize(dir) * cos(phase) * amplitude * k;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Warp the phase a little so no two waves line up into a grid.
	vec2 q = p + vec2(sin(p.y * 0.31 + TIME * 0.1), cos(p.x * 0.27 - TIME * 0.08)) * 0.9;
	vec2 slope = wave(q, vec2(1.0, 0.35), 3.7, 0.008, 0.6)
			+ wave(q, vec2(0.45, 1.0), 2.3, 0.005, 0.8)
			+ wave(q, vec2(-0.9, 0.55), 1.55, 0.003, 1.0)
			+ wave(q, vec2(0.2, -1.0), 0.95, 0.0018, 1.3);
	float dist_fade = clamp(1.0 - length(VERTEX) / 60.0, 0.35, 1.0);
	slope *= dist_fade;
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float crest = clamp(length(slope) * 6.0, 0.0, 1.0);
	// Slow swirls of milk drifting through the cocoa.
	float swirl = vnoise(q * 0.22 + vec2(TIME * 0.02, 0.0)) * 0.6 + vnoise(q * 0.6 - vec2(0.0, TIME * 0.03)) * 0.4;
	vec3 base = mix(deep, milk, smoothstep(0.4, 0.8, swirl) * 0.6);
	base = mix(base, milk, crest * 0.4);
	// Cream foam along the bowl's edge, broken up by a little noise.
	float r = length(p - bowl_centre);
	float edge = smoothstep(bowl_radius - 1.6 + 0.8 * vnoise(p * 0.9), bowl_radius - 0.1, r);
	base = mix(base, foam, edge * 0.9);
	ALBEDO = base;
	ROUGHNESS = mix(0.1, 0.5, edge);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0, 0.78, 0.55) * fres * 0.12 + deep * 0.35;
}
