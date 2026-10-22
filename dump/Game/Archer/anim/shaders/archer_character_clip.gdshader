shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR ARCHER - CHARACTER CLIP
// ===========================================================================
//  Dissolves the archer away between two converging bars.
//
//  The bars are drawn by the archer's own effect shaders and live in the
//  archer's local space (the same 0..33 x 0..32 canvas the pieces are
//  positioned in).
//
//  `band_top` is the upper bar (the smaller Y) and `band_bottom` the lower
//  bar.  Anything above the upper bar or below the lower bar has already been
//  passed by a bar and is fully transparent.  `feather` is how many pixels a
//  bar takes to dissolve the sprite as it travels, so the erase reads as a
//  soft wipe rather than a hard cut.
//
//  `to_local` is the inverse of the archer's global transform, so the dissolve
//  is measured in the archer's own space and stays correct no matter where the
//  archer is placed or how far it is scaled.
// ===========================================================================

uniform mat4 to_local = mat4(
	vec4(1.0, 0.0, 0.0, 0.0),
	vec4(0.0, 1.0, 0.0, 0.0),
	vec4(0.0, 0.0, 1.0, 0.0),
	vec4(0.0, 0.0, 0.0, 1.0));

uniform float band_top = -100000.0;      // upper bar, archer local Y
uniform float band_bottom = 100000.0;    // lower bar, archer local Y
uniform float feather = 2.0;             // pixels a bar takes to dissolve the sprite

varying float local_y;

void vertex() {
	vec3 canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xyz;
	vec4 local = to_local * vec4(canvas_pos, 1.0);
	local_y = local.y;
}

void fragment() {
	// the bar sweeps down from above and up from below, dissolving as it goes
	float a = smoothstep(band_top, band_top + feather, local_y);
	a *= 1.0 - smoothstep(band_bottom - feather, band_bottom, local_y);

	// The texture is deliberately NOT resampled here. Sampling it with
	// texture(TEXTURE, UV) returns the colour in the wrong space and the
	// sprite comes out roughly a gamma darker than the source art, so the
	// default fetch is used and only the alpha is scaled.
	COLOR.a *= a;

	if (COLOR.a <= 0.002) {
		discard;
	}
}
