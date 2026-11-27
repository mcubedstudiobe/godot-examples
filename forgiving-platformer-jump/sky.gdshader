shader_type sky;
// A bright morning window: warm cream low down, a pale blue above, and a big soft sun glow to one
// side. Smooth gradients only, so no cube-face seams can show through in the reflections.

uniform vec3 top : source_color = vec3(0.55, 0.74, 0.96);
uniform vec3 middle : source_color = vec3(0.98, 0.86, 0.76);
uniform vec3 low : source_color = vec3(1.0, 0.8, 0.62);
uniform vec3 sun_direction = vec3(-0.55, 0.35, -0.75);

void sky() {
	vec3 d = EYEDIR;
	vec3 sun = normalize(sun_direction);
	float glow = max(dot(d, sun), 0.0);
	float h = d.y;
	vec3 color = mix(low, middle, smoothstep(-0.05, 0.25, h));
	color = mix(color, top, smoothstep(0.2, 0.9, h));
	color = mix(color, low * 0.7, smoothstep(0.0, -0.35, h));
	color += vec3(1.0, 0.8, 0.55) * (pow(glow, 4.0) * 0.5 + pow(glow, 60.0) * 2.0);
	COLOR = color;
}
