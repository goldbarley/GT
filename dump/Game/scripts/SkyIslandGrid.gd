extends Node2D
class_name SkyIslandGrid

enum TileType {
	WALKABLE = 0,
	WALL = 1,
	PIT = 2,
	OBSTACLE = 3,
	STAIRS = 4
}

const COLS: int = 13
const ROWS: int = 15
const TILE_WIDTH: float = 71.0 / 3.0
const TILE_HEIGHT: float = 71.0 / 3.0
const ORIGIN_X: float = 165.5 / 3.0
const ORIGIN_Y: float = 129.0 / 3.0

@export var debug_show_grid: bool = false:
	set(val):
		debug_show_grid = val
		queue_redraw()

const TILEMAP_DATA_PATH: String = "res://data/sky_island_tilemap.json"

var grid: Array = []

func _init() -> void:
	if not load_from_json(TILEMAP_DATA_PATH):
		_build_grid()
		save_to_json(TILEMAP_DATA_PATH)

func _ready() -> void:
	z_index = 10

func _build_grid() -> void:
	grid.clear()
	for r in range(ROWS):
		var row_arr: Array = []
		for c in range(COLS):
			row_arr.append(TileType.WALKABLE)
		grid.append(row_arr)

	# 1. Outer Perimeter Walls
	for c in range(COLS):
		grid[0][c] = TileType.WALL
		grid[14][c] = TileType.WALL
	for r in range(ROWS):
		grid[r][0] = TileType.WALL
		grid[r][12] = TileType.WALL

	# North and South wall overhangs
	for c in [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]:
		grid[1][c] = TileType.WALL
		grid[13][c] = TileType.WALL

	# Stairs (Walkable North & South entrances)
	grid[0][6] = TileType.STAIRS
	grid[1][6] = TileType.STAIRS
	grid[13][6] = TileType.STAIRS
	grid[14][6] = TileType.STAIRS

	# 2. Pits (>50% Sky Chasms)
	# NW Pit
	grid[2][2] = TileType.PIT
	grid[2][3] = TileType.PIT
	# NE Pit
	grid[2][10] = TileType.PIT
	grid[2][11] = TileType.PIT
	# Mid-West Pit
	grid[6][2] = TileType.PIT
	grid[6][3] = TileType.PIT
	grid[7][2] = TileType.PIT
	# Mid-East Pit
	grid[5][10] = TileType.PIT
	grid[5][11] = TileType.PIT
	grid[6][10] = TileType.PIT
	# Center Pit
	grid[8][6] = TileType.PIT
	# SE Pit
	grid[9][10] = TileType.PIT
	grid[10][10] = TileType.PIT
	grid[11][10] = TileType.PIT

	# 3. Pillars & Obstacles
	# NW Pillar (occupies (4,3) and (4,4) since sitting halfway)
	grid[3][4] = TileType.OBSTACLE
	grid[4][4] = TileType.OBSTACLE
	# NE Pillar (occupies (8,2) and (8,3))
	grid[2][8] = TileType.OBSTACLE
	grid[3][8] = TileType.OBSTACLE
	# SW Pillar (occupies (3,9) and (3,10))
	grid[9][3] = TileType.OBSTACLE
	grid[10][3] = TileType.OBSTACLE
	# East Ruin Pillar Cluster ((8,8), (9,7), (9,8))
	grid[7][9] = TileType.OBSTACLE
	grid[8][8] = TileType.OBSTACLE
	grid[8][9] = TileType.OBSTACLE
	# South stone rubble
	grid[10][8] = TileType.OBSTACLE
	# Corner Crates & Barrels
	grid[1][1] = TileType.OBSTACLE
	grid[1][11] = TileType.OBSTACLE
	grid[11][1] = TileType.OBSTACLE
	grid[12][1] = TileType.OBSTACLE
	grid[11][11] = TileType.OBSTACLE
	grid[12][11] = TileType.OBSTACLE

	# 4. User Specific Corrections
	# from 0,1 to 0,10 (straight vertical) -> green (walkable)
	for r in range(1, 11):
		grid[r][0] = TileType.WALKABLE

	# from 12,0 to 12,12 (straight vertical) -> green (walkable)
	for r in range(0, 13):
		grid[r][12] = TileType.WALKABLE

	# 1,1 -> green
	grid[1][1] = TileType.WALKABLE

	# 1,0 to 5,0 and 7,0 to 12,0 -> green
	for c in range(1, 6):
		grid[0][c] = TileType.WALKABLE
	for c in range(7, 13):
		grid[0][c] = TileType.WALKABLE

	# 10,1 and 11,1 -> blue (pit)
	grid[1][10] = TileType.PIT
	grid[1][11] = TileType.PIT

	# 8,2 -> green
	grid[2][8] = TileType.WALKABLE

	# 6,1 -> green
	grid[1][6] = TileType.WALKABLE

	# 2,1 -> blue (pit)
	grid[1][2] = TileType.PIT

	# 4,3 -> green
	grid[3][4] = TileType.WALKABLE

	# 10,6 -> green
	grid[6][10] = TileType.WALKABLE

	# 8,8 and 9,8 -> green
	grid[8][8] = TileType.WALKABLE
	grid[8][9] = TileType.WALKABLE

	# 11,11 and 11,12 -> green
	grid[11][11] = TileType.WALKABLE
	grid[12][11] = TileType.WALKABLE

	# 3,10 -> green
	grid[10][3] = TileType.WALKABLE

	# 1,11 -> green
	grid[11][1] = TileType.WALKABLE

	# 10,11 -> green
	grid[11][10] = TileType.WALKABLE

func is_valid_tile(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < COLS and coord.y >= 0 and coord.y < ROWS

func get_tile_type(coord: Vector2i) -> int:
	if not is_valid_tile(coord):
		return TileType.WALL
	return grid[coord.y][coord.x]

func is_tile_walkable(coord: Vector2i) -> bool:
	if not is_valid_tile(coord):
		return false
	var t: int = grid[coord.y][coord.x]
	return t == TileType.WALKABLE or t == TileType.STAIRS

func tile_to_world(coord: Vector2i) -> Vector2:
	return Vector2(
		ORIGIN_X + (float(coord.x) + 0.5) * TILE_WIDTH,
		ORIGIN_Y + (float(coord.y) + 0.5) * TILE_HEIGHT
	)

## The tile at a place in the world, without being clamped to the edge.
##
## This is the one to use when asking whether a place can be walked on: the
## clamped one turns the world outside the island into the tile at its edge,
## which is usually walkable, so a character would walk straight off.
func tile_at(world_pos: Vector2) -> Vector2i:
	var c: int = int(floor((world_pos.x - ORIGIN_X) / TILE_WIDTH))
	var r: int = int(floor((world_pos.y - ORIGIN_Y) / TILE_HEIGHT))
	return Vector2i(c, r)

func world_to_tile(world_pos: Vector2) -> Vector2i:
	var c: int = clampi(roundi((world_pos.x - ORIGIN_X - TILE_WIDTH * 0.5) / TILE_WIDTH), 0, COLS - 1)
	var r: int = clampi(roundi((world_pos.y - ORIGIN_Y - TILE_HEIGHT * 0.5) / TILE_HEIGHT), 0, ROWS - 1)
	return Vector2i(c, r)

func get_tile_name(coord: Vector2i) -> String:
	var t: int = get_tile_type(coord)
	match t:
		TileType.WALKABLE:
			return "Walkable (Courtyard)"
		TileType.WALL:
			return "Wall / Battlement"
		TileType.PIT:
			return "Sky Chasm (Pit)"
		TileType.OBSTACLE:
			return "Pillar / Crate Obstacle"
		TileType.STAIRS:
			return "Stone Stairs"
		_:
			return "Unknown"

func _draw() -> void:
	if not debug_show_grid:
		return

	var font = ThemeDB.fallback_font
	for r in range(ROWS):
		for c in range(COLS):
			var x0: float = ORIGIN_X + float(c) * TILE_WIDTH
			var y0: float = ORIGIN_Y + float(r) * TILE_HEIGHT
			var rect := Rect2(x0, y0, TILE_WIDTH, TILE_HEIGHT)
			var t: int = grid[r][c]
			var col := Color(0.2, 0.8, 0.2, 0.25)
			match t:
				TileType.WALL:
					col = Color(0.5, 0.5, 0.6, 0.45)
				TileType.PIT:
					col = Color(0.1, 0.6, 1.0, 0.5)
				TileType.OBSTACLE:
					col = Color(1.0, 0.8, 0.1, 0.5)
				TileType.STAIRS:
					col = Color(0.8, 0.2, 0.9, 0.45)
			draw_rect(rect, col, true)
			draw_rect(rect, Color(1, 1, 1, 0.3), false, 1.0)
			draw_string(font, Vector2(x0 + 6, y0 + 18), "%d,%d" % [c, r], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func load_from_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("Failed to parse tilemap JSON %s: %s" % [path, json.get_error_message()])
		return false
	var data: Dictionary = json.data
	if not data.has("matrix"):
		return false
	var mat: Array = data["matrix"]
	if mat.size() != ROWS:
		return false
	grid.clear()
	for r in range(ROWS):
		var row_arr: Array = []
		for c in range(COLS):
			row_arr.append(int(mat[r][c]))
		grid.append(row_arr)
	return true

func save_to_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var categorized := {
		"walkable": [],
		"walls": [],
		"pits": [],
		"obstacles": [],
		"stairs": []
	}
	for r in range(ROWS):
		for c in range(COLS):
			var t: int = grid[r][c]
			match t:
				TileType.WALKABLE:
					categorized["walkable"].append([c, r])
				TileType.WALL:
					categorized["walls"].append([c, r])
				TileType.PIT:
					categorized["pits"].append([c, r])
				TileType.OBSTACLE:
					categorized["obstacles"].append([c, r])
				TileType.STAIRS:
					categorized["stairs"].append([c, r])
	
	var lines: Array[String] = ["{"]
	lines.append('  "version": "1.0",')
	lines.append('  "map_name": "Floating Sky Island",')
	lines.append('  "texture_path": "res://Floating_Sky_Island.png",')
	lines.append('  "grid_dimensions": {')
	lines.append('    "columns": %d,' % COLS)
	lines.append('    "rows": %d,' % ROWS)
	lines.append('    "tile_width": %.6f,' % TILE_WIDTH)
	lines.append('    "tile_height": %.6f,' % TILE_HEIGHT)
	lines.append('    "origin_x": %.6f,' % ORIGIN_X)
	lines.append('    "origin_y": %.6f' % ORIGIN_Y)
	lines.append('  },')
	lines.append('  "tile_types": {')
	lines.append('    "0": "WALKABLE",')
	lines.append('    "1": "WALL",')
	lines.append('    "2": "PIT",')
	lines.append('    "3": "OBSTACLE",')
	lines.append('    "4": "STAIRS"')
	lines.append('  },')
	lines.append('  "walkable_types": [%d, %d],' % [TileType.WALKABLE, TileType.STAIRS])
	
	# Matrix formatted with each row on its own line
	lines.append('  "matrix": [')
	for r in range(ROWS):
		var comma: String = "," if r < ROWS - 1 else ""
		lines.append("    " + JSON.stringify(grid[r]) + comma)
	lines.append('  ],')
	
	# Categorized tiles formatted cleanly
	lines.append('  "categorized_tiles": {')
	var cat_keys: Array = ["walkable", "walls", "pits", "obstacles", "stairs"]
	for i in range(cat_keys.size()):
		var key: String = cat_keys[i]
		var k_comma: String = "," if i < cat_keys.size() - 1 else ""
		var coords: Array = categorized[key]
		lines.append('    "%s": [' % key)
		var chunk_size: int = 10
		for j in range(0, coords.size(), chunk_size):
			var sub_chunk: Array = []
			for k in range(j, mini(j + chunk_size, coords.size())):
				sub_chunk.append(JSON.stringify(coords[k]))
			var c_comma: String = "," if (j + chunk_size) < coords.size() else ""
			lines.append("      " + ", ".join(sub_chunk) + c_comma)
		lines.append("    ]%s" % k_comma)
	lines.append("  }")
	lines.append("}")
	
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return true
