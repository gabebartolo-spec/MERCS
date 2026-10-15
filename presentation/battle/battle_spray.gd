class_name BattleSpray
extends RefCounted
## Blood thrown by a blow (director, 2026-10-16; P6c). Every hit throws 10 to 16 flat drops that
## face the camera, from the hit point at the struck figure's torso height: within a few frames
## they burst out past its silhouette along the blow as it shows on screen (away from the
## attacker) and up, then fall onto the splat BattleMarks already laid for that hit, each on one
## of the splat's own pixels (from its side down the blow), and the splat shows when the first
## drop lands, then stays (the stain). Over the figure's picture a drop is drawn just behind it,
## so it never paints over the body (BattleDropAim).
## Presentation only: it reads the sim's "hit" events and the marks, decides nothing, and moves
## only on the visual seconds it is handed (BattleImpact.step), so a hit-stop holds it in the air.
## Its variation (how many drops, their size, shade, delay and where on the splat each lands) is
## seeded from the hit itself (round, hit number, attacker and target) on its own generator:
## no clock, no unseeded roll, no sim stream. Drops are squares of 1 to 3 logical pixels in the
## blood ramp's two reds at the figures' pixel size, no gradient. Numbers: battle_view.json "spray".

const DATA_PATH := "res://data/balance/battle_view.json"
## The two blood reds a drop may be (the ramp's brown is not blood).
const DROP_REFS: Array[String] = ["blood:1", "blood:0"]
const PAIR := 2
const HALF := 0.5

## One entry per drop thrown this fight, in order: {splat (its index in marks), unit, pixel (of the
## splat it lands on), start, land (world points), blow (the ground step attacker to target), out
## (the blow on screen), up (the screen's up),
## reach (its share of the burst), size (pixels), ref (palette), delay_s, flight_s, launched_s,
## landed}.
var drops: Array[Dictionary] = []

var _data: StageData = StageData.load_file(DATA_PATH)
var _stage: StreetStage = null
var _ground := Callable()
## Drop number -> its node while in the air.
var _nodes: Dictionary = {}
## Splat index -> its node, hidden until its first drop lands.
var _waiting: Dictionary = {}
## Splat index -> the struck figure as the camera saw it at the blow (BattleDropAim.figure).
var _shapes: Dictionary = {}
var _sprites: Dictionary = {}
var _age_s := 0.0


## Draws on this stage; ground turns a battle cell into the world point at its centre. Without a
## stage the drops are still worked out (the model the tests read) but no node is made.
func begin(stage: StreetStage, ground: Callable) -> void:
	_stage = stage
	_ground = ground


## Throws the drops for every hit in one action's events onto the splats marks has just laid
## (marks.record adds one splat per hit, in order, so the last ones are this action's).
func launch(
	events: Array[Dictionary], battle: Battle, marks: BattleMarks, sprites: Dictionary = {}
) -> void:
	_sprites = sprites
	var hits: Array[Dictionary] = []
	for event: Dictionary in events:
		if str(event.get("type", "")) == BattleMarks.EVENT_HIT:
			hits.append(event)
	var first := marks.splats.size() - hits.size()
	if first < 0:
		return
	for i: int in hits.size():
		_throw(hits[i], marks.splats[first + i], battle, marks)


## Moves every drop in the air on by these visual seconds; a drop that reaches its spot goes,
## and shows its splat if it was the first.
func tick(delta: float) -> void:
	_age_s += delta
	for number: Variant in _nodes.keys():
		var drop: Dictionary = drops[Merc.whole(number)]
		var sprite: Sprite3D = _nodes[number]
		var t := progress(drop, _age_s)
		if t >= 1.0:
			_land(Merc.whole(number), drop)
			continue
		sprite.visible = t > 0.0
		sprite.position = drawn_at(drop, t)
		sprite.pixel_size = _texel_at(sprite.position)


## How far along its flight a drop is at this visual time: 0 before it leaves, 1 when it lands.
static func progress(drop: Dictionary, age_s: float) -> float:
	var flight: float = drop["flight_s"]
	var left: float = drop["launched_s"] + drop["delay_s"]
	if flight <= 0.0:
		return 1.0
	return clampf((age_s - left) / flight, 0.0, 1.0)


## Where a drop is at t of its flight: it bursts out along the blow and up at once (the burst
## peaks a quarter of the way through), then falls, faster and faster, exactly onto its spot at
## t = 1.
func point_at(drop: Dictionary, t: float) -> Vector3:
	var start: Vector3 = drop["start"]
	var land: Vector3 = drop["land"]
	var out: Vector3 = drop["out"]
	var up: Vector3 = drop["up"]
	var reach: float = drop["reach"]
	var burst := sin(PI * sqrt(clampf(t, 0.0, 1.0))) * reach
	return (
		start.lerp(land, t * t)
		+ out * _data.num("spray", "push_m") * burst
		+ up * _data.num("spray", "arc_m") * burst
	)


## Where a drop in the air is drawn at t: its path's point, pushed back along the camera's ray
## behind the struck figure while it is over the figure's picture (same spot on screen).
func drawn_at(drop: Dictionary, t: float) -> Vector3:
	var point := point_at(drop, t)
	var shape := shape_of(drop)
	if _stage == null or shape.is_empty():
		return point
	return BattleDropAim.drawn_at(_stage, shape, point, float(Merc.whole(drop["size"])))


## The struck figure as the camera saw it when this drop's blow landed ({} without a stage).
func shape_of(drop: Dictionary) -> Dictionary:
	var shape: Dictionary = _shapes.get(drop["splat"], {})
	return shape


## Drops still in the air.
func flying() -> int:
	return _nodes.size()


## The node drawing a drop (by its number in drops) while it is in the air, else null.
func node_of_drop(number: int) -> Sprite3D:
	var found: Sprite3D = _nodes.get(number, null)
	return found


## Takes every drop out of the air and shows any splat still waiting for one.
func clear() -> void:
	for node: Variant in _nodes.values():
		var sprite: Sprite3D = node
		sprite.queue_free()
	_nodes.clear()
	for node: Variant in _waiting.values():
		var sprite: Sprite3D = node
		if is_instance_valid(sprite):
			sprite.visible = true
	_waiting.clear()
	_shapes.clear()
	drops.clear()
	_age_s = 0.0


## The world point under one pixel of a ground mark's picture (a face-up quad: picture x along
## world x, picture rows along world z).
static func pixel_point(sprite: Sprite3D, pixel: Vector2i) -> Vector3:
	var size := Vector2(sprite.texture.get_size())
	var across := (pixel.x + HALF - size.x / PAIR) * sprite.pixel_size
	var down := (pixel.y + HALF - size.y / PAIR) * sprite.pixel_size * sprite.scale.z
	return sprite.position + Vector3(across, 0.0, down)


## The seeded generator of one hit: same round, hit number, attacker and target, same drops.
static func rng_for(event: Dictionary, round_number: int, index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var key := "%d|%d|%s|%s" % [round_number, index, event.get("unit", ""), event.get("target", "")]
	rng.seed = key.hash()
	return rng


func _throw(event: Dictionary, splat: Dictionary, battle: Battle, marks: BattleMarks) -> void:
	var index := Merc.whole(splat["index"])
	var rng := rng_for(event, battle.round_number, index)
	var count := _count(event)
	var blow := _blow(event, battle)
	var picture := marks.splat_image(index, Merc.whole(splat["damage"]), BattleSplat.FRESH)
	var pixels := _down_blow(_solid_pixels(picture), blow)
	var node := marks.node_of(splat)
	if pixels.is_empty() or count <= 0:
		return
	var aim := _aim(event, index, blow)
	var cone := deg_to_rad(_data.num("spray", "cone_deg"))
	for i: int in count:
		var pixel: Vector2i = pixels[rng.randi_range(0, pixels.size() - 1)]
		var drop := {
			"splat": index,
			"unit": str(event.get("target", "")),
			"pixel": pixel,
			"land": _land_point(node, splat, pixel),
			"out": _turned(aim, rng.randf_range(-cone, cone)),
			"reach": rng.randf_range(_data.num("spray", "reach_min"), 1.0),
			"size": rng.randi_range(1, int(_data.num("spray", "drop_px_max"))),
			"ref": DROP_REFS[rng.randi_range(0, DROP_REFS.size() - 1)],
			"delay_s": rng.randf_range(0.0, _data.num("spray", "delay_spread_s")),
			"flight_s": _data.num("spray", "flight_s"),
			"launched_s": _age_s,
			"landed": false,
		}
		drop.merge(aim)
		drops.append(drop)
		if _stage != null:
			_nodes[drops.size() - 1] = _sprite(drop)
	if node != null and not _waiting.has(index):
		node.visible = false
		_waiting[index] = node


## How many drops a hit throws: base + damage x per-damage, capped.
func _count(event: Dictionary) -> int:
	return mini(
		(
			int(_data.num("spray", "drops_base"))
			+ Merc.whole(event.get("damage", 0)) * int(_data.num("spray", "drops_per_damage"))
		),
		int(_data.num("spray", "drops_max"))
	)


## The start, the burst's direction and the screen's up for one hit's drops; with the struck
## figure on the stage they come from its picture, else from its cell on the ground.
func _aim(event: Dictionary, index: int, blow: Vector3) -> Dictionary:
	var sprite: Sprite3D = _sprites.get(str(event.get("target", "")), null)
	if _stage == null or sprite == null:
		var cell: Vector2i = event.get("cell", Vector2i.ZERO)
		var feet: Vector3 = _ground.call(cell) if _ground.is_valid() else Vector3.ZERO
		return {"start": feet, "out": blow, "up": Vector3.UP, "blow": blow}
	var shape := BattleDropAim.figure(_stage, sprite, _data.num("spray", "torso_share"))
	shape["behind_m"] = _data.num("spray", "behind_m")
	_shapes[index] = shape
	return {
		"start": shape["start"],
		"out": BattleDropAim.out_along(_stage, shape, blow),
		"up": shape["up"],
		"right": shape["right"],
		"blow": blow,
	}


## The burst's direction turned by this angle within the screen (a spray, not a line); as it
## is without a picture plane (no stage).
func _turned(aim: Dictionary, angle: float) -> Vector3:
	var out: Vector3 = aim["out"]
	if not aim.has("right") or out == Vector3.ZERO:
		return out
	var right: Vector3 = aim["right"]
	var up: Vector3 = aim["up"]
	var flat := Vector2(out.dot(right), out.dot(up)).rotated(angle)
	return (right * flat.x + up * flat.y).normalized()


## The splat's pixels on its side down the blow (the half the blood is thrown toward); all of
## them when there is no blow.
func _down_blow(pixels: Array[Vector2i], blow: Vector3) -> Array[Vector2i]:
	if blow == Vector3.ZERO or pixels.is_empty():
		return pixels
	var centre := Vector2.ZERO
	for pixel: Vector2i in pixels:
		centre += Vector2(pixel)
	centre /= pixels.size()
	var way := Vector2(blow.x, blow.z)
	var out: Array[Vector2i] = []
	for pixel: Vector2i in pixels:
		if (Vector2(pixel) - centre).dot(way) >= 0.0:
			out.append(pixel)
	return out if not out.is_empty() else pixels


func _land(number: int, drop: Dictionary) -> void:
	drop["landed"] = true
	var sprite: Sprite3D = _nodes[number]
	_nodes.erase(number)
	sprite.queue_free()
	var index := Merc.whole(drop["splat"])
	if _waiting.has(index):
		var node: Sprite3D = _waiting[index]
		_waiting.erase(index)
		if is_instance_valid(node):
			node.visible = true


## The blow's direction on the ground: from the attacker's cell to the target's, one step long.
func _blow(event: Dictionary, battle: Battle) -> Vector3:
	var attacker := battle.unit(str(event.get("unit", "")))
	var cell: Vector2i = event.get("cell", Vector2i.ZERO)
	if attacker == null or attacker.cell == cell or not _ground.is_valid():
		return Vector3.ZERO
	var from: Vector3 = _ground.call(attacker.cell)
	var to: Vector3 = _ground.call(cell)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return flat.normalized()


func _land_point(node: Sprite3D, splat: Dictionary, pixel: Vector2i) -> Vector3:
	if node != null:
		return pixel_point(node, pixel)
	var cell: Vector2i = splat["cell"]
	return _ground.call(cell) if _ground.is_valid() else Vector3.ZERO


func _solid_pixels(image: Image) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > HALF:
				out.append(Vector2i(x, y))
	return out


## A drop: a square of 1 to 3 logical pixels in one blood red, always facing the camera, at
## the figures' pixel size.
func _sprite(drop: Dictionary) -> Sprite3D:
	var size := Merc.whole(drop["size"])
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Palette.colour(str(drop["ref"])))
	var sprite := Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = drawn_at(drop, 0.0)
	sprite.visible = false
	_stage.world().add_child(sprite)
	sprite.pixel_size = _texel_at(sprite.position)
	return sprite


## A logical pixel's size at a world point, as the stage sizes its figures there (one texel is one
## logical pixel wherever a figure stands; StreetStage depth scale).
func _texel_at(point: Vector3) -> float:
	var texel := _stage.texel_m()
	var rail := _stage.rail_distance_m()
	if _stage.depth_scale != StreetStage.DepthScale.CONSTANT or rail <= 0.0:
		return texel
	var camera := _stage.camera()
	var forward: Vector3 = -camera.global_transform.basis.z
	return texel * (point - camera.global_position).dot(forward) / rail
