class_name BattleMarks
extends RefCounted
## What a fight leaves on the field (director ruling Q-G, "at every hit": a splat on every wound,
## drying over the fight; bodies stay where they fell until it ends). Presentation only: it reads
## the sim's "hit" and "down" events (Battle.apply's output) and decides nothing, so the same
## events always draw the same field. A splat lies at the hit's logged cell, a body at the cell
## its fighter fell on. Each splat is a small clustered pixel blot in the core palette's blood
## ramp (no speckle, no gradient), its shape seeded by the hit's number and damage; it goes
## fresh red, then dark red as actions pass (never brown), and never vanishes early. A body
## is the fighter's own frame laid flat, head away from the killer (the axis the blow came along),
## shrunk to fit inside its own cell and never over a standing fighter's feet, until the art
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


## The way a body lies: a unit step along the axis the killing blow came along, away from the
## killer's cell (the sim's hit event names the killer; nothing is decided here). A blow from
## nowhere (no killer, or the same cell) falls east or west by the order of the fall.
func fall_dir(victim: Vector2i, killer: Vector2i, order: int) -> Vector2i:
	var away := victim - killer
	if away == Vector2i.ZERO:
		return Vector2i.RIGHT if order % PAIR == 0 else Vector2i.LEFT
	if absi(away.x) >= absi(away.y):
		return Vector2i.RIGHT if away.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if away.y > 0 else Vector2i.UP


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


## The ground a body's drawing covers, in world metres (x, z); an empty rect with no node.
func body_rect(body: Dictionary) -> Rect2:
	var sprite := node_of(body)
	if sprite == null or sprite.texture == null:
		return Rect2()
	var size := Vector2(sprite.texture.get_size()) * sprite.pixel_size
	size.y *= sprite.scale.z
	return Rect2(Vector2(sprite.position.x, sprite.position.z) - size / PAIR, size)


## The feet of a fighter standing at this cell, in world metres (x, z): the ground a body must
## keep off so it never draws over them.
func feet_rect(cell: Vector2i) -> Rect2:
	var here: Vector3 = _ground.call(cell)
	var half := _data.num("body", "feet_half_m")
	return Rect2(here.x - half, here.z - half, half * PAIR, half * PAIR)


## Puts the fighter's frame on the ground at its body's cell, inside the cell's footprint and
## clear of the feet of whoever stands there (shrunk, never scaled off the pixel grid).
func _lay(body: Dictionary, source: Sprite3D, shown: ShaderMaterial) -> void:
	var dir: Vector2i = body["dir"]
	var image := _lying(source, dir, shown)
	if image == null:
		return
	var cell: Vector2i = body["cell"]
	var area := footprint(cell)
	var feet := feet_rect(cell)
	var texel := _stage.texel_m()
	var feet_point: Vector3 = _ground.call(cell)
	var depth := texel * _squash(feet_point)
	# Room beside the feet: the cell's width, and the depth on the side the body lies on.
	var margin := _data.num("body", "margin_m")
	var behind := dir != Vector2i.DOWN
	var room_z := (feet.position.y - area.position.y) if behind else (area.end.y - feet.end.y)
	room_z -= margin
	var room_x := area.size.x - PAIR * margin
	var fit := minf(
		1.0, minf(room_x / (image.get_width() * texel), room_z / (image.get_height() * depth))
	)
	if fit < 1.0:
		var size := Vector2i(
			maxi(1, floori(image.get_width() * fit)), maxi(1, floori(image.get_height() * fit))
		)
		image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var sprite := _sprite(_data.num("lift", "body_m"))
	sprite.texture = ImageTexture.create_from_image(image)
	var half_z := image.get_height() * depth / PAIR
	var centre_z := feet.end.y + margin + half_z
	if behind:
		centre_z = feet.position.y - margin - half_z
	sprite.position = Vector3(area.get_center().x, sprite.position.y, centre_z)
	sprite.scale = Vector3(1.0, 1.0, _squash(sprite.position))
	_nodes[_key(body)] = sprite


## The fighter's frame as it stands, cropped to its pixels and turned flat; null with no frame.
func _lying(source: Sprite3D, dir: Vector2i, shown: ShaderMaterial) -> Image:
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
	var cropped := frame.get_region(used)
	# The frame stands head up (away from the camera); turn the head to the way it lies.
	if dir == Vector2i.RIGHT:
		cropped.rotate_90(CLOCKWISE)
	elif dir == Vector2i.LEFT:
		cropped.rotate_90(COUNTERCLOCKWISE)
	elif dir == Vector2i.DOWN:
		cropped.rotate_180()
	return cropped


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
