class_name MapCover
extends Node
## Keeps the map's own panel and header out from under a full screen (the hub, the company):
## while one stands over the map they step aside, and when it closes the panel comes back as
## it was. A child of the overworld director, which sits under the SliceGame; it watches the
## game's screens each frame and decides nothing else.

var _panel: LoopPanel = null
var _map: OverworldMap = null
var _covered := false
var _panel_was_up := false


static func make(panel: LoopPanel, map: OverworldMap) -> MapCover:
	var cover := MapCover.new()
	cover._panel = panel
	cover._map = map
	return cover


func _process(_delta: float) -> void:
	var game := get_parent().get_parent() as SliceGame
	if game != null:
		_cover(game.company_open() or game.hub_open())


func _cover(covered: bool) -> void:
	if covered == _covered:
		# A panel the director raises under a screen (an encounter standing, the map reopened)
		# steps aside at once and comes back with the others when the screen closes.
		if covered and _panel.visible:
			_panel_was_up = true
			_panel.visible = false
		return
	_covered = covered
	if covered:
		_panel_was_up = _panel.visible
	_panel.visible = _panel_was_up and not covered
	_map.show_header(not covered)
