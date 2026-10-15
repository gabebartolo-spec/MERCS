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
## Grass variants (kit tile_plain, tile_plain_1, _2): different tuft clumps, so the grid does
## not repeat.
const PLAIN := "P"
const PLAIN_VARIANTS := 3
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
			if code == PLAIN and (i * 3 + j * 7) % PLAIN_VARIANTS > 0:
				tile += "_%d" % ((i * 3 + j * 7) % PLAIN_VARIANTS)
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
