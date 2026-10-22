shader_type canvas_item;
render_mode blend_add, unshaded;

// ===========================================================================
//  BEAM BLAST
// ===========================================================================
//  Draws one frame of the diagonal beam shot.
//
//  The frames come off a rendered video, so they arrive with the dark
//  vignetted background baked in.  The shader does three things, and the
//  third is the only one that matters for the look:
//
//    1. keys the background out, so the effect can be drawn over the game
//    2. adds the remaining light instead of painting it over whatever is
//       behind it, which is what makes it read as glowing
//    3. grades the colour, so the hot core stays white, the body of the beam
//       stays gold and the rim keeps its violet
//
//  Nothing in here knows what a beam is.  It takes a texture and a
//  progress value, which means the same shader can hang off a sprite on the
//  mage's rig and be driven by a clip instead of a frame counter.
// ===========================================================================

uniform sampler2D frame_tex : filter_nearest, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// How big a pixel of the effect is, in source texels.  1 is the video as it
// came, 4 makes every four by four block of it a single flat colour, which is
// what puts the shot in the same league as the game's hand drawn art.
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;

// --- keying -----------------------------------------------------------------
// The background is dark and grey.  The beam is bright, and where it is dim
// it is still strongly coloured.  A pixel is background only when it is both
// dark and colourless, so the violet rim of the beam survives.
// The background sits around a luma of 0.02 to 0.07 and is almost colourless.
// The beam is either bright (the white core) or strongly coloured (the gold
// and the violet).  So a pixel is background only when it is both dim and
// colourless.
// The backdrop is not flat: the beam lights it, so a wide soft grey wash
// spreads out around the shot.  That wash is bright enough to beat a plain
// luma cut but it is still colourless, and the beam's own gold and violet
// are not.  So the cut is made on colour as much as on brightness.
uniform float key_floor : hint_range(0.0, 1.0) = 0.45;
uniform float key_soft : hint_range(0.001, 1.0) = 0.20;
// How colourful a pixel has to be to count as part of the effect.  The beam's
// body sits around a chroma of 0.4 and its soft outer glow around 0.2, so
// this is what tells the beam from the glow around it.
uniform float key_saturation : hint_range(0.0, 1.0) = 0.32;

// --- grading ----------------------------------------------------------------
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.15;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
// the rim of the beam is violet, and it is what gives the shot its colour
uniform vec3 rim_tint : source_color = vec3(0.85, 0.70, 1.0);
// the body of the beam is gold, and it is the hot part
uniform vec3 core_tint : source_color = vec3(1.0, 0.92, 0.72);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.45;
// a glow around the whole thing, to lift it off the background
uniform float bloom : hint_range(0.0, 4.0) = 0.0;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float bloom_radius : hint_range(0.0, 8.0) = 2.0;

// The texel the frame is read from, snapped onto a grid so that the shot is
// drawn in blocks instead of smoothly.
vec2 block_uv(vec2 uv) {
	vec2 grid = vec2(textureSize(frame_tex, 0)) / max(pixel_size, 1.0);
	return (floor(uv * grid) + 0.5) / grid;
}

void fragment() {
	vec4 texel = texture(frame_tex, block_uv(UV));
	vec3 colour = texel.rgb;

	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	float mx = max(colour.r, max(colour.g, colour.b));
	float mn = min(colour.r, min(colour.g, colour.b));
	float chroma = mx - mn;

	// the background is dark and colourless, the effect is bright or colourful
	// the hot core of the beam is white, so it is kept on brightness
	float solid = smoothstep(key_floor, key_floor + key_soft, luma);
	// the body of the beam is gold and the rim is violet, so they are kept on
	// colour, with a little brightness so a dim coloured pixel still fades out
	// instead of cutting off square
	float colourful = smoothstep(key_saturation * 0.4, key_saturation, chroma)
		* smoothstep(0.05, 0.14, luma);
	float alpha = max(solid, colourful);

	// grading
	colour = max(colour - 0.5, 0.0) * contrast + 0.5;
	colour *= brightness;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(vec3(grey), colour, saturation);

	// the hot core goes white, the rim goes violet
	float hot = smoothstep(0.55, 1.0, luma);
	float cold = smoothstep(0.45, 0.05, luma) * colourful;
	colour = mix(colour, core_tint * (0.6 + hot), hot * tint_strength);
	colour = mix(colour, rim_tint * luma * 1.6, cold * tint_strength);

	// a soft glow around the brightest parts
	if (bloom > 0.0) {
		vec2 px = 1.0 / vec2(textureSize(frame_tex, 0));
		vec3 glow = vec3(0.0);
		float total = 0.0;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				vec2 offset = vec2(float(x), float(y)) * px * bloom_radius;
				vec3 s = texture(frame_tex, block_uv(UV + offset)).rgb;
				float sl = dot(s, vec3(0.299, 0.587, 0.114));
				glow += s * smoothstep(bloom_threshold, 1.0, sl);
				total += 1.0;
			}
		}
		colour += glow / total * bloom * 3.0;
	}

	COLOR = vec4(colour, alpha);
}
