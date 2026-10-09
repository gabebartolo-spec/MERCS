class_name GridWalker
extends RefCounted
## One figure walking the street grid, Pokémon-style: it moves cell to cell (8 directions,
## no corner cutting past a blocked cell), either while a direction is held or along an
## A* path to a clicked cell. Pure and deterministic: the same calls in the same order give
## the same positions. Cells are GridMap cells on the ground (x, z); a cell's centre is
## (x + 0.5, z + 0.5) in metres. Presentation only: walking the hub decides no outcome.

## Screen-direction facing names, as in tools/pipeline/camera_rig.json "facings": +z is
## toward the viewer (S), +x is screen right (E).
const FACING_BY_STEP := {
	Vector2i(0, 1): &"S",
	Vector2i(1, 1): &"SE",
	Vector2i(1, 0): &"E",
	Vector2i(1, -1): &"NE",
	Vector2i(0, -1): &"N",
	Vector2i(-1, -1): &"NW",
	Vector2i(-1, 0): &"W",
	Vector2i(-1, 1): &"SW",
}
const CENTRE := Vector2(0.5, 0.5)

var cell := Vector2i.ZERO
var facing: String = &"S"
var speed_m_s := 1.0

var _grid := AStarGrid2D.new()
var _position := Vector2.ZERO
var _next := Vector2i.ZERO
var _moving := false
var _held := Vector2i.ZERO
var _path: Array[Vector2i] = []


## region: every cell the walker may ever stand on lies inside it; walkable: those cells.
func setup(region: Rect2i, walkable: Dictionary, start: Vector2i, speed: float) -> void:
	_grid.region = region
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	_grid.fill_solid_region(region, true)
	for key: Variant in walkable:
		if key is Vector2i:
			var free: Vector2i = key
			if region.has_point(free):
				_grid.set_point_solid(free, false)
	speed_m_s = speed
	teleport(start)


func is_walkable(at: Vector2i) -> bool:
	return _grid.is_in_boundsv(at) and not _grid.is_point_solid(at)


## Stands on a cell at once (doors, spawning); any walk in progress is dropped.
func teleport(to: Vector2i) -> void:
	cell = to
	_next = to
	_position = Vector2(to) + CENTRE
	_moving = false
	_path.clear()


## The direction held this frame (keys); ZERO when none. Overrides a clicked path.
func hold(direction: Vector2i) -> void:
	_held = direction.clamp(-Vector2i.ONE, Vector2i.ONE)
	if _held != Vector2i.ZERO:
		_path.clear()


## Walks to a cell along the shortest path; returns false (keeping still) when unreachable.
func walk_to(target: Vector2i) -> bool:
	if not is_walkable(target):
		return false
	var from := _next if _moving else cell
	var route := _grid.get_id_path(from, target)
	if route.is_empty():
		return false
	_path.clear()
	for step: Vector2i in route.slice(1):
		_path.append(step)
	return true


## True while walking, including the instant between two cells of a held direction, so a
## walk clip never flickers to idle at a cell boundary.
func is_moving() -> bool:
	return _moving or not _path.is_empty() or (_held != Vector2i.ZERO and _can_step(_held))


## Feet position in metres on the ground plane (x, z).
func position_m() -> Vector2:
	return _position


func advance(delta: float) -> void:
	var budget := speed_m_s * delta
	while budget > 0.0:
		if not _moving and not _pick_next():
			return
		var target := Vector2(_next) + CENTRE
		var gap := _position.distance_to(target)
		if gap > budget:
			_position = _position.move_toward(target, budget)
			return
		budget -= gap
		_position = target
		cell = _next
		_moving = false


func _pick_next() -> bool:
	var step := Vector2i.ZERO
	if _held != Vector2i.ZERO:
		step = _held
	elif not _path.is_empty():
		var waypoint: Vector2i = _path.pop_front()
		step = waypoint - cell
	if step == Vector2i.ZERO:
		return false
	var name: String = FACING_BY_STEP.get(step, facing)
	facing = name
	var to := cell + step
	if not _can_step(step):
		return false
	_next = to
	_moving = true
	return true


## A step is allowed onto a free cell, and diagonally only when both side cells are free.
func _can_step(step: Vector2i) -> bool:
	if not is_walkable(cell + step):
		return false
	if step.x != 0 and step.y != 0:
		return is_walkable(cell + Vector2i(step.x, 0)) and is_walkable(cell + Vector2i(0, step.y))
	return true
