extends ModularRig
class_name MageModularBase

## The Mage's rig: flat pieces, a data driven hierarchy, and the gem on the
## staff found in the art.

## Where the mage's next spell is aimed, in the world.  It is a place in the
## world and not a tile, because a tile means nothing without a map, and
## the mage does not have to know what a map is.  The scene works out the
## tile and hands over the place.
var cast_target: Vector2 = Vector2.INF


## The mage's own pieces.json, which is where the roles, the groups and the
## parent relationships live.
func get_piece_data() -> Dictionary:
	return ModularMageUtility.get_piece_data(perspective_name)
