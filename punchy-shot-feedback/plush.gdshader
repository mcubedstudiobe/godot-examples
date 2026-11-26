shader_type spatial;
// The Godot Plush Character's own shader (Tibo, MIT, github.com/gtibo/Godot-Plush-Character)
// with two additions: hue_shift turns the plush's blue around the colour wheel and
// saturation strengthens the result, so two plushes in one scene read as different
// characters. Eyes stay black and white.

uniform sampler2D albedo_texture : source_color, repeat_disable;
uniform sampler2D normal_texture : hint_normal, repeat_disable;
uniform float hue_shift = 0.0; // in turns: 0.5 is the opposite colour
uniform float saturation = 1.0;

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow(1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0), amount);
}

vec3 rotate_hue(vec3 color, float turns) {
	// Rotate around the grey axis; greys, black and white do not move.
	float a = turns * 6.2831853;
	vec3 k = vec3(0.57735);
	return color * cos(a) + cross(k, color) * sin(a) + k * dot(k, color) * (1.0 - cos(a));
}

void fragment() {
	vec3 body = rotate_hue(texture(albedo_texture, UV).rgb, hue_shift);
	ALBEDO = clamp(mix(vec3(dot(body, vec3(0.299, 0.587, 0.114))), body, saturation), 0.0, 1.0);
	NORMAL_MAP = texture(normal_texture, UV).xyz;
	EMISSION = mix(vec3(1.0), ALBEDO, 0.75) * clamp(smoothstep(0.6, 0.7, fresnel(1.0, NORMAL, VIEW)) * NORMAL.y, 0.0, 1.0) * 2.0;
	ROUGHNESS = 0.7;
	SPECULAR = 0.8;
}
