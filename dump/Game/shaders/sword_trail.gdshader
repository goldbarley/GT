shader_type canvas_item;
render_mode blend_mix;

// --- Temperature Color Palette ---
// Low temperature: crescent area closest to the sprite -> Darker shade of yellow / amber
uniform vec4 low_temp_color : source_color = vec4(0.86, 0.52, 0.0, 1.0);
// Mid temperature: middle of crescent -> Vibrant golden yellow
uniform vec4 mid_temp_color : source_color = vec4(1.0, 0.88, 0.08, 1.0);
// High temperature: crescent area farthest from the sprite -> Bright pure white
uniform vec4 high_temp_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float trail_sweep : hint_range(0.0, 1.0) = 1.0;                 // How much of the arc is drawn downward (0 = none, 1 = full)
uniform float appearance_opacity : hint_range(0.0, 1.0) = 1.0;          // Rapid appearance opacity from 0% to 100% as sword draws down
uniform float die_down : hint_range(0.0, 1.0) = 0.0;                    // Die down: thins from inner low-temp to outer high-temp, then fades

uniform vec2 center = vec2(0.38, 0.50);                                 // Pivot center in UV coordinates
uniform float arc_radius = 0.44;                                        // Mid radius of the crescent arc
uniform float max_thickness = 0.165;                                    // Maximum thickness at arc center (+10% width)
uniform float min_thickness_px = 1.0;                                   // 1px wide at either edge
uniform float texture_size = 320.0;                                     // Size of the canvas quad in pixels

uniform float angle_start = -1.67;                                      // Arc start angle in radians (+15% length: ~ -96 degrees)
uniform float angle_end = 1.67;                                         // Arc end angle in radians (+15% length: ~ +96 degrees)
uniform float crescent_exponent = 0.60;                                 // Slow-thinning crescent profile exponent

uniform bool pixel_snap = true;
uniform float pixel_grid_size = 160.0;                                  // Retro pixel art snapping resolution

void fragment() {
	vec2 uv = UV;
	if (pixel_snap && pixel_grid_size > 0.0) {
		uv = floor(uv * pixel_grid_size) / pixel_grid_size;
	}
	
	vec2 delta = uv - center;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);
	
	float arc_range = angle_end - angle_start;
	float t = (angle - angle_start) / arc_range;
	
	vec4 col = vec4(0.0);
	
	// Check if within the angular arc and sweep
	if (t >= 0.0 && t <= 1.0 && t <= trail_sweep) {
		// Crescent moon profile: thickest in center (t=0.5), thinning to 1px at t=0.0 and t=1.0
		float crescent = pow(sin(t * 3.1415926535), crescent_exponent);
		
		float min_thick_uv = min_thickness_px / texture_size;
		float current_thickness = min_thick_uv + (max_thickness - min_thick_uv) * crescent;
		float half_thick = current_thickness * 0.5;
		
		float r_inner = arc_radius - half_thick;
		float r_outer = arc_radius + half_thick;
		
		// Die down animation:
		// From 0.0 to 0.8: thins from area of low temperature (inner) towards area of high temperature (outer)
		// until only a razor-thin 1px filament at r_outer remains.
		// From 0.8 to 1.0: the razor-thin filament fades out completely.
		float thin_factor = min(1.0, die_down / 0.80);
		float fade_factor = max(0.0, (die_down - 0.80) / 0.20);
		float alpha_mul = (1.0 - fade_factor) * appearance_opacity;
		
		float r_inner_eff = r_inner + (r_outer - min_thick_uv - r_inner) * thin_factor;
		
		if (dist >= r_inner_eff && dist <= r_outer) {
			// Rising temperature gradient from r_inner (closest to sprite) to r_outer (farthest from sprite)
			float u_temp = clamp((dist - r_inner) / (r_outer - r_inner), 0.0, 1.0);
			
			vec4 energy_color;
			if (u_temp < 0.5) {
				float f = u_temp / 0.5;
				energy_color = mix(low_temp_color, mid_temp_color, f);
			} else {
				float f = (u_temp - 0.5) / 0.5;
				energy_color = mix(mid_temp_color, high_temp_color, f);
			}
			
			// Highlight the outer razor-thin edge with pure hot white as it reaches extreme thinness
			if (thin_factor > 0.6) {
				energy_color = mix(energy_color, high_temp_color, (thin_factor - 0.6) / 0.4);
			}
			
			float tail_fade = min(1.0, max(0.0, t / 0.06));
			float alpha = alpha_mul * tail_fade;
			
			col = vec4(energy_color.rgb, energy_color.a * alpha);
		}
	}
	
	COLOR = col;
}
