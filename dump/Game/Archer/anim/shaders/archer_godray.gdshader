shader_type canvas_item;
render_mode blend_add;

// ===========================================================================
//  MODULAR ARCHER - GODRAY CHARGE
// ===========================================================================
//  The charge the archer winds up before a shot: green energy flies in from
//  around the screen, gathers on the bow, spirals round it, collapses into a
//  single bright point, and then opens out into a large energy bow that
//  covers the real one.
//
//  This is the node that lives on the bow, so everything it draws is centred
//  on the grip and turns with the bow.
//
//  The node runs from -1 to 1, with the middle of it on the grip.  The
//  progress of each part of the charge is driven by the clip, the same way
//  the mage's spells are driven.
//
//    gather      the streaks flying in
//    spiral      the ring spinning around the bow
//    focus       the ring collapsing to a point
//    energy_bow  the big bow opening over the real one
//    arrow       the arrow drawn back along the line of the shot
//    charge      the glow around it all
//    flash       the white out on the release
//
//  `aim` is the way the shot goes along the node: 1 for a shot to the right,
//  -1 for a shot to the left.
// ===========================================================================

uniform float gather : hint_range(0.0, 1.0) = 0.0;
uniform float spiral : hint_range(0.0, 1.0) = 0.0;
uniform float focus : hint_range(0.0, 1.0) = 0.0;
uniform float energy_bow : hint_range(0.0, 1.0) = 0.0;
uniform float arrow : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float aim = 1.0;

uniform vec4 fringe_color : source_color = vec4(0.62, 0.92, 0.18, 1.0);
uniform vec4 mid_color : source_color = vec4(0.86, 1.0, 0.42, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

const float FULL_TURN = 6.28318530718;

float hashf(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float a = atan(p.y, p.x);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// --- the streaks flying in toward the bow -----------------------------
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float ang = hashf(fi * 3.7) * FULL_TURN;
		float start = 1.15 + hashf(fi * 7.1) * 0.8;
		float speed = 0.55 + hashf(fi * 11.3) * 0.55;
		float k = clamp(gather * speed + hashf(fi * 5.9) * 0.30, 0.0, 1.0);
		float r = start * (1.0 - k) + 0.34 * k;
		float tail = 0.09 + 0.16 * k;
		float streak = pow(clamp(1.0 - abs(d - r) / tail, 0.0, 1.0), 1.6);
		streak *= clamp((cos(a - ang) - 0.86) / 0.14, 0.0, 1.0);
		streak *= (1.0 - k * 0.55) * gather * 2.6;
		col += fringe_color.rgb * streak;
		alpha = max(alpha, streak);
	}

	// --- the spiral that winds in ------------------------------------------
	if (spiral > 0.001) {
		float radius = 0.62 * (1.0 - focus * 0.90) + 0.05 * focus;
		float thick = 0.16 + 0.10 * focus;
		// the arms wind in: the further out, the further round they are
		float swirl = sin(a * 3.0 - log(max(d, 0.02)) * 5.5 + TIME * 4.2);
		float arm = pow(clamp((swirl + 0.15) / 1.15, 0.0, 1.0), 1.6);
		// the band the arms live in, fading out towards the middle
		float reach = pow(clamp(1.0 - abs(d - radius)
			/ (thick * (0.5 + 0.9 * (1.0 - focus))), 0.0, 1.0), 1.4);
		float ring = arm * reach * spiral * (1.0 - focus * 0.45);
		col += fringe_color.rgb * ring * 1.5;
		col += core_color.rgb * pow(ring, 3.0) * 0.5;
		alpha = max(alpha, ring * 0.95);
	}

	// --- the point the ring collapses to ----------------------------------
	if (focus > 0.001) {
		float r0 = 0.05 + 0.10 * focus;
		float dot = pow(clamp(1.0 - d / r0, 0.0, 1.0), 2.0);
		dot *= focus * (1.0 - energy_bow * 0.75);
		col += core_color.rgb * dot * 1.7;
		alpha = max(alpha, dot);
	}

	// --- the big energy bow -----------------------------------------------
	// A fan of sharp white shards out of the grip, the way the energy comes
	// apart in the source, rather than a smooth arc.
	if (energy_bow > 0.001) {
		float body = 0.0;
		float hot = 0.0;
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float a0 = -2.6 + hashf(fi * 3.7) * 3.6;
			float l = 0.45 + 0.55 * hashf(fi * 7.1);
			float w = 0.15 + 0.13 * hashf(fi * 5.3);
			float rel = mod(a - a0 + PI, FULL_TURN) - PI;
			float along = d * cos(rel);
			float perp = abs(d * sin(rel));
			float width = max(w * (1.0 - 0.55 * clamp(along / max(l, 0.001), 0.0, 1.0)), 0.001);
			float shard = clamp(1.0 - perp / width, 0.0, 1.0);
			shard *= step(0.0, along) * step(along, l);
			// the shard is torn, not a clean blade
			float tear = 0.78 + 0.22 * clamp(
				sin(along * 9.0 + hashf(fi * 11.0) * FULL_TURN) * 0.5 + 0.75, 0.0, 1.0);
			shard *= tear;
			body = max(body, shard);
			hot = max(hot, shard * clamp(1.0 - perp / (width * 0.55), 0.0, 1.0));
		}
		// the hot heart of it, where the shards come out of the bow
		float heart = pow(clamp(1.0 - d / 0.42, 0.0, 1.0), 1.8);
		body = max(body, heart * 0.8);
		hot = max(hot, heart);
		col += fringe_color.rgb * body * 1.1;
		col += core_color.rgb * hot * 1.6;
		alpha = max(alpha, max(body * 0.8, hot));
	}

	// --- the arrow drawn back along the line of the shot -------------------
	if (arrow > 0.001) {
		float x = p.x * aim;
		float y = p.y;
		float along = clamp(1.0 - max(0.0, -x) / 0.9, 0.0, 1.0);
		along *= clamp(x / 0.9, 0.0, 1.0);
		float shaft = pow(clamp(1.0 - abs(y) / 0.045, 0.0, 1.0), 1.4) * along;
		float head = clamp(1.0 - abs(abs(x) - 0.86) / 0.10, 0.0, 1.0);
		head *= clamp(1.0 - abs(y) / 0.11, 0.0, 1.0) * along;
		float glow = shaft * 0.5 + head * 0.5;
		col += fringe_color.rgb * glow * arrow * 1.3;
		col += core_color.rgb * (shaft * 0.8 + head) * arrow * 1.4;
		alpha = max(alpha, (shaft * 0.9 + head) * arrow);
	}

	// --- the glow around it all -------------------------------------------
	if (charge > 0.001) {
		float glow = pow(clamp(1.0 - d / 0.55, 0.0, 1.0), 2.2) * charge * 0.7;
		col += mid_color.rgb * glow;
		alpha = max(alpha, glow * 0.85);
	}

	// --- the white out on the release --------------------------------------
	if (flash > 0.001) {
		float f = pow(clamp(1.0 - d / 1.2, 0.0, 1.0), 1.5) * flash;
		col += core_color.rgb * f * 1.8;
		alpha = max(alpha, f);
	}

	COLOR = vec4(col, alpha);
}
