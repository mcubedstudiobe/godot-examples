shader_type sky;
// A clear early-afternoon sky: deep blue overhead fading to a pale horizon, a bright sun with a
// soft glow, and a few puffy clouds. Smooth gradients and noise only, so no seams show in
// reflections.

uniform vec3 top : source_color = vec3(0.16, 0.42, 0.86);
uniform vec3 horizon : source_color = vec3(0.64, 0.82, 0.98);
uniform vec3 ground_colour : source_color = vec3(0.55, 0.66, 0.50);
uniform vec3 sun_direction = vec3(-0.45, 0.62, -0.5);

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amount = 0.5;
	for (int i = 0; i < 5; i++) {
		total += vnoise(p) * amount;
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + vec2(17.3, 9.1);
		amount *= 0.5;
	}
	return total;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 sun = normalize(sun_direction);
	float h = d.y;
	vec3 colour = mix(horizon, top, pow(smoothstep(0.0, 0.85, h), 0.7));
	colour = mix(colour, ground_colour, smoothstep(0.0, -0.25, h));
	float glow = max(dot(d, sun), 0.0);
	colour += vec3(1.0, 0.9, 0.7) * (pow(glow, 8.0) * 0.25 + pow(glow, 220.0) * 6.0);
	if (h > 0.0) {
		vec2 plane = d.xz / (h + 0.18) * 0.9;
		float c = fbm(plane * 1.3 + vec2(3.0, 1.0));
		float cover = smoothstep(0.52, 0.78, c) * smoothstep(0.0, 0.25, h);
		// The undersides of the clouds are a touch grey-blue, their tops bright white.
		vec3 cloud = mix(vec3(0.82, 0.88, 0.96), vec3(1.0, 0.99, 0.97), smoothstep(0.55, 0.95, c));
		colour = mix(colour, cloud, cover * 0.92);
	}
	COLOR = colour;
}
