class_name BattleMarks
extends RefCounted
## What a fight leaves on the field (director ruling Q-G, "at every hit": a splat on every wound,
## drying over the fight; bodies stay where they fell until it ends). Presentation only: it reads
## the sim's "hit" and "down" events (Battle.apply's output) and decides nothing, so the same
## events always draw the same field. A splat lies at the hit's logged cell, a body at the cell
## its fighter fell on. Each splat is a small clustered pixel blot in the core palette's blood
## ramp (no speckle, no gradient), its shape seeded by the hit's number and damage; it goes
## fresh red, then dark red as actions pass (never brown), and never vanishes early. A body
## is the fighter's own frame laid flat, head away from the killer (the blow's direction),
## at full size (a body is never smaller than the man), lying along a diagonal of its own cell and
## never over a standing fighter's feet, a pool spreading from under its torso, until the art
## agent's fall frames replace it (placeholder). Every ground mark is drawn at the figures' pixel
## size on screen: a ground quad is stretched along the ground's depth by the ratio the camera
## foreshortens it there (measured by projecting, not assumed from the pitch), so its pixels
## come out square. Numbers: data/balance/battle_view.json.

const DATA_PATH := "res://data/balance/battle_view.json"
const EVENT_HIT := "hit"
const EVENT_DOWN := "down"
const FRESH := BattleSplat.FRESH
const WET := BattleSplat.WET
const DRY := BattleSplat.DRY
const NOWHERE := Vector2i(-1, -1)
const NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PAIR := 2

## One entry per wound, in order: {index, cell, unit, by, damage, born, jitter, level}.
var splats: Array[Dictionary] = []
## One entry per fighter who fell, in order: {unit, cell, by, dir (a unit step: the way the body
## lies, head first), from (the killer's cell at the blow), born}.
var bodies: Array[Dictionary] = []

var _data: StageData = StageData.load_file(DATA_PATH)
var _splat := BattleSplat.new()
var _stage: StreetStage = null
var _ground := Callable()
var _hits := 0
var _actions := 0
var _nodes: Dictionary = {}


## Draws onto this stage; ground turns a battle cell into the world point at its centre
## (BattleView.world_point). Without a stage the marks are still recorded (the model the tests
## read) but no node is made.
func begin(stage: StreetStage, ground: Callable) -> void:
	_stage = stage
	_ground = ground


## Takes one applied action's events: a splat per hit, a body per fall, and ages every splat.
func record(
	events: Array[Dictionary], battle: Battle, sprites: Dictionary, fx: BattleFx = null
) -> void:
	_actions += 1
	for event: Dictionary in events:
		var kind := str(event.get("type", ""))
		if kind == EVENT_HIT:
			_add_splat(event)
		elif kind == EVENT_DOWN:
			var unit_id := str(event.get("unit", ""))
			var body := _add_body(unit_id, events, battle)
			var source: Sprite3D = sprites.get(unit_id, null)
			if _stage != null and source != null:
				var shown: ShaderMaterial = null
				if fx != null:
					shown = fx.plain_material(unit_id, source)
				_lay(body, source, shown)
	for splat: Dictionary in splats:
		_age(splat)
	for body: Dictionary in bodies:
		_age_pool(body)


## The cells the splats lie on, in the order the hits happened.
func splat_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for splat: Dictionary in splats:
		var cell: Vector2i = splat["cell"]
		out.append(cell)
	return out


## The fighters lying on the field, in the order they fell.
func body_units() -> Array[String]:
	var out: Array[String] = []
	for body: Dictionary in bodies:
		out.append(str(body["unit"]))
	return out


## The node drawing a splat or body entry, or null (no stage, or no frame to lay down).
func node_of(mark: Dictionary) -> Sprite3D:
	var key := _key(mark)
	if not _nodes.has(key):
		return null
	var found: Sprite3D = _nodes[key]
	return found


## The pool drawn under a body, or null.
func pool_of(body: Dictionary) -> Sprite3D:
	var found: Sprite3D = _nodes.get("pool_%s" % body["unit"], null)
	return found


## The age of a splat now: FRESH, WET or DRY.
func age_of(splat: Dictionary) -> int:
	var old := _actions - Merc.whole(splat["born"])
	if old >= int(_data.num("age", "dry_after_actions")):
		return DRY
	if old >= int(_data.num("age", "wet_after_actions")):
		return WET
	return FRESH


## Takes every mark off the field (the fight is over and its figures are cleared).
func clear() -> void:
	for node: Variant in _nodes.values():
		var sprite: Sprite3D = node
		sprite.queue_free()
	_nodes.clear()
	splats.clear()
	bodies.clear()
	_hits = 0
	_actions = 0


func _add_splat(event: Dictionary) -> void:
	var splat := {
		"index": _hits,
		"cell": event.get("cell", NOWHERE),
		"unit": str(event.get("target", "")),
		"by": str(event.get("unit", "")),
		"damage": Merc.whole(event.get("damage", 0)),
		"born": _actions,
		"level": FRESH,
	}
	_hits += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = Merc.whole(splat["index"]) * int(_data.num("splat", "seed_mul")) + 1
	var spread := int(_data.num("splat", "jitter_px"))
	var jitter := Vector2i(
		rng.randi_range(-spread, spread),
		rng.randi_range(0, Merc.whole(_data.num("splat", "jitter_front_px")))
	)
	splat["jitter"] = jitter
	splats.append(splat)
	if _stage != null:
		var sprite := _sprite(_data.num("lift", "splat_m"))
		sprite.texture = ImageTexture.create_from_image(
			_splat.image(Merc.whole(splat["index"]), Merc.whole(splat["damage"]), FRESH)
		)
		var cell: Vector2i = splat["cell"]
		_place(sprite, cell, jitter)
		_nodes[_key(splat)] = sprite


func _add_body(unit_id: String, events: Array[Dictionary], battle: Battle) -> Dictionary:
	var cell := NOWHERE
	var by := ""
	for event: Dictionary in events:
		if event.get("type", "") == EVENT_HIT and event.get("target", "") == unit_id:
			cell = event.get("cell", NOWHERE)
			by = str(event.get("unit", ""))
	var fallen := battle.unit(unit_id)
	if cell == NOWHERE and fallen != null:
		cell = fallen.cell
	var attacker := battle.unit(by)
	var from := cell if attacker == null else attacker.cell
	var body := {
		"unit": unit_id,
		"cell": cell,
		"by": by,
		"from": from,
		"dir": fall_dir(cell, from, bodies.size()),
		"born": _actions
	}
	bodies.append(body)
	return body


## The way a body lies: a diagonal step of its cell (x and z each one way), away from the
## killer's cell (the sim's hit event names the killer; nothing is decided here). An axis with no
## difference (the blow came along the other axis, or from nowhere) is taken by the order of the
## fall, so the same events always lay the same bodies.
func fall_dir(victim: Vector2i, killer: Vector2i, order: int) -> Vector2i:
	var away := victim - killer
	var even := order % PAIR == 0
	var x := Vector2i.RIGHT.x if away.x > 0 else Vector2i.LEFT.x
	var z := Vector2i.DOWN.y if away.y > 0 else Vector2i.UP.y
	if away.x == 0:
		x = Vector2i.RIGHT.x if even else Vector2i.LEFT.x
	if away.y == 0:
		z = Vector2i.UP.y if even else Vector2i.DOWN.y
	return Vector2i(x, z)


## The ground a cell owns, in world metres (x, z): a cell wide, and from half way to the row
## above to half way to the row below. Needs the ground callable (begin).
func footprint(cell: Vector2i) -> Rect2:
	var here: Vector3 = _ground.call(cell)
	var above: Vector3 = _ground.call(cell + Vector2i.UP)
	var below: Vector3 = _ground.call(cell + Vector2i.DOWN)
	var near := (here.z + below.z) / PAIR
	var far := (here.z + above.z) / PAIR
	var half := _data.num("body", "cell_width_m") / PAIR
	return Rect2(here.x - half, far, half * PAIR, near - far)


## The ground points (x, z) of every solid pixel of a body's drawing; empty with no node.
func body_points(body: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var sprite := node_of(body)
	if sprite == null or sprite.texture == null:
		return out
	var image := sprite.texture.get_image()
	var depth := sprite.pixel_size * sprite.scale.z
	var half := Vector2(image.get_size()) / PAIR
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= BattleBody.OPAQUE:
				out.append(
					Vector2(
						sprite.position.x + (x + 0.5 - half.x) * sprite.pixel_size,
						sprite.position.z + (y + 0.5 - half.y) * depth
					)
				)
	return out


## The feet of a fighter standing at this cell, in world metres (x, z): the ground a body must
## keep off so it never draws over them.
func feet_rect(cell: Vector2i) -> Rect2:
	var here: Vector3 = _ground.call(cell)
	var half := _data.num("body", "feet_half_m")
	return Rect2(here.x - half, here.z - half, half * PAIR, half * PAIR)


## Puts the fighter's frame on the ground at full size, lying along the diagonal of its cell as
## seen on screen (head to the corner away from the killer), with the death pool under its torso.
func _lay(body: Dictionary, source: Sprite3D, shown: ShaderMaterial) -> void:
	var frame := _frame(source, shown)
	if frame == null:
		return
	var cell: Vector2i = body["cell"]
	var dir: Vector2i = body["dir"]
	var image := BattleBody.turn(frame, _diagonal_angle(cell, dir))
	var area := footprint(cell)
	var sprite := _sprite(_data.num("lift", "body_m"))
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.position = Vector3(area.get_center().x, sprite.position.y, area.get_center().y)
	sprite.scale = Vector3(1.0, 1.0, _squash(sprite.position))
	_nodes[_key(body)] = sprite
	body["solid"] = BattleBody.solid(image)
	body["source_solid"] = BattleBody.solid(frame)
	var torso := BattleBody.torso(image)
	var spot := Vector3(
		sprite.position.x + torso.x * sprite.pixel_size,
		sprite.position.y,
		sprite.position.z + torso.y * sprite.pixel_size * sprite.scale.z
	)
	body["torso"] = Vector2(spot.x, spot.z)
	var pool := _sprite(_data.num("lift", "pool_m"))
	pool.texture = ImageTexture.create_from_image(_pool_image(body, FRESH))
	pool.position = Vector3(spot.x, pool.position.y, spot.z)
	pool.scale = Vector3(1.0, 1.0, _squash(pool.position))
	_nodes["pool_%s" % body["unit"]] = pool


## The clockwise turn that points a standing frame's head along the cell's screen diagonal
## towards the corner this step names.
func _diagonal_angle(cell: Vector2i, dir: Vector2i) -> float:
	var area := footprint(cell)
	var camera := _stage.camera()
	var centre := area.get_center()
	var half := area.size / PAIR
	var tail := camera.unproject_position(
		Vector3(centre.x - dir.x * half.x, 0.0, centre.y - dir.y * half.y)
	)
	var head := camera.unproject_position(
		Vector3(centre.x + dir.x * half.x, 0.0, centre.y + dir.y * half.y)
	)
	var along := head - tail
	return atan2(along.x, -along.y)


## The fighter's frame as it stands, cropped to its pixels; null with no frame.
func _frame(source: Sprite3D, shown: ShaderMaterial) -> Image:
	var material := shown if shown != null else source.material_override as ShaderMaterial
	if material == null:
		return null
	var texture: Texture2D = material.get_shader_parameter(&"albedo_texture")
	if texture == null:
		return null
	var sheet := texture.get_image()
	if sheet == null or sheet.is_empty():
		return null
	var frame := sheet.get_region(Rect2i(source.region_rect))
	frame.convert(Image.FORMAT_RGBA8)
	var used := frame.get_used_rect()
	if used.size == Vector2i.ZERO:
		return null
	return frame.get_region(used)


## A stable key for a mark's node (its entry changes as it ages, so it cannot be the key).
func _key(mark: Dictionary) -> String:
	return "splat_%d" % Merc.whole(mark["index"]) if mark.has("index") else "body_%s" % mark["unit"]


func _age(splat: Dictionary) -> void:
	var level := age_of(splat)
	if level == Merc.whole(splat["level"]):
		return
	splat["level"] = level
	var sprite := node_of(splat)
	if sprite != null:
		sprite.texture = ImageTexture.create_from_image(
			_splat.image(Merc.whole(splat["index"]), Merc.whole(splat["damage"]), level)
		)


## A death pool dries with the splats, by the age of its body's fall.
func _age_pool(body: Dictionary) -> void:
	var pool: Sprite3D = _nodes.get("pool_%s" % body["unit"], null)
	if pool == null:
		return
	var level := age_of(body)
	if level == Merc.whole(body.get("pool_level", FRESH)):
		return
	body["pool_level"] = level
	pool.texture = ImageTexture.create_from_image(_pool_image(body, level))


func _pool_image(body: Dictionary, level: int) -> Image:
	var index := Merc.whole(_data.num("pool", "seed")) + bodies.find(body)
	return _splat.image(index, Merc.whole(_data.num("pool", "damage")), level)


## A flat quad lying face up on the ground, one logical pixel per texel.
func _sprite(lift_m: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.axis = Vector3.AXIS_Y
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.pixel_size = _stage.texel_m()
	sprite.position.y = lift_m
	_stage.world().add_child(sprite)
	return sprite


## How much longer a ground quad is made along the depth axis: the camera sees ground depth
## foreshortened by sin(pitch), and the figures' frames are already drawn foreshortened, so this
## puts a ground pixel at the figures' size on screen.
func _squash(point: Vector3) -> float:
	var camera := _stage.camera()
	var origin := camera.unproject_position(point)
	var step := _data.num("body", "probe_m")
	var upright := camera.unproject_position(point + camera.global_transform.basis.y * step)
	var along := camera.unproject_position(point + Vector3(0.0, 0.0, step))
	var flat := absf(along.y - origin.y)
	return absf(upright.y - origin.y) / flat if flat > 0.0 else 1.0


func _place(sprite: Sprite3D, cell: Vector2i, jitter: Vector2i) -> void:
	var centre: Vector3 = _ground.call(cell)
	var texel := _stage.texel_m()
	sprite.position = Vector3(
		centre.x + jitter.x * texel, sprite.position.y, centre.z + jitter.y * texel
	)
	sprite.scale = Vector3(1.0, 1.0, _squash(sprite.position))


## The blot for a hit: same hit number, damage and age, same pixels.
func splat_image(index: int, damage: int, level: int) -> Image:
	return _splat.image(index, damage, level)
