shader_type spatial;
#include "res://noise.gdshaderinc"
// The mown lawn: broad light and dark mowing stripes, big soft patches of colour and fine
// blade-scale noise that fades with distance. The grass blades stand on top of it.
varying vec3 world_pos;

uniform vec3 light_grass : source_color = vec3(0.33, 0.58, 0.14);
uniform vec3 dark_grass : source_color = vec3(0.19, 0.43, 0.10);
uniform vec3 dry_grass : source_color = vec3(0.50, 0.58, 0.20);

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float stripe_coord = (p.x * 0.94 + p.y * 0.34) / 0.85;
	float w = fwidth(stripe_coord) + 0.02;
	float stripe = smoothstep(0.5 - w, 0.5 + w, abs(fract(stripe_coord * 0.5) - 0.5) * 2.0);
	vec3 colour = mix(dark_grass, light_grass, stripe);
	float patches = fbm(p * 0.35);
	colour = mix(colour, dry_grass, smoothstep(0.5, 0.8, patches) * 0.55);
	colour *= 0.88 + 0.24 * fbm(p * 1.7 + 4.0);
	float detail_fade = 1.0 - smoothstep(6.0, 22.0, length(VERTEX));
	float fine = vnoise(p * 55.0) * 0.6 + vnoise(p * 140.0) * 0.4;
	colour *= 1.0 + (fine - 0.5) * 0.45 * detail_fade;
	ALBEDO = colour;
	ROUGHNESS = 0.95;
}
