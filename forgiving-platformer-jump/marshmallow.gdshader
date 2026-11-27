shader_type spatial;
#include "res://noise.gdshaderinc"
// A marshmallow: soft white, a little pink, lit from within by the light that scatters through it,
// with fine wrinkles. toast browns the top, as if it had been near a flame.

uniform float toast = 0.0;
uniform float seed = 0.0;
uniform float top_y = 0.21; // the height of the top, which is where the toasting is

uniform vec3 tint : source_color = vec3(0.84, 0.78, 0.74);
varying vec3 opos;
varying vec3 world_pos;

void vertex() {
	opos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wrinkle = fbm(opos.xz * 11.0 + opos.y * 5.0 + seed);
	float brown = toast * smoothstep(top_y * 0.35, top_y * 0.9, opos.y) * (0.6 + 0.6 * fbm(opos.xz * 4.0 + seed * 2.0));
	vec3 col = mix(tint, vec3(0.8, 0.5, 0.24), clamp(brown, 0.0, 1.0));
	ALBEDO = col * (0.95 + 0.1 * wrinkle);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4((wrinkle - 0.5) * 0.12, 0.0, (fbm(opos.zx * 9.0) - 0.5) * 0.12, 0.0)).xyz);
	ROUGHNESS = 0.62;
	SPECULAR = 0.45;
	SSS_STRENGTH = 0.0;
	BACKLIGHT = vec3(0.55, 0.38, 0.3);
	EMISSION = col * 0.02;
}
