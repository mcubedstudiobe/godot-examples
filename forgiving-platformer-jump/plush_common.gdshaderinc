// Shared by the player and the ghost: the plush's own colours, its eyes and a hue turn.
// The Godot Plush Character's shader is by Tibo (MIT, github.com/gtibo/Godot-Plush-Character);
// the eye states below are additions: blink closes the lids, wide opens the eyes, and dead
// redraws them as X's.

uniform sampler2D albedo_texture : source_color, repeat_disable;
uniform sampler2D normal_texture : hint_normal, repeat_disable;
uniform float hue_shift = 0.0; // in turns: 0.5 is the opposite colour
uniform float saturation = 1.0;
uniform float brightness = 1.0;
uniform float blink = 0.0; // 0 open, 1 closed
uniform float wide = 0.0; // 1 opens the eyes wide
uniform float dead = 0.0; // 1 draws X's for eyes
uniform float flash = 0.0; // 1 is pure white

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
	if (wide > 0.0) {
		// Sample the eye from closer in, so it looks bigger.
		vec2 s = EYE_CENTER + q * (1.0 - 0.2 * wide) * EYE_HALF;
		color = texture(albedo_texture, s).rgb;
	}
	if (q.y < -1.0 + 2.2 * blink) {
		// The eyelid: the plush's own fabric from a plain corner of the texture.
		return texture(albedo_texture, vec2(0.01, 0.01)).rgb;
	}
	return color;
}

vec3 plush_colour(vec2 uv) {
	vec3 body = rotate_hue(eye(uv, texture(albedo_texture, uv).rgb), hue_shift);
	vec3 c = clamp(mix(vec3(dot(body, vec3(0.299, 0.587, 0.114))), body, saturation), 0.0, 1.0);
	return clamp(c * brightness, 0.0, 1.0);
}
