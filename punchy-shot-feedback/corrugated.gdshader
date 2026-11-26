shader_type spatial;
// Corrugated sheet metal for the backstop: vertical ridges, a seam every sheet, and rust
// creeping up from the ground. Drawn on the wall's XY plane.

uniform vec3 metal_color : source_color = vec3(0.66, 0.7, 0.74);
uniform vec3 rust_color : source_color = vec3(0.5, 0.36, 0.24);
uniform float ridges_per_metre = 8.0;
uniform float sheet_width = 1.1;

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
	float phase = world_pos.x * ridges_per_metre * 6.2831853;
	NORMAL_MAP = normalize(vec3(cos(phase) * 0.5, 0.0, 1.0)) * 0.5 + 0.5;
	float grain = noise(world_pos.xy * vec2(1.6, 2.4)) * 0.6 + noise(world_pos.xy * 8.0) * 0.4;
	float rust = smoothstep(0.55, 0.9, grain + (0.6 - world_pos.y) * 0.35) * 0.8;
	float seam = 1.0 - smoothstep(0.0, 0.03, abs(fract(world_pos.x / sheet_width + 0.5) - 0.5) * sheet_width);
	vec3 color = mix(metal_color, rust_color, rust) * (0.82 + 0.18 * cos(phase));
	ALBEDO = color * (1.0 - seam * 0.5);
	METALLIC = mix(0.7, 0.1, rust);
	ROUGHNESS = mix(0.4, 0.85, rust);
}
