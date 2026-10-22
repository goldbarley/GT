extends Control

@onready var output_label: Label = $Panel/VBoxContainer/OutputLabel
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel

func _ready() -> void:
	print("==================================================================")
	print("🧪 RUNNING MODULAR MAGE TEST SUITE (SCENE RUNNER)")
	print("==================================================================")
	
	var log_lines: Array[String] = []
	var perspectives = ["front", "back", "left", "right"]
	var all_passed := true
	
	for p in perspectives:
		var line_start = "Verifying perspective: %s..." % p.to_upper()
		print(line_start)
		log_lines.append(line_start)
		
		# 1. Verify files exist
		var scene_path = ModularMageUtility.get_scene_path(p)
		var json_path = ModularMageUtility.get_json_path(p)
		var tex_path = ModularMageUtility.get_texture_path(p)
		
		if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(tex_path):
			var err = "  ❌ FAIL: Missing file(s) for %s" % p
			print(err)
			log_lines.append(err)
			all_passed = false
			continue
			
		var json_data = ModularMageUtility.get_piece_data(p)
		var pieces_dict = json_data.get("pieces", {}) as Dictionary
		if pieces_dict.size() < 5:
			var err = "  ❌ FAIL: Less than 5 pieces defined for %s" % p
			print(err)
			log_lines.append(err)
			all_passed = false
			continue
			
		# 2. Test instantiation
		var mage = ModularMageUtility.instantiate_mage(p)
		if not mage or not (mage is MageModularBase):
			var err = "  ❌ FAIL: Could not instantiate MageModularBase for %s" % p
			print(err)
			log_lines.append(err)
			all_passed = false
			continue
			
		add_child(mage)
		mage.visible = false
		
		# 3. Verify pieces
		var pieces_ok = true
		for p_name in pieces_dict.keys():
			var sprite = mage.get_piece(p_name)
			if not sprite or not sprite.texture or not sprite.region_enabled:
				pieces_ok = false
				break
				
		if not pieces_ok:
			var err = "  ❌ FAIL: Pieces not properly configured for %s" % p
			print(err)
			log_lines.append(err)
			all_passed = false
			mage.queue_free()
			continue
			
		# 4. Test manipulation
		mage.set_piece_visible("hat", false)
		mage.rotate_piece("staff", 0.5)
		mage.reset_pose()
		
		# 5. Dynamic assembly
		var blank = MageModularBase.new()
		add_child(blank)
		blank.visible = false
		var dyn_ok = blank.assemble_from_json(json_path, tex_path)
		blank.queue_free()
		mage.queue_free()
		
		if not dyn_ok:
			var err = "  ❌ FAIL: Dynamic assembly failed for %s" % p
			print(err)
			log_lines.append(err)
			all_passed = false
			continue
			
		var pass_msg = "  ✅ PASS: %s (All %d pieces verified, runtime manipulation OK)" % [p.to_upper(), pieces_dict.size()]
		print(pass_msg)
		log_lines.append(pass_msg)
		
	if all_passed:
		status_label.text = "🎉 ALL 4 MODULAR MAGE PERSPECTIVE TESTS PASSED!"
		status_label.modulate = Color(0.2, 0.9, 0.3)
	else:
		status_label.text = "❌ SOME TESTS FAILED"
		status_label.modulate = Color(0.9, 0.2, 0.2)
		
	output_label.text = "\n".join(log_lines)
	print("\n==================================================================")
	print(status_label.text)
	print("==================================================================")
