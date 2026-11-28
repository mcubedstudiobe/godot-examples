shader_type spatial;
// One small star that circles a dazed plush's head: a flat quad that always faces the camera,
// drawn from the angle, so it stays crisp. Unlike the crit's star it is hidden by whatever is in
// front of it.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 colour : source_color = vec3(1.0, 0.86, 0.25);

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
	// Five points.
	float wave = abs(fract(a / 6.2831853 * 5.0 + 0.25) * 2.0 - 1.0);
	float edge = mix(0.4, 0.98, wave);
	float aa = fwidth(r) * 1.5;
	float inside = 1.0 - smoothstep(edge - aa, edge + aa, r);
	ALBEDO = mix(vec3(1.0, 0.6, 0.1), colour, smoothstep(edge, 0.0, r)) * 1.8;
	ALPHA = inside;
}
