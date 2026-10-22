shader_type canvas_item;
render_mode blend_mix;

// --- Temperature Color Palette (from Knight's Sword Slash) ---
// Low temperature: shockwave area closest to the archer -> Darker shade of yellow / amber
uniform vec4 low_temp_color : source_color = vec4(0.86, 0.52, 0.0, 1.0);
// Mid temperature: middle part of the shockwave -> Vibrant golden yellow
uniform vec4 mid_temp_color : source_color = vec4(1.0, 0.88, 0.08, 1.0);
// High temperature: extreme far part of the shockwave -> Bright pure white
uniform vec4 high_temp_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- Dynamic Shockwave Controls ---
uniform float energy_boost : hint_range(0.5, 2.5) = 1.0;                  // Luminance boost during peak stage
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;             // Fine-grained edge erosion & thinning
uniform float opacity : hint_range(0.0, 1.0) = 1.0;                       // Overall opacity multiplier
uniform vec4 elemental_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // Recolor tint for abilities

// --- Pixel Art Snapping ---
uniform bool pixel_grid_snap = true;
uniform vec2 pixel_grid_size = vec2(48.0, 34.0);

// Simple hash for procedural pixel dithering / erosion
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	if (pixel_grid_snap && pixel_grid_size.x > 0.0 && pixel_grid_size.y > 0.0) {
		uv = (floor(uv * pixel_grid_size) + 0.5) / pixel_grid_size;
	}
	
	vec4 tex = texture(TEXTURE, uv);
	if (tex.a < 0.05) {
		COLOR = vec4(0.0);
	} else {
		// Calculate normalized position along arrow trajectory:
		// 0.0 at archer end (left), 1.0 at extreme far end (right)
		float pos_t = clamp((uv.x - 0.06) / 0.86, 0.0, 1.0);
		
		// Modulate temperature by energy boost (peak expands high temperature forward/backward)
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float u_temp = clamp(pos_t * (0.8 + 0.2 * energy_boost) + (energy_boost - 1.0) * 0.2, 0.0, 1.0);
		
		vec4 mapped_color;
		if (u_temp < 0.45) {
			// Low temperature: closest to archer -> Dark yellow / amber
			float f = u_temp / 0.45;
			mapped_color = mix(low_temp_color, mid_temp_color, f);
		} else {
			// Mid to High temperature: middle golden yellow -> extreme far pure white
			float f = (u_temp - 0.45) / 0.55;
			mapped_color = mix(mid_temp_color, high_temp_color, f);
		}
		
		// Modulate slightly by native pixel luminance for shading/depth
		mapped_color.rgb *= mix(0.85, 1.0, lum);
		
		// Apply elemental tint
		mapped_color.rgb *= elemental_tint.rgb;
		
		// Edge dissolution / erosion logic for sub-frame thinning
		float alpha = tex.a * opacity;
		if (dissolve_progress > 0.0) {
			vec2 pixel_coord = floor(uv * pixel_grid_size);
			float n = hash(pixel_coord);
			if (n < dissolve_progress) {
				alpha = 0.0;
			}
		}
		
		COLOR = vec4(clamp(mapped_color.rgb, vec3(0.0), vec3(1.0)), alpha);
	}
}
