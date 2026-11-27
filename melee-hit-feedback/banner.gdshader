shader_type spatial;
// A hanging banner: a swallowtail cut, a cream border, and a saffron sun on teal. The cloth
// sways, more towards the loose end.

render_mode cull_disabled;

uniform vec3 field : source_color = vec3(0.07, 0.48, 0.5);
uniform vec3 sun : source_color = vec3(0.95, 0.65, 0.1);
uniform vec3 trim : source_color = vec3(0.97, 0.92, 0.8);
uniform float notch = 0.18;
uniform float sway = 0.07;
uniform float phase = 0.0;

void vertex() {
	float loose = UV.y;
	VERTEX.z += sin(TIME * 1.5 + phase + UV.y * 4.0 + UV.x * 2.0) * sway * loose * loose;
	VERTEX.x += sin(TIME * 1.1 + phase + UV.y * 3.0) * sway * 0.3 * loose;
}

void fragment() {
	vec2 uv = UV;
	float cut = notch * (1.0 - abs(uv.x - 0.5) * 2.0);
	if (uv.y > 1.0 - cut) {
		discard;
	}
	vec2 centered = uv - vec2(0.5, 0.42);
	centered.y *= 0.62; // banners are tall; keep the sun round on it
	float r = length(centered);
	float angle = atan(centered.y, centered.x);
	float rays = step(0.0, sin(angle * 8.0)) * smoothstep(0.32, 0.18, r) * smoothstep(0.13, 0.15, r);
	float disc = smoothstep(0.135, 0.125, r);
	vec3 color = field;
	color = mix(color, sun, max(disc, rays));
	float border = min(min(uv.x, 1.0 - uv.x), 0.5) < 0.055 ? 1.0 : 0.0;
	float bottom = uv.y > 1.0 - cut - 0.05 ? 1.0 : 0.0;
	color = mix(color, trim, max(border, bottom));
	// Folds in the cloth.
	color *= 0.9 + 0.1 * sin(uv.x * 18.0 + sin(uv.y * 5.0 + phase) * 1.5);
	ALBEDO = color;
	ROUGHNESS = 0.85;
	BACKLIGHT = color * 0.35;
}
