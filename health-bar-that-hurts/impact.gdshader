shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// A comic impact star: a white-hot core with yellow points, drawn on a camera-facing quad.
uniform float energy = 3.0;
uniform float spin = 0.0;

void vertex() {
	// Face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float c = cos(spin);
	float s = sin(spin);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float angle = atan(p.y, p.x);
	float points = 0.45 + 0.55 * pow(abs(cos(angle * 4.0)), 3.0);
	float d = length(p) / points;
	float star = 1.0 - smoothstep(0.55, 0.95, d);
	float core = 1.0 - smoothstep(0.0, 0.35, length(p));
	ALBEDO = (vec3(1.0, 0.8, 0.3) * star + vec3(1.0) * core) * energy;
	ALPHA = clamp(star + core, 0.0, 1.0);
}
