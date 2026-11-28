shader_type spatial;
// The burst behind a crit's number: a bold spiky star on a flat quad that always faces the
// camera. No texture; the points are drawn from the angle, so it stays crisp at any size. It is
// drawn over everything, like the number it sits behind.
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.93, 0.55);
uniform vec3 rim : source_color = vec3(1.0, 0.42, 0.08);
uniform float points = 11.0;
uniform float energy = 1.6;
uniform float alpha = 1.0;

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
	float r = length(p);
	float a = atan(p.y, p.x);
	// A star polygon: the outline swings between the inner and the outer radius.
	float wave = abs(fract(a / 6.2831853 * points) * 2.0 - 1.0);
	float edge = mix(0.46, 0.98, wave);
	float aa = fwidth(r) * 1.5;
	float inside = 1.0 - smoothstep(edge - aa, edge + aa, r);
	float heat = smoothstep(edge, 0.0, r);
	ALBEDO = mix(rim, core, pow(heat, 0.8)) * energy;
	ALPHA = inside * alpha;
}
