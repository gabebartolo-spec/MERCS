class_name TileRegion
extends RefCounted
## The region at map scale (Phase 2, the walkable overworld): a grid of tiles, each one
## terrain (road, plain, forest, hill, water, town), with each site's entrance tile. Walking
## costs the terrain's units (data/balance/world.json "terrain_cost"); water and town walls
## cannot be walked. TileGen fills it from the seed; nothing here rolls or changes after.

enum Terrain { PLAIN, ROAD, FOREST, HILL, WATER, TOWN }

## The terrain names the balance's "terrain_cost" block uses, by Terrain value.
const TERRAIN_KEYS: Array[String] = ["plain", "road", "forest", "hill", "water", "town"]
## The eight steps a walker can take, in the fixed order every tie is broken by.
const STEPS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

var width := 0
var height := 0
## One Terrain value per tile, row by row (index y * width + x).
var tiles := PackedByteArray()
## Each site's entrance tile, by site id.
var entrances: Dictionary = {}

var _costs: Dictionary = {}


## An all-plain region; costs: data/balance/world.json "terrain_cost" (name -> units).
static func make(size: Vector2i, costs: Dictionary) -> TileRegion:
	var region := TileRegion.new()
	region.width = maxi(1, size.x)
	region.height = maxi(1, size.y)
	region.tiles.resize(region.width * region.height)
	region.tiles.fill(Terrain.PLAIN)
	region._costs = costs
	return region


func inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func terrain(tile: Vector2i) -> Terrain:
	if not inside(tile):
		return Terrain.WATER
	return tiles[tile.y * width + tile.x] as Terrain


func set_terrain(tile: Vector2i, kind: Terrain) -> void:
	if inside(tile):
		tiles[tile.y * width + tile.x] = kind


## Whether a walker (the band or a party) can stand on the tile.
func passable(tile: Vector2i) -> bool:
	var kind := terrain(tile)
	return inside(tile) and kind != Terrain.WATER and kind != Terrain.TOWN


## The units a step onto the tile costs (0 for a tile nobody can walk onto).
func cost(tile: Vector2i) -> int:
	if not passable(tile):
		return 0
	var value: Variant = _costs.get(TERRAIN_KEYS[terrain(tile)], 1)
	if value is int:
		var whole: int = value
		return maxi(1, whole)
	if value is float:
		var number: float = value
		return maxi(1, roundi(number))
	return 1


## The site whose entrance is the tile, or "".
func site_at(tile: Vector2i) -> String:
	for site_id: Variant in entrances:
		var at: Vector2i = entrances[site_id]
		if at == tile:
			return str(site_id)
	return ""


func entrance(site_id: String) -> Vector2i:
	var found: Variant = entrances.get(site_id, Vector2i(-1, -1))
	return found if found is Vector2i else Vector2i(-1, -1)


## Steps apart, counting a diagonal as one (the reach of sight and of contact).
static func gap(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The tile grid as text, one character per tile (two seeds compared at a glance).
func picture() -> String:
	var rows: PackedStringArray = []
	for y: int in height:
		var row := ""
		for x: int in width:
			row += str(tiles[y * width + x])
		rows.append(row)
	return "\n".join(rows)
