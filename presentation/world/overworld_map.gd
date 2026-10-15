class_name OverworldMap
extends Control
## The walkable overworld on screen (Phase 2): the region's tiles drawn as flat placeholder
## colours (data/balance/overworld.json), a marker and a name on each site's entrance, a token
## per party on the map (coloured by type, ringed while it chases the band), the band's token,
## and a header line with the day and the supplies. The view follows the band: its tile sits
## at the centre and the map scrolls under it. Reads WorldSim through show_world(); decides
## nothing. Placeholder look (D-067: final UI is out).

const DATA := "res://data/balance/overworld.json"
const MARGIN_PX := 12
const HEADER_PX := 32
const RING_POINTS := 32
const MARKER_PREFIX := &"Site_"
const PARTY_PREFIX := &"Party_"
const COMPANY_NAME := &"Company"
## The map takes the width the loop panel leaves free (LoopPanel.WIDTH_SHARE on the right).
const WIDTH_SHARE := 1.0 - LoopPanel.WIDTH_SHARE

var _data: StageData = null
var _world: WorldSim = null
var _tile_px := 1.0
var _origin := Vector2.ZERO
var _terrain_colours: Array[Color] = []
var _header := Label.new()
var _header_back := PanelContainer.new()
var _markers := Control.new()
var _parties := Control.new()
var _company := Control.new()


func _ready() -> void:
	_data = StageData.load_file(DATA)
	_tile_px = maxf(1.0, _data.num("map", "tile_px"))
	for key: String in TileRegion.TERRAIN_KEYS:
		_terrain_colours.append(_data.rgb("colours", key + "_rgb"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for layer: Control in [_markers, _parties, _company]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	_markers.name = &"Markers"
	_parties.name = &"Parties"
	_company.name = COMPANY_NAME
	# Below the slice's key help, which sits on the window's top edge.
	_header_back.position = Vector2(MARGIN_PX, HEADER_PX)
	_header_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_back.add_child(_header)
	add_child(_header_back)
	_fit()


## Centres the view on the band, places every marker and token, and redraws.
func show_world(world: WorldSim) -> void:
	_world = world
	_header.text = Text.t("world.header", {"day": world.day, "supplies": world.supplies})
	_origin = size / 2.0 - (Vector2(world.band) + Vector2.ONE / 2.0) * _tile_px
	for site: WorldSite in world.sites:
		var marker := _token(_markers, String(MARKER_PREFIX) + site.id)
		_place(marker, world.region.entrance(site.id), _data.num("map", "site_radius_px"))
		if marker.get_child_count() == 0:
			var label := Label.new()
			label.text = site_name(site)
			label.position = Vector2(marker.size.x + MARGIN_PX / 2.0, -marker.size.y)
			marker.add_child(label)
	for party: WorldParty in world.parties:
		var token := _token(_parties, String(PARTY_PREFIX) + party.id)
		_place(token, party.tile, _data.num("map", "party_radius_px"))
		token.visible = party.active(world.day)
	_place(_company, world.band, _data.num("map", "band_radius_px"))
	queue_redraw()


## The marker for a site id, or null (tests read its rect).
func marker_for(site_id: String) -> Control:
	return _markers.get_node_or_null(NodePath(String(MARKER_PREFIX) + site_id)) as Control


## A party's token, or null; hidden while the party is off the map.
func party_marker(party_id: String) -> Control:
	return _parties.get_node_or_null(NodePath(String(PARTY_PREFIX) + party_id)) as Control


## The band's token, centred on the band's tile (at the view's centre).
func company_marker() -> Control:
	return _company


## Where a tile's centre lands inside the map, at the view as last shown.
func tile_centre(tile: Vector2i) -> Vector2:
	return _origin + (Vector2(tile) + Vector2.ONE / 2.0) * _tile_px


## The site's name for a player: the hub, or its kind and number (the id's last part).
static func site_name(site: WorldSite) -> String:
	var number := site.id.rsplit("_", true, 1)[-1]
	match site.kind:
		WorldSite.Kind.HAMLET:
			return Text.t("world.site.hamlet", {"n": number})
		WorldSite.Kind.WILD:
			return Text.t("world.site.wild", {"n": number})
	return Text.t("world.site.hub")


func _token(layer: Control, token_name: String) -> Control:
	var found := layer.get_node_or_null(NodePath(token_name)) as Control
	if found == null:
		found = Control.new()
		found.name = token_name
		found.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(found)
	return found


func _place(token: Control, tile: Vector2i, radius: float) -> void:
	token.size = Vector2.ONE * radius * 2.0
	token.position = tile_centre(tile) - Vector2.ONE * radius


func _draw() -> void:
	if _world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _terrain_colours[TileRegion.Terrain.WATER])
	var first := Vector2i((-_origin / _tile_px).floor()).max(Vector2i.ZERO)
	var last := Vector2i(((size - _origin) / _tile_px).ceil())
	last = last.min(Vector2i(_world.region.width, _world.region.height))
	for y: int in range(first.y, last.y):
		for x: int in range(first.x, last.x):
			var tile := Vector2i(x, y)
			var rect := Rect2(_origin + Vector2(tile) * _tile_px, Vector2.ONE * _tile_px)
			draw_rect(rect, _terrain_colours[_world.region.terrain(tile)])
	for site: WorldSite in _world.sites:
		var radius := _data.num("map", "site_radius_px")
		draw_circle(tile_centre(_world.region.entrance(site.id)), radius, _colour("site"))
	for party: WorldParty in _world.parties:
		if party.active(_world.day):
			_draw_token(party.tile, _data.num("map", "party_radius_px"), _colour(party.type), party.chasing)
	_draw_token(_world.band, _data.num("map", "band_radius_px"), _colour("band"), true)


func _draw_token(tile: Vector2i, radius: float, colour: Color, ringed: bool) -> void:
	var centre := tile_centre(tile)
	draw_circle(centre, radius, colour)
	if ringed:
		var ring := _data.num("map", "ring_width_px")
		draw_arc(centre, radius, 0.0, TAU, RING_POINTS, _colour("ring"), ring)


func _colour(key: String) -> Color:
	return _data.rgb("colours", key + "_rgb")


func _fit() -> void:
	var view := get_viewport_rect().size
	position = Vector2.ONE * MARGIN_PX
	size = Vector2(view.x * WIDTH_SHARE - 2.0 * MARGIN_PX, view.y - 2.0 * MARGIN_PX)
