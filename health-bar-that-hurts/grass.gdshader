shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// One blade of grass, drawn thousands of times. The blade is a tapered ribbon whose UV.y runs
// from the root (0) to the tip (1). Each instance carries its own tint and height in its custom
// data, and the wind sways the tips.
varying float tip;
varying float tint;

uniform vec3 root_colour : source_color = vec3(0.07, 0.20, 0.04);
uniform vec3 tip_colour : source_color = vec3(0.50, 0.76, 0.18);
uniform float wind_speed = 1.4;
uniform float wind_strength = 0.035;

void vertex() {
	tip = UV.y;
	tint = INSTANCE_CUSTOM.r;
	vec3 base = MODEL_MATRIX[3].xyz;
	float sway = sin(TIME * wind_speed + base.x * 1.7 + base.z * 1.1) + 0.5 * sin(TIME * wind_speed * 2.3 + base.z * 3.1);
	VERTEX.x += sway * wind_strength * tip * tip * INSTANCE_CUSTOM.g;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + base.x * 1.3) * wind_strength * 0.5 * tip * tip;
}

void fragment() {
	vec3 colour = mix(root_colour, tip_colour, pow(tip, 0.8)) * (0.8 + 0.4 * tint);
	ALBEDO = colour;
	ROUGHNESS = 0.85;
	// Every blade is lit as if it faced up, like the lawn it grows from.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	BACKLIGHT = colour * 0.35;
}
