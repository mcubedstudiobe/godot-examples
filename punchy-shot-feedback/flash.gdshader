shader_type spatial;
// Muzzle flash drawn on flat quads, no texture. "petal" 0 is the star seen down the
// barrel (it turns to face the camera); 1 is the side flame, laid along the barrel
// with its base at the muzzle. Colours above 1 reach the environment glow.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float petal : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.97, 0.85);
uniform vec3 warm : source_color = vec3(1.0, 0.55, 0.16);
uniform float energy = 5.0;
uniform float seed = 0.0;

void vertex() {
	if (petal < 0.5) {
		mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * facing * mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float glow;
	float core;
	if (petal < 0.5) {
		// Five uneven spikes around a round core.
		float r = length(p);
		float a = atan(p.y, p.x);
		float spikes = pow(abs(cos(a * 2.5 + seed)), 6.0) * (0.75 + 0.25 * sin(a * 7.0 + seed * 3.0));
		float reach = 0.3 + 0.7 * spikes;
		glow = pow(clamp(1.0 - r / reach, 0.0, 1.0), 1.3);
		core = exp(-r * r * 18.0);
	} else {
		// u runs from the muzzle (0) to the tip (1), v across the flame.
		float u = UV.y;
		float v = abs(p.x);
		float width = 0.55 * pow(1.0 - u, 0.9) * smoothstep(0.0, 0.12, u) + 0.05;
		width *= 0.85 + 0.15 * sin(u * 22.0 + seed * 5.0);
		float main = clamp(1.0 - v / width, 0.0, 1.0);
		// Two short side jets just past the muzzle.
		float jets = clamp(1.0 - abs(v - (u - 0.05) * 1.6) * 9.0, 0.0, 1.0) * step(u, 0.4) * (1.0 - u * 2.5);
		glow = max(main * main, jets * 0.8);
		core = exp(-u * 6.0) * clamp(1.0 - v / (width * 0.45), 0.0, 1.0);
	}
	float heat = clamp(core * 1.6, 0.0, 1.0);
	ALBEDO = mix(warm * 0.6, hot * 1.4, heat) * energy;
	ALPHA = clamp(glow * 1.5 + core, 0.0, 1.0);
}
