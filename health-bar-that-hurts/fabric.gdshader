shader_type spatial;
#include "res://noise.gdshaderinc"
// Soft furnishings: a woven cloth with a velvety sheen at the edges. One shader dresses the
// cushions and the blanket; `pattern` picks the print, and the print follows the object.
varying vec3 obj;

uniform vec3 base_colour : source_color = vec3(0.9, 0.3, 0.3);
uniform vec3 accent_colour : source_color = vec3(1.0, 0.95, 0.88);
uniform int pattern = 0; // 0 plain, 1 gingham, 2 stripes, 3 dots, 4 quilted
uniform float scale = 4.0;
uniform float piping = 0.0; // 1 draws a seam round the middle of a cushion
uniform float weave_scale = 190.0;

void vertex() {
	obj = VERTEX;
}

float filtered_square(float x) {
	float w = fwidth(x) * 0.75 + 0.015;
	return smoothstep(0.5 - w, 0.5 + w, abs(fract(x * 0.5) - 0.5) * 2.0);
}

void fragment() {
	vec2 q = vec2(obj.x + obj.z * 0.7, obj.y + obj.z * 0.3);
	vec3 colour = base_colour;
	float lift = 0.0;
	if (pattern == 1) {
		float a = filtered_square(obj.x * scale);
		float b = filtered_square((obj.z + obj.y) * scale);
		colour = mix(accent_colour, base_colour, clamp((a + b) * 0.5, 0.0, 1.0));
		colour = mix(accent_colour, colour, 0.15 + 0.85 * clamp((a + b) * 0.5 * 1.4, 0.0, 1.0));
	} else if (pattern == 2) {
		colour = mix(accent_colour, base_colour, filtered_square((obj.x + obj.z * 0.2) * scale));
	} else if (pattern == 3) {
		vec2 g = vec2(obj.x, obj.z + obj.y) * scale;
		vec2 cell = fract(g) - 0.5;
		float d = length(cell);
		float w = fwidth(d) + 0.01;
		colour = mix(base_colour, accent_colour, 1.0 - smoothstep(0.24 - w, 0.24 + w, d));
	} else if (pattern == 4) {
		// A quilt: diamond stitch lines pressed into the fabric.
		vec2 g = vec2(obj.x + obj.z, obj.x - obj.z) * scale * 0.5;
		vec2 f = abs(fract(g) - 0.5);
		float stitch = smoothstep(0.43, 0.5, max(f.x, f.y));
		lift = -stitch;
		colour = mix(base_colour, accent_colour, 0.18 * stitch + 0.12 * vnoise(g * 3.0));
	}
	// The weave: a fine criss-cross of threads, seen only up close.
	float fade = 1.0 - smoothstep(1.2, 5.0, length(VERTEX));
	float threads = sin(q.x * weave_scale) * sin(q.y * weave_scale);
	colour *= 1.0 + threads * 0.045 * fade;
	float cloth = vnoise(q * 90.0) * 0.5 + vnoise(q * 31.0) * 0.5;
	colour *= 0.93 + 0.14 * cloth;
	// The piping: a seam cord round the equator of a cushion.
	float cord = 0.0;
	if (piping > 0.5) {
		float d = abs(obj.y);
		float width = 0.012;
		cord = 1.0 - smoothstep(width, width * 2.2, d);
		colour = mix(colour, base_colour * 0.72, cord);
	}
	ALBEDO = colour;
	ROUGHNESS = 0.92;
	// A velvet sheen: the fabric glows a little where it turns away from the eye.
	RIM = 0.25;
	RIM_TINT = 0.5;
	BACKLIGHT = colour * 0.25;
	float h = threads * 0.1 * fade + cloth * 0.3 + cord * 0.8 + lift * 0.6;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.012 * grad);
}
