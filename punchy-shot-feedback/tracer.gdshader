shader_type spatial;
// The tracer is a unit-depth box stretched from the muzzle to the hit. Local -Z is the
// hit end. The head burns white, the tail fades to orange, and "tail" eats the streak
// from the muzzle end so it closes in on the hit as it thins.
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;

uniform vec3 hot : source_color = vec3(1.0, 0.96, 0.82);
uniform vec3 warm : source_color = vec3(1.0, 0.5, 0.12);
uniform float energy = 5.0;
instance uniform float tail : hint_range(0.0, 1.0) = 0.0;

varying float along;

void vertex() {
	along = 0.5 - VERTEX.z; // 0 at the muzzle end, 1 at the hit end
}

void fragment() {
	float t = along;
	if (t < tail) {
		discard;
	}
	float head = smoothstep(0.55, 1.0, t);
	float fade = smoothstep(tail, tail + 0.35, t);
	ALBEDO = mix(warm, hot, head) * energy;
	ALPHA = fade * (0.35 + 0.65 * head);
}
