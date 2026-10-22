shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR MAGE - ENERGY BARRIER
// ===========================================================================
//  A glass dome that closes around the mage.
//
//  Two independent parts, as in the reference sheet:
//
//    the ground oval  spreads out first and finishes early, a flat ring
//                     lying on the floor
//    the dome         grows downwards from a point above the head, its arc
//                     extending further and further until it meets the ground
//                     oval and the shape is closed
//
//  Everything is measured in the mage's own space, the same 0..38 x 0..32
//  canvas the character pieces sit in.
// ===========================================================================

// --- Palette ----------------------------------------------------------------
uniform vec4 rim_color : source_color = vec4(0.78, 0.87, 1.00, 1.00);  // bright glass edge
uniform vec4 fill_color : source_color = vec4(0.34, 0.44, 0.95, 0.26);  // faint interior tint
uniform vec4 glow_color : source_color = vec4(0.58, 0.72, 1.00, 1.00);  // soft outer bloom

uniform float progress : hint_range(0.0, 1.0) = 0.0;  // how far the dome has formed
uniform float ground_progress : hint_range(0.0, 1.0) = 0.0;  // how far the ground oval has spread
uniform float dismiss_fade : hint_range(0.0, 1.0) = 1.0;  // the whole barrier fading out

// --- Geometry ---------------------------------------------------------------
uniform vec2 quad_origin = vec2(-16.0, -40.0);  // the effect quad corner in mage space
uniform vec2 quad_size = vec2(70.0, 76.0);       // the effect quad size in mage space
uniform float centre_x = 19.0;                  // the mage's centre line
uniform float ground_y = 31.0;                  // the floor line
uniform float dome_rx = 24.0;                    // the dome's half width
uniform float dome_ry = 33.0;                    // the dome's height above the floor
uniform float ground_rx = 22.0;                  // the ground oval's half width
uniform float ground_ry = 4.5;                   // the ground oval's half height
uniform float rim_width = 1.25;                   // the glass edge thickness in pixels
uniform float highlight_strength = 0.55;          // the specular streak on the dome


// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------
// How far a pixel is from an ellipse outline, roughly in pixels.
float ellipse_distance(vec2 p, vec2 centre, vec2 radii) {
	vec2 d = (p - centre) / max(radii, vec2(0.001));
	float r = length(d);
	return abs(r - 1.0) * min(radii.x, radii.y);
}

// A soft band around an ellipse outline.
float ellipse_band(vec2 p, vec2 centre, vec2 radii, float width) {
	float dist = ellipse_distance(p, centre, radii);
	return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, dist);
}

// How far inside the dome a pixel is, 0 at the edge and 1 at the centre.
float dome_inside(vec2 p) {
	float y = clamp((ground_y - p.y) / max(dome_ry, 0.001), 0.0, 1.0);
	float x = (p.x - centre_x) / max(dome_rx, 0.001);
	return 1.0 - clamp(x * x + y * y, 0.0, 1.0);
}

vec3 core_color_of(float fill) {
	return fill_color.rgb;
}

void fragment() {
	vec2 p = quad_origin + UV * quad_size;

	float alpha = 0.0;
	vec3 colour = rim_color.rgb;

	// ---- the ground oval, spreading out across the floor --------------------
	float g = clamp(ground_progress, 0.0, 1.0);
	if (g > 0.001) {
		float gx = max(ground_rx * g, 0.5);
		vec2 radii = vec2(gx, max(ground_ry * g, 0.5));
		float ring = ellipse_band(p, vec2(centre_x, ground_y), radii, rim_width);
		float inner = 1.0 - smoothstep(0.0, 1.0, ellipse_distance(p, vec2(centre_x, ground_y), radii) / max(radii.y, 1.0));

		colour = mix(colour, glow_color.rgb, 0.55);
		alpha = max(alpha, ring * 0.62);
		// a faint pool of light inside the ring
		alpha = max(alpha, inner * 0.16 * g);
	}

	// ---- the dome, growing downwards from above the head ------------------
	if (progress > 0.001) {
		float apex_y = ground_y - dome_ry;
		// the arc has reached this far down
		float reach = mix(apex_y, ground_y, clamp(progress, 0.0, 1.0));

		if (p.y <= reach) {
			float edge = ellipse_band(p, vec2(centre_x, ground_y), vec2(dome_rx, dome_ry), rim_width);
			// only the upper half of the ellipse belongs to the dome
			edge *= step(p.y, ground_y);

			// a faint glass fill inside the dome
			float inside = dome_inside(p);
			float fill = inside * fill_color.a * clamp(progress * 1.4, 0.0, 1.0);

			// a soft specular streak in the upper right, like the reference
			vec2 hi = vec2(centre_x + dome_rx * 0.34, ground_y - dome_ry * 0.72);
			float streak = 1.0 - smoothstep(0.0, dome_ry * 0.20, length((p - hi) * vec2(0.55, 1.0)));
			streak *= inside * highlight_strength;

			colour = mix(colour, core_color_of(fill), fill);
			alpha = max(alpha, edge);
			alpha = max(alpha, fill);
			alpha = max(alpha, streak * 0.8);
			colour = mix(colour, rim_color.rgb, max(edge, streak));
		}
	}

	alpha *= dismiss_fade;
	if (alpha <= 0.003) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(colour, clamp(alpha, 0.0, 1.0));
	}
}

