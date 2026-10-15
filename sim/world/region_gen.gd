class_name RegionGen
extends RefCounted
## Lays out a region from data/balance/world.json "region" with the Rng "world" stream: the
## hub first, then the hamlets, then the wild sites, each on its own free grid cell; every
## site after the hub gets one road to a site already placed, so the roads form a tree and
## every site is reachable from the hub. Road length in days comes from the balance range.
## Static and seeded: the same region block and seed give the same sites and roads.

const STREAM := "world"
const HUB_ID := "site_hub"
const HAMLET_PREFIX := "site_hamlet_"
const WILD_PREFIX := "site_wild_"


## The sites in placement order (the hub is first). Stops early when the grid is full.
static func generate(region: Dictionary, rng: Rng) -> Array[WorldSite]:
	var free := _cells(_num(region, "grid_w"), _num(region, "grid_h"))
	var sites: Array[WorldSite] = []
	var min_days := _num(region, "road_min_days")
	var max_days := maxi(min_days, _num(region, "road_max_days"))
	for i: int in _count(region):
		if free.is_empty():
			break
		var cell: Vector2i = free.pop_at(rng.roll(STREAM, 0, free.size() - 1))
		var site := WorldSite.make(_id(region, i), _kind(region, i), cell)
		if not sites.is_empty():
			var other: WorldSite = sites[rng.roll(STREAM, 0, sites.size() - 1)]
			site.link(other, rng.roll(STREAM, min_days, max_days))
		sites.append(site)
	return sites


static func _count(region: Dictionary) -> int:
	return 1 + _num(region, "hamlets") + _num(region, "sites")


## Placement order: 0 is the hub, then the hamlets, then the wild sites.
static func _kind(region: Dictionary, index: int) -> WorldSite.Kind:
	if index == 0:
		return WorldSite.Kind.HUB
	if index <= _num(region, "hamlets"):
		return WorldSite.Kind.HAMLET
	return WorldSite.Kind.WILD


static func _id(region: Dictionary, index: int) -> String:
	match _kind(region, index):
		WorldSite.Kind.HUB:
			return HUB_ID
		WorldSite.Kind.HAMLET:
			return "%s%d" % [HAMLET_PREFIX, index]
	return "%s%d" % [WILD_PREFIX, index - _num(region, "hamlets")]


static func _cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in height:
		for x: int in width:
			cells.append(Vector2i(x, y))
	return cells


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
