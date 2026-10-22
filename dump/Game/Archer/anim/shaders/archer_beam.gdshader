shader_type canvas_item;
render_mode blend_add;

// ===========================================================================
//  MODULAR ARCHER - GODRAY BEAM
// ===========================================================================
//  The beam the archer lets go of.  It is a long streak of white hot energy
//  with a green fringe, hottest at the head and trailing off behind, with
//  wisps running along it.
//
//  The node runs backwards along the shot: the right hand end of the rectangle
//  is the head of the beam, which is where the beam is doing its damage, and
//  the left hand end is the tail, 200 pixels back, where it left the bow.
//
//    length  how much of the beam is still there, 0 to 1
//    fade    the whole thing going out
//    width   how thick the hot core is
// ===========================================================================

uniform float length : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float width : hint_range(0.01, 0.5) = 0.16;
uniform float seed = 0.0;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.86, 1.0, 0.42, 1.0);
uniform vec4 fringe_color : source_color = vec4(0.62, 0.92, 0.18, 1.0);


void fragment() {
	float x = UV.x;
	float y = UV.y - 0.5;

	// the tail burns away as the beam goes
	float along = smoothstep(1.0 - length, 1.0 - length + 0.18, x);

	// it tapers along its length, thickest at the head
	float w = width * (0.22 + 0.78 * x);

	// the wisps running along it
	float n = sin(x * 21.0 + seed) * 0.5 + sin(x * 9.0 - seed * 1.7) * 0.35
		+ sin(x * 47.0 + seed * 3.1) * 0.15;
	float core = exp(-pow(abs(y) / max(w, 0.001), 2.0));
	core *= 0.70 + 0.30 * n;
	float fringe = exp(-pow(abs(y) / max(w * 2.4, 0.001), 2.0));

	// the head is the hot end
	float tip = exp(-pow((x - 1.0) / 0.06, 2.0));

	vec3 col = fringe_color.rgb * fringe * 0.85;
	col += mid_color.rgb * core * 0.7;
	col += core_color.rgb * (core * 1.15 + tip * 1.2);

	float alpha = clamp(fringe * 0.8 + core * 0.9 + tip, 0.0, 1.0);

	COLOR = vec4(col * along * fade, alpha * along * fade);
}
