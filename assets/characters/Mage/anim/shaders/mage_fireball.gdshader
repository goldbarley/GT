shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR MAGE - FIREBALL
// ===========================================================================
//  The cast of the fireball spell.
//
//    progress 0.00 - 0.28   the arm raises, the gem at the top of the staff
//                          starts to glow
//    progress 0.28 - 0.42   the fireball is called out of the gem
//    progress 0.42 - 0.90   the staff rotates down and the fireball is
//                          thrown forward, arcing over into the ground
//    progress 0.90 - 1.00   the fireball hits, leaving a pit of burning ground
//
//  The pit outlives the clip: once the cast is over `linger` counts up and the
//  fire burns out over `linger_duration`.  It also stays where it was lit:
//  the driver remembers the spot in the world and hands it back in the mage's
//  own space, so the fire does not walk away with her.
//
//  Everything is measured in the mage's local space, the same 0..38 x 0..32
//  canvas the character pieces are positioned in.
// ===========================================================================

// --- Temperature Palette ----------------------------------------------------
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.85, 1.0);  // white hot
uniform vec4 mid_color : source_color = vec4(1.0, 0.48, 0.08, 1.0);   // fire orange
uniform vec4 cool_color : source_color = vec4(0.62, 0.10, 0.02, 1.0); // deep ember

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float fall : hint_range(0.0, 1.0) = 0.0;     // how far the fireball has dropped
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

uniform vec2 spawn_pos = vec2(9.0, 10.0);           // where the fireball is called from
uniform vec2 impact_pos = vec2(-9.0, 30.0);          // where it lands
uniform float arc_height = 15.0;                     // how far the throw arcs above the way

uniform vec2 gem_pos = vec2(2.0, 15.0);               // the gem at the top of the staff
uniform float gem_glow : hint_range(0.0, 1.0) = 0.0;

uniform vec2 pit_pos = vec2(34.0, 30.0);              // the burning ground
uniform float pit_strength : hint_range(0.0, 1.0) = 0.0;
uniform float linger : hint_range(0.0, 10.0) = 0.0;   // seconds since the cast ended
uniform float linger_duration : hint_range(0.0, 10.0) = 2.5;
uniform float time_seconds = 0.0;                      // the clock the embers rise on

// --- Geometry ---------------------------------------------------------------
uniform vec2 quad_origin = vec2(-34.0, -40.0);       // quad corner in mage local space
uniform vec2 quad_size = vec2(90.0, 76.0);           // quad size in mage local pixels
uniform float fireball_radius = 4.0;
uniform bool pixel_snap = true;

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// A soft round blob, used for the fireball and the trail.
float blob(vec2 p, vec2 centre, float radius) {
	float d = length(p - centre);
	return 1.0 - smoothstep(radius - 1.0, radius + 0.5, d);
}

// The position of the fireball at a given point along its flight.
//
// The fireball is thrown: it sails up out of the staff, arcs over and comes
// down into the ground in front of the mage.  The path is a parabola, drawn
// as a curve through the spawn point, a control point above the way and the
// impact point.  The sideways motion never changes direction, so the ball
// never doubles back on the staff it came from.
vec2 fireball_at(float f) {
	vec2 middle = (spawn_pos + impact_pos) * 0.5;
	// the control point is twice the arc height above the middle, so the
	// path bows that far above the straight line between the two points
	vec2 control = middle + vec2(0.0, -arc_height * 2.0);
	float u = 1.0 - f;
	return u * u * spawn_pos + 2.0 * u * f * control + f * f * impact_pos;
}

void fragment() {
	// the quad is laid over the mage, so UV maps back to mage local space
	vec2 p = quad_origin + UV * quad_size;

	float alpha = 0.0;
	vec3 colour = mid_color.rgb;

	// ---- the gem at the top of the staff ---------------------------------
	if (gem_glow > 0.001) {
		// a tight bright core with a small halo, not a big flat disc
		float core = blob(p, gem_pos, 1.4 + gem_glow * 0.8);
		float halo = blob(p, gem_pos, 3.0 + gem_glow * 1.8);
		float amount = max(core, halo * 0.30) * gem_glow;
		colour = mix(colour, core_color.rgb, core);
		colour = mix(colour, mid_color.rgb, halo * 0.6);
		alpha = max(alpha, amount);
	}

	// ---- the fireball and its trail --------------------------------------
	// The ball is summoned into the sky before it falls, so it is shown from
	// the moment it is summoned and not from the moment it starts to fall.
	// It goes away again as soon as it reaches the ground.
	bool ball_visible = progress > 0.28 && fall < 0.999;
	if (ball_visible) {
		vec2 at = fireball_at(fall);
		// the fireball spins as it falls
		float spin = fall * 6.0;

		// the trail: embers further back along the path
		for (int i = 1; i <= 5; i++) {
			float back = fall - float(i) * 0.05;
			if (back < 0.0) {
				continue;
			}
			vec2 ghost = fireball_at(back);
			float fade = (1.0 - float(i) / 6.0) * (1.0 - fall * 0.4);
			float g = blob(p, ghost, fireball_radius * (0.7 - float(i) * 0.09));
			colour = mix(colour, mid_color.rgb, 0.7);
			alpha = max(alpha, g * fade * 0.7);
		}

		// the ball itself: a hot core wrapped in licking flames
		vec2 d = p - at;
		// flames trail upwards, so the ball is taller than it is wide
		d.y *= 0.82;
		float r = length(d);
		float ang = atan(d.y, d.x);
		// a handful of flame tongues around the edge
		float lick = 0.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float phase = spin * 2.0 + fi * 1.7;
			float centre = sin(phase) * 0.9;
			float off = abs(atan(sin(ang - centre), cos(ang - centre)));
			lick = max(lick, (1.0 - smoothstep(0.0, 0.55 + 0.25 * sin(phase * 1.3), off))
				* (0.55 + 0.45 * hash(fi + floor(spin * 3.0))));
		}
		float radius = fireball_radius * (0.85 + 0.5 * lick);
		float body = 1.0 - smoothstep(radius - 1.0, radius + 0.5, r);
		float hot = 1.0 - smoothstep(0.0, fireball_radius * 0.5, r);
		colour = mix(cool_color.rgb, mid_color.rgb, clamp(hot + 0.3, 0.0, 1.0));
		colour = mix(colour, core_color.rgb, smoothstep(0.5, 1.0, hot));
		alpha = max(alpha, body);
	}

	// ---- the impact flash -------------------------------------------------
	if (progress > 0.88 && progress < 1.0) {
		float flash = 1.0 - smoothstep(0.88, 1.0, progress);
		vec2 at = impact_pos;
		float ring = 1.0 - smoothstep(0.0, 9.0 * (1.0 - flash) + 1.0, length(p - at));
		colour = mix(colour, core_color.rgb, 0.7);
		alpha = max(alpha, ring * flash);
	}

	// ---- the pit of fire on the ground ------------------------------------
	float pit = pit_strength;
	if (linger > 0.0) {
		// the fire burns out once the cast is over
		pit *= clamp(1.0 - linger / max(linger_duration, 0.001), 0.0, 1.0);
	}
	if (pit > 0.001) {
		// a low burning patch with a few licks of flame
		float dx = (p.x - pit_pos.x) / 6.0;
		float dy = (p.y - pit_pos.y) / 2.6;
		float d = length(vec2(dx, dy));
		float lick = 1.0 + hash(floor(p.x * 0.8) + floor(linger * 6.0)) * 0.7;
		float patch = 1.0 - smoothstep(0.85 * lick, 1.15 * lick, d);
		float hot = 1.0 - smoothstep(0.0, 0.6, d);
		colour = mix(cool_color.rgb, mid_color.rgb, clamp(hot + 0.4, 0.0, 1.0));
		colour = mix(colour, core_color.rgb, smoothstep(0.6, 1.0, hot));
		alpha = max(alpha, patch * pit);

		// the embers coming off the fire, drifting up and going out
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			// every ember has its own rhythm and its own place in the fire
			float life = fract(time_seconds * (0.32 + fi * 0.06) + fi * 0.41);
			float x = pit_pos.x + (hash(fi * 7.3) - 0.5) * 8.0
				+ sin(time_seconds * 1.7 + fi * 2.1) * 1.3;
			float y = pit_pos.y - 1.0 - life * 12.0;
			float ember = blob(p, vec2(x, y), 1.0) * (1.0 - life) * pit;
			colour = mix(colour, core_color.rgb, ember);
			alpha = max(alpha, ember);
		}
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
