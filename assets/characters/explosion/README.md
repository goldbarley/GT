# The pillar of fire

A pillar of fire that stands on the ground, for the sky island.

## What is here

    explosion_blast.gdshader   the shader that keys the frames and lights them
    frames/                   the shot, one frame per picture, 125 of them
    explosion_column.gd       the node: the column, the orb at its foot, the cut

## The frames

They come off a rendered video shot from ground level, at 1280 by 720, so
they arrive with a blue grey backdrop baked in.  The blast lights that
backdrop, so there is a wide, fairly bright cool haze around the fire.

Brightness cannot tell the haze from the fire, because the haze is quite
bright and the dimmer edges of the fire are not.  What does tell them apart
is warmth: the fire is orange, white hot or deep red, so its red channel is
well above its blue one, while the backdrop and its haze are blue grey, so
their red is below their blue.  The key is made on that difference.

## How long it burns

The shot runs at eight updates a second, with most updates advancing four
source frames, so the column burns for about five and a half seconds from
the first spark to the last ember.

## The dying out

The last twenty frames of the shot are the fire going out.  The column
narrows to a couple of streaks and then to nothing, and the fire cools as it
dies, so the tail of the shot is dim and only just warm.

Two things had to be changed for that ending to be seen at all:

The key had to be let down.  It was set at a brightness that the dying fire
fell under, so the explosion stopped dead instead of fizzling out.

And the block of the effect has to be read as the brightest texel in it,
not as the one in the middle.  The last of the shot is nothing but thin
streaks of fire a couple of texels wide, and reading the middle of the
block lost every one of them.

The tail plays at the full rate, the way the quad beam's tail does, so the
ending can be seen.  The blast is quick and the dying out is slow.

## The perspective

The island is looked down on from the sky, but the column was filmed from
the ground.  So the column is treated as a billboard: it turns with the
camera and stays upright, the way the characters do.  The knight does the
same thing in `KnightIslandController`, which turns its visual root to the
camera's angle.

The column is also stretched up until it runs past the top of the screen, so
there is no top edge to give it away, and cut off at the edge of the map, so
it does not hang in the sky.

The orb of fire at its foot is the same art squashed down, so the two are
one shape rather than two things that happen to be near each other.

## The meteorite

The mage's meteorite used to end in a mushroom cloud, drawn by a shader on
her own rig.  That cloud gives way to this pillar of fire.

The clip format has a way of setting a thing off: the clip's "fx" block can
name a node to spawn, and a "spawn" parameter in the clip's keys goes from
nothing to something at the moment the effect should start.  The meteorite
clip names the "ExplosionFX" node on her rig, and the spawn happens as the
meteor lands.

The site of the impact is wherever the spell was aimed.  The aim is a place
in the world, and the meteorite's own effect turns it into the mage's own
space every frame, so the pillar and the meteor can never end up in
different places.  The site moves with the ground while she is floating, so
the pillar drops back down with her.

Aimed at nothing, the meteor lands where the clip says, in front of her.

The meteor takes 40% longer to come down, and the screen goes down by 40%
over half a second as it is summoned.  That dim is driven by the clip the
same way the spawn is: the clip's "fx" block names a "MeteoriteDim" node,
and a "dim" parameter in its keys says how dark the screen should be.

## Using it

Put the node in the scene where the fire should stand and call `fire()` on
it.  It plays once and emits `finished` when it is over.

    explosion.position = knight.position
    explosion.fire()

Set `clip_rect` to the map's own bounds, so the cut is at the edge of the
island and not at the edge of the screen.

    explosion.clip_rect = Rect2(0, 0, 456, 432)

`column_width` is how wide the column is in world pixels.  A tile on the
island is a shade under 24 pixels, so the default of 106 is about four and a
half tiles.  The column on the mage's own rig is 72, which is three tiles,
and it is set in the four rig scenes.
`column_stretch` is how many times taller than it is wide the column is
drawn; the default reaches past the top of the screen.
