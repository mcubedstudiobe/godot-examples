shader_type spatial;
// The Godot Plush Character's own shader (Tibo, MIT, github.com/gtibo/Godot-Plush-Character)
// with two additions: hue_shift turns the plush's blue around the colour wheel and
// saturation strengthens the result, so two plushes in one scene read as different
// characters. Eyes stay black and white; blink closes them and dead turns them into X's.

uniform sampler2D albedo_texture : source_color, repeat_disable;
uniform sampler2D normal_texture : hint_normal, repeat_disable;
uniform float hue_shift = 0.0; // in turns: 0.5 is the opposite colour
uniform float saturation = 1.0;
uniform float blink = 0.0; // 0 open, 1 closed
uniform float dead = 0.0; // 1 draws X's for eyes

// Both eyes sample this square of the texture; nothing else does.
const vec2 EYE_CENTER = vec2(0.1433, 0.1795);
const vec2 EYE_HALF = vec2(0.1376, 0.1339);

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow(1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0), amount);
}

vec3 rotate_hue(vec3 color, float turns) {
	// Rotate around the grey axis; greys, black and white do not move.
	float a = turns * 6.2831853;
	vec3 k = vec3(0.57735);
	return color * cos(a) + cross(k, color) * sin(a) + k * dot(k, color) * (1.0 - cos(a));
}

vec3 eye(vec2 uv, vec3 color) {
	vec2 q = (uv - EYE_CENTER) / EYE_HALF;
	if (abs(q.x) > 1.0 || abs(q.y) > 1.0) {
		return color;
	}
	if (dead > 0.5 && length(q) < 0.8) {
		// A white eye with a bold black X across it.
		float stroke = min(abs(q.x - q.y), abs(q.x + q.y)) * 0.7071;
		return (stroke < 0.13 && max(abs(q.x), abs(q.y)) < 0.5) ? vec3(0.0) : vec3(1.0);
	}
	if (q.y < -1.0 + 2.2 * blink) {
		// The eyelid: the plush's own fabric from a plain corner of the texture.
		return texture(albedo_texture, vec2(0.01, 0.01)).rgb;
	}
	return color;
}

void fragment() {
	vec3 body = rotate_hue(eye(UV, texture(albedo_texture, UV).rgb), hue_shift);
	ALBEDO = clamp(mix(vec3(dot(body, vec3(0.299, 0.587, 0.114))), body, saturation), 0.0, 1.0);
	NORMAL_MAP = texture(normal_texture, UV).xyz;
	EMISSION = mix(vec3(1.0), ALBEDO, 0.75) * clamp(smoothstep(0.6, 0.7, fresnel(1.0, NORMAL, VIEW)) * NORMAL.y, 0.0, 1.0) * 2.0;
	ROUGHNESS = 0.7;
	SPECULAR = 0.8;
}
