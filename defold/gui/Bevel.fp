/****************************************************************************************
*-  _________.__              .__
*- /   _____/|  |   _______  _|__|____    ____  ©2025
*- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
*- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
*-/_______  /|____/\____/ \_/ |__(____  /___|  /
*-       \/                          \/     \/
****************************************************************************************/
// Bevel.fp
varying mediump vec2 v_uv;

uniform lowp    vec4 base_color;
uniform lowp    vec4 border_color;
uniform mediump vec4 edge_data;    // x=round_px, y=border_px, z=bevel_px
uniform mediump vec4 panel_size;   // x=width, y=height

// signed‐distance to a rounded rectangle
mediump float sdRoundedRect(vec2 p, vec2 half_size, float r) {
	vec2 d = abs(p) - (half_size - vec2(r));
	return length(max(d,0.0)) + min(max(d.x,d.y), 0.0) - r;
}

void main() {
	// unpack
	float round_px  = edge_data.x;
	float border_px = edge_data.y;
	float bevel_px  = edge_data.z;

	vec2 size       = panel_size.xy;
	vec2 half_size  = 0.5 * size;

	vec2 p = (v_uv - vec2(0.5)) * size;

	// SDF & AA
	float sd    = sdRoundedRect(p, half_size, round_px);
	float aa    = 1.0 - smoothstep(0.0, 1.0, sd);
	float d_in  = -sd;              // ≥0 inside

	if (d_in <= 0.0) {              // outside
		discard;
	} else if (d_in < border_px) {
		gl_FragColor = border_color * aa;
	} else if (d_in < border_px + bevel_px) {
		float t = smoothstep(border_px, border_px + bevel_px, d_in);
		float light = mix(1.25, 0.75, step(0.0, p.x + p.y));
		vec3  rgb   = mix(border_color.rgb, base_color.rgb, t) * light;
		gl_FragColor = vec4(rgb, mix(border_color.a, base_color.a, t)) * aa;
	} else {
		gl_FragColor = base_color * aa;
	}
}
