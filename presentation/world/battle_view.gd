class_name BattleView
extends Node
## Draws a sim Battle on the street (docs/specs/art_direction_slice.md §2a step 6) and turns
## the player's clicks and buttons into Battle.apply() actions; the sim decides every
## outcome (CLAUDE.md rule 3). Battle cell (x, y) stands on street cell origin + (x, y). On
## a company fighter's turn the panel offers attack, ability and wait buttons and a click on
## a reachable cell moves; enemy turns play themselves after a short pause (BattleAi, which
## only acts on what it sees). A flat ring under each fighter says whose side they are on
## (placeholder until the hand-made cast's art carries it; slice.json "markers"); a downed
## fighter's sprite goes and a dark ring marks where they fell.

signal finished

const MARKER_DATA := "res://data/balance/slice.json"
const ENEMY_PAUSE_S := 0.45
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


## Places one sprite per fighter and shows the first turn.
func begin(fight: Battle, origin: Vector2i, sight: int) -> void:
	battle = fight
	_origin = origin
	_sight = sight
	_markers = StageData.load_file(MARKER_DATA)
	for fighter: BattleUnit in battle.units:
		_sprites[fighter.id] = street_stage.add_merc(world_point(fighter.cell))
		_rings[fighter.id] = _ring()
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
	if battle == null or battle.is_over():
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
	if parts[0] == Battle.ACTION_CHARGE and parts.size() > 1:
		action["to"] = _charge_landing(battle.current(), battle.unit(parts[1]))
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


## The buttons for a company fighter: attack and abilities on each enemy in reach, wait.
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
			if actor.can_blood_price:
				out.append(
					{
						"id": Battle.ACTION_BLOOD_PRICE + ":" + enemy.id,
						"label": Text.t("slice.battle.blood", params)
					}
				)
		if actor.can_charge and _charge_landing(actor, enemy) != Vector2i(-1, -1):
			out.append(
				{
					"id": Battle.ACTION_CHARGE + ":" + enemy.id,
					"label": Text.t("slice.battle.charge", params)
				}
			)
	out.append({"id": Battle.ACTION_WAIT, "label": Text.t("slice.battle.wait")})
	return out


## The nearest cell the actor can reach (or stands on) beside the enemy; (-1, -1) if none.
func _charge_landing(actor: BattleUnit, enemy: BattleUnit) -> Vector2i:
	if enemy == null:
		return Vector2i(-1, -1)
	if _adjacent(actor.cell, enemy.cell):
		return actor.cell
	var best := Vector2i(-1, -1)
	var cells: Array = battle.reachable(actor).keys()
	cells.sort()
	for cell: Vector2i in cells:
		if (
			_adjacent(cell, enemy.cell)
			and (best == Vector2i(-1, -1) or _gap(cell, actor.cell) < _gap(best, actor.cell))
		):
			best = cell
	return best


func _refresh() -> void:
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
