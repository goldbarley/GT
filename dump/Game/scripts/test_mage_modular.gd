extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("🧪 STARTING MODULAR MAGE (4 PERSPECTIVES) TEST SUITE")
	print("==================================================================")
	
	var perspectives = ["front", "back", "left", "right"]
	
	for p in perspectives:
		print("\n[TEST] Verifying perspective: %s" % p.to_upper())
		
		# 1. Verify files exist
		var scene_path = ModularMageUtility.get_scene_path(p)
		var json_path = ModularMageUtility.get_json_path(p)
		var tex_path = ModularMageUtility.get_texture_path(p)
		
		assert(FileAccess.file_exists(json_path), "JSON file must exist: %s" % json_path)
		assert(FileAccess.file_exists(tex_path), "Texture file must exist: %s" % tex_path)
		
		var json_data = ModularMageUtility.get_piece_data(p)
		assert(json_data.size() > 0, "JSON data must parse successfully")
		var pieces_dict = json_data.get("pieces", {}) as Dictionary
		assert(pieces_dict.size() >= 5, "Perspective %s must define at least 5 pieces" % p)
		print("  ✅ PASS: Directory files & JSON specification validated (%d pieces defined)" % pieces_dict.size())
		
		# 2. Test instantiation via ModularMageUtility
		var mage = ModularMageUtility.instantiate_mage(p)
		assert(mage != null, "ModularMageUtility must instantiate %s" % p)
		assert(mage is MageModularBase, "Instantiated mage must inherit from MageModularBase")
		root.add_child(mage)
		mage._ready()
		
		# 3. Verify all defined pieces exist and have proper Sprite2D attributes
		for p_name in pieces_dict.keys():
			var p_info = pieces_dict[p_name] as Dictionary
			var sprite = mage.get_piece(p_name)
			assert(sprite != null, "Piece '%s' must exist in %s scene" % [p_name, p])
			assert(sprite.texture != null, "Piece '%s' must have texture assigned" % p_name)
			assert(sprite.region_enabled, "Piece '%s' must have region_enabled == true" % p_name)
			
			var reg_expected = p_info.get("region", {})
			var expected_rect = Rect2(reg_expected["x"], reg_expected["y"], reg_expected["w"], reg_expected["h"])
			assert(sprite.region_rect == expected_rect, "Piece '%s' region_rect must match specification: expected %s, got %s" % [p_name, expected_rect, sprite.region_rect])
			assert(sprite.z_index == int(p_info.get("z_index", 0)), "Piece '%s' z_index must match specification" % p_name)
			
		print("  ✅ PASS: All %d piece nodes instantiated with correct region rects and z-ordering" % pieces_dict.size())
		
		# 4. Test utility manipulation methods: set_piece_visible, rotate_piece, reset_pose
		mage.set_piece_visible("hat", false)
		assert(mage.get_piece("hat").visible == false, "set_piece_visible(hat, false) must hide hat")
		
		mage.rotate_piece("staff", 0.5)
		assert(abs(mage.get_piece("staff").rotation - 0.5) < 0.001, "rotate_piece(staff, 0.5) must rotate staff")
		
		mage.reset_pose()
		assert(mage.get_piece("hat").visible == true, "reset_pose must restore hat visibility")
		assert(abs(mage.get_piece("staff").rotation) < 0.001, "reset_pose must reset staff rotation to 0.0")
		print("  ✅ PASS: Runtime manipulation (visibility toggle, joint pivot rotation, reset) verified")
		
		# 5. Test dynamic assembly from JSON on a blank node
		var blank_mage = MageModularBase.new()
		root.add_child(blank_mage)
		var assembled = blank_mage.assemble_from_json(json_path, tex_path)
		assert(assembled, "assemble_from_json must return true")
		for p_name in pieces_dict.keys():
			assert(blank_mage.get_piece(p_name) != null, "Dynamic piece '%s' must be created" % p_name)
		print("  ✅ PASS: Dynamic programmatic assembly from JSON verified")
		
		mage.queue_free()
		blank_mage.queue_free()

	print("\n==================================================================")
	print("🎉 ALL MODULAR MAGE PERSPECTIVE TESTS PASSED SUCCESSFULLY!")
	print("==================================================================")
	quit(0)
