shader_type spatial;
// River water: two moving wave patterns, a little shine. Works in the browser renderer.
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.07, 0.20, 0.32, 1.0);
uniform vec4 shallow : source_color = vec4(0.18, 0.45, 0.58, 1.0);
uniform vec4 foam : source_color = vec4(0.75, 0.9, 0.95, 1.0);

void fragment() {
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = TIME;
	float w1 = sin(p.x * 3.1 + t * 1.3) * cos(p.y * 2.3 - t * 0.9);
	float w2 = sin((p.x + p.y) * 5.0 - t * 2.1);
	float w = w1 * 0.6 + w2 * 0.4;
	vec3 col = mix(deep.rgb, shallow.rgb, 0.5 + 0.5 * w);
	col = mix(col, foam.rgb, smoothstep(0.82, 0.98, w2) * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = col * 0.25;
}
