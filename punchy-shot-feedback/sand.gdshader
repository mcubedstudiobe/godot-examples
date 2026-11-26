shader_type spatial;
// Sun-baked desert floor: soft patches of light and dark sand, faint wind ripples,
// and a trodden lane from the shooter to the backstop.

uniform vec3 sand_light : source_color = vec3(0.94, 0.77, 0.56);
uniform vec3 sand_dark : source_color = vec3(0.84, 0.61, 0.41);
uniform vec3 lane_color : source_color = vec3(0.66, 0.43, 0.29);
uniform float lane_half_width = 0.85;
uniform vec2 lane_z = vec2(-6.7, 0.9);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float patches = noise(p * 0.09) * 0.45 + noise(turn * p * 0.35) * 0.35 + noise(turn * turn * p * 1.3) * 0.2;
	float ripple = 0.5 + 0.5 * sin(p.x * 6.0 + p.y * 1.5 + noise(p * 0.7) * 6.0);
	vec3 color = mix(sand_dark, sand_light, patches * 0.85 + ripple * 0.1);
	float across = 1.0 - smoothstep(lane_half_width * 0.6, lane_half_width, abs(p.x - 0.1));
	float along = smoothstep(lane_z.x - 0.4, lane_z.x, p.y) * (1.0 - smoothstep(lane_z.y, lane_z.y + 0.6, p.y));
	color = mix(color, lane_color * (0.9 + 0.2 * patches), across * along * 0.6);
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
