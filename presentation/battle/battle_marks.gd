class_name BattleMarks
extends RefCounted
## What a fight leaves on the field (director ruling Q-G, "at every hit": a splat on every wound,
## drying over the fight; bodies stay where they fell until it ends). Presentation only: it reads
## the sim's "hit" and "down" events (Battle.apply's output) and decides nothing, so the same
## events always draw the same field. A splat lies at the hit's logged cell, a body at the cell
## its fighter fell on. Each splat is a small clustered pixel blot in the core palette's blood
## ramp (no speckle, no gradient), its shape seeded by the hit's number and damage; it goes
## fresh red, then dark red, then dried brown as actions pass, and never vanishes early. A body
## is the fighter's own frame laid flat, head away from the blow, until the art agent's fall
## frames replace it (placeholder). Numbers: data/balance/battle_view.json.

const DATA_PATH := "res://data/balance/battle_view.json"
const EVENT_HIT := "hit"
const EVENT_DOWN := "down"
const FRESH := 0
const WET := 1
const DRY := 2
## Palette references (ramp:step) of each age: the blot's fill, then its shadow edge.
const AGE_REFS := [["blood:1", "blood:0"], ["blood:0", "blood:2"], ["blood:2", "soot:2"]]
const NOWHERE := Vector2i(-1, -1)
const NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PAIR := 2
const FILL_NEIGHBOURS := 3
const GROW_TRIES := 20000

## One entry per wound, in order: {index, cell, unit, by, damage, born, jitter, level}.
var splats: Array[Dictionary] = []
## One entry per fighter who fell, in order: {unit, cell, by, dir, born}.
var bodies: Array[Dictionary] = []

var _data: StageData = StageData.load_file(DATA_PATH)
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


## The blot for a hit: same hit number, damage and age, same pixels.
func splat_image(index: int, damage: int, level: int) -> Image:
	var half := int(_data.num("splat", "half_px"))
	var rng := RandomNumberGenerator.new()
	rng.seed = index * int(_data.num("splat", "seed_mul")) + damage
	var area := mini(
		(
			int(_data.num("splat", "base_area_px"))
			+ damage * int(_data.num("splat", "area_per_damage_px"))
		),
		int(_data.num("splat", "max_area_px"))
	)
	var pixels := _grow(rng, Vector2i.ZERO, area, half)
	var satellites := 0
	var from := int(_data.num("splat", "satellite_from_damage"))
	if from > 0:
		satellites = mini(damage / from, PAIR)
	for i: int in satellites:
		var ring := _data.num("splat", "satellite_ring_px")
		var at := Vector2i((Vector2.from_angle(rng.randf() * TAU) * ring).round())
		var clump := _grow(rng, at, int(_data.num("splat", "satellite_area_px")), half)
		for cell: Variant in clump:
			pixels[cell] = true
	pixels = _tidy(pixels, half)
	pixels = _drop_small(pixels, int(_data.num("splat", "satellite_min_px")))
	return _paint(pixels, half, level)


## The blot's pixels as a picture: fill, with a shadow edge along its lower and right sides.
func _paint(pixels: Dictionary, half: int, level: int) -> Image:
	var refs: Array = AGE_REFS[clampi(level, FRESH, DRY)]
	var fill := Palette.colour(str(refs[0]))
	var shade := Palette.colour(str(refs[1]))
	var size := half * PAIR + 1
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Palette.CLEAR)
	var edge := {}
	for key: Variant in pixels:
		var cell: Vector2i = key
		if not pixels.has(cell + Vector2i.RIGHT) or not pixels.has(cell + Vector2i.DOWN):
			edge[cell] = true
	for key: Variant in pixels:
		var cell: Vector2i = key
		# A shadow pixel with no shadow neighbour is a stray dot: it takes the fill instead.
		var in_shadow := edge.has(cell) and _count(edge, cell) > 0
		image.set_pixelv(cell + Vector2i(half, half), shade if in_shadow else fill)
	return image


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
			splat_image(Merc.whole(splat["index"]), Merc.whole(splat["damage"]), FRESH)
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
	var dir := 1
	if attacker != null and cell.x < attacker.cell.x:
		dir = -1
	var body := {"unit": unit_id, "cell": cell, "by": by, "dir": dir, "born": _actions}
	bodies.append(body)
	return body


## Puts the fighter's frame on the ground at its body's cell.
func _lay(body: Dictionary, source: Sprite3D, shown: ShaderMaterial) -> void:
	var image := _lying(source, Merc.whole(body["dir"]), shown)
	if image == null:
		return
	var sprite := _sprite(_data.num("lift", "body_m"))
	sprite.texture = ImageTexture.create_from_image(image)
	var cell: Vector2i = body["cell"]
	_place(sprite, cell, Vector2i.ZERO)
	_nodes[_key(body)] = sprite


## The fighter's frame as it stands, cropped to its pixels and turned flat; null with no frame.
func _lying(source: Sprite3D, dir: int, shown: ShaderMaterial) -> Image:
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
	cropped.rotate_90(CLOCKWISE if dir > 0 else COUNTERCLOCKWISE)
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
			splat_image(Merc.whole(splat["index"]), Merc.whole(splat["damage"]), level)
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


func _place(sprite: Sprite3D, cell: Vector2i, jitter: Vector2i) -> void:
	var centre: Vector3 = _ground.call(cell)
	var texel := _stage.texel_m()
	sprite.position = Vector3(
		centre.x + jitter.x * texel, sprite.position.y, centre.z + jitter.y * texel
	)


## Pixels (a set of offsets from the picture's centre) grown from one start by random edge
## steps to roughly this many, kept inside the picture.
func _grow(rng: RandomNumberGenerator, start: Vector2i, area: int, half: int) -> Dictionary:
	var pixels := {start: true}
	var order: Array[Vector2i] = [start]
	var tries := 0
	while order.size() < area and tries < GROW_TRIES:
		tries += 1
		var from := order[rng.randi_range(0, order.size() - 1)]
		var next := from + NEIGHBOURS[rng.randi_range(0, NEIGHBOURS.size() - 1)]
		if absi(next.x) <= half and absi(next.y) <= half and not pixels.has(next):
			pixels[next] = true
			order.append(next)
	return pixels


## Fills pinholes (an empty pixel with three filled sides), then trims one-pixel spurs.
func _tidy(pixels: Dictionary, half: int) -> Dictionary:
	var filled := pixels.duplicate()
	for y: int in range(-half, half + 1):
		for x: int in range(-half, half + 1):
			var here := Vector2i(x, y)
			if not pixels.has(here) and _count(pixels, here) >= FILL_NEIGHBOURS:
				filled[here] = true
	var out := {}
	for key: Variant in filled:
		var pixel: Vector2i = key
		if _count(filled, pixel) >= PAIR:
			out[pixel] = true
	return out


func _count(pixels: Dictionary, cell: Vector2i) -> int:
	var n := 0
	for step: Vector2i in NEIGHBOURS:
		if pixels.has(cell + step):
			n += 1
	return n


## Drops every connected clump smaller than this many pixels (no orphan specks).
func _drop_small(pixels: Dictionary, smallest: int) -> Dictionary:
	var out := {}
	var seen := {}
	for start: Variant in pixels:
		if seen.has(start):
			continue
		var clump: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			clump.append(cell)
			for step: Vector2i in NEIGHBOURS:
				var next := cell + step
				if pixels.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		if clump.size() >= smallest:
			for cell: Vector2i in clump:
				out[cell] = true
	return out
