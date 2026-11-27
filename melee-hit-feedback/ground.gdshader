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
	// A hash built from fract() alone: sin() on large arguments loses precision on some GPUs.
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Smooth noise from one seamless texture, so no cell edges can show at any scale.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float noise(vec2 p) {
	return texture(noise_tex, p * 0.125).r;
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
	float pebble = step(0.975, hash(cell)) * smoothstep(0.2, 0.08, length(fract(p * 14.0) - 0.5));
	sand = mix(sand, vec3(0.66, 0.55, 0.44), pebble * 0.6);
	// Scuffed rings of lighter sand where the fighters stand.
	for (int i = 0; i < 2; i++) {
		vec2 spot = vec2(i == 0 ? -1.0 : 1.0, i == 0 ? 0.3 : -0.3);
		float ring = abs(length(p - spot) - 0.85);
		sand = mix(sand, sand_a * 1.12, smoothstep(0.22, 0.0, ring) * 0.35 * noise(p * 6.0 + 3.0));
		sand = mix(sand, sand_b * 0.8, smoothstep(0.55, 0.0, length(p - spot)) * 0.25);
	}
	// Fine detail, faded out with distance so it never shimmers: grass fibres that run away from
	// the camera, and the grit and small clods of trodden sand.
	float near = 1.0 - smoothstep(3.0, 13.0, length(VERTEX));
	float fibre = noise(p * vec2(26.0, 20.0)) * 0.6 + noise(p * vec2(70.0, 52.0)) * 0.4;
	// Blades: dark gaps between them, lit tips, and the odd flower speck.
	float blades = noise(p * vec2(45.0, 120.0));
	grass *= mix(1.0, 0.5 + 0.95 * fibre, near);
	grass = mix(grass, grass * 1.35 + vec3(0.05, 0.04, 0.0), smoothstep(0.55, 0.8, blades) * near * 0.8);
	grass = mix(grass, grass * 0.55, smoothstep(0.45, 0.2, blades) * near * 0.7);
	float flower = step(0.992, hash(floor(p * 38.0))) * smoothstep(0.22, 0.1, length(fract(p * 38.0) - 0.5));
	grass = mix(grass, vec3(0.8, 0.72, 0.45), flower * near * 0.5);
	grass = mix(grass, grass * vec3(1.18, 1.12, 0.8), smoothstep(0.62, 0.9, noise(p * vec2(34.0, 6.0))) * near);
	float grit = noise(p * 60.0) * 0.4 + noise(p * 17.0) * 0.6;
	sand *= mix(1.0, 0.88 + 0.26 * grit, near);
	ALBEDO = mix(grass, sand, sand_mask);
	ROUGHNESS = mix(0.95, 0.9, sand_mask);
	SPECULAR = 0.15;
}
