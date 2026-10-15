class_name BattleSplat
extends RefCounted
## The picture of one blood splat (P6b): a small clustered blot grown from the hit's number and
## damage, in the blood ramp's two reds only (darker is older). Same hit, damage and age give the
## same pixels. Numbers: data/balance/battle_view.json "splat".

const FRESH := 0
const WET := 1
const DRY := 2
## Palette references (ramp:step) of each age: the blot's fill, then its shadow edge. Only the
## blood ramp's two reds (the ramp's brown is not blood).
const AGE_REFS := [["blood:1", "blood:0"], ["blood:0", "blood:0"], ["blood:0", "blood:0"]]
const PAIR := 2
const FILL_NEIGHBOURS := 3
const GROW_TRIES := 20000
const NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _data: StageData = StageData.load_file("res://data/balance/battle_view.json")


## The blot for a hit: same hit number, damage and age, same pixels.
func image(index: int, damage: int, level: int) -> Image:
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
