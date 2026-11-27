shader_type spatial;
// The yard floor: trodden sand in the middle that fades into long golden grass, with
// pebbles, scuffed rings where the two fighters stand, and soft patches of colour.

uniform vec3 grass_a : source_color = vec3(0.4, 0.46, 0.17);
uniform vec3 grass_b : source_color = vec3(0.62, 0.58, 0.24);
uniform vec3 sand_a : source_color = vec3(0.6, 0.47, 0.34);
uniform vec3 sand_b : source_color = vec3(0.47, 0.35, 0.25);
uniform vec2 yard_center = vec2(0.0, -0.8);
uniform vec2 yard_radius = vec2(5.8, 4.2);

varying vec3 world_pos;

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
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = noise(p * 0.12) * 0.55 + noise(p * 0.5) * 0.3 + noise(p * 2.7) * 0.15;
	vec3 grass = mix(grass_a, grass_b, broad);
	grass *= 0.85 + 0.3 * noise(p * vec2(9.0, 2.0)); // blades lean one way
	// The yard: an uneven ellipse of sand.
	vec2 q = (p - yard_center) / yard_radius;
	float edge = length(q) + (noise(p * 0.9) - 0.5) * 0.35;
	float sand_mask = 1.0 - smoothstep(0.62, 1.0, edge);
	vec3 sand = mix(sand_b, sand_a, noise(p * 0.7) * 0.7 + noise(p * 4.0) * 0.3);
	// Pebbles and grit.
	vec2 cell = floor(p * 14.0);
	float pebble = step(0.93, hash(cell)) * smoothstep(0.35, 0.1, length(fract(p * 14.0) - 0.5));
	sand = mix(sand, vec3(0.9, 0.82, 0.7), pebble * 0.7);
	// Scuffed rings of lighter sand where the fighters stand.
	for (int i = 0; i < 2; i++) {
		vec2 spot = vec2(i == 0 ? -1.0 : 1.0, i == 0 ? 0.3 : -0.3);
		float ring = abs(length(p - spot) - 0.85);
		sand = mix(sand, sand_a * 1.12, smoothstep(0.22, 0.0, ring) * 0.35 * noise(p * 6.0 + 3.0));
		sand = mix(sand, sand_b * 0.8, smoothstep(0.55, 0.0, length(p - spot)) * 0.25);
	}
	ALBEDO = mix(grass, sand, sand_mask);
	ROUGHNESS = mix(0.95, 0.9, sand_mask);
	SPECULAR = 0.15;
}
