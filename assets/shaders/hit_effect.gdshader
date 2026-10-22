shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  HIT IMPACT / SPARK SHADER
// ===========================================================================
//  Renders a 9-frame hit spark animation sequence based on pixel-art stars:
//    Frame 0: Tiny spark dot
//    Frame 1: Small 4-point star
//    Frame 2: Medium 4-point star
//    Frame 3: 8-point bright star
//    Frame 4: Expanding 8-point diamond star
//    Frame 5: Peak starburst explosion with radiating rays
//    Frame 6: Ring of flying spark shards
//    Frame 7: Dispersing spark shards
//    Frame 8: Fading ember sparks
//
//  Can be used on:
//    1) A dedicated quad/Sprite2D (overlay_on_sprite = false)
//    2) Directly as a material on character sprites (overlay_on_sprite = true)
// ===========================================================================

uniform sampler2D hit_texture : filter_nearest, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float num_frames = 9.0;
uniform vec4 hit_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// For direct character overlay
uniform bool overlay_on_sprite = false;
uniform vec2 spark_offset = vec2(0.5, 0.5);
uniform vec2 spark_size = vec2(1.0, 1.0);

void fragment() {
	if (overlay_on_sprite) {
		vec4 base = texture(TEXTURE, UV);
		if (base.a > 0.001) {
			// Character hit flash
			if (flash_intensity > 0.0) {
				base.rgb = mix(base.rgb, flash_color.rgb, flash_intensity);
			}
			// Overlay spark if active
			if (progress > 0.0 && progress < 1.0) {
				vec2 s_uv = (UV - spark_offset) / spark_size + vec2(0.5);
				if (s_uv.x >= 0.0 && s_uv.x <= 1.0 && s_uv.y >= 0.0 && s_uv.y <= 1.0) {
					int frame_idx = clamp(int(floor(progress * num_frames)), 0, int(num_frames) - 1);
					vec2 sample_uv = vec2((s_uv.x + float(frame_idx)) / num_frames, s_uv.y);
					vec4 spark = texture(hit_texture, sample_uv) * hit_color;
					base.rgb = mix(base.rgb, spark.rgb, spark.a);
				}
			}
		}
		COLOR = base;
	} else {
		// Dedicated quad (HitEffect node / Sprite2D)
		if (progress > 0.0 && progress < 1.0) {
			int frame_idx = clamp(int(floor(progress * num_frames)), 0, int(num_frames) - 1);
			vec2 sample_uv = vec2((UV.x + float(frame_idx)) / num_frames, UV.y);
			vec4 spark = texture(hit_texture, sample_uv) * hit_color;
			COLOR = spark;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
