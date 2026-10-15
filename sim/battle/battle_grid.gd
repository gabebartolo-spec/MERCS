class_name BattleGrid
extends RefCounted
## The battle's square grid (D-066: square grid, eight facings): its size, the blocked cells
## (walls and props), 8-way steps that never cut a blocked or occupied corner, and the one
## terrain feature of Phase 2, blocking: a fighter who steps next to a standing opponent is
## engaged and his walk ends there, so a front-liner standing in front of a back-liner stops
## attackers from walking past him to reach the one behind (the shieldman literally stands in
## front of the archer; vision "Combat"). Every standing fighter blocks; there are no numbers.
## The straight line between two cells (line_clear, Phase 4 P1c) is what a shot or a spear's
## thrust needs: walls and props stop it, fighters never do (director 2026-10-16).

var size := Vector2i.ONE
var blocked := {}


## field: {"size": Vector2i, "blocked": {Vector2i: true}}.
func setup(field: Dictionary) -> void:
	var read_size: Variant = field.get("size", Vector2i.ONE)
	size = read_size if read_size is Vector2i else Vector2i.ONE
	var read_blocked: Variant = field.get("blocked", {})
	blocked = read_blocked if read_blocked is Dictionary else {}


## Cells the fighter may walk to within limit steps: a walk ends on the first cell next to a
## standing opponent (engaged), though a fighter who starts engaged may step away.
func reachable(fighter: BattleUnit, units: Array[BattleUnit], limit: int) -> Dictionary:
	var reach := {fighter.cell: 0}
	var frontier: Array[Vector2i] = [fighter.cell]
	while not frontier.is_empty():
		var from: Vector2i = frontier.pop_front()
		var steps: int = reach[from]
		if steps >= limit or (from != fighter.cell and engaged(from, fighter.side, units)):
			continue
		for step: Vector2i in steps_from(from, units):
			if not reach.has(step):
				reach[step] = steps + 1
				frontier.append(step)
	reach.erase(fighter.cell)
	return reach


## Steps from every cell the goal can be walked to, around walls and props (8-way, never
## cutting a blocked corner; fighters ignored, they move): {cell: steps}, the goal at 0. The
## AI's way round a wall (BattleAi), where a straight walk would stall behind it.
func distances(goal: Vector2i) -> Dictionary:
	var nobody: Array[BattleUnit] = []
	var out := {goal: 0}
	var frontier: Array[Vector2i] = [goal]
	while not frontier.is_empty():
		var from: Vector2i = frontier.pop_front()
		for step: Vector2i in steps_from(from, nobody):
			if not out.has(step):
				out[step] = out[from] + 1
				frontier.append(step)
	return out


## True when a standing fighter of the other side stands next to the cell.
func engaged(cell: Vector2i, side: int, units: Array[BattleUnit]) -> bool:
	for other: BattleUnit in units:
		if other.side != side and not other.down and adjacent(cell, other.cell):
			return true
	return false


## Free neighbouring cells, 8-way, never cutting a blocked or occupied corner.
func steps_from(from: Vector2i, units: Array[BattleUnit]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step: Vector2i in BattleUnit.FACINGS:
		if not is_free(from + step, units):
			continue
		if (
			step.x != 0
			and step.y != 0
			and not (
				is_free(from + Vector2i(step.x, 0), units)
				and is_free(from + Vector2i(0, step.y), units)
			)
		):
			continue
		out.append(from + step)
	return out


func is_free(cell: Vector2i, units: Array[BattleUnit]) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y or blocked.has(cell):
		return false
	for fighter: BattleUnit in units:
		if fighter.cell == cell and not fighter.down:
			return false
	return true


## True when the straight line from a to b crosses no wall or prop and stays on the field (a
## bow's shot, a spear's thrust; Phase 4 P1c, director 2026-10-16: walls stop arrows and
## spears, no fighter does). The line steps one cell along the longer axis at a time and takes
## the nearest cell on the other; where it runs exactly between two cells it may take either
## that is open. A diagonal step between two walls (both side cells walled, as steps_from holds
## a man) stops it too: a corner gap or a staircase wall (lead's ruling on review of #139).
## The line reads the same both ways. The end cells are not checked.
func line_clear(a: Vector2i, b: Vector2i) -> bool:
	var steps := gap(a, b)
	var here: Array[Vector2i] = [a]
	for i: int in range(1, steps + 1):
		var next: Array[Vector2i] = []
		for cell: Vector2i in _line_cells(a, b, i):
			if (i == steps or _open(cell)) and _passes(here, cell):
				next.append(cell)
		if next.is_empty():
			return false
		here = next
	return true


## The cells the line from a to b may stand on at step i (one, or two when exactly halfway).
func _line_cells(a: Vector2i, b: Vector2i, i: int) -> Array[Vector2i]:
	var steps := gap(a, b)
	var out: Array[Vector2i] = []
	for x: int in _crossed(a.x, b.x - a.x, i, steps):
		for y: int in _crossed(a.y, b.y - a.y, i, steps):
			out.append(Vector2i(x, y))
	return out


## True when the line can step to cell from one of the cells it may stand on: a straight step,
## or a diagonal one with at least one side cell open.
func _passes(from_cells: Array[Vector2i], cell: Vector2i) -> bool:
	for from: Vector2i in from_cells:
		var step := cell - from
		if step.x == 0 or step.y == 0:
			return true
		if _open(from + Vector2i(step.x, 0)) or _open(from + Vector2i(0, step.y)):
			return true
	return false


func _open(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < size.x
		and cell.y < size.y
		and not blocked.has(cell)
	)


## Where a line along one axis stands at step i of steps: the nearest whole cell, or both
## neighbours when it is exactly halfway (whole-number arithmetic, no rounding rule to drift).
static func _crossed(start: int, delta: int, i: int, steps: int) -> Array[int]:
	var scaled := delta * i
	var rest := posmod(scaled, steps)
	var low := start + floori(float(scaled - rest) / float(steps))
	if rest + rest < steps:
		return [low]
	if rest + rest > steps:
		return [low + 1]
	return [low, low + 1]


static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


## Chebyshev distance: king moves on the 8-way grid.
static func gap(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The facing (one of the eight) that looks from a towards b; keeps fallback when a == b.
static func toward(a: Vector2i, b: Vector2i, fallback: Vector2i) -> Vector2i:
	var facing := (b - a).sign()
	return facing if facing != Vector2i.ZERO else fallback


## Faces the nearest standing opponent (ties by id); keeps the facing when there is none.
static func face_nearest(fighter: BattleUnit, units: Array[BattleUnit]) -> void:
	var nearest: BattleUnit = null
	for other: BattleUnit in units:
		if other.side == fighter.side or other.down:
			continue
		var steps := gap(fighter.cell, other.cell)
		var best := gap(fighter.cell, nearest.cell) if nearest != null else steps
		if nearest == null or steps < best or (steps == best and other.id < nearest.id):
			nearest = other
	if nearest != null:
		fighter.facing = toward(fighter.cell, nearest.cell, fighter.facing)
