shader_type canvas_item;
render_mode blend_mix;

// ===========================================================================
//  MODULAR KNIGHT - KNIGHT'S EDGE, THE DARK
// ===========================================================================
//  The second part of the Knight's ultimate: the whole screen goes to
//  pitch black, and the knight is taken down with it.
//
//  The quad covers the screen, and the black comes up over it.  The slash
//  that follows is drawn on another quad above this one, so it burns in the
//  dark.
//
//    dim   0 to 1, how black the screen is
// ===========================================================================

uniform float dim : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	// the black is already the colour, so only the opacity has to change
	COLOR = vec4(0.0, 0.0, 0.0, dim);
}
