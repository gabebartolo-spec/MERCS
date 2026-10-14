class_name WorldSite
extends RefCounted
## One place on the region map: the hub, a hamlet or a wild site, where it sits on the
## integer grid, and the roads out of it (neighbour id -> days on the road). A plain record
## that WorldSim and RegionGen fill; to_dict() and from_dict() carry it through a save.

## Kinds travel in saves as plain numbers (the enum's value).
enum Kind { HUB, HAMLET, WILD }

var id := ""
var kind := Kind.HUB
var x := 0
var y := 0
## Days on the road to each neighbouring site, by the neighbour's id.
var roads: Dictionary = {}


static func make(site_id: String, site_kind: Kind, at: Vector2i) -> WorldSite:
	var site := WorldSite.new()
	site.id = site_id
	site.kind = site_kind
	site.x = at.x
	site.y = at.y
	return site


## A road of `days` between this site and `other`, walkable both ways.
func link(other: WorldSite, days: int) -> void:
	roads[other.id] = days
	other.roads[id] = days


func is_neighbour(site_id: String) -> bool:
	return roads.has(site_id)


## The road length to a neighbour, or 0 when there is no road.
func days_to(site_id: String) -> int:
	return _num(roads, site_id)


func neighbour_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: Variant in roads:
		ids.append(str(key))
	ids.sort()
	return ids


func to_dict() -> Dictionary:
	var out_roads := {}
	for key: Variant in roads:
		out_roads[str(key)] = _num(roads, str(key))
	return {"id": id, "kind": int(kind), "x": x, "y": y, "roads": out_roads}


## Rebuilds the record; JSON turns every number into a float, so each is read back whole.
static func from_dict(saved: Dictionary) -> WorldSite:
	var site := WorldSite.new()
	site.id = str(saved.get("id", ""))
	site.kind = _num(saved, "kind") as Kind
	site.x = _num(saved, "x")
	site.y = _num(saved, "y")
	var saved_roads: Variant = saved.get("roads", {})
	if saved_roads is Dictionary:
		var by_id: Dictionary = saved_roads
		for key: Variant in by_id:
			site.roads[str(key)] = _num(by_id, str(key))
	return site


static func _num(block: Dictionary, key: String) -> int:
	var value: Variant = block.get(key, 0)
	if value is int:
		return value
	if value is float:
		var number: float = value
		return roundi(number)
	return 0
