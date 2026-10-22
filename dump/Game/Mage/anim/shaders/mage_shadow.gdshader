shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR MAGE - CONTACT SHADOW
// ===========================================================================
//  The soft shadow under the mage's feet.
//
//  Without it she stands on the ground as if she were painted onto it, and
//  the meteorite's leap reads as a sprite being dragged upwards rather than
//  as a mage leaving the ground.
//
//  The shadow lives on the ground, so it has to know two things the clip
//  cannot tell it: where her feet are and how high she is.  The driver
//  `mage_shadow_fx.gd` answers both and moves the quad into place, so the
//  shadow is drawn in the quad's own space and always sits in the middle
//  of it.
//
//  The higher she is, the wider and the fainter the shadow becomes, the way
//  a shadow spreads out and softens when its caster moves away from the
//  ground.
// ===========================================================================

uniform vec2 quad_size = vec2(78.0, 22.0);   // the size of the shadow quad
uniform float radius = 7.0;         // the shadow's half width
uniform float squash = 0.34;        // how flat it lies on the ground
uniform float opacity = 0.34;       // how dark it is
uniform float softness = 1.5;       // how quickly it fades out at the edge


void fragment() {
	// the offset from the middle of the quad, in the quad's own pixels
	vec2 d = (UV - vec2(0.5)) * quad_size;

	// the shadow is an ellipse lying on the ground
	vec2 e = vec2(d.x / max(radius, 0.1), d.y / max(radius * squash, 0.1));
	float r = length(e);

	// a soft edge, so the shadow fades into the ground
	float a = pow(clamp(1.0 - r, 0.0, 1.0), softness) * opacity;

	if (a <= 0.002) {
		COLOR = vec4(0.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, a);
	}
}
