shader_type spatial;
// The flash where the blade meets the bucket: a spiky star drawn on a flat quad, no texture,
// always turned to face the camera. Colours above 1 reach the environment glow.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 hot : source_color = vec3(1.0, 0.97, 0.85);
uniform vec3 warm : source_color = vec3(1.0, 0.55, 0.16);
uniform float energy = 5.0;
uniform float seed = 0.0;

void vertex() {
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Five uneven spikes around a round core.
	float r = length(p);
	float a = atan(p.y, p.x);
	float spikes = pow(abs(cos(a * 2.5 + seed)), 6.0) * (0.75 + 0.25 * sin(a * 7.0 + seed * 3.0));
	float reach = 0.3 + 0.7 * spikes;
	float glow = pow(clamp(1.0 - r / reach, 0.0, 1.0), 1.3);
	float core = exp(-r * r * 18.0);
	float heat = clamp(core * 1.6, 0.0, 1.0);
	ALBEDO = mix(warm * 0.6, hot * 1.4, heat) * energy;
	ALPHA = clamp(glow * 1.5 + core, 0.0, 1.0);
}
