shader_type canvas_item;
render_mode blend_mix;

// Temperature Color Palette
uniform vec4 fissure_hot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);    // Core white hot
uniform vec4 fissure_mid_color : source_color = vec4(1.0, 0.88, 0.08, 1.0);   // Electric yellow
uniform vec4 fissure_cool_color : source_color = vec4(0.86, 0.40, 0.0, 1.0);  // Deep amber

// Fissure Revelation & Progression
uniform float lead_progress : hint_range(0.0, 1.0) = 0.0;     // Revealed left-to-right strictly behind arrow
uniform float fade_progress : hint_range(0.0, 1.0) = 0.0;     // 0 = fresh, 1 = completely closed/faded
uniform float slash_spacing = 18.0;                           // Frequency of diagonal ground cuts
uniform float slash_angle_slope = 0.85;                       // Diagonal tilt
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	
	// 1. Strict Left-to-Right Reveal: Never show ahead of the leading edge
	if (uv.x > lead_progress || lead_progress <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Calculate local age of this segment (0 = newly opened at leading edge, 1 = old)
		float local_age = clamp((lead_progress - uv.x) * 1.8 + fade_progress, 0.0, 1.0);
		
		// 2. Uplift / Mound profile at archer's feet (start of tear, uv.x < 0.12)
		float mound_factor = 0.0;
		if (uv.x < 0.12) {
			float m_t = uv.x / 0.12;
			mound_factor = sin(m_t * 3.14159) * 0.28;
		}
		
		// 3. Diagonal fracture stripes
		float diag = uv.x * slash_spacing + (uv.y - mound_factor) * slash_angle_slope * 6.0;
		float stripe = fract(diag);
		float dist_center = abs(stripe - 0.5) * 2.0;
		
		// 4. Vertical envelope (tapered around ground line)
		float vert_mask = smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.45, uv.y);
		if (uv.x < 0.08) {
			// Mound pushes upward at the feet
			vert_mask = smoothstep(0.0, 0.20, uv.y + mound_factor) * smoothstep(1.0, 0.40, uv.y);
		}
		
		// 5. Crack width dynamics:
		// Freshly opened -> expands/widens briefly -> then closes and fades
		float width_envelope = sin(clamp(local_age * 2.5, 0.0, 3.14159));
		if (local_age > 0.8) {
			width_envelope *= (1.0 - (local_age - 0.8) / 0.2);
		}
		
		float noise = hash(vec2(floor(diag), floor(uv.y * 6.0))) * 0.2;
		float crack_mask = smoothstep(0.85 * width_envelope + noise, 0.05, dist_center) * vert_mask;
		
		if (crack_mask < 0.03 || local_age >= 0.99) {
			COLOR = vec4(0.0);
		} else {
			// Heat color progression:
			// Young -> White hot, Mid -> Yellow, Old -> Amber / Dissolving
			vec4 col;
			if (local_age < 0.25) {
				col = mix(fissure_hot_color, fissure_mid_color, local_age / 0.25);
			} else if (local_age < 0.65) {
				col = mix(fissure_mid_color, fissure_cool_color, (local_age - 0.25) / 0.40);
			} else {
				col = mix(fissure_cool_color, vec4(0.3, 0.1, 0.0, 0.0), (local_age - 0.65) / 0.35);
			}
			
			float alpha = crack_mask * (1.0 - local_age) * opacity * (1.0 - fade_progress);
			col.a *= alpha;
			COLOR = col;
		}
	}
}
