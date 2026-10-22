shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR MAGE - METEORITE
// ===========================================================================
//  The grand cast: a burning meteorite falls out of the sky and detonates on
//  the ground in a mushroom cloud.
//
//  Everything the clip needs is driven from outside:
//
//    meteor_y      how far the meteorite is above the ground, in mage pixels
//    meteor_x      how far it is to the side of the mage
//    dust          0 to 1, the puffs kicked up when the mage jumps
//    explode       0 to 1, how far the mushroom cloud has grown
//    aftermath     0 to 1, the smoke and debris settling afterwards
//    shake         how hard the whole thing rattles
//    ground_y      the ground line, in mage local space
//
//  The quad is far bigger than the character, so the meteorite can wait high
//  in the sky and the explosion can fill the ground.
// ===========================================================================

// --- Temperature Palette ----------------------------------------------------
uniform vec4 rock_dark : source_color = vec4(0.11, 0.09, 0.10, 1.0);
uniform vec4 rock_light : source_color = vec4(0.30, 0.22, 0.19, 1.0);
uniform vec4 fire_core : source_color = vec4(1.0, 0.97, 0.82, 1.0);   // white hot
uniform vec4 fire_mid : source_color = vec4(1.0, 0.45, 0.05, 1.0);    // orange
uniform vec4 fire_yellow : source_color = vec4(1.0, 0.84, 0.24, 1.0); // bright yellow
uniform vec4 fire_deep : source_color = vec4(0.58, 0.09, 0.02, 1.0);  // ember
uniform vec4 smoke : source_color = vec4(0.29, 0.26, 0.31, 1.0);
uniform vec4 smoke_light : source_color = vec4(0.67, 0.63, 0.69, 1.0);

uniform float meteor_y : hint_range(-400.0, 400.0) = 260.0;
uniform float meteor_x : hint_range(-80.0, 80.0) = 26.0;
uniform float dust : hint_range(0.0, 1.0) = 0.0;
uniform float explode : hint_range(0.0, 1.0) = 0.0;
uniform float aftermath : hint_range(0.0, 1.0) = 0.0;
uniform float shake : hint_range(0.0, 4.0) = 0.0;
uniform float ground_y : hint_range(-200.0, 200.0) = 32.0;
uniform float meteor_radius = 18.0;
uniform float time_seconds = 0.0;
uniform float gem_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec2 gem_pos = vec2(-11.0, -10.0);
uniform float dust_spread : hint_range(0.0, 1.0) = 0.0;   // how far the dust has spread
uniform float cloud_age : hint_range(0.0, 1.0) = 0.0;    // how far the cloud has spread and cooled
uniform float centre_x : hint_range(0.0, 64.0) = 19.0;    // the mage's middle, where her feet are

// where the effect quad sits, in mage local space, and how big it is
uniform vec2 quad_origin = vec2(-80.0, -280.0);
uniform vec2 quad_size = vec2(220.0, 370.0);

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

// Puts one element on the pile.  Every element brings its own colour, and the
// strongest one wins, so a bright ember shows through a soft puff of smoke.
void layer(inout float alpha, inout vec3 colour, float a, vec3 c) {
	if (a > alpha) {
		alpha = a;
		colour = c;
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// A soft round blob, used for the cloud puffs.
float blob(vec2 p, vec2 centre, float radius) {
	return 1.0 - smoothstep(radius - 1.0, radius + 1.0, length(p - centre));
}

// A puff of dust.  A plain circle reads as a bubble, so the edge is broken
// up and the inside is patchy, the way real dust is.
float dust_puff(vec2 p, vec2 centre, float radius, float seed) {
	float d = length(p - centre);
	float lump = noise((p - centre) * 0.45 + vec2(seed, seed * 1.3)) * 1.4;
	float edge = radius * (0.70 + 0.60 * lump);
	float a = 1.0 - smoothstep(edge * 0.25, edge, d);
	a *= 0.55 + 0.60 * noise((p - centre) * 0.85 + vec2(seed * 1.7, seed));
	return a;
}

void fragment() {
	vec2 p = UV * quad_size + quad_origin;
	// p is now in mage local space, with the mage's feet near y = 32

	float alpha = 0.0;
	vec3 colour = fire_mid.rgb;

	// ---- the dust kicked up when the mage jumps ---------------------------
	// It comes out from under her feet and fans out to both sides, thinning
	// and lifting as it goes.
	if (dust > 0.001) {
		float age = clamp(dust_spread, 0.0, 1.0);
		float radius = 2.4 + age * 3.4;
		float lift = age * 4.5;
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			// they come out from under her feet and fan out to both sides
			float side = 1.0 - 2.0 * float(i % 2);
			float step_out = float(i / 2);
			float wander = (noise(vec2(fi * 5.7, time_seconds * 1.3)) - 0.5) * 2.0;
			float off = side * (2.0 + step_out * (1.5 + age * 3.2)) + wander * (0.4 + age);
			vec2 centre = vec2(centre_x + off, ground_y - 1.0 - lift * (0.55 + 0.12 * fi));
			float puff = dust_puff(p, centre, radius, fi * 9.1);
			layer(alpha, colour, puff * dust * 0.9, mix(smoke_light.rgb, smoke.rgb, age * 0.45));
		}
	}

	// ---- the gem on the staff, lighting up --------------------------------
	if (gem_glow > 0.001) {
		float d = length(p - gem_pos);
		// the hot core
		float core = 1.0 - smoothstep(0.0, 2.2, d);
		// the halo, flickering
		float halo = 1.0 - smoothstep(0.0, 5.5, d);
		halo *= 0.45 + 0.55 * noise((p - gem_pos) * 0.7 + vec2(0.0, time_seconds * 6.0));
		layer(alpha, colour, halo * 0.8 * gem_glow, fire_mid.rgb);
		layer(alpha, colour, core * gem_glow, fire_core.rgb);
		// a few sparks drifting off the gem
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float ang = time_seconds * (1.2 + fi * 0.4) + fi * 1.57;
			float orbit = 1.6 + fi * 1.1;
			vec2 centre = gem_pos + vec2(cos(ang), sin(ang)) * orbit;
			float spark = blob(p, centre, 0.7 + gem_glow * 0.5);
			layer(alpha, colour, spark * 0.9 * gem_glow, fire_core.rgb);
		}
	}

	// ---- the meteorite, burning -------------------------------------------
	if (meteor_y > 0.0) {
		vec2 centre = vec2(meteor_x, ground_y - meteor_y);
		// it tumbles a little on the way down
		float wobble = (noise(vec2(time_seconds * 2.5, 0.0)) - 0.5) * 2.5;
		centre.x += wobble;

		// the tail of fire streaming up behind it
		float trail_len = 90.0;
		float along = centre.y - p.y;
		if (along > -2.0 && along < trail_len) {
			float fade = clamp(1.0 - along / trail_len, 0.0, 1.0);
			// the tail is ragged, not a clean cone
			float rip = noise(vec2(along * 0.09, time_seconds * 3.0)) * 0.9;
			float half_w = meteor_radius * (0.20 + fade * 1.35) * (0.75 + rip);
			float off = p.x - centre.x - wobble * fade;
			float band = 1.0 - smoothstep(half_w * 0.15, half_w, abs(off));
			// the tail breaks up into wisps as it goes
			float wisp = noise(vec2(off * 0.30, along * 0.10 - time_seconds * 6.0));
			float tail = band * fade * fade * (0.40 + 0.90 * wisp);
			layer(alpha, colour, tail * 0.92, mix(fire_mid.rgb, fire_core.rgb, fade * fade * 0.75));
		}

		// the rock: a lumpy dark mass
		float lump = noise((p - centre) * 0.26) * 2.6;
		float r = length(p - centre);
		float rock = 1.0 - smoothstep(meteor_radius - 1.5 + lump, meteor_radius + 0.5 + lump, r);
		layer(alpha, colour, rock, mix(rock_dark.rgb, rock_light.rgb, noise((p - centre) * 0.5)));

		// the burning crust, hottest on the leading, lower edge
		float rim = 1.0 - smoothstep(meteor_radius * 0.5, meteor_radius * 1.12, r);
		rim *= 0.45 + 0.55 * noise((p - centre) * 0.42 + vec2(0.0, time_seconds * 7.0));
		float low = smoothstep(centre.y - meteor_radius * 0.9, centre.y + meteor_radius, p.y);
		layer(alpha, colour, rim * 0.96, mix(fire_deep.rgb, fire_mid.rgb, low));

		// the white hot leading edge
		float lead = 1.0 - smoothstep(meteor_radius * 0.30, meteor_radius * 0.95, r);
		lead *= smoothstep(centre.y - meteor_radius * 0.1, centre.y + meteor_radius * 0.95, p.y);
		lead *= 0.35 + 0.65 * noise((p - centre) * 0.8 + vec2(0.0, time_seconds * 9.0));
		layer(alpha, colour, lead * 0.97, mix(fire_mid.rgb, fire_core.rgb, 0.55));
	}

	// ---- the mushroom cloud ------------------------------------------------
	// A wall of fire in the shape of a mushroom: a narrow column of flame
	// climbing out of the impact, a wide billowing cap of lobes on top of
	// it, and the ground thrown out in chunks around the base.
	//
	// Once it has reached full size the cloud does not shrink away.  It
	// spreads out, cools from fire to smoke and thins until it has merged
	// with the air, the way a puff of dust does.
	if (explode > 0.001) {
		float e = explode;
		float age = clamp(cloud_age, 0.0, 1.0);
		float ground = ground_y;
		// and the whole of it fades as it goes
		float fade = (1.0 - age) * (1.0 - age * 0.3);

		// the stem: a narrow column of flame climbing out of the impact.  It
		// is eaten away from the bottom as the cloud spreads.
		float stem_h = 17.0 * e * (1.0 - age * 0.8);
		float stem_w = 4.6 * (1.0 - e * 0.25) * (1.0 + age * 0.8);
		if (p.y < ground && p.y > ground - stem_h) {
			float inside = 1.0 - smoothstep(stem_w - 0.8, stem_w + 0.8, abs(p.x - meteor_x));
			// the column is made of streaks of flame
			float streak = 0.55 + 0.45 * noise(vec2(p.x * 1.4, p.y * 0.30 - time_seconds * 3.5));
			layer(alpha, colour, inside * streak * (0.95 - e * 0.15) * fade,
				mix(fire_mid.rgb, fire_core.rgb, streak * 0.55));
		}

		// the cap: a wide billowing cloud of lobes on top of the stem.  It
		// spreads wider than it grows tall, and lifts as it goes.
		float cap_y = ground - stem_h - 1.0 - age * 5.0;
		float cap_rx = (5.0 + 19.0 * e) * (1.0 + age * 1.15);
		float cap_ry = (3.0 + 10.0 * e) * (1.0 + age * 0.45);
		vec2 cap_p = p - vec2(meteor_x, cap_y);
		vec2 cap_n = cap_p / vec2(cap_rx, cap_ry);
		float shell = length(cap_n);

		// the edge is lumpy, the way a cauliflower is
		float scallop = noise(cap_p * 0.35 + vec2(0.0, time_seconds * 0.4)) * 0.30 * e;
		float cap = 1.0 - smoothstep(0.92 - scallop, 1.06 - scallop, shell);

		// and there are lobes heaving up out of it
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float a2 = -3.14159 + 3.14159 * (fi + 0.5) / 7.0;
			vec2 lobe = vec2(cos(a2) * 0.68, sin(a2) * 0.82);
			float d = length(cap_n - lobe);
			float r = 0.42 + 0.14 * noise(vec2(fi * 3.3, time_seconds * 0.5));
			cap = max(cap, 1.0 - smoothstep(r * 0.55, r, d));
		}

		// the cap is white hot where it comes off the column and cools to a
		// deep red at the rim
		float heat = 1.0 - smoothstep(0.0, 1.0, shell);
		vec3 cloud = mix(fire_mid.rgb, fire_core.rgb, heat * 0.8);
		float rim = smoothstep(0.55, 1.05, shell);
		cloud = mix(cloud, fire_deep.rgb, rim * 0.65);
		// and the top of it catches the light
		float high = smoothstep(0.35, -0.85, cap_n.y);
		cloud = mix(cloud, fire_yellow.rgb, high * 0.45);
		// then the whole thing cools and turns to smoke as it spreads
		cloud = mix(cloud, smoke_light.rgb, smoothstep(0.05, 0.62, age));
		cloud = mix(cloud, smoke.rgb, smoothstep(0.45, 1.0, age) * 0.5);
		layer(alpha, colour, cap * 0.96 * fade, cloud);

		// the hot core of the blast, right at the impact
		float flash = 1.0 - smoothstep(0.0, 13.0 * e, length(p - vec2(meteor_x, ground - 3.0 * e)));
		layer(alpha, colour, flash * (1.0 - e) * 0.95, fire_core.rgb);
		float hot = 1.0 - smoothstep(0.0, 14.0 * e, length(p - vec2(meteor_x, ground - 5.0 * e)));
		layer(alpha, colour, hot * (1.0 - e * 0.8) * 0.55, fire_mid.rgb);

		// the fire still burning at the foot of the cloud
		float base = 1.0 - smoothstep(0.0, 12.0 * e + 4.0, length(p - vec2(meteor_x, ground - 2.0)));
		base *= 0.6 + 0.4 * noise((p - vec2(meteor_x, ground)) * 0.5 + vec2(0.0, time_seconds * 4.0));
		layer(alpha, colour, base * (1.0 - e * 0.75) * 0.9 * fade, fire_mid.rgb);

		// the shockwave racing out along the ground
		float ring_r = 5.0 + 38.0 * e;
		float ring = 1.0 - smoothstep(0.0, 2.5, abs(length(p - vec2(meteor_x, ground)) - ring_r));
		ring *= (1.0 - e) * step(abs(p.y - ground), 3.0);
		layer(alpha, colour, ring * 0.9, fire_core.rgb);

		// the ground thrown out in chunks around the base
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float side = 1.0 - 2.0 * float(i % 2);
			float step_out = float(i / 2);
			vec2 centre = vec2(meteor_x + side * (4.0 + step_out * (4.5 + 9.0 * e)), ground - 1.0 - step_out * 0.6);
			// the chunks are hard and angular, not round
			float lump = noise((p - centre) * 0.9 + fi * 5.0) * 0.9;
			float size = 1.4 + e * 1.8;
			float chunk = 1.0 - smoothstep(size * (0.45 + lump), size * (0.80 + lump), length(p - centre));
			layer(alpha, colour, chunk * (1.0 - e * 0.35) * 0.95 * fade, mix(rock_dark.rgb, rock_light.rgb, 0.25));
		}

		// embers thrown out of the blast
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float spread = (fi - 2.0) * (5.0 + 16.0 * e);
			vec2 centre = vec2(meteor_x + spread, ground - 3.0 - fi * 3.0 * e);
			float ember = blob(p, centre, 1.2);
			layer(alpha, colour, ember * (1.0 - e * 0.5) * 0.8 * fade, fire_mid.rgb);
		}
	}

	// ---- the smoke and debris settling afterwards --------------------------
	if (aftermath > 0.001) {
		float a = aftermath;
		float age = clamp(cloud_age, 0.0, 1.0);
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float drift = a * (5.0 + fi * 3.5);
			vec2 centre = vec2(meteor_x + (fi - 2.0) * 10.0 + drift * 0.5, ground_y - 5.0 - drift);
			float puff = blob(p, centre, 2.5 + a * 4.5);
			layer(alpha, colour, puff * (1.0 - a) * 0.55 * (1.0 - age), smoke.rgb);
		}
	}

	if (alpha <= 0.004) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(colour, clamp(alpha, 0.0, 1.0));
	}
}
