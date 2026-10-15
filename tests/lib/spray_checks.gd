extends RefCounted
## The blood spray's on-screen checks for the impact suite (P6c, lead QC round 1): drops leave
## the struck figure's picture at torso height, burst out past its silhouette along the blow
## within a few frames, 10 to 16 per hit in mixed sizes, and are never drawn over the body (over
## its picture they lie behind its plane, so its pixels hide them). Static; the suite passes the
## live stage and spray before the fight is cleared.

const FPS := 60.0
const CLEAR_FRAMES := 3
const PEAK_T := 0.25
const TORSO_TOLERANCE := 0.08
const DEPTH_EPS_M := 0.001
const SIDEWAYS := 0.5


## Every hit threw between lo and hi drops.
static func counts_ok(drops: Array[Dictionary], lo: int, hi: int) -> bool:
	var per: Dictionary = {}
	for drop: Dictionary in drops:
		per[drop["splat"]] = Merc.whole(per.get(drop["splat"], 0)) + 1
	for count: Variant in per.values():
		if Merc.whole(count) < lo or Merc.whole(count) > hi:
			return false
	return not per.is_empty()


## The drops of every hit with a blow fly out in more than one direction (a spray, not a line).
static func spread_ok(drops: Array[Dictionary]) -> bool:
	var ways: Dictionary = {}
	for drop: Dictionary in drops:
		var blow: Vector3 = drop["blow"]
		if blow == Vector3.ZERO:
			continue
		var seen: Dictionary = ways.get(drop["splat"], {})
		seen[var_to_str(drop["out"])] = true
		ways[drop["splat"]] = seen
	for seen: Variant in ways.values():
		var each: Dictionary = seen
		if each.size() < 2:
			return false
	return not ways.is_empty()


## The drop sizes thrown, smallest first.
static func sizes(drops: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for drop: Dictionary in drops:
		var size := Merc.whole(drop["size"])
		if not out.has(size):
			out.append(size)
	out.sort()
	return out


## Each drop leaves inside the struck figure's picture, at the torso share of its height.
static func torso_ok(spray: BattleSpray, stage: StreetStage, share: float) -> bool:
	var camera := stage.camera()
	var seen := 0
	for drop: Dictionary in spray.drops:
		var shape := spray.shape_of(drop)
		if shape.is_empty():
			continue
		var rect: Rect2 = shape["rect"]
		var start: Vector3 = drop["start"]
		var at := camera.unproject_position(start)
		var height := (rect.end.y - at.y) / rect.size.y
		if not rect.grow(1.0).has_point(at) or absf(height - share) > TORSO_TOLERANCE:
			return false
		seen += 1
	return seen > 0


## [drops clear of the figure's picture by their third frame of flight, drops with a blow that
## shows mostly sideways on screen, of those how many are clear].
static func clear_counts(spray: BattleSpray, stage: StreetStage) -> Array[int]:
	var camera := stage.camera()
	var out: Array[int] = [0, 0, 0]
	for drop: Dictionary in spray.drops:
		var shape := spray.shape_of(drop)
		var away: Vector3 = drop["out"]
		if shape.is_empty() or away == Vector3.ZERO:
			continue
		var flight: float = drop["flight_s"]
		var t := CLEAR_FRAMES / (FPS * flight)
		var rect: Rect2 = shape["rect"]
		var clear := not rect.has_point(camera.unproject_position(spray.point_at(drop, t)))
		out[0] += 1 if clear else 0
		if absf(_screen(camera, shape, away).x) >= SIDEWAYS:
			out[1] += 1
			out[2] += 1 if clear else 0
	return out


## Each drop's burst goes the way the blow goes on screen (away from the attacker).
static func along_blow_ok(spray: BattleSpray, stage: StreetStage) -> bool:
	var camera := stage.camera()
	var seen := 0
	for drop: Dictionary in spray.drops:
		var shape := spray.shape_of(drop)
		var blow: Vector3 = drop["blow"]
		if shape.is_empty() or blow == Vector3.ZERO:
			continue
		var start: Vector3 = drop["start"]
		var land: Vector3 = drop["land"]
		var line := start.lerp(land, PEAK_T * PEAK_T)
		var burst := (
			camera.unproject_position(spray.point_at(drop, PEAK_T))
			- camera.unproject_position(line)
		)
		if burst.dot(_screen(camera, shape, blow)) <= 0.0:
			return false
		seen += 1
	return seen > 0


## Every drop in the air that is over its struck figure's picture lies behind the figure's plane.
static func behind_ok(spray: BattleSpray, stage: StreetStage) -> bool:
	var camera := stage.camera()
	for number: int in spray.drops.size():
		var node := spray.node_of_drop(number)
		if node == null or not node.visible:
			continue
		var drop: Dictionary = spray.drops[number]
		var shape := spray.shape_of(drop)
		if shape.is_empty():
			continue
		var rect: Rect2 = shape["rect"]
		if not rect.has_point(camera.unproject_position(node.position)):
			continue
		var floor_m: float = shape["depth"] + shape["behind_m"]
		if BattleDropAim.depth(camera, node.position) < floor_m - DEPTH_EPS_M:
			return false
	return true


## A world direction at the figure's feet as a unit step on screen.
static func _screen(camera: Camera3D, shape: Dictionary, way: Vector3) -> Vector2:
	var feet: Vector3 = shape["feet"]
	var step := camera.unproject_position(feet + way) - camera.unproject_position(feet)
	return step.normalized()
