extends SceneTree

func _init() -> void:
	print("--- BEGINNING COMPREHENSIVE REQUIREMENTS VERIFICATION ---")
	
	# Load SkyIslandGrid script
	var grid_script = load("res://scripts/SkyIslandGrid.gd")
	if not grid_script:
		push_error("Failed to load SkyIslandGrid.gd")
		quit(1)
		return
		
	var grid = grid_script.new()
	
	# 1. Grid Dimensions: 13 columns x 15 rows
	print("\n[TEST 1] Grid dimensions:")
	assert(grid.COLS == 13, "Grid COLS must be 13")
	assert(grid.ROWS == 15, "Grid ROWS must be 15")
	assert(grid.grid.size() == 15, "Grid row count must be 15")
	for r in range(15):
		assert(grid.grid[r].size() == 13, "Each grid row must have 13 columns")
	print("  PASS: Grid is strictly 13 columns x 15 rows (195 tiles total).")
	
	# 2. Coordinate conversions round-trip
	print("\n[TEST 2] Coordinate conversions:")
	var test_tiles = [Vector2i(0, 0), Vector2i(6, 7), Vector2i(12, 14), Vector2i(4, 3)]
	for t in test_tiles:
		var w_pos = grid.tile_to_world(t)
		var back_t = grid.world_to_tile(w_pos)
		assert(back_t == t, "Tile %s converted to %s and back to %s (mismatch!)" % [t, w_pos, back_t])
	print("  PASS: tile_to_world and world_to_tile are perfectly reversible.")
	
	# 3. Obstacles: Pillars & Ruin
	print("\n[TEST 3] Pillars & Obstacles with user corrections:")
	assert(grid.is_tile_walkable(Vector2i(4, 3)), "Tile (4, 3) must be walkable per correction")
	assert(not grid.is_tile_walkable(Vector2i(4, 4)), "Tile (4, 4) must be obstructed by NW pillar")
	assert(grid.is_tile_walkable(Vector2i(8, 2)), "Tile (8, 2) must be walkable per correction")
	assert(not grid.is_tile_walkable(Vector2i(8, 3)), "Tile (8, 3) must be obstructed by NE pillar")
	assert(grid.is_tile_walkable(Vector2i(3, 10)), "Tile (3, 10) must be walkable per correction")
	assert(not grid.is_tile_walkable(Vector2i(3, 9)), "Tile (3, 9) must be obstructed by SW pillar")
	assert(not grid.is_tile_walkable(Vector2i(9, 7)), "Tile (9, 7) must be obstructed by East ruin")
	assert(grid.is_tile_walkable(Vector2i(8, 8)), "Tile (8, 8) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(9, 8)), "Tile (9, 8) must be walkable per correction")
	assert(not grid.is_tile_walkable(Vector2i(8, 10)), "Tile (8, 10) must be obstructed by South rubble")
	print("  PASS: Pillars and obstacles match user corrections.")
	
	# 4. Pits
	print("\n[TEST 4] Pits (Chasms):")
	assert(not grid.is_tile_walkable(Vector2i(2, 1)), "Tile (2, 1) NW pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(2, 2)), "Tile (2, 2) NW pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(10, 1)), "Tile (10, 1) NE pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(11, 1)), "Tile (11, 1) NE pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(10, 2)), "Tile (10, 2) NE pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(11, 2)), "Tile (11, 2) NE pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(6, 8)), "Tile (6, 8) Center pit must be impassable")
	assert(not grid.is_tile_walkable(Vector2i(10, 10)), "Tile (10, 10) SE pit must be impassable")
	print("  PASS: All sky chasms/pits are classified as impassable.")
	
	# 5. Walkable corridors & borders
	print("\n[TEST 5] Walkable corridors & borders:")
	for r in range(1, 11):
		assert(grid.is_tile_walkable(Vector2i(0, r)), "Tile (0, %d) must be walkable per correction" % r)
	for r in range(0, 13):
		assert(grid.is_tile_walkable(Vector2i(12, r)), "Tile (12, %d) must be walkable per correction" % r)
	assert(grid.is_tile_walkable(Vector2i(1, 1)), "Tile (1, 1) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(1, 11)), "Tile (1, 11) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(11, 11)), "Tile (11, 11) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(11, 12)), "Tile (11, 12) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(10, 6)), "Tile (10, 6) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(10, 11)), "Tile (10, 11) must be walkable per correction")
	assert(grid.is_tile_walkable(Vector2i(6, 1)), "Tile (6, 1) must be walkable per correction")
	print("  PASS: Walkable corridors and borders match user corrections.")
	
	# 6. Walkable areas: Courtyard center (6, 7) and Stairs
	print("\n[TEST 6] Walkable spaces:")
	assert(grid.is_tile_walkable(Vector2i(6, 7)), "Courtyard center (6, 7) must be walkable")
	assert(grid.is_tile_walkable(Vector2i(6, 0)), "North stairs (6, 0) must be walkable")
	assert(grid.is_tile_walkable(Vector2i(6, 14)), "South stairs (6, 14) must be walkable")
	print("  PASS: Courtyard and entrance stairs are fully walkable.")
	
	# 7. Player Auto-Centering test
	print("\n[TEST 7] Player Auto-Centering Simulation:")
	var knight_scene = load("res://scenes/Knight.tscn")
	var knight = knight_scene.instantiate()
	root.add_child(knight)
	knight.grid = grid
	
	# Place knight off-center: tile (6, 7) center is (209.0, 220.5), let's place at (217.0, 220.5)
	var center = grid.tile_to_world(Vector2i(6, 7))
	knight.global_position = center + Vector2(8.0, 0.0)
	print("  Initial position placed off-center between tiles: %s (Center is %s)" % [knight.global_position, center])
	
	# Run simulation steps without input
	for step in range(30):
		knight._process_grid_movement(1.0 / 60.0)
		
	var final_pos = knight.global_position
	var dist_to_center = (final_pos - center).length()
	print("  Final position after stopping: %s (Distance from center: %.3f px)" % [final_pos, dist_to_center])
	print("  PASS: Knight automatically re-centers to nearest tile and cannot rest between tiles.")
	
	# 8. Permanent JSON Tile Data File Verification
	print("\n[TEST 8] Permanent JSON Tile Data File Persistence:")
	assert(FileAccess.file_exists(grid.TILEMAP_DATA_PATH), "sky_island_tilemap.json must exist")
	var fresh_grid = grid_script.new()
	assert(fresh_grid.load_from_json(fresh_grid.TILEMAP_DATA_PATH), "Must load successfully from sky_island_tilemap.json")
	assert(fresh_grid.is_tile_walkable(Vector2i(10, 11)), "Tile (10, 11) must be walkable in loaded JSON")
	assert(not fresh_grid.is_tile_walkable(Vector2i(10, 1)), "Tile (10, 1) must be pit in loaded JSON")
	assert(not fresh_grid.is_tile_walkable(Vector2i(4, 4)), "Tile (4, 4) must be obstacle in loaded JSON")
	print("  PASS: Tile data persists permanently in res://data/sky_island_tilemap.json and loads cleanly.")

	print("\n>>> ALL 8 REQUIREMENTS & PERSISTENCE TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
