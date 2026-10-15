class_name BattleView
extends Node
## Draws a sim Battle on the street (docs/specs/art_direction_slice.md §2a step 6) and turns
## the player's clicks and buttons into Battle.apply() actions; the sim decides every
## outcome (CLAUDE.md rule 3). Battle cell (x, y) stands on street cell origin + (x, y). On
## a company fighter's turn the panel offers attack, learnt-move and wait buttons and a click
## on a reachable cell moves; enemy turns play themselves after a short pause (BattleAi, which
## only acts on what it sees). A flat ring under each fighter says whose side they are on
## (placeholder until the hand-made cast's art carries it; slice.json "markers"); a downed
## fighter's sprite goes and a dark ring marks where they fell. A strip at the top shows the
## turn order from now (Battle.turn_order) and whether a side wavers; a word marker over each
## enemy shows its intent for the round until it acts (Battle.intent). Placeholder look.

signal finished

const MARKER_DATA := "res://data/balance/slice.json"
const ENEMY_PAUSE_S := 0.45
const HUD_MARGIN_PX := 12.0
## How far above a fighter's feet the intent marker sits, and its outline for legibility.
const INTENT_LIFT_M := 2.1
const OUTLINE_PX := 6
const NOWHERE := Vector2i(-1, -1)
var battle: Battle = null
## Set before begin(): the street to draw on and the panel to speak through.
var street_stage: StreetStage = null
var panel: LoopPanel = null

var _origin := Vector2i.ZERO
var _sight := 0
var _sprites := {}
var _rings := {}
var _markers: StageData = null
var _wait_s := 0.0
var _hud: CanvasLayer = null
var _order_label: Label = null
var _intent_labels := {}


## Places one sprite per fighter and shows the first turn.
func begin(fight: Battle, origin: Vector2i, sight: int) -> void:
	battle = fight
	_origin = origin
	_sight = sight
	_markers = StageData.load_file(MARKER_DATA)
	for fighter: BattleUnit in battle.units:
		_sprites[fighter.id] = street_stage.add_merc(world_point(fighter.cell))
		_rings[fighter.id] = _ring()
	_make_hud()
	if not panel.chosen.is_connected(_on_choice):
		panel.chosen.connect(_on_choice)
	_refresh()
	_show_turn()


## Takes the fighters off the street.
func clear() -> void:
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


## The turn order strip's words (tests read it).
func order_text() -> String:
	return _order_label.text if _order_label != null else ""


## The intent marker over an enemy, or null.
func intent_label(unit_id: String) -> Label:
	if not _intent_labels.has(unit_id):
		return null
	var label: Label = _intent_labels[unit_id]
	return label


## The world point at the centre of a battle cell.
func world_point(cell: Vector2i) -> Vector3:
	var at := _origin + cell
	return Vector3(at.x + 0.5, 0.0, at.y + 0.5)


## The centre of the battle field, for the camera.
func centre() -> Vector3:
	return world_point(Vector2i.ZERO).lerp(world_point(_field_far()), 0.5)


## A click on a street cell: on a company turn, a move to that cell if reachable.
func click_cell(street_cell: Vector2i) -> void:
	var actor := battle.current() if battle != null else null
	if actor == null or battle.is_over() or actor.side != BattleUnit.COMPANY:
		return
	_play({"type": Battle.ACTION_MOVE, "to": street_cell - _origin})


func _process(delta: float) -> void:
	if battle == null:
		return
	_place_intents()
	if battle.is_over():
		return
	if battle.current().side == BattleUnit.ENEMY:
		_wait_s += delta
		if _wait_s >= ENEMY_PAUSE_S:
			_wait_s = 0.0
			_play(BattleAi.choose(battle, battle.current(), _sight))


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
	if battle.apply(action).is_empty():
		return
	_refresh()
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
					"id": Battle.ACTION_ATTACK + ":" + enemy.id,
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
		var key := (
			"down_rgb"
			if fighter.down
			else ("company_rgb" if fighter.side == BattleUnit.COMPANY else "enemy_rgb")
		)
		var material := ring.material_override as StandardMaterial3D
		material.albedo_color = _markers.rgb("markers", key)


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
	_order_label = _hud_label()
	_order_label.position = Vector2(HUD_MARGIN_PX, HUD_MARGIN_PX)
	for fighter: BattleUnit in battle.units:
		if fighter.side == BattleUnit.ENEMY:
			_intent_labels[fighter.id] = _hud_label()


func _hud_label() -> Label:
	var label := Label.new()
	label.add_theme_constant_override(&"outline_size", OUTLINE_PX)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(label)
	return label


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
	for unit_id: Variant in _intent_labels:
		var label: Label = _intent_labels[unit_id]
		var plan := battle.intent(str(unit_id))
		label.visible = not plan.is_empty() and not battle.is_over()
		if plan.is_empty():
			continue
		var target := battle.unit(str(plan.get("target", "")))
		var params := {"target": _name(target) if target != null else ""}
		label.text = Text.t("battle.intent." + str(plan.get("kind", "")), params)
	_place_intents()


## Keeps each intent marker over its enemy's head on screen.
func _place_intents() -> void:
	var camera := street_stage.camera()
	var scale := 1.0
	if street_stage.pixel_mode == StreetStage.PixelMode.WHOLE_SCREEN:
		scale = float(street_stage.screen_scale())
	for unit_id: Variant in _intent_labels:
		var label: Label = _intent_labels[unit_id]
		var head := world_point(battle.unit(str(unit_id)).cell) + Vector3.UP * INTENT_LIFT_M
		var at := camera.unproject_position(head) * scale
		label.reset_size()
		label.position = at - Vector2(label.size.x / 2.0, label.size.y)


func _field_far() -> Vector2i:
	var far := Vector2i.ZERO
	for fighter: BattleUnit in battle.units:
		far = far.max(fighter.cell)
	return far


func _name(fighter: BattleUnit) -> String:
	var kind := fighter.id.rstrip("0123456789").trim_suffix("_")
	var key := ("cast.%s.name" if fighter.side == BattleUnit.COMPANY else "enemy.%s.name") % kind
	return Text.t(key)


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


static func _gap(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
