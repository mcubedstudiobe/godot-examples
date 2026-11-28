shader_type spatial;
// A tennis ball: fuzzy yellow-green felt with the two-lobed white seam, all procedural.
varying vec3 obj;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float seam_distance(vec3 p) {
	float lon = atan(p.z, p.x);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	return abs(lat - 0.62 * sin(2.0 * lon)) * max(cos(lat), 0.35);
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	vec3 p = normalize(obj);
	float fuzz = hash31(floor(p * 140.0)) * 0.6 + hash31(floor(p * 55.0)) * 0.4;
	vec3 felt = mix(vec3(0.34, 0.55, 0.0), vec3(0.55, 0.78, 0.0), fuzz);
	float seam = 1.0 - smoothstep(0.06, 0.09, seam_distance(p));
	vec3 colour = mix(felt, vec3(0.93, 0.95, 0.88), seam);
	ALBEDO = colour;
	ROUGHNESS = 0.95;
	RIM = 0.2;
	RIM_TINT = 0.5;
	// The seam is a shallow raised cord.
	float h = seam * 0.5 + fuzz * 0.25;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.02 * grad);
}
