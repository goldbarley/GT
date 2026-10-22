shader_type canvas_item;
render_mode blend_add;

// ===========================================================================
//  MODULAR ARCHER - GODRAY BEAM
// ===========================================================================
//  The beam the archer lets go of.  It is a long streak of white hot energy
//  with a green fringe, brightest at the head and trailing off behind, with
//  wisps running along it.
//
//  The picture is laid out backwards from the head: the head of the beam is
//  the right hand end of the rectangle, and the tail reaches back towards the
//  bow.
//
//    tail_x   where the tail of the beam is, 0 at the far end and 1 at the head
//    fade     the whole thing going out
//    width    how thick the hot core is
// ===========================================================================

uniform float tail_x : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float width : hint_range(0.01, 0.5) = 0.16;
uniform float seed = 0.0;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 mid_color : source_color = vec4(0.86, 1.0, 0.42, 1.0);
uniform vec4 fringe_color : source_color = vec4(0.62, 0.92, 0.18, 1.0);


void fragment() {
	float x = UV.x;
	float y = (UV.y - 0.5) * 2.0; // -1.0 to 1.0 (0.0 is center axis)

	// Beam extends from bow (x=0) to far offscreen (x=1)
	float head_fade = smoothstep(1.0, 0.90, x);
	float tail_fade = smoothstep(0.0, 0.03, x);
	float envelope = head_fade * tail_fade;

	float t = TIME * 18.0;

	// =========================================================================
	// 1. MAIN STRAIGHT ENERGY BEAM (Rigid Horizontal Core)
	// =========================================================================
	// Noticeable perfectly straight beam along y=0 matching reference
	float straight_w = 0.38; // solid straight horizontal beam
	float straight_core_w = 0.22; // intense pure white center

	float straight_dist = abs(y);
	float straight_core = smoothstep(straight_core_w, straight_core_w * 0.4, straight_dist);
	float straight_fringe = smoothstep(straight_w, straight_core_w, straight_dist);

	// Light high-speed internal ripples along the straight beam
	float ripple = sin(x * 50.0 - t * 2.5) * 0.12 + 0.88;
	straight_core *= ripple;

	// Forward muzzle flare right at the bow (x=0)
	float muzzle = exp(-pow(x / 0.08, 2.0)) * exp(-pow(y / 0.75, 2.0));

	// =========================================================================
	// 2. ENCIRCLING / SPIRALLING HELICAL BEAMS (Wrapping 3D Ribbons)
	// =========================================================================
	// Helix wraps around the straight beam with wider amplitude as it leaves the bow
	float wave_freq = 9.0; // wider spiral period matching reference
	float helix_radius = 0.78 * smoothstep(0.0, 0.15, x); // opens out into full orbit
	
	float phase1 = x * wave_freq - t;
	float helix_y1 = sin(phase1) * helix_radius;
	float depth1 = cos(phase1); // > 0 in front of beam, < 0 behind beam

	// Strand 2 (opposite phase):
	float phase2 = phase1 + 3.14159;
	float helix_y2 = sin(phase2) * helix_radius;
	float depth2 = cos(phase2);

	// Strand thickness and flame texturing
	float strand_w = 0.14;
	float strand1 = exp(-pow(abs(y - helix_y1) / strand_w, 2.0));
	float strand2 = exp(-pow(abs(y - helix_y2) / strand_w, 2.0));

	// Flaring wisps trailing along the ribbons
	float wisp1 = sin(x * 30.0 - t * 1.5 + y * 6.0) * 0.35 + 0.65;
	float wisp2 = sin(x * 30.0 - t * 1.5 - y * 6.0 + 3.14) * 0.35 + 0.65;
	strand1 *= wisp1;
	strand2 *= wisp2;

	// Modulate brightness by 3D depth (brighter when in front of beam)
	strand1 *= (0.75 + 0.45 * depth1);
	strand2 *= (0.75 + 0.45 * depth2);

	// Outer trailing green halo around the spirals
	float spiral_fringe = exp(-pow(abs(y - helix_y1) / (strand_w * 2.4), 1.6)) * 0.55
	                    + exp(-pow(abs(y - helix_y2) / (strand_w * 2.4), 1.6)) * 0.55;

	// =========================================================================
	// 3. COLOR COMPOSITION
	// =========================================================================
	vec3 col = vec3(0.0);

	// Straight core contributes pure white + bright light-green edge
	col += core_color.rgb * (straight_core * 2.0 + muzzle * 1.8);
	col += mid_color.rgb * (straight_fringe * 1.4 + muzzle * 1.0);

	// Spiralling beams contribute emerald and mid-green energy with bright highlights
	col += fringe_color.rgb * (strand1 + strand2 + spiral_fringe) * 1.6;
	col += mid_color.rgb * (pow(strand1, 1.8) + pow(strand2, 1.8)) * 1.3;
	col += core_color.rgb * (pow(strand1, 2.8) + pow(strand2, 2.8)) * 0.9;

	float alpha = clamp(straight_core * 1.0 + straight_fringe * 0.85 + (strand1 + strand2) * 1.0 + spiral_fringe * 0.5 + muzzle, 0.0, 1.0);
	alpha *= envelope * fade;

	COLOR = vec4(col * fade, alpha);
}



