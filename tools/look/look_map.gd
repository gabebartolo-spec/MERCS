extends RefCounted
## The look target's overworld strip (Art, 2026-10-15): the tile layout and how the map kit's tiles
## are laid on it. Used by tools/look/look_target.gd for the map frame.
## Water shorelines: every water-tile edge that meets land gets a bank piece (kit bank_<n>, ragged
## mud and rushes), turned to face the land, so no shore is a ruler-straight line.

const TILE_M := 4.0
const ROWS: Array[String] = [
	"FFFFFHHHHFFFFFHHHH",
	"FFFFHHHPPPFFFFHHHH",
	"FFFFFHPPPPPFFFFHHH",
	"FFFFPPPPPPPPFFFFHH",
	"FFFPPPPPTRRRRRRRRR",
	"FFPPPPPPNPPPPPFFFF",
	"RRRRRRRRNPPPPPFFFF",
	"PPPPPPPPNPPPHHFFFH",
	"PPPPPPPPNPPHHHFFHH",
	"SSSSSPPPNPPPPPPFHH",
	"WWWWWSSSNSSSSSSSPP",
	"WWWWWWWWWWWWWWWWSS",
	"WWWWWWWWWWWWWWWWWW",
]
const TILE_NAMES := {
	"P": "tile_plain",
	"R": "tile_road",
	"N": "tile_road_ns",
	"F": "tile_forest",
	"H": "tile_hill",
	"W": "tile_water",
	"S": "tile_shore",
	"T": "tile_plain",
}
const TURNABLE := "PFHW"
const WATER := "W"
const SHORE := "S"
## Shore tile variants (kit tile_shore_<n>), picked by a fixed hash like the banks.
const SHORE_VARIANTS := 3
## Road variants (kit tile_road, _1, _2 and the same for tile_road_ns): the verges wander
## differently, so a long road does not repeat tile by tile.
const ROADS := "RN"
const ROAD_VARIANTS := 3
## Grass is bare tiles plus hand-placed dressing (desloppify round 2, 2026-10-15): lush patches
## spill out of the woods and along the damp shore, dry patches lie on sunny hill feet and trodden
## verges, tuft clumps gather at edges (shore, woods, hill feet, roads) and stones in a few clusters
## near paths, water and hill feet. Open meadow is left quiet on purpose. A half road joins the
## west road to the north road (tile roads stop at their tile's edge, short of the junction).
## Each: kit piece, tile column, tile row, offset x and z (metres), scale x and z, turn (degrees).
const DRESSING: Array = [
	["patch_lush_0", 3, 4, -0.5, -0.5, 1.0, 1.0, 20.0],
	["patch_lush_2", 3, 8, 0.0, 2.2, 1.0, 0.6, 0.0],
	["patch_lush_1", 13, 5, 0.5, 1.0, 1.0, 1.0, -15.0],
	["patch_lush_2", 11, 9, 0.0, 1.5, 1.0, 0.8, 180.0],
	["patch_dry_0", 8, 5, 0.0, 0.3, 1.0, 1.0, 30.0],
	["patch_dry_2", 8, 7, 0.0, 0.5, 1.0, 1.0, 90.0],
	["patch_dry_1", 4, 6, 0.5, 0.2, 1.0, 1.0, 0.0],
	["patch_dry_1", 11, 7, 1.0, 0.5, 1.0, 1.0, 160.0],
	["patch_dry_2", 6, 2, -1.0, 0.5, 1.0, 1.0, 10.0],
	["tile_road_1", 8, 6, -1.0, 0.0, 0.5, 1.0, 0.0],
	["tufts_0", 3, 8, 1.2, 1.6, 1.0, 1.0, 0.0],
	["tufts_1", 6, 9, 0.5, -0.8, 1.0, 1.0, 70.0],
	["tufts_2", 12, 9, 0.5, 1.0, 1.0, 1.0, 140.0],
	["tufts_0", 14, 9, -0.5, 0.6, 1.0, 1.0, 200.0],
	["tufts_1", 10, 8, 1.4, 0.0, 1.0, 1.0, 30.0],
	["tufts_2", 3, 4, -1.3, 0.5, 1.0, 1.0, 250.0],
	["tufts_0", 10, 4, 0.5, 1.2, 1.0, 1.0, 100.0],
	["tufts_1", 7, 7, 2.9, 0.5, 1.0, 1.0, 300.0],
	["tufts_2", 6, 2, -1.2, 1.0, 1.0, 1.0, 10.0],
	["tufts_0", 11, 3, 1.0, 0.5, 1.0, 1.0, 160.0],
	["stones_0", 7, 6, 2.0, 1.3, 1.0, 1.0, 0.0],
	["stones_1", 10, 8, 1.2, -0.6, 1.0, 1.0, 80.0],
	["stones_2", 5, 9, -0.3, -0.3, 1.0, 1.0, 200.0],
	["stones_0", 13, 9, 0.3, 1.0, 1.0, 1.0, 130.0],
	["stones_1", 6, 2, -1.5, 0.2, 1.0, 1.0, 290.0],
]
## Open water with only water around it (all eight neighbours, or the map edge) is deep (kit
## tile_water_deep); each side facing shallower water gets a ragged fringe (kit deep_fringe_<n>).
const DEEP_TILE := "tile_water_deep"
const DEEP_FRINGES := 3
## Each tile copy is scaled up this much so neighbours overlap a few millimetres: exact edges left
## hairline cracks that showed the sky as a long pale line across the water.
const TILE_OVERLAP := 1.002
## Bank variants in the kit; one is picked per edge by a fixed hash so a long shore does not repeat.
const BANK_VARIANTS := 3
const FULL_BANK := "bank"
## North, west, south, east: a bank turned by side * 90 degrees faces that neighbour.
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]


static func centre(i: int, j: int) -> Vector3:
	var cols := ROWS[0].length()
	return Vector3((i - cols / 2.0 + 0.5) * TILE_M, 0.0, (j - ROWS.size() / 2.0 + 0.5) * TILE_M)


## Lays every tile, and the banks of every water and shore tile, under holder.
static func lay(kit: Node3D, holder: Node3D) -> void:
	for j: int in ROWS.size():
		for i: int in ROWS[0].length():
			var code := ROWS[j][i]
			var tile: String = TILE_NAMES[code]
			if code == SHORE:
				tile += "_%d" % ((i * 5 + j * 11) % SHORE_VARIANTS)
			if code in ROADS and (i * 7 + j * 3) % ROAD_VARIANTS > 0:
				tile += "_%d" % ((i * 7 + j * 3) % ROAD_VARIANTS)
			var deep := _deep(i, j)
			if deep:
				tile = DEEP_TILE
			var copy := _piece(kit, tile, i, j, holder)
			copy.scale = Vector3.ONE * TILE_OVERLAP
			if code in TURNABLE:
				copy.rotation.y = PI / 2.0 * ((i * 7 + j * 13) % 4)
			if code == WATER or code == SHORE:
				_banks(kit, i, j, holder)
			if deep:
				_fringes(kit, i, j, holder)
	_dress(kit, holder)


## Places the hand-placed grass patches, tuft clumps and stone clusters (DRESSING).
static func _dress(kit: Node3D, holder: Node3D) -> void:
	for spot: Array in DRESSING:
		var key: String = spot[0]
		var i: int = spot[1]
		var j: int = spot[2]
		var dx: float = spot[3]
		var dz: float = spot[4]
		var sx: float = spot[5]
		var sz: float = spot[6]
		var turn: float = spot[7]
		var piece := _piece(kit, key, i, j, holder)
		piece.position += Vector3(dx, 0.0, dz)
		piece.scale = Vector3(sx, 1.0, sz)
		piece.rotation.y = deg_to_rad(turn)


## Whether (i, j) is water with water on all eight sides (the map's edge counts as water).
static func _deep(i: int, j: int) -> bool:
	for dj: int in range(-1, 2):
		for di: int in range(-1, 2):
			var x := i + di
			var y := j + dj
			if x < 0 or y < 0 or x >= ROWS[0].length() or y >= ROWS.size():
				continue
			if ROWS[y][x] != WATER:
				return false
	return true


## A ragged deep fringe on each side of deep tile (i, j) that meets shallower water.
static func _fringes(kit: Node3D, i: int, j: int, holder: Node3D) -> void:
	for side: int in SIDES.size():
		var n := Vector2i(i, j) + SIDES[side]
		if n.x < 0 or n.y < 0 or n.x >= ROWS[0].length() or n.y >= ROWS.size():
			continue
		if _deep(n.x, n.y):
			continue
		var key := "deep_fringe_%d" % ((i * 5 + j * 11 + side * 3) % DEEP_FRINGES)
		var fringe := _piece(kit, key, i, j, holder)
		fringe.rotation.y = PI / 2.0 * side


## A bank on each edge of tile (i, j) where its water meets land; the map's outer edge is left open.
static func _banks(kit: Node3D, i: int, j: int, holder: Node3D) -> void:
	for side: int in SIDES.size():
		var n := Vector2i(i, j) + SIDES[side]
		if n.x < 0 or n.y < 0 or n.x >= ROWS[0].length() or n.y >= ROWS.size():
			continue
		var key := _bank_key(ROWS[j][i], ROWS[n.y][n.x], side)
		if key == FULL_BANK:
			key = "bank_%d" % ((i * 5 + j * 11 + side * 3) % BANK_VARIANTS)
		if not key.is_empty():
			var bank := _piece(kit, key, i, j, holder)
			bank.rotation.y = PI / 2.0 * side


## Which bank the edge on side (0 north, 1 west, 2 south, 3 east) of a water or shore tile needs.
## A shore tile is water on its south half and grass on its north half, with its own bank between:
## a water tile beside one banks only its north half, a shore tile beside land only its south half
## (bank_half_pos or _neg: whichever half of the turned piece lies there). "" means none.
static func _bank_key(code: String, other: String, side: int) -> String:
	if other == WATER:
		return ""
	if code == WATER and other == SHORE:
		if side == 0:
			return ""
		if side % 2 == 1:
			return "bank_half_pos" if side == 1 else "bank_half_neg"
	if code == SHORE:
		if side == 0 or other == SHORE:
			return ""
		if side % 2 == 1:
			return "bank_half_neg" if side == 1 else "bank_half_pos"
	return FULL_BANK


static func _piece(kit: Node3D, key: String, i: int, j: int, holder: Node3D) -> Node3D:
	var copy := (kit.find_child(key, true, false) as Node3D).duplicate() as Node3D
	copy.position = centre(i, j)
	holder.add_child(copy)
	return copy
