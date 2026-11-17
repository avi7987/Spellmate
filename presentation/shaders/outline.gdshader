shader_type spatial;
// Cartoon outline: draws the back faces of the mesh slightly inflated, in a
// dark colour. Used as next_pass on every character material.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.1, 0.07, 0.06, 1.0);
uniform float thickness = 0.012;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
