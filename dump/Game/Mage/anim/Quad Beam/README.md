# The quad beam

The mage's ultimate: a beam thrown out in four directions at once, north
east, north west, south east and south west.

## What is here

    beam_blast.gdshader    the shader that keys the frames and lights them
    frames/                the shot, one frame per picture, 130 of them
    mage_beam_burst.gd     the node that runs the shot and aims the four beams
    quad_beam_dim.gd       the dim that comes up while the shot winds up

## The frames

They come off a rendered video at 1280 by 720, so they arrive with the dark
background baked in.  The shader keys that out, adds the remaining light
instead of painting it over whatever is behind it, and grades the colour so
the hot core stays white, the body stays gold and the rim stays violet.

The frames are kept at the size they came out at.  A smaller copy loses the
colour of the beam, and the key goes with the colour, so the shot disappears.

## The four beams

Each beam is a sprite with the frames hung on it.  The muzzle is pinned to
the node's origin, so the whole picture can be turned to aim, and the shot
goes out of the mage's hand whichever way she is facing.

The frames are drawn at an angle of 23 degrees below horizontal, because that
is the way the shot was filmed.  Every beam is turned from that to a true
diagonal.

## Where the shot comes from

The shot comes out of the gem on the mage's staff.  The gem sits in a
different place in every view, and it moves while the staff is being
animated, so the burst is told where the gem is every frame it is out:

    burst.anchor_to_gem(rig)

The rig can sit anywhere in the tree.  The place is worked out in world
terms, so the caller does not have to care where the rig or the burst live.

## The size on screen

The burst's `beam_scale` sets how big the beams are.  The blocks of the
effect are `pixel_size` texels of the source, so they get smaller with the
beam: the size of a block on screen is `pixel_size` times `beam_scale`.  At
the default of four texels and a quarter size, a block comes out about one
pixel across, which is in the same league as the hand drawn art.

## The rate

The shot is 130 frames of a 30 frames a second video.  It plays at a third
of that rate, three source frames for every frame shown, so the whole thing
takes about a second and a half.  The last twenty frames play at the full
rate, so the end of the shot lands.

## The dim

While the shot winds up, the screen goes down by 40% over half a second.
The mage and her beams stay as bright as they were.

The dim is done with a light rather than with an overlay.  A light reaches
the whole canvas whatever the camera is doing, and a light has a mask: the
things that must stay bright are given a mask of their own, and the dimming
light is kept away from it.  An overlay would have to be drawn over the mage
as well, and would then have to be un-drawn again.

The light takes light away rather than giving it, which is what a dim is; a
light that adds would only ever make things brighter.

    light.blend_mode = Light2D.BLEND_MODE_SUB

The burst makes the dim for itself, so the whole effect is one node that can
be dropped onto a character:

    burst.fire()     starts the shot and brings the dim up
    burst.finished   comes when the shot is over and the dim goes back down

Anything that should stay out of the dim is given the dim's own mask:

    burst.dim.set_exempt(node)

The wind up lasts seven tenths of a second, and the screen comes back up
over the same time when the shot is over.

The user interface is drawn in its own layer, which a light does not reach,
so it stays as bright as it was.  If it should go down with the rest of the
screen, it needs an overlay of its own.
