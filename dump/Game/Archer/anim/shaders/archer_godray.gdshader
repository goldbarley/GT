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
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float aim = 1.0;

uniform vec4 fringe_color : source_color = vec4(0.62, 0.92, 0.18, 1.0);
uniform vec4 mid_color : source_color = vec4(0.86, 1.0, 0.42, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float basic_charge : hint_range(0.0, 1.0) = 0.0;
uniform float basic_burst : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D basic_charge_tex : source_color, filter_nearest;
uniform sampler2D basic_burst_tex : source_color, filter_nearest;

// the energy bow, cut out of the reference video
uniform sampler2D energy_tex : source_color, filter_nearest;

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
		float start = 0.95 + hashf(fi * 7.1) * 0.4;
		float speed = 0.70 + hashf(fi * 11.3) * 0.40;
		float k = clamp(gather * speed + hashf(fi * 5.9) * 0.20, 0.0, 1.0);
		float r = start * (1.0 - k) + 0.15 * k;
		float tail = 0.04 + 0.08 * k;
		float streak = pow(clamp(1.0 - abs(d - r) / tail, 0.0, 1.0), 3.0);
		streak *= clamp((cos(a - ang) - 0.94) / 0.06, 0.0, 1.0);
		streak *= gather * 3.5;
		col += fringe_color.rgb * streak;
		alpha = max(alpha, streak);
	}

	// --- the spiral that winds in ------------------------------------------
	if (spiral > 0.001) {
		float radius = 0.50 * (1.0 - focus * 0.85) + 0.05 * focus;
		float thick = 0.12 + 0.08 * focus;
		// the arms wind in: the further out, the further round they are
		float swirl = sin(a * 3.0 - log(max(d, 0.02)) * 5.5 + TIME * 4.2);
		float arm = pow(clamp((swirl + 0.15) / 1.15, 0.0, 1.0), 2.2);
		// the band the arms live in, fading out towards the middle
		float reach = pow(clamp(1.0 - abs(d - radius)
			/ (thick * (0.5 + 0.9 * (1.0 - focus))), 0.0, 1.0), 1.8);
		float ring = arm * reach * spiral * (1.0 - focus * 0.45);
		col += fringe_color.rgb * ring * 1.6;
		col += core_color.rgb * pow(ring, 3.0) * 0.6;
		alpha = max(alpha, ring * 0.95);
	}

	// --- the point the ring collapses to ----------------------------------
	if (focus > 0.001) {
		float r0 = 0.05 + 0.10 * focus;
		float dot = pow(clamp(1.0 - d / r0, 0.0, 1.0), 2.5);
		dot *= focus * (1.0 - energy_bow * 0.75);
		col += core_color.rgb * dot * 1.8;
		alpha = max(alpha, dot);
	}

	// --- the big energy bow (subtle flame animation) ---------------------
	// Crisp pixel-art energy bow with subtle stepped flame flicker along the
	// fiery tips and edges (updating at 8 fps on pixel steps, no water ripples).
	if (energy_bow > 0.001) {
		vec4 bow = texture(energy_tex, UV);

		// Subtle stepped flame shimmer on the glowing edges
		float step_t = floor(TIME * 8.0);
		float flame_noise = sin(UV.y * 35.0 + step_t * 2.3) * 0.5
		                  + sin(UV.y * 70.0 - step_t * 3.7) * 0.5;
		// Flame intensity: subtle pulse along the fiery tips (where green edge is)
		float edge_glow = (1.0 - bow.r) * bow.a;
		float flame_flicker = 1.0 + flame_noise * 0.18 * edge_glow;

		// Pure crisp sprite colors accented with stepped heat
		vec3 flame_col = bow.rgb * flame_flicker;
		flame_col += fringe_color.rgb * max(0.0, flame_noise) * edge_glow * 0.35;

		float a = bow.a * energy_bow;
		col += flame_col * a * 1.25;
		alpha = max(alpha, a);
	}




	// --- the glow around it all -------------------------------------------
	if (charge > 0.001) {
		float glow = pow(clamp(1.0 - d / 0.45, 0.0, 1.0), 3.0) * charge * 0.5;
		col += mid_color.rgb * glow;
		alpha = max(alpha, glow * 0.75);
	}

	// --- the burst star on the release ------------------------------------
	if (flash > 0.001) {
		// Sharp starburst instead of a huge screen-obscuring dome
		float star = pow(clamp(1.0 - d / 0.45, 0.0, 1.0), 2.5);
		float rays = pow(clamp((cos(a * 8.0) + 0.2) / 1.2, 0.0, 1.0), 2.0);
		float burst = star * (0.6 + 0.4 * rays) * flash;
		col += core_color.rgb * burst * 2.0;
		col += mid_color.rgb * burst * 0.8;
		alpha = max(alpha, burst);
	}

	// --- basic attack: frame 10 on the bow (charge light) ----------------
	if (basic_charge > 0.001) {
		vec4 c_px = texture(basic_charge_tex, UV);
		col += c_px.rgb * c_px.a * basic_charge * 1.5;
		alpha = max(alpha, c_px.a * basic_charge);
	}

	// --- basic attack: frame 11 on the bow (muzzle burst on release) ------
	if (basic_burst > 0.001) {
		vec4 b_px = texture(basic_burst_tex, UV);
		col += b_px.rgb * b_px.a * basic_burst * 1.5;
		alpha = max(alpha, b_px.a * basic_burst);
	}

	COLOR = vec4(col, alpha);

}
