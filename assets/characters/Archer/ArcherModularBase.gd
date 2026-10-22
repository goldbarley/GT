extends ModularRig
class_name ArcherModularBase

## The Archer's rig: flat pieces, a data driven hierarchy, and the leaves and
## cloth she wears.
##
## The archer's own pieces.json is where the roles, the groups and the parent
## relationships live, exactly as it is for the Mage.

## The archer's own pieces.json, which is where the roles, the groups and the
## parent relationships live.
func get_piece_data() -> Dictionary:
	return ModularArcherUtility.get_piece_data(perspective_name)
