class_name BattleView
extends Node
## Draws a sim Battle on the street (docs/specs/art_direction_slice.md §2a step 6) and turns
## the player's clicks and buttons into Battle.apply() actions; the sim decides every
## outcome (CLAUDE.md rule 3). Battle cell (x, y) stands on street cell origin + (x, y). On
## a company fighter's turn the panel offers attack, learnt-move and wait buttons and a click
## on a reachable cell moves; enemy turns play themselves after a short pause (BattleAi, which
## only acts on what it sees). A flat ring under each fighter says whose side they are on
## (placeholder until the hand-made cast's art carries it; slice.json "markers"); a downed
## fighter's sprite and ring go and the body stays (BattleMarks). A strip along the bottom
## left (clear of the help line at the top) shows the turn order from now
## (Battle.turn_order) and whether a side wavers; a word marker over each enemy's head shows
## its intent for the round until it acts (Battle.intent). The intents are one backed line
## per enemy in a lane at the top left, named by enemy, clear of the side panel; nothing floats
## over the bodies. Rows of the battle grid are drawn a figure's height apart on screen
## (BattleRows) so neighbours never overlap; two fighters with one name are numbered.
## Placeholder look.

signal finished
## Every action the battle applied, either side's, in order (Battle.apply's input): Ironman
## records them so a reload can resume the fight (FightRecord). Raised before `finished`.
signal acted(action: Dictionary)

const MARKER_DATA := "res://data/balance/slice.json"
const ENEMY_PAUSE_S := 0.45
const HUD_MARGIN_PX := 12.0
## The intent lane's top edge in window pixels at 1080p: under the help line.
const LANE_TOP_PX := 56.0
const NOWHERE := Vector2i(-1, -1)
var battle: Battle = null
## Set before begin(): the street to draw on and the panel to speak through.
var street_stage: StreetStage = null
var panel: LoopPanel = null
## Display names by fighter id, for fighters the cast text keys do not name (the company's
## mercs, from their data); the others are named by their kind.
var unit_names := {}
## What the fight leaves on the field (blood at every hit, bodies) and the hit flashes (P6b).
var marks := BattleMarks.new()
var fx := BattleFx.new()

var _origin := Vector2i.ZERO
var _sight := 0
var _sprites := {}
var _rings := {}
var _markers: StageData = null
var _wait_s := 0.0
var _hud: CanvasLayer = null
var _order_label: Label = null
var _intent_labels := {}
var _lane: PanelContainer = null
var _order_box: PanelContainer = null
var _names := {}
var _rows: BattleRows = null
var _mid := Vector2.ZERO
var _was_logical := Vector2i.ZERO
var _was_scale := 0


## Places one sprite per fighter and shows the first turn.
func begin(fight: Battle, origin: Vector2i, sight: int) -> void:
	battle = fight
	_origin = origin
	_sight = sight
	_names = BattleNames.of(battle, unit_names)
	_rows = BattleRows.new(street_stage)
	_zoom_out()
	_mid = _field_mid()
	_markers = StageData.load_file(MARKER_DATA)
	for fighter: BattleUnit in battle.units:
		var sprite := street_stage.add_merc(world_point(fighter.cell))
		_sprites[fighter.id] = sprite
		_rows.learn(sprite)
		_rings[fighter.id] = _ring()
	marks.begin(street_stage, world_point)
	_make_hud()
	if not panel.chosen.is_connected(_on_choice):
		panel.chosen.connect(_on_choice)
	_refresh()
	_show_turn()


## Takes the fighters off the street.
func clear() -> void:
	fx.clear(_sprites, battle)
	marks.clear()
	for unit_id: Variant in _sprites:
		var sprite: Sprite3D = _sprites[unit_id]
		street_stage.remove_merc(sprite)
		var ring: MeshInstance3D = _rings[unit_id]
		ring.queue_free()
	_sprites.clear()
	_rings.clear()
	if _hud != null:
		_hud.queue_free()
		_hud = null
	_intent_labels.clear()
	_lane = null
	_order_box = null
	_zoom_back()


## The turn order strip's words (tests read it).
func order_text() -> String:
	return _order_label.text if _order_label != null else ""


## The intent marker over an enemy, or null.
func intent_label(unit_id: String) -> Label:
	if not _intent_labels.has(unit_id):
		return null
	var label: Label = _intent_labels[unit_id]
	return label


## The intent lane's rectangle on the HUD layer (empty when no enemy has a plan).
func lane_rect() -> Rect2:
	if _lane == null or not _lane.visible:
		return Rect2()
	return Rect2(_lane.position, _lane.size)


## The world point at the centre of a battle cell. The middle row of the field (where the
## fight began) stands on the street at its own row; the others are spaced by BattleRows.
func world_point(cell: Vector2i) -> Vector3:
	var depth := _rows.depth_of(cell.y - _mid.y)
	return Vector3(_origin.x + cell.x + 0.5, 0.0, _origin.y + _mid.y + 0.5 + depth)


## The street cell (origin + battle cell) under a ground point: the click's cell.
func street_cell_at(ground: Vector3) -> Vector2i:
	var rows := _rows.rows_of(ground.z - (_origin.y + _mid.y + 0.5))
	return Vector2i(floori(ground.x), _origin.y + roundi(_mid.y + rows))


## The middle of the field the fight began on, for the camera.
func centre() -> Vector3:
	return Vector3(_origin.x + _mid.x + 0.5, 0.0, _origin.y + _mid.y + 0.5)


## The screen rectangle the drawn figure of each fighter covers (the opaque pixels of its
## frame, not the frame's empty cell), in the camera's viewport pixels (tests compare them:
## neighbours must not overlap).
func sprite_rects() -> Dictionary:
	var out := {}
	for unit_id: Variant in _sprites:
		var sprite: Sprite3D = _sprites[unit_id]
		out[unit_id] = _rows.figure_rect(sprite)
	return out


## A click on a street cell: on a company turn, a move to that cell if reachable.
func click_cell(street_cell: Vector2i) -> void:
	var actor := battle.current() if battle != null else null
	if actor == null or battle.is_over() or actor.side != BattleUnit.COMPANY:
		return
	_play({"type": Battle.ACTION_MOVE, "to": street_cell - _origin})


func _process(delta: float) -> void:
	if battle == null:
		return
	fx.tick(delta, _sprites, battle)
	if battle.is_over():
		return
	if battle.current().side == BattleUnit.ENEMY:
		_wait_s += delta
		if _wait_s >= ENEMY_PAUSE_S:
			_wait_s = 0.0
			var before := battle.log.size()
			var done := BattleAi.act(battle, battle.current(), _sight)
			if not done.is_empty():
				_played(done, battle.log.slice(before))


func _on_choice(choice_id: String) -> void:
	if battle == null or battle.is_over():
		return
	var parts := choice_id.split(":")
	var action := {"type": parts[0]}
	if parts.size() > 1:
		action["target"] = parts[1]
	if parts.size() > 1 and battle.current().knows(parts[0]):
		action["to"] = _landing(battle.current(), battle.unit(parts[1]), parts[0])
	_play(action)


func _play(action: Dictionary) -> void:
	var events := battle.apply(action)
	if not events.is_empty():
		_played(action, events)


## An action the battle took: recorded (FightRecord), drawn, and the next turn shown.
func _played(action: Dictionary, events: Array[Dictionary]) -> void:
	acted.emit(action)
	_refresh()
	marks.record(events, battle, _sprites, fx)
	fx.play(events, _sprites)
	if battle.is_over():
		finished.emit()
	else:
		_show_turn()


func _show_turn() -> void:
	var actor := battle.current()
	var title := Text.t("slice.battle.turn", {"name": _name(actor), "hp": actor.hp})
	if actor.side == BattleUnit.ENEMY:
		panel.present(title, Text.t("slice.battle.enemy_turn"), [])
		return
	panel.present(title, Text.t("slice.battle.move_hint"), _actions(actor))


## The buttons for a company fighter: attack and each learnt move on each enemy in reach,
## in loadout order, then wait.
func _actions(actor: BattleUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enemy: BattleUnit in battle.units:
		if enemy.side == actor.side or enemy.down:
			continue
		var params := {"target": _name(enemy)}
		if _adjacent(actor.cell, enemy.cell):
			out.append(
				{
					"id": battle.kit(actor.id)[0] + ":" + enemy.id,
					"label": Text.t("slice.battle.attack", params)
				}
			)
		for move: String in actor.moves:
			if _landing(actor, enemy, move) != NOWHERE:
				out.append(
					{"id": move + ":" + enemy.id, "label": Text.t("battle.move." + move, params)}
				)
	out.append({"id": Battle.ACTION_WAIT, "label": Text.t("slice.battle.wait")})
	return out


## Where the actor uses a move on the enemy: where he stands when beside them, else the
## nearest reachable cell beside them for a move that walks; NOWHERE when out of reach.
func _landing(actor: BattleUnit, enemy: BattleUnit, move: String) -> Vector2i:
	if enemy == null:
		return NOWHERE
	if _adjacent(actor.cell, enemy.cell):
		return actor.cell
	if battle.move_def(move).get("walk") != true:
		return NOWHERE
	var best := NOWHERE
	var cells: Array = battle.reachable(actor).keys()
	cells.sort()
	for cell: Vector2i in cells:
		if (
			_adjacent(cell, enemy.cell)
			and (best == NOWHERE or _gap(cell, actor.cell) < _gap(best, actor.cell))
		):
			best = cell
	return best


func _refresh() -> void:
	_refresh_hud()
	var extras := street_stage.extra_mercs
	for fighter: BattleUnit in battle.units:
		var sprite: Sprite3D = _sprites[fighter.id]
		var index := extras.find(sprite)
		street_stage.move_extra(index, world_point(fighter.cell))
		sprite.visible = not fighter.down
		var ring: MeshInstance3D = _rings[fighter.id]
		ring.position = world_point(fighter.cell) + Vector3.UP * _markers.num("markers", "lift_m")
		ring.visible = not fighter.down
		var key := "company" if fighter.side == BattleUnit.COMPANY else "enemy"
		var material := ring.material_override as StandardMaterial3D
		material.albedo_color = _markers.colour("markers", key)


func _ring() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = _markers.num("markers", "radius_m")
	mesh.bottom_radius = mesh.top_radius
	mesh.height = _markers.num("markers", "height_m")
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	street_stage.world().add_child(ring)
	return ring


func _make_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_order_box = _backed()
	_order_label = _hud_label(_order_box)
	_lane = _backed()
	var lines := VBoxContainer.new()
	_lane.add_child(lines)
	for fighter: BattleUnit in battle.units:
		if fighter.side == BattleUnit.ENEMY:
			_intent_labels[fighter.id] = _hud_label(lines)


func _hud_label(parent: Node) -> Label:
	var label := Label.new()
	UiLook.outlined(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## A panel behind HUD text: the theme's panel, made opaque so the world never shows through.
func _backed() -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	var style := box.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style != null:
		style = style.duplicate() as StyleBoxFlat
		style.bg_color.a = 1.0
		box.add_theme_stylebox_override(&"panel", style)
	return box


## The turn order from now and any wavering side; each enemy's plan for the round.
func _refresh_hud() -> void:
	var names: Array[String] = []
	for fighter: BattleUnit in battle.turn_order():
		names.append(_name(fighter))
	var line := Text.t("battle.order", {"names": Text.t("battle.order.separator").join(names)})
	for side: int in BattleUnit.SIDES:
		if battle.is_shaken(side):
			line += " " + Text.t("battle.shaken." + BattleUnit.SIDE_KEYS[side])
	_order_label.text = line
	_order_box.reset_size()
	var strip := _order_box.get_combined_minimum_size()
	var view := _order_box.get_viewport_rect().size
	_order_box.position = Vector2(HUD_MARGIN_PX, view.y - strip.y - HUD_MARGIN_PX)
	var shown := 0
	for unit_id: Variant in _intent_labels:
		var label: Label = _intent_labels[unit_id]
		var plan := battle.intent(str(unit_id))
		label.visible = not plan.is_empty() and not battle.is_over()
		if plan.is_empty():
			continue
		shown += 1
		var target := battle.unit(str(plan.get("target", "")))
		var params := {"target": _name(target) if target != null else ""}
		label.text = Text.t(
			"battle.intent.line",
			{
				"who": _name(battle.unit(str(unit_id))),
				"plan": Text.t("battle.intent." + str(plan.get("kind", "")), params)
			}
		)
	_lane.visible = shown > 0
	_lane.reset_size()
	_lane.position = Vector2(HUD_MARGIN_PX, LANE_TOP_PX)


func _name(fighter: BattleUnit) -> String:
	return str(_names.get(fighter.id, fighter.id))


## Zooms the stage out for the fight (data "pixel" "fight_zoom": the logical viewport that many
## times larger, its upscale that many times smaller, so every texel stays a whole number of
## window pixels and six fighters a figure's height apart fit on screen).
func _zoom_out() -> void:
	var zoom := int(street_stage.stage_data.num("pixel", "fight_zoom"))
	_was_logical = street_stage.logical_size_px
	_was_scale = street_stage.integer_scale
	var base_scale := street_stage.screen_scale()
	street_stage.logical_size_px = street_stage.logical_size() * zoom
	street_stage.integer_scale = maxi(1, base_scale / zoom)
	if street_stage.pixel_mode == StreetStage.PixelMode.WHOLE_SCREEN:
		PixelScreen.refit(street_stage)


func _zoom_back() -> void:
	street_stage.logical_size_px = _was_logical
	street_stage.integer_scale = _was_scale
	if street_stage.pixel_mode == StreetStage.PixelMode.WHOLE_SCREEN:
		PixelScreen.refit(street_stage)


## The middle of the cells the fighters stand on at the start.
func _field_mid() -> Vector2:
	var low := Vector2i(1000, 1000)
	var high := Vector2i(-1000, -1000)
	for fighter: BattleUnit in battle.units:
		low = low.min(fighter.cell)
		high = high.max(fighter.cell)
	return Vector2(low + high) / 2.0


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


static func _gap(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
