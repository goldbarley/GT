shader_type canvas_item;
render_mode blend_add;

// ===========================================================================
//  MODULAR KNIGHT - KNIGHT'S EDGE, THE FIRE
// ===========================================================================
//  The Knight's ultimate attack, in two parts.
//
//  The first part is the flame on the blade: the knight raises his sword and
//  the fire climbs it.  The second part is the sweep: a flipbook of eight
//  frames - the arc as it opens, grows and breaks into embers.
//
//  The fire is drawn in the screen's own pixels, but it is placed and sized
//  by the knight, so it is always the size of him and always in front of his
//  face, however the camera is placed.  The knight says where his face is
//  and which way he looks, and the fire is turned so that its hollow opens
//  back towards him.
//
//    charge      0 to 1, how far the fire has climbed the blade
//    slash       0 to 1, how much of the sweep is showing
//    frame       the flipbook frame, 0 to 7
//    time        the clock the flame flickers on
//    drift       how far the embers have drifted, in the master's pixels
//    drift_mix   0 to 1, how much of the art has drifted
//
//  The master's canvas is where the frames were painted, and the arc's centre,
//  its radius and the way its hollow opens are measured from the frames
//  themselves.
// ===========================================================================

uniform sampler2D flipbook : filter_linear, repeat_disable;

uniform float frames = 8.0;
uniform vec2 master_size = vec2(1158.0, 740.0);   // the canvas the art is on
uniform vec2 art_centre = vec2(473.0, 295.0);     // the arc's centre in it
uniform float art_radius = 265.0;                  // the arc's radius in it
uniform vec2 art_mouth = vec2(-0.464, -0.886);     // the way the hollow opens

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float slash : hint_range(0.0, 1.0) = 0.0;
uniform float frame : hint_range(0.0, 7.0) = 0.0;
uniform float time_seconds = 0.0;

uniform vec2 screen_size = vec2(1280.0, 720.0);  // the screen, in its own pixels
uniform vec2 origin = vec2(0.0, 0.0);        // the master's canvas, on the screen
uniform float scale = 0.05;                    // screen pixels per master pixel
uniform float mirror = 1.0;                    // -1 for the view that faces the other way
uniform float rotation = 0.0;                  // how far the fire is turned, in radians
uniform vec2 drift = vec2(0.0, 0.0);           // the embers, floating
uniform float drift_mix : hint_range(0.0, 1.0) = 0.0;
uniform float drift_wander = 26.0;              // how far each ember wanders on its own
uniform float drift_time = 0.0;                 // the clock the embers drift on

uniform vec2 blade_pos = vec2(0.0, 0.0);      // the grip, in screen pixels
uniform vec2 blade_dir = vec2(1.0, 0.0);      // along the blade
uniform float blade_len = 10.0;                // the blade's length on screen

uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.78);
uniform vec3 mid_color : source_color = vec3(1.0, 0.45, 0.06);
uniform vec3 cool_color : source_color = vec3(0.70, 0.12, 0.02);


// A turn, in the screen's own terms.
vec2 turn(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}


// A number that never repeats, from a place.  Used to give each scrap of
// ember a course of its own.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


// A soft noise, so the wander of the embers is smooth and not jittery.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void fragment() {
	// where this pixel is, on the screen
	vec2 px = UV * screen_size;

	vec3 colour = vec3(0.0);

	// ---- the flame on the blade -------------------------------------------
	if (charge > 0.001) {
		// the blade, as an axis to measure along
		vec2 along_axis = blade_dir;
		vec2 across_axis = vec2(-blade_dir.y, blade_dir.x);
		vec2 rel = px - blade_pos;
		float along = dot(rel, along_axis);
		float across = dot(rel, across_axis);

		// the fire climbs the blade, and burns past the tip as it charges
		float reach = charge * blade_len * 1.6;
		if (along > -1.0 && along < reach) {
			// the flame's body: a tongue that narrows as it climbs
			float t = clamp(along / max(1.0, reach), 0.0, 1.0);
			float width = (1.0 - t * 0.7) * blade_len * 0.75 * charge;

			// the tongues of flame lick about as they rise
			float lick = sin(along * 0.42 - time_seconds * 9.0) * 0.62
				+ sin(along * 0.19 + time_seconds * 5.5) * 0.38;
			float d = abs(across - lick * width * 0.45);

			float body = (1.0 - smoothstep(width * 0.20, width, d))
				* (1.0 - smoothstep(0.72, 1.0, t));

			if (body > 0.001) {
				// the heart of the flame is white, the edges are embers
				float heat = body * (1.0 - t * 0.55);
				vec3 flame = mix(cool_color.rgb, mid_color.rgb, smoothstep(0.10, 0.55, heat));
				flame = mix(flame, core_color.rgb, smoothstep(0.55, 1.0, heat));
				colour += flame * body;
			}
		}
	}

	// ---- the sweep --------------------------------------------------------
	if (slash > 0.001) {
		// The master's canvas, laid over the screen.  The fire is turned so
		// that its hollow opens back towards the knight, and then it is laid
		// over him at the size he is.
		vec2 rel = (px - origin) / scale;
		rel = turn(rel, -rotation);
		rel.x *= mirror;
		vec2 master = art_centre + rel;

		// The last of the fire is embers, and embers do not stop where
		// they are: they float.  The whole lot rises, and each scrap of
		// fire wanders on its own course, so the embers drift apart
		// rather than sliding as one piece.  They float in the screen's
		// own terms, so they always rise, whichever way the fire is turned.
		if (drift_mix > 0.001) {
			float slow = drift_time * 0.30;
			vec2 flow = vec2(
				vnoise(master * 0.013 + vec2(slow, 0.0)) - 0.5,
				vnoise(master * 0.013 + vec2(19.3, -slow * 0.8)) - 0.5
			) * 2.0;
			// the drift is in the master's pixels, and the master's pixels
			// are the screen's pixels, scaled
			px -= (drift + flow * drift_wander) * drift_mix * scale;
			rel = (px - origin) / scale;
			rel = turn(rel, -rotation);
			rel.x *= mirror;
			master = art_centre + rel;
		}

		vec2 m_uv = master / master_size;

		// the art stops at the edge of the master's canvas
		float inside = step(0.0, m_uv.x) * step(m_uv.x, 1.0)
			* step(0.0, m_uv.y) * step(m_uv.y, 1.0);

		// which frame of the flipbook
		float index = floor(clamp(frame, 0.0, frames - 1.0));
		vec2 uv = vec2((index + clamp(m_uv.x, 0.0, 1.0)) / frames, clamp(m_uv.y, 0.0, 1.0));

		vec4 sweep = texture(flipbook, uv) * inside;
		if (sweep.a > 0.002) {
			// the fire keeps the colour the artist gave it: white at the
			// hottest core, gold through the body, and orange in the embers
			colour += sweep.rgb * (0.75 + 0.45 * sweep.a) * sweep.a * slash;
		}
	}

	COLOR = vec4(colour, 1.0);
}
