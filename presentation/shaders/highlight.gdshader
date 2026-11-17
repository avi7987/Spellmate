shader_type spatial;
// Square highlights drawn on a 1x1 plane lying on a board square.
// mode: 0 = move (glowing gem), 1 = capture (target brackets), 2 = power target (rune circle),
//       3 = selected, 4 = hover, 5 = last move, 6 = check (red glow)
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform int mode = 0;

float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV - 0.5;
	float t = TIME;
	float pulse = 0.8 + 0.2 * sin(t * 4.0);
	float a = 0.0;
	if (mode == 0) {
		// Soft glow on the tile + a small faceted gem in the middle.
		float d = rbox(p, vec2(0.42), 0.1);
		float edge = exp(-abs(d) * 30.0) * 0.35;
		float dia = abs(p.x) + abs(p.y);
		float gem = smoothstep(0.1, 0.085, dia);
		float halo = exp(-dia * 9.0) * 0.6;
		a = (edge + halo) * pulse + gem;
	} else if (mode == 1) {
		vec2 q = p * (1.0 - 0.05 * sin(t * 5.0));
		float d = rbox(q, vec2(0.43), 0.06);
		float line = smoothstep(0.035, 0.012, abs(d));
		float corners = step(0.2, abs(q.x)) * step(0.2, abs(q.y));
		a = line * corners + 0.18 * smoothstep(0.0, -0.1, d);
	} else if (mode == 2) {
		float r = length(p);
		float ang = atan(p.y, p.x) + t * 1.2;
		float ring = smoothstep(0.03, 0.0, abs(r - 0.38)) * step(0.0, sin(ang * 8.0));
		float ring2 = smoothstep(0.015, 0.0, abs(r - 0.3)) * 0.8;
		float glow = exp(-r * 5.0) * 0.35 * pulse;
		a = ring + ring2 + glow;
	} else if (mode == 3) {
		float d = rbox(p, vec2(0.45), 0.08);
		a = smoothstep(0.03, 0.005, abs(d)) + 0.22 * smoothstep(0.0, -0.2, d) * pulse;
	} else if (mode == 4) {
		float d = rbox(p, vec2(0.46), 0.08);
		a = 0.12 * smoothstep(0.0, -0.05, d) + 0.35 * smoothstep(0.02, 0.0, abs(d));
	} else if (mode == 5) {
		float d = rbox(p, vec2(0.47), 0.05);
		a = 0.28 * smoothstep(0.0, -0.05, d);
	} else {
		float r = length(p);
		a = exp(-r * 3.5) * pulse;
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
