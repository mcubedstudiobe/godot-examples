shader_type spatial;
// The glazed lip of the bowl: cream with a soft blue band, and a bright sheen.
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = smoothstep(0.1, 0.5, abs(fract(world_pos.y * 0.45 + 0.1) - 0.5)) ;
	vec3 cream = vec3(0.97, 0.9, 0.78);
	vec3 blue = vec3(0.42, 0.62, 0.86);
	ALBEDO = mix(blue, cream, band);
	ROUGHNESS = 0.14;
	SPECULAR = 0.8;
	EMISSION = ALBEDO * 0.1;
}
