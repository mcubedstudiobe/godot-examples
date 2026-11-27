shader_type spatial;
// Castle masonry in world space: courses of blocks of uneven width, mortar between, a
// different tint and grain on every block, grime at the foot, and a warm wash on top.

uniform vec3 stone_a : source_color = vec3(0.74, 0.66, 0.6);
uniform vec3 stone_b : source_color = vec3(0.5, 0.45, 0.43);
uniform vec3 mortar : source_color = vec3(0.38, 0.33, 0.31);
uniform float course = 0.62;
uniform float block = 1.5;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	// Walls facing along X use z for the run; walls facing along Z use x; tops use x and z.
	vec2 run_up = n.y > 0.7 ? world_pos.xz : (n.x > n.z ? vec2(world_pos.z, world_pos.y) : vec2(world_pos.x, world_pos.y));
	float row = floor(run_up.y / course);
	float width = block * (0.75 + 0.6 * hash(vec2(row, 3.0)));
	float shifted = run_up.x + hash(vec2(row, 7.0)) * 10.0;
	float col = floor(shifted / width);
	vec2 inside = vec2(fract(shifted / width), fract(run_up.y / course));
	vec2 id = vec2(col, row);
	float tone = hash(id);
	vec3 color = mix(stone_a, stone_b, tone);
	color *= 0.85 + 0.3 * noise(run_up * 6.0 + tone * 20.0);
	// Rounded block edges and mortar lines.
	vec2 edge = min(inside, 1.0 - inside) * vec2(width, course);
	float gap = min(edge.x, edge.y);
	float line = smoothstep(0.012, 0.04, gap);
	color = mix(mortar, color * (0.8 + 0.4 * smoothstep(0.0, 0.12, gap)), line);
	// Grime near the ground and a warm wash up high.
	color *= mix(0.7, 1.0, smoothstep(0.0, 1.6, world_pos.y));
	ALBEDO = color;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
