extends RefCounted
## What the battle view suite measures on the bodies lying on the field (P6b): where their pixels

const SCALE_TOLERANCE := 0.06


## How many solid pixels of the body lie outside its own cell's footprint (0 = inside), with a
## pixel's width of slack for the turned edge.
static func outside(marks: BattleMarks, body: Dictionary, texel: float) -> int:
	var cell: Vector2i = body["cell"]
	var area := marks.footprint(cell).grow(texel)
	var n := 0
	for point: Vector2 in marks.body_points(body):
		n += 0 if area.has_point(point) else 1
	return n


## Whether no solid pixel of the body lies on a living fighter's feet. A fighter who stands on
## the body's own cell (the sim lets the living step onto the dead) stands over it: the body is
## flat on the ground, so it can only draw below the feet's pixels, never over them.
static func clear_of_feet(marks: BattleMarks, body: Dictionary, battle: Battle) -> bool:
	var points := marks.body_points(body)
	for fighter: BattleUnit in battle.units:
		if fighter.down or fighter.cell == body["cell"]:
			continue
		var feet := marks.feet_rect(fighter.cell)
		for point: Vector2 in points:
			if feet.has_point(point):
				return false
	return true


## Whether the body keeps the figure's full size: same pixel size as a figure's texel, and as
## many solid pixels as the standing frame had (a turn by nearest sampling keeps the count within
## a few per cent), and its longer side is not shorter than the frame's.
static func full_size(marks: BattleMarks, body: Dictionary, texel: float) -> bool:
	var node := marks.node_of(body)
	if node == null:
		return false
	var had := float(Merc.whole(body.get("source_solid", 0)))
	var now := float(Merc.whole(body.get("solid", 0)))
	return (
		is_equal_approx(node.pixel_size, texel)
		and had > 0.0
		and absf(now - had) <= had * SCALE_TOLERANCE
		and BattleBody.solid(node.texture.get_image()) == int(now)
	)


## Whether the death pool is under the torso: its picture has a solid pixel at the torso point,
## and it lies beneath the body and above the ground.
static func pool_under_torso(marks: BattleMarks, body: Dictionary) -> bool:
	var pool := marks.pool_of(body)
	var node := marks.node_of(body)
	if pool == null or node == null or pool.texture == null:
		return false
	var torso: Vector2 = body["torso"]
	var image := pool.texture.get_image()
	var depth := pool.pixel_size * pool.scale.z
	var x := floori((torso.x - pool.position.x) / pool.pixel_size + image.get_width() / 2.0)
	var y := floori((torso.y - pool.position.z) / depth + image.get_height() / 2.0)
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return false
	return image.get_pixel(x, y).a > 0.0 and pool.position.y < node.position.y
