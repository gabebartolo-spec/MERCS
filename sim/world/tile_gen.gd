class_name TileGen
extends RefCounted
## Lays RegionGen's sites and roads onto tiles (Phase 2, the walkable overworld), on the Rng
## "world" stream after RegionGen: plain everywhere, then blobs of forest, hills and water
## (data/balance/world.json "tiles"), then each site's hand-made stamp (data/locations.json,
## handed in as the world data's "locations": town walls and the entrance tile), then each
## road as the shortest walk between two entrances around the town walls, laid as road tiles
## (a road crosses water as a ford). Every site is therefore reachable from the hub on roads.
## Static and seeded: the same data, sites and seed give the same tiles.

const STREAM := "world"
const WALL := "#"
const GATE := "E"
## The site kinds as the stamps name them, by WorldSite.Kind value.
const KIND_KEYS: Array[String] = ["hub", "hamlet", "wild"]
## A road is walked on the four straight steps only, so it reads as one line.
const ROAD_STEPS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]


## world_data: data/balance/world.json, with "locations" (data/locations.json's array).
static func generate(world_data: Dictionary, sites: Array[WorldSite], rng: Rng) -> TileRegion:
	var tiles := _dict(world_data, "tiles")
	var cell := maxi(1, _num(tiles, "cell_tiles"))
	var region_block := _dict(world_data, "region")
	var size := Vector2i(_num(region_block, "grid_w"), _num(region_block, "grid_h")) * cell
	var region := TileRegion.make(size, _dict(world_data, "terrain_cost"))
	_blobs(region, tiles, "forests", TileRegion.Terrain.FOREST, rng)
	_blobs(region, tiles, "hills", TileRegion.Terrain.HILL, rng)
	_blobs(region, tiles, "lakes", TileRegion.Terrain.WATER, rng)
	var offset := Vector2i.ONE * _num(tiles, "site_offset_tiles")
	var stamps := _stamps(world_data)
	for site: WorldSite in sites:
		var gate := Vector2i(site.x, site.y) * cell + offset
		_stamp(region, gate, _list(stamps, KIND_KEYS[site.kind]))
		region.entrances[site.id] = gate
	for site: WorldSite in sites:
		for other_id: String in site.neighbour_ids():
			if other_id > site.id and region.entrances.has(other_id):
				_road(region, region.entrance(site.id), region.entrance(other_id))
	return region


## Round patches of one terrain: a count, and a radius rolled in the balance's range.
static func _blobs(
	region: TileRegion, tiles: Dictionary, key: String, kind: TileRegion.Terrain, rng: Rng
) -> void:
	var low := _num(tiles, "blob_min_radius")
	var high := maxi(low, _num(tiles, "blob_max_radius"))
	for _blob: int in _num(tiles, key):
		var centre := Vector2i(
			rng.roll(STREAM, 0, region.width - 1), rng.roll(STREAM, 0, region.height - 1)
		)
		var radius := rng.roll(STREAM, low, high)
		for y: int in range(centre.y - radius, centre.y + radius + 1):
			for x: int in range(centre.x - radius, centre.x + radius + 1):
				var dx := x - centre.x
				var dy := y - centre.y
				if dx * dx + dy * dy <= radius * radius:
					region.set_terrain(Vector2i(x, y), kind)


## The stamp rows by site kind: {"hub": [rows], ...} from the locations' entries.
static func _stamps(world_data: Dictionary) -> Dictionary:
	var by_kind := {}
	for entry: Variant in _list(world_data, "locations"):
		var record: Dictionary = entry if entry is Dictionary else {}
		var kind := str(record.get("site_kind", ""))
		if not kind.is_empty() and not by_kind.has(kind):
			by_kind[kind] = _list(record, "rows")
	return by_kind


## A stamp's rows laid with its gate on the site's tile: "#" a town wall, "E" the gate, any
## other character leaves the land as it was. No stamp: the gate tile alone.
static func _stamp(region: TileRegion, gate: Vector2i, rows: Array) -> void:
	var gate_at := Vector2i.ZERO
	for y: int in rows.size():
		var found := str(rows[y]).find(GATE)
		if found >= 0:
			gate_at = Vector2i(found, y)
	for y: int in rows.size():
		var row := str(rows[y])
		for x: int in row.length():
			if row[x] == WALL:
				region.set_terrain(gate - gate_at + Vector2i(x, y), TileRegion.Terrain.TOWN)
	region.set_terrain(gate, TileRegion.Terrain.ROAD)


## The shortest straight-step walk from one entrance to another around town walls, laid as
## road. Steps along a road already laid cost nothing, so roads join and share their way
## (a 0-1 breadth-first search, steps tried in ROAD_STEPS order: the same map, the same road).
static func _road(region: TileRegion, from: Vector2i, to: Vector2i) -> void:
	var came := {from: from}
	var spent := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_front()
		for step: Vector2i in ROAD_STEPS:
			var next := here + step
			var walled := region.terrain(next) == TileRegion.Terrain.TOWN and next != to
			if not region.inside(next) or walled:
				continue
			var free := region.terrain(next) == TileRegion.Terrain.ROAD
			var total: int = spent[here] + (0 if free else 1)
			if spent.has(next) and spent[next] <= total:
				continue
			spent[next] = total
			came[next] = here
			if free:
				queue.push_front(next)
			else:
				queue.push_back(next)
	_lay(region, came, from, to)


static func _lay(region: TileRegion, came: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if not came.has(to):
		return
	var at := to
	while at != from:
		region.set_terrain(at, TileRegion.Terrain.ROAD)
		at = came[at]


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0


static func _dict(block: Dictionary, key: String) -> Dictionary:
	var value: Variant = block.get(key, {})
	return value if value is Dictionary else {}


static func _list(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	if not value is Array:
		return []
	var items: Array = value
	return items.duplicate()
