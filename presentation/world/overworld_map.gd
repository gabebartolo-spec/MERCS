class_name OverworldMap
extends Control
## The walkable overworld on screen (Phase 2): the region's tiles as flat placeholder colours
## (data/balance/overworld.json), a dot on each site's entrance, a token per party on the map
## (coloured by type, ringed while it chases the band) and the band's token. One texel grid,
## like the street (D-035, "no mixels or fake pixels"): everything is drawn at 1x on a logical
## SubViewport (the window's size over the street's whole-number scale, data/balance/stage.json
## "pixel") shown with nearest filtering, nothing is ever scaled, and the view follows the band
## in whole logical pixels: its tile sits at the centre and the map scrolls under it. The site
## names and the header (day, supplies) are UI text at window resolution. Reads WorldSim
## through show_world(); decides nothing. Placeholder look (D-067: final UI is out).

const DATA := "res://data/balance/overworld.json"
const MARGIN_PX := 12
const HEADER_PX := 32
const RING_POINTS := 32
const MARKER_PREFIX := &"Site_"
const PARTY_PREFIX := &"Party_"
const COMPANY_NAME := &"Company"
const PIXELS_NAME := &"MapPixels"
## The map takes the width the loop panel leaves free (LoopPanel.WIDTH_SHARE on the right).
const WIDTH_SHARE := 1.0 - LoopPanel.WIDTH_SHARE

var _data: StageData = null
var _world: WorldSim = null
## Logical pixels per tile, and window pixels per logical pixel.
var _tile := 1
var _scale := 1
## Where tile (0, 0)'s corner lands on the logical grid.
var _origin := Vector2i.ZERO
var _terrain_colours: Array[Color] = []
var _pixels := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _canvas := Control.new()
var _header := Label.new()
var _header_back := PanelContainer.new()
var _markers := Control.new()
var _parties := Control.new()
var _company := Control.new()


func _ready() -> void:
	_data = StageData.load_file(DATA)
	_tile = maxi(1, int(_data.num("map", "tile_px")))
	for key: String in TileRegion.TERRAIN_KEYS:
		_terrain_colours.append(_data.rgb("colours", key + "_rgb"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_fit()
	_build_pixels()
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


## The logical viewport the map is drawn in, shown _scale times larger with nearest filtering
## (the street's PixelScreen, for a 2D canvas).
func _build_pixels() -> void:
	var stage := StageData.load_file(StreetStage.STAGE_DATA_PATH)
	var logical_h := maxi(1, int(stage.num("pixel", "logical_height_px")))
	_scale = maxi(1, int(get_viewport_rect().size.y) / logical_h)
	_pixels.name = PIXELS_NAME
	_pixels.stretch = true
	_pixels.stretch_shrink = _scale
	_pixels.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixels.size = Vector2(Vector2i(size) / _scale * _scale)
	_viewport.size = Vector2i(size) / _scale
	_viewport.disable_3d = true
	_viewport.handle_input_locally = false
	_viewport.canvas_item_default_texture_filter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = Vector2(_viewport.size)
	_canvas.draw.connect(_draw_map)
	add_child(_pixels)
	_pixels.add_child(_viewport)
	_viewport.add_child(_canvas)


## Centres the view on the band (in whole logical pixels), places every marker and token, and
## redraws.
func show_world(world: WorldSim) -> void:
	_world = world
	_header.text = Text.t("world.header", {"day": world.day, "supplies": world.supplies})
	_origin = _viewport.size / 2 - world.band * _tile - Vector2i.ONE * floori(_tile / 2.0)
	for site: WorldSite in world.sites:
		var marker := _token(_markers, String(MARKER_PREFIX) + site.id)
		_place(marker, world.region.entrance(site.id), int(_data.num("map", "site_radius_px")))
		if marker.get_child_count() == 0:
			var label := Label.new()
			label.text = site_name(site)
			label.position = Vector2(marker.size.x + MARGIN_PX / 2.0, -marker.size.y)
			marker.add_child(label)
	for party: WorldParty in world.parties:
		var token := _token(_parties, String(PARTY_PREFIX) + party.id)
		_place(token, party.tile, int(_data.num("map", "party_radius_px")))
		token.visible = party.active(world.day)
	_place(_company, world.band, int(_data.num("map", "band_radius_px")))
	_canvas.queue_redraw()


## The marker for a site id, or null (tests read its rect).
func marker_for(site_id: String) -> Control:
	return _markers.get_node_or_null(NodePath(String(MARKER_PREFIX) + site_id)) as Control


## A party's token, or null; hidden while the party is off the map.
func party_marker(party_id: String) -> Control:
	return _parties.get_node_or_null(NodePath(String(PARTY_PREFIX) + party_id)) as Control


## The band's token, centred on the band's tile (at the view's centre).
func company_marker() -> Control:
	return _company


## The logical viewport the map is drawn in, and the container that shows it (tests check
## the texel grid: whole-number scale, nearest filtering, nothing scaled).
func pixel_view() -> SubViewport:
	return _viewport


func pixel_container() -> SubViewportContainer:
	return _pixels


## Window pixels per logical pixel.
func pixel_scale() -> int:
	return _scale


## Where a tile's centre lands on the logical grid, at the view as last shown.
func tile_centre(tile: Vector2i) -> Vector2i:
	return _origin + tile * _tile + Vector2i.ONE * floori(_tile / 2.0)


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


## A window-space stand-in over a token drawn on the logical grid (tests and labels use it).
func _place(token: Control, tile: Vector2i, radius: int) -> void:
	token.size = Vector2.ONE * radius * 2 * _scale
	token.position = Vector2((tile_centre(tile) - Vector2i.ONE * radius) * _scale)


## Draws the tiles in view, the site dots, the parties and the band, all at 1x on the grid.
func _draw_map() -> void:
	if _world == null:
		return
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), _terrain_colours[TileRegion.Terrain.WATER])
	var first := (-_origin / _tile).max(Vector2i.ZERO)
	var last := (_viewport.size - _origin) / _tile + Vector2i.ONE
	last = last.min(Vector2i(_world.region.width, _world.region.height))
	for y: int in range(first.y, last.y):
		for x: int in range(first.x, last.x):
			var tile := Vector2i(x, y)
			var rect := Rect2(Vector2(_origin + tile * _tile), Vector2.ONE * _tile)
			_canvas.draw_rect(rect, _terrain_colours[_world.region.terrain(tile)])
	var site_radius := _data.num("map", "site_radius_px")
	for site: WorldSite in _world.sites:
		var at := Vector2(tile_centre(_world.region.entrance(site.id)))
		_canvas.draw_circle(at, site_radius, _colour("site"))
	var party_radius := _data.num("map", "party_radius_px")
	for party: WorldParty in _world.parties:
		if party.active(_world.day):
			_draw_token(party.tile, party_radius, _colour(party.type), party.chasing)
	_draw_token(_world.band, _data.num("map", "band_radius_px"), _colour("band"), true)


func _draw_token(tile: Vector2i, radius: float, colour: Color, ringed: bool) -> void:
	var centre := Vector2(tile_centre(tile))
	_canvas.draw_circle(centre, radius, colour)
	if ringed:
		var ring := _data.num("map", "ring_width_px")
		_canvas.draw_arc(centre, radius, 0.0, TAU, RING_POINTS, _colour("ring"), ring)


func _colour(key: String) -> Color:
	return _data.rgb("colours", key + "_rgb")


func _fit() -> void:
	var view := get_viewport_rect().size
	position = Vector2.ONE * MARGIN_PX
	size = Vector2(view.x * WIDTH_SHARE - 2.0 * MARGIN_PX, view.y - 2.0 * MARGIN_PX)
