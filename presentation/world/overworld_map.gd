class_name OverworldMap
extends Control
## The region as a flat map (Phase 2 M1b, docs/08_ROADMAP.md Phase 2 M1): one marker per
## site on the balance's grid, the hub a large disc, hamlets small discs, wild sites hollow
## diamonds, roads as straight lines, a ring around the site the company is at, and a header
## line with the day and the supplies. Grey-box: the theme's colours only (there is no UiKit
## yet), no art. Reads WorldSim through show_world(); decides nothing.

const MARGIN_PX := 12
const PAD_PX := 40
const HEADER_PX := 32
const HUB_RADIUS := 11.0
const HAMLET_RADIUS := 6.0
const WILD_RADIUS := 8.0
const COMPANY_RADIUS := 18.0
const ROAD_WIDTH := 2.0
const RING_WIDTH := 3.0
const RING_POINTS := 32
const MARKER_PREFIX := &"Site_"
const COMPANY_NAME := &"Company"
## The map takes the width the loop panel leaves free (LoopPanel.WIDTH_SHARE on the right).
const WIDTH_SHARE := 1.0 - LoopPanel.WIDTH_SHARE

var _grid := Vector2i.ONE
var _sites: Array[WorldSite] = []
var _at := ""
var _header := Label.new()
var _back := Panel.new()
var _markers := Control.new()
var _company := Control.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	# Below the slice's key help, which sits on the window's top edge.
	_header.position = Vector2(MARGIN_PX, HEADER_PX)
	add_child(_header)
	_markers.name = &"Markers"
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)
	_company.name = COMPANY_NAME
	_company.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_company)
	_fit()


## The grid the sites sit on (data/balance/world.json "region": grid_w, grid_h).
func setup(grid: Vector2i) -> void:
	_grid = Vector2i(maxi(1, grid.x), maxi(1, grid.y))


## Places a marker per site and the company's ring at the site it is at, and redraws.
func show_world(world: WorldSim) -> void:
	_sites = world.sites
	_at = world.at
	_header.text = Text.t("world.header", {"day": world.day, "supplies": world.supplies})
	for old: Node in _markers.get_children():
		_markers.remove_child(old)
		old.queue_free()
	for site: WorldSite in _sites:
		var marker := Control.new()
		marker.name = String(MARKER_PREFIX) + site.id
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var radius := _radius(site)
		marker.position = _point(site) - Vector2.ONE * radius
		marker.size = Vector2.ONE * radius * 2.0
		var label := Label.new()
		label.text = site_name(site)
		label.position = Vector2(radius * 2.0 + MARGIN_PX / 2.0, 0.0)
		marker.add_child(label)
		_markers.add_child(marker)
	var here := world.site(_at)
	_company.visible = here != null
	if here != null:
		_company.position = _point(here) - Vector2.ONE * COMPANY_RADIUS
		_company.size = Vector2.ONE * COMPANY_RADIUS * 2.0
	queue_redraw()


## The marker for a site id, or null (tests read its rect).
func marker_for(site_id: String) -> Control:
	return _markers.get_node_or_null(NodePath(String(MARKER_PREFIX) + site_id)) as Control


## The company's ring, centred on the marker of the site it is at.
func company_marker() -> Control:
	return _company


## The site's name for a player: the hub, or its kind and number (the id's last part).
static func site_name(site: WorldSite) -> String:
	var number := site.id.rsplit("_", true, 1)[-1]
	match site.kind:
		WorldSite.Kind.HAMLET:
			return Text.t("world.site.hamlet", {"n": number})
		WorldSite.Kind.WILD:
			return Text.t("world.site.wild", {"n": number})
	return Text.t("world.site.hub")


func _draw() -> void:
	var colour := get_theme_color(&"font_color", &"Label")
	var by_id := {}
	for site: WorldSite in _sites:
		by_id[site.id] = site
	for site: WorldSite in _sites:
		for other_id: String in site.neighbour_ids():
			# Each road is walkable both ways; draw it once, from the lower id.
			if other_id > site.id and by_id.has(other_id):
				var other: WorldSite = by_id[other_id]
				draw_line(_point(site), _point(other), colour, ROAD_WIDTH)
	for site: WorldSite in _sites:
		_draw_marker(site, colour)
	if _company.visible:
		var centre := _company.position + _company.size / 2.0
		draw_arc(centre, COMPANY_RADIUS, 0.0, TAU, RING_POINTS, colour, RING_WIDTH)


func _draw_marker(site: WorldSite, colour: Color) -> void:
	var centre := _point(site)
	var radius := _radius(site)
	if site.kind == WorldSite.Kind.WILD:
		var diamond := PackedVector2Array(
			[
				centre + Vector2(0.0, -radius),
				centre + Vector2(radius, 0.0),
				centre + Vector2(0.0, radius),
				centre + Vector2(-radius, 0.0),
				centre + Vector2(0.0, -radius),
			]
		)
		draw_polyline(diamond, colour, ROAD_WIDTH)
	else:
		draw_circle(centre, radius, colour)


func _radius(site: WorldSite) -> float:
	match site.kind:
		WorldSite.Kind.HUB:
			return HUB_RADIUS
		WorldSite.Kind.WILD:
			return WILD_RADIUS
	return HAMLET_RADIUS


## Where a grid cell's centre lands inside the map, below the header.
func _point(site: WorldSite) -> Vector2:
	var area := Rect2(
		Vector2(PAD_PX, 2.0 * HEADER_PX + PAD_PX),
		Vector2(size.x - 2.0 * PAD_PX, size.y - 2.0 * HEADER_PX - 2.0 * PAD_PX)
	)
	return area.position + Vector2((site.x + 0.5) / _grid.x, (site.y + 0.5) / _grid.y) * area.size


func _fit() -> void:
	var view := get_viewport_rect().size
	position = Vector2.ONE * MARGIN_PX
	size = Vector2(view.x * WIDTH_SHARE - 2.0 * MARGIN_PX, view.y - 2.0 * MARGIN_PX)
