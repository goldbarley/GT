shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR MAGE - CHARACTER CLIP
// ===========================================================================
//  Dissolves the mage away between two converging teleport bars.
//
//  The bars are drawn by mage_teleport_bars.gdshader and live in the mage's
//  local space (the same 0..38 x 0..32 canvas the pieces are positioned in).
//
//  `band_top` is the upper bar (the smaller Y) and `band_bottom` the lower
//  bar.  Anything above the upper bar or below the lower bar has already been
//  passed by a bar and is fully transparent.  `feather` is how many pixels a
//  bar takes to dissolve the sprite as it travels, so the erase reads as a
//  soft wipe rather than a hard cut.
//
//  `to_local` is the inverse of the mage's global transform, so the dissolve is
//  measured in the mage's own space and stays correct no matter where the mage
//  is placed or how far it is scaled.
//
//  The gem on the staff lights the mage from wherever it is held: `gem_glow`
//  is how bright the gem is and `gem_pos` is where it is, both in the mage's
//  own space.  A spell that is charging up warms her up with it.
// ===========================================================================

uniform mat4 to_local = mat4(
	vec4(1.0, 0.0, 0.0, 0.0),
	vec4(0.0, 1.0, 0.0, 0.0),
	vec4(0.0, 0.0, 1.0, 0.0),
	vec4(0.0, 0.0, 0.0, 1.0));

uniform float band_top = -100000.0;      // upper bar, mage local Y
uniform float band_bottom = 100000.0;   // lower bar, mage local Y
uniform float feather = 2.0;          // pixels a bar takes to dissolve the sprite

uniform float gem_glow : hint_range(0.0, 1.0) = 0.0;   // how bright the gem is
uniform vec2 gem_pos = vec2(0.0, 0.0);                 // where the gem is

varying float local_y;
varying vec2 local_pos;

void vertex() {
	vec3 canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xyz;
	vec4 local = to_local * vec4(canvas_pos, 1.0);
	local_pos = local.xy;
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

	// the gem casts its light on her, brightest right at the gem itself
	if (gem_glow > 0.001) {
		float d = distance(local_pos, gem_pos);
		float warm = gem_glow * exp(-d * 0.11);
		COLOR.rgb += vec3(1.0, 0.44, 0.14) * warm * 0.8;
	}

	if (COLOR.a <= 0.002) {
		discard;
	}
}
