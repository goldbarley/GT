shader_type canvas_item;
render_mode blend_add, unshaded;

// ===========================================================================
//  EXPLOSION
// ===========================================================================
//  Draws one frame of the explosion shot.
//
//  The shot comes off a rendered video with a blue grey backdrop baked in,
//  and the blast lights that backdrop, so there is a wide cool haze around
//  the fire.  Brightness alone cannot tell the haze from the fire, because
//  the haze is quite bright and the dimmer edges of the fire are not.
//
//  What does tell them apart is warmth.  The fire is orange, white hot or
//  deep red, so its red channel is well above its blue one.  The backdrop
//  and the haze it lights are blue grey, so their red is below their blue.
//  The key is made on that difference.
//
//  The fire cools as it dies, so the last of the shot is dim and only just
//  warm.  The key has to let that through, or the explosion stops dead
//  instead of fizzling out.
// ===========================================================================

uniform sampler2D frame_tex : filter_nearest, repeat_disable;

// How big a pixel of the effect is, in source texels.
uniform float pixel_size : hint_range(1.0, 32.0) = 8.0;

// --- keying -----------------------------------------------------------------
// How warm a pixel has to be before it counts as fire.
uniform float warm_floor : hint_range(0.0, 1.0) = 0.05;
uniform float warm_soft : hint_range(0.001, 1.0) = 0.08;
// How bright a pixel has to be before it counts as fire.
uniform float light_floor : hint_range(0.0, 1.0) = 0.035;
uniform float light_soft : hint_range(0.001, 1.0) = 0.09;

// --- grading ----------------------------------------------------------------
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.15;
uniform vec3 core_tint : source_color = vec3(1.0, 0.95, 0.78);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.35;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// The texel the frame is read from, taken as the brightest of the block.
//
// Reading the middle of the block would lose anything thin, and the last
// of the shot is nothing but thin streaks of dying fire.  So the block is
// read at a few points and the brightest one is taken, which keeps the
// streaks and is how a picture like this wants to be blocked up anyway.
vec3 block_texel(vec2 uv) {
	vec2 size = vec2(textureSize(frame_tex, 0));
	float block = max(pixel_size, 1.0);
	vec2 cell = floor(uv * (size / block));
	vec2 centre = (cell + 0.5) * block;
	vec3 best = vec3(0.0);
	float best_luma = -1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 at = centre + vec2(float(x), float(y)) * (block * 0.4);
			vec3 s = texture(frame_tex, (at + 0.5) / size).rgb;
			float l = dot(s, LUMA);
			if (l > best_luma) {
				best_luma = l;
				best = s;
			}
		}
	}
	return best;
}

void fragment() {
	vec3 colour = block_texel(UV);

	float luma = dot(colour, LUMA);
	// how much warmer than blue the pixel is, from -1 to 1
	float warm = (colour.r - colour.b);

	// the fire is warm and lit, the backdrop is neither
	float fire = smoothstep(warm_floor, warm_floor + warm_soft, warm)
		* smoothstep(light_floor, light_floor + light_soft, luma);

	// grading
	colour *= brightness;
	float grey = dot(colour, LUMA);
	colour = mix(vec3(grey), colour, saturation);

	// the hot core goes white
	float hot = smoothstep(0.6, 1.0, luma);
	colour = mix(colour, core_tint * (0.7 + hot), hot * tint_strength);

	COLOR = vec4(colour * fire, fire);
}
