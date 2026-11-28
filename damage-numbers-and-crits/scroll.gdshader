shader_type spatial;
#include "res://noise.gdshaderinc"
// A hanging scroll: cream paper in a woven teal mount, with one brush circle painted on it in a
// single stroke. The stroke starts heavy and wet, thins out and dries into streaks, and stops
// short of closing. The quad is `size` metres.
varying vec2 metres;

uniform vec2 size = vec2(0.72, 1.7);
uniform vec3 paper_colour : source_color = vec3(0.93, 0.88, 0.74);
uniform vec3 mount_colour : source_color = vec3(0.13, 0.27, 0.3);
uniform vec3 ink_colour : source_color = vec3(0.04, 0.035, 0.04);

void vertex() {
	metres = vec2((UV.x - 0.5) * size.x, (0.5 - UV.y) * size.y);
}

void fragment() {
	vec2 inner_half = vec2(size.x * 0.5 - 0.075, size.y * 0.5 - 0.17);
	vec2 inner_centre = vec2(0.0, -0.05);
	vec2 q = abs(metres - inner_centre) - inner_half;
	float in_paper = 1.0 - smoothstep(-0.002, 0.002, max(q.x, q.y));
	// The mount: a woven cloth, and a thin gold-brown line around the paper.
	float weave = sin(metres.x * 900.0) * sin(metres.y * 900.0);
	vec3 mount = mount_colour * (0.9 + 0.06 * weave + 0.12 * vnoise(metres * 60.0));
	float edge_line = 1.0 - smoothstep(0.0, 0.004, abs(max(q.x, q.y) - 0.012));
	mount = mix(mount, vec3(0.7, 0.55, 0.25), edge_line * 0.7);
	vec3 paper = paper_colour * (0.9 + 0.14 * fbm(metres * 14.0)) * (0.94 + 0.08 * vnoise(metres * vec2(260.0, 30.0)));
	// The ink circle.
	vec2 c = metres - vec2(0.0, 0.1);
	float radius = 0.19;
	float angle = atan(c.y, c.x);
	float turn = fract((angle + 3.14159 * 0.65) / 6.2831853);
	float length_ = 0.93;
	float along = turn / length_;
	float thickness = mix(0.034, 0.008, pow(along, 1.4)) * (0.8 + 0.4 * vnoise(vec2(angle * 3.0, 4.0)));
	float dist = abs(length(c) - radius - 0.006 * sin(angle * 2.0 + 1.0));
	float stroke = 1.0 - smoothstep(thickness - 0.004, thickness, dist);
	float dry = mix(1.0, 0.45 + 0.55 * vnoise(vec2(dist * 700.0, angle * 40.0)), smoothstep(0.35, 1.0, along));
	stroke *= step(turn, length_) * dry;
	vec3 colour = mix(mount, mix(paper, ink_colour, clamp(stroke * 0.96, 0.0, 1.0)), in_paper);
	ALBEDO = colour;
	ROUGHNESS = 0.9;
}
