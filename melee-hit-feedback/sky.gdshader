shader_type sky;
// Golden hour: a deep blue top fading through rose to a gold horizon, a sun glow low behind
// the castle, and streaky clouds lit orange from below. No textures.

uniform vec3 top : source_color = vec3(0.06, 0.12, 0.38);
uniform vec3 middle : source_color = vec3(0.62, 0.34, 0.5);
uniform vec3 low : source_color = vec3(1.0, 0.7, 0.36);
uniform vec3 ground : source_color = vec3(0.34, 0.24, 0.2);
uniform vec3 sun_direction = vec3(0.5, 0.08, -0.86);

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

float fbm(vec2 p) {
	float total = 0.0;
	float amount = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amount;
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + vec2(17.3, 9.1);
		amount *= 0.5;
	}
	return total;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 sun = normalize(sun_direction);
	float glow = max(dot(d, sun), 0.0);
	float h = d.y;
	vec3 color = mix(low, middle, smoothstep(0.0, 0.22, h));
	color = mix(color, top, smoothstep(0.18, 0.85, h));
	color = mix(color, ground, smoothstep(0.0, -0.12, h));
	color += vec3(1.0, 0.6, 0.25) * (pow(glow, 5.0) * 0.55 + pow(glow, 90.0) * 2.4);
	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.3) * 1.5 + vec2(TIME * 0.003, 0.0);
		float c = fbm(uv * vec2(1.0, 1.8));
		float cover = smoothstep(0.48, 0.78, c) * smoothstep(0.01, 0.12, h);
		// Lit from below by the low sun, shaded blue-violet on top.
		vec3 lit = mix(vec3(1.0, 0.5, 0.3), vec3(1.0, 0.86, 0.62), pow(glow, 2.0));
		vec3 shade = vec3(0.5, 0.34, 0.5);
		color = mix(color, mix(shade, lit, smoothstep(0.45, 0.75, c)), cover * 0.9);
	}
	COLOR = color;
}
