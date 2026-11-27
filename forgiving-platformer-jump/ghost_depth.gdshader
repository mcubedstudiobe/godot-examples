shader_type spatial;
render_mode unshaded, blend_add, depth_draw_always, cull_back;
// The first pass of the ghost: it adds nothing to the picture but writes the depth, so the
// second pass shows only the surface nearest the camera and the arms do not show through the body.

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 1.0;
}
