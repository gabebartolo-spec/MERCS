class_name BattleEnd
extends RefCounted
## How a fight ends (vision pillar 4, D-066), checked after every action, company side first.
## First any newly fallen leader's side holds or breaks (BattleMorale.captain_check). Then a
## side with no one standing loses; a side that gives way (its morale below its rout line, or
## every fighter it has standing broken) while the other still has fighters up ends the fight
## with its fighters alive. Who runs and who surrenders (Phase 4, director ruling Q-C
## "cornered or leader down"): with its leader down, every one of them surrenders; otherwise
## each runs if he has a way out and surrenders if he is cornered: pinned by at least
## "surrender" "pinned_by" standing foes beside him, or with no walk to a free edge of the
## field. Position decides, so the player can engineer captures. Logs "rout" (who ran) and
## "surrender" (who was taken) with who is still standing, then "end". No rolls.

const EVENT_ROUT := "rout"
const EVENT_SURRENDER := "surrender"
const EVENT_END := "end"


static func check(
	battle: Battle, morale: BattleMorale, grid: BattleGrid, events: Array[Dictionary]
) -> void:
	events.append_array(morale.captain_check(battle.units))
	for side: int in BattleUnit.SIDES:
		var up := standing(battle.units, side)
		var other := other_side(side)
		if up == 0:
			battle.winner = other
		elif gives_way(battle.units, morale, side) and standing(battle.units, other) > 0:
			battle.winner = other
			_give_way(battle, morale, grid, side, events)
		if battle.is_over():
			events.append({"type": EVENT_END, "winner": battle.winner})
			return


## True when the side's morale broke or every fighter it has standing has broken.
static func gives_way(units: Array[BattleUnit], morale: BattleMorale, side: int) -> bool:
	return morale.breaks(side) or morale.all_broken(units, side)


## True when the fighter cannot run: pinned by enough standing foes beside him, or no walk
## (8-way, never through a fighter or past a foe's reach) leads to a free edge cell.
static func cornered(
	fighter: BattleUnit, units: Array[BattleUnit], grid: BattleGrid, pinned_by: int
) -> bool:
	var beside := 0
	for other: BattleUnit in units:
		if other.side != fighter.side and not other.down:
			if BattleGrid.adjacent(fighter.cell, other.cell):
				beside += 1
	if pinned_by > 0 and beside >= pinned_by:
		return true
	if _on_edge(fighter.cell, grid.size):
		return false
	var seen := {fighter.cell: true}
	var frontier: Array[Vector2i] = [fighter.cell]
	while not frontier.is_empty():
		var from: Vector2i = frontier.pop_front()
		for step: Vector2i in grid.steps_from(from, units):
			if seen.has(step):
				continue
			seen[step] = true
			if grid.engaged(step, fighter.side, units):
				continue
			if _on_edge(step, grid.size):
				return false
			frontier.append(step)
	return true


## How many of the side's fighters are not down.
static func standing(units: Array[BattleUnit], side: int) -> int:
	var count := 0
	for fighter: BattleUnit in units:
		if fighter.side == side and not fighter.down:
			count += 1
	return count


static func other_side(side: int) -> int:
	return BattleUnit.ENEMY if side == BattleUnit.COMPANY else BattleUnit.COMPANY


## The side gives way: each standing fighter runs or is taken; sets routed, surrendered,
## fled and prisoners on the battle and logs "rout" and "surrender".
static func _give_way(
	battle: Battle, morale: BattleMorale, grid: BattleGrid, side: int, events: Array[Dictionary]
) -> void:
	var up := standing(battle.units, side)
	var leaderless := morale.leader_down(side)
	var pinned_by := morale.pinned_by()
	battle.routed = side
	for fighter: BattleUnit in battle.units:
		if fighter.side != side or fighter.down:
			continue
		if leaderless or cornered(fighter, battle.units, grid, pinned_by):
			battle.prisoners.append(fighter.id)
		else:
			battle.fled.append(fighter.id)
	if not battle.fled.is_empty():
		events.append(
			{"type": EVENT_ROUT, "side": side, "standing": up, "fled": battle.fled.duplicate()}
		)
	if not battle.prisoners.is_empty():
		battle.surrendered = side
		events.append(
			{
				"type": EVENT_SURRENDER,
				"side": side,
				"standing": up,
				"prisoners": battle.prisoners.duplicate(),
				"leader_down": leaderless
			}
		)


static func _on_edge(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == size.x - 1 or cell.y == size.y - 1
