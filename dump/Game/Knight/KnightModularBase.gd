extends ModularRig
class_name KnightModularBase

## The Knight's rig: flat pieces and a data driven hierarchy.
##
## The pieces are siblings, the same way the Mage's are.  What holds them
## together is the data: `roles` says which piece answers to which name,
## `groups` moves several pieces as one, and `piece_parents` says who holds
## whom.  The clip and the action scripts only ever use those names, so the
## same movement drives every view.

## The Knight's own pieces.json, which is where the roles, the groups and the
## parent relationships live.
func get_piece_data() -> Dictionary:
	var path := "res://Knight/Knight_%s/pieces.json" % perspective_name
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) == OK:
		return json.get_data() as Dictionary
	return {}
