shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR MAGE - TELEPORT BARS
// ===========================================================================
//  The two magic bars of a teleport out.
//
//  A bar forms above the head and a bar forms at the feet.  The clip drives
//  where they sit (`band_top` and `band_bottom`, in the mage's local space)
//  and how long they are (`bar_half_width`, the -x and +x extent of each
//  bar).  They close in on each other, meeting at the centre of the mage, and
//  the character clip shader dissolves the mage away between them.
//
//  Once they have met, the bars shrink horizontally until only a single point
//  is left, and that point finally fades out.
//
//  Everything is snapped to the pixel grid to stay crisp next to the hand
//  drawn pixel art.
// ===========================================================================

// --- Temperature Palette ----------------------------------------------------
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);  // white hot centre
uniform vec4 mid_color : source_color = vec4(1.0, 0.55, 0.13, 1.0);   // vivid orange
uniform vec4 cool_color : source_color = vec4(0.72, 0.20, 0.02, 1.0); // deep ember

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// --- Geometry ---------------------------------------------------------------
uniform vec2 canvas_size = vec2(38.0, 50.0);   // size of the effect quad in pixels
uniform float quad_top = -18.0;                 // quad top, in mage local Y
uniform float band_top = -1000.0;              // upper bar, mage local Y
uniform float band_bottom = 1000.0;            // lower bar, mage local Y
uniform float bar_half_width = 9.0;            // the -x and +x extent of a bar
uniform float bar_thickness = 1.6;             // bar thickness in pixels
uniform float bar_flatness = 1.1;              // how tall the lens is
uniform bool pixel_snap = true;

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------
// A filled, flat lens shape - this is what reads as a magic bar.  It collapses
// to a dot as the half width goes to zero.
float ellipse_fill(vec2 p, vec2 centre, vec2 radii) {
	vec2 d = (p - centre) / max(radii, vec2(0.001));
	return 1.0 - smoothstep(0.88, 1.0, length(d));
}

void fragment() {
	// the quad is laid over the mage, so UV maps back to mage local Y
	vec2 px = UV * canvas_size;

	float alpha = 0.0;
	vec3 colour = mid_color.rgb;
	float centre_x = canvas_size.x * 0.5;

	// the bars sit exactly on the band edges the character is dissolved at
	float top_y = band_top - quad_top;
	float bottom_y = band_bottom - quad_top;
	vec2 radii = vec2(max(bar_half_width, 0.5), bar_flatness);

	float top_bar = ellipse_fill(px, vec2(centre_x, top_y), radii);
	float bottom_bar = ellipse_fill(px, vec2(centre_x, bottom_y), radii);
	float mask = max(top_bar, bottom_bar);

	// the centre of each bar burns hotter towards the middle
	float heat_top = 1.0 - smoothstep(0.0, max(bar_half_width, 1.0) * 0.8, length(px - vec2(centre_x, top_y)));
	float heat_bottom = 1.0 - smoothstep(0.0, max(bar_half_width, 1.0) * 0.8, length(px - vec2(centre_x, bottom_y)));
	float heat = max(heat_top, heat_bottom);
	colour = mix(cool_color.rgb, mid_color.rgb, heat);
	colour = mix(colour, core_color.rgb, smoothstep(0.55, 1.0, heat));
	alpha = mask;

	// a small curl rides on the top bar once the bars are wide
	if (bar_half_width > 6.0) {
		vec2 curl_centre = vec2(centre_x + bar_half_width * 0.9, top_y - bar_flatness * 1.6);
		float curl = 1.0 - smoothstep(0.4, 1.4, length(px - curl_centre));
		colour = mix(colour, mid_color.rgb, curl);
		alpha = max(alpha, curl * 0.9);
	}

	if (pixel_snap) {
		alpha = step(0.5, alpha);
	}
	alpha *= opacity;
	if (alpha <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(colour, alpha);
	}
}
