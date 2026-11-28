shader_type spatial;
#include "res://noise.gdshaderinc"
// Dark lacquered cedar for posts, beams and the weapon rack. The grain runs along the object's
// longest axis (`grain_axis`: 0 is X, 1 is Y, 2 is Z), warped by a slow noise so it never
// looks ruled, with a satin sheen.
varying vec3 obj;

uniform vec3 wood_colour : source_color = vec3(0.26, 0.15, 0.08);
uniform vec3 grain_colour : source_color = vec3(0.14, 0.07, 0.035);
uniform int grain_axis = 1;
uniform float grain_scale = 34.0;
uniform float roughness = 0.5;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	vec2 q;
	float along;
	if (grain_axis == 0) {
		q = obj.yz;
		along = obj.x;
	} else if (grain_axis == 1) {
		q = obj.xz;
		along = obj.y;
	} else {
		q = obj.xy;
		along = obj.z;
	}
	float warp = fbm(vec2(along * 1.6, q.x * 3.0 + q.y * 2.0)) * 0.12;
	float rings = sin((q.x + q.y * 0.7 + warp) * grain_scale + fbm(vec2(along * 2.0, q.x * 9.0)) * 4.0);
	float fine = vnoise(vec2(along * 6.0, (q.x + q.y) * 45.0));
	float grain = clamp(0.5 + 0.35 * rings + 0.3 * (fine - 0.5), 0.0, 1.0);
	vec3 colour = mix(grain_colour, wood_colour, smoothstep(0.1, 0.9, grain));
	colour *= 0.9 + 0.2 * fbm(vec2(along * 0.8, q.x * 2.0));
	ALBEDO = colour;
	ROUGHNESS = roughness - 0.15 * grain;
	SPECULAR = 0.55;
	float h = fine * 0.02 + grain * 0.01;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.5 * grad);
}
