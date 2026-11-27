shader_type spatial;
// Straw: fine strands running along the bale, light and dark, with a few bright stalks.

uniform vec3 straw_light : source_color = vec3(0.98, 0.82, 0.38);
uniform vec3 straw_dark : source_color = vec3(0.7, 0.5, 0.18);
uniform float strands = 90.0;

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

void fragment() {
	vec2 p = vec2(UV.x * 6.0, UV.y * strands);
	float fine = noise(p * vec2(1.0, 1.0) + noise(p * 0.3) * 4.0);
	float coarse = noise(UV * vec2(4.0, 10.0));
	float stalk = step(0.86, hash(floor(vec2(UV.x * 40.0, UV.y * strands))));
	vec3 color = mix(straw_dark, straw_light, fine * 0.7 + coarse * 0.3);
	color = mix(color, straw_light * 1.15, stalk * 0.6);
	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
