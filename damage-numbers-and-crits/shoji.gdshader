shader_type spatial;
#include "res://noise.gdshaderinc"
// A wall of shoji screens: paper in a lattice of dark wood, with a dusk glow behind the paper.
// The mesh is a flat quad of `size` metres. Every `panel_width` metres is a tall panel with a
// frame; inside it, the paper has vertical and horizontal bars, and the bottom of the panel is
// a solid wood board. The paper is lit by the room and also glows from behind.
varying vec2 metres;

uniform vec2 size = vec2(7.2, 2.6);
uniform float panel_width = 1.2;
uniform float board_height = 0.42;
uniform vec3 paper_colour : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 wood_colour : source_color = vec3(0.27, 0.16, 0.08);
uniform vec3 dusk_low : source_color = vec3(0.9, 0.42, 0.45);
uniform vec3 dusk_high : source_color = vec3(0.3, 0.36, 0.9);
uniform float glow = 0.35;

void vertex() {
	metres = vec2(UV.x * size.x, (1.0 - UV.y) * size.y);
}

float bar(float x, float period, float width) {
	float d = abs(fract(x / period + 0.5) - 0.5) * period;
	return 1.0 - smoothstep(width * 0.5 - 0.0015, width * 0.5 + 0.0015, d);
}

void fragment() {
	float px = mod(metres.x, panel_width);
	float y = metres.y;
	float frame = 0.0;
	frame = max(frame, 1.0 - smoothstep(0.034, 0.038, min(px, panel_width - px)));
	frame = max(frame, 1.0 - smoothstep(size.y - 0.07, size.y - 0.066, size.y - y));
	frame = max(frame, 1.0 - smoothstep(board_height - 0.003, board_height + 0.003, y));
	float bars = 0.0;
	bars = max(bars, bar(metres.x - 0.0, panel_width / 4.0, 0.03));
	float lattice_y = clamp((y - board_height) / (size.y - board_height), 0.0, 1.0);
	bars = max(bars, bar(lattice_y * 6.0, 1.0, 0.07));
	bars = max(bars, frame);
	// A thin top rail across the lattice and a lower rail above the board.
	bars *= step(board_height - 0.02, y);
	float board = 1.0 - step(board_height, y);
	float wood = max(bars, board);
	// The paper: fibres, slightly uneven in tone, with the lit side catching the light.
	float fibre = vnoise(vec2(metres.x * 180.0, metres.y * 24.0)) * 0.5 + vnoise(vec2(metres.x * 40.0, metres.y * 90.0)) * 0.5;
	vec3 paper = paper_colour * (0.9 + 0.12 * fibre);
	// Wood grain along the bars.
	float grain = vnoise(vec2(metres.x * 8.0 + metres.y * 90.0, metres.y * 8.0 + metres.x * 90.0));
	vec3 timber = wood_colour * (0.75 + 0.5 * grain);
	timber *= mix(1.0, 0.8 + 0.4 * vnoise(vec2(metres.x * 3.0, metres.y * 40.0)), board);
	vec3 colour = mix(paper, timber, wood);
	ALBEDO = colour;
	ROUGHNESS = mix(0.95, 0.5, wood);
	// The dusk behind the paper: a warm band low down, a cool sky above, never reaching the wood.
	float sky = smoothstep(board_height, size.y, y);
	vec3 dusk = mix(dusk_low, dusk_high, pow(sky, 0.8));
	float lamp_pools = 0.82 + 0.28 * vnoise(vec2(metres.x * 1.3, 2.0));
	EMISSION = dusk * glow * (0.6 + 0.4 * fibre) * (1.0 - wood) * lamp_pools;
	float h = wood * 0.02 + fibre * 0.002;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.9 * grad);
}
