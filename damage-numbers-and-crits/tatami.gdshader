shader_type spatial;
#include "res://noise.gdshaderinc"
// Tatami: mats of woven rush, two to one, laid in a running bond. Each mat has fine straw
// ribs along its length, a dark cloth edge along both long sides, and a faint stitch of binding
// threads. The ribs are drawn from the world position, so the pattern holds still for any
// camera, and they fade out with distance instead of shimmering.
varying vec3 wpos;

uniform vec3 straw_colour : source_color = vec3(0.66, 0.64, 0.38);
uniform vec3 edge_colour : source_color = vec3(0.2, 0.24, 0.15);
uniform float mat_length = 1.8;
uniform float mat_width = 0.9;
uniform float edge_width = 0.034;
uniform float rib_per_metre = 64.0;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float row = floor(wpos.z / mat_width);
	float shifted = wpos.x + mod(row, 2.0) * mat_length * 0.5 + floor(row / 2.0) * 0.37;
	float col = floor(shifted / mat_length);
	float along = shifted - col * mat_length;
	float across = wpos.z - row * mat_width;
	float id = hash21(vec2(col, row));
	// Each mat sits a touch greener or yellower than its neighbours.
	vec3 straw = straw_colour * (0.9 + 0.2 * hash21(vec2(col + 7.0, row - 3.0)));
	straw = mix(straw, straw * vec3(0.9, 1.04, 0.86), id);
	// The ribs: one straw every 8 mm, each its own brightness, with the line wandering a little.
	float wander = vnoise(vec2(along * 2.2, row * 5.0 + col * 3.0)) * 0.006;
	float rib_coord = (across + wander) * rib_per_metre;
	float rib_id = floor(rib_coord);
	float rib_f = fract(rib_coord);
	float rib_bright = 0.82 + 0.3 * hash21(vec2(rib_id, col + row * 13.0));
	float profile = 0.5 + 0.5 * cos((rib_f - 0.5) * 6.2832 * 0.5);
	float aa = clamp(fwidth(rib_coord) * 1.2, 0.0, 1.0);
	float contrast = 1.0 - smoothstep(0.12, 0.5, aa);
	// Straw has a slight sheen along the grain, and a few darker dashes where it is bound.
	float dashes = smoothstep(0.7, 0.78, vnoise(vec2(along * 22.0, rib_id * 0.7)));
	vec3 colour = straw * mix(1.0, rib_bright * (0.85 + 0.15 * profile), contrast);
	colour *= 1.0 - 0.12 * dashes * contrast;
	colour *= 0.95 + 0.08 * fbm(vec2(along * 3.0, across * 3.0) + id * 11.0);
	// The cloth edge along both long sides, with a thin bright stitch beside it.
	float to_edge = min(across, mat_width - across);
	float edge = 1.0 - smoothstep(edge_width - 0.004, edge_width, to_edge);
	vec3 cloth = edge_colour * (0.85 + 0.3 * hash21(vec2(floor(along * 200.0), 3.0)) * contrast);
	colour = mix(colour, cloth, edge);
	float stitch = smoothstep(0.006, 0.0, abs(to_edge - edge_width - 0.007));
	colour = mix(colour, straw * 1.1, stitch * 0.45 * contrast);
	// The seam where two mats meet: a dark crack and a shaded lip.
	float to_end = min(along, mat_length - along);
	float seam = 1.0 - smoothstep(0.0, 0.011, to_end);
	colour *= 1.0 - 0.55 * seam;
	ALBEDO = colour;
	ROUGHNESS = mix(0.72, 0.9, edge);
	SPECULAR = 0.35;
	// Bump: the ribs and the lip of each mat, from the height's screen-space slope.
	float h = profile * 0.012 * contrast + seam * -0.5 + edge * 0.2;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.9 * grad);
}
