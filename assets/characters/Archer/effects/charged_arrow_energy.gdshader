shader_type canvas_item;
render_mode blend_mix;

// Temperature Color Palette
uniform vec4 low_temp_color : source_color = vec4(0.86, 0.52, 0.0, 1.0);  // Amber fringe
uniform vec4 mid_temp_color : source_color = vec4(1.0, 0.88, 0.08, 1.0);  // Electric yellow
uniform vec4 high_temp_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // White hot core

// Energy Parameters
uniform float charge_progress : hint_range(0.0, 1.0) = 1.0;
uniform float energy_boost : hint_range(0.5, 3.0) = 1.3;
uniform float tip_radiance : hint_range(0.0, 1.0) = 0.0; // Strictly modulates backward 45° tip streaks
uniform float shimmer_speed = 14.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec4 tex = texture(TEXTURE, uv);
	
	if (tex.a < 0.02) {
		COLOR = vec4(0.0);
	} else {
		// Detect whether pixel is part of the 45° tip streaks:
		// Tip streaks are off-axis (abs(uv.y - 0.5) > 0.10) in the forward half (uv.x > 0.55)
		bool is_tip_streak = (abs(uv.y - 0.5) > 0.09) && (uv.x > 0.52);
		
		if (is_tip_streak) {
			// Energy radiates strictly from TIP only at ±45° backwards
			if (tip_radiance <= 0.01) {
				COLOR = vec4(0.0);
			} else {
				float streak_shimmer = sin(uv.x * 30.0 - TIME * shimmer_speed) * 0.15;
				vec4 streak_col = mix(mid_temp_color, high_temp_color, clamp(0.5 + streak_shimmer, 0.0, 1.0));
				streak_col.a = tex.a * tip_radiance * opacity;
				streak_col.rgb *= energy_boost * 1.2;
				COLOR = streak_col;
			}
		} else {
			// Arrow shaft and head: strictly clean horizontal energy beam
			float d_center = abs(uv.y - 0.5) / 0.08;
			vec4 col;
			if (d_center < 0.4) {
				col = high_temp_color;
			} else if (d_center < 0.8) {
				col = mix(high_temp_color, mid_temp_color, (d_center - 0.4) / 0.4);
			} else {
				col = mix(mid_temp_color, low_temp_color, clamp((d_center - 0.8) / 0.5, 0.0, 1.0));
			}
			
			// Tip is white hot
			if (uv.x > 0.82) {
				col = mix(col, high_temp_color, (uv.x - 0.82) / 0.18);
			}
			
			col.rgb *= energy_boost;
			col.a *= tex.a * opacity * clamp(charge_progress, 0.0, 1.0);
			COLOR = col;
		}
	}
}
