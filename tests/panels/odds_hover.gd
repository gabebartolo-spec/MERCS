extends RefCounted
## The panels suite's hover check (Phase 4 P1c; director 2026-10-16: hover odds show a
## percentage, "Hit 40%"), run by tests/run_panels_tests.gd at 1920x1080: the slice's fight on
## the street (tests/lib/battle_view_kit.gd) played by clicks to the first company turn with a
## foe in reach; the panel offers the weapon action on exactly the foes Battle.targets names,
## and the mouse moved onto one of those buttons reads its chance from Battle.odds as a
## percentage. Seeded by design: the battle view suite's seed.

const Kit := preload("res://tests/lib/battle_view_kit.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const HOVER_SEED := 1009
const HOVER_TURNS := 400
const SETTLE := 8

var _tree: SceneTree = null


## Plays the slice's fight (BattleAi's choices for the company too, as clicks) to the first
## company turn with a foe in reach, then reads that turn's blow buttons and hovers one.
## tree: the running suite; check: its check(condition, expectation).
func run(tree: SceneTree, check: Callable) -> void:
	_tree = tree
	var mounted := Kit.mount(tree, HOVER_SEED)
	var battle := mounted.view.battle
	var read := {}
	var offered := true
	for _turn: int in HOVER_TURNS:
		if battle.is_over() or not read.is_empty():
			break
		var actor := battle.current()
		if actor.side != BattleUnit.COMPANY:
			await _tree.process_frame
			continue
		await InputKit.frames(_tree, SETTLE)
		offered = offered and _offers_reach(mounted, actor)
		if not battle.targets(actor.id).is_empty():
			read = await _read_hover(mounted, actor)
			continue
		await _play_turn(mounted, BattleAi.choose(battle, actor, Kit.sight()))
	var hint := str(read.get("hint", ""))
	var expected := str(read.get("expected", "-"))
	check.call(
		not read.is_empty() and offered,
		"the panel offers a blow on exactly the foes in reach (Battle.targets)"
	)
	check.call(
		hint == expected and hint.begins_with("Hit ") and hint.ends_with("%"),
		"a blow's hover reads its chance as a percentage: '%s' (odds say '%s')" % [hint, expected]
	)
	mounted.view.clear()
	Kit.unmount(mounted)


## True when the panel shows the actor's blow on every foe in reach and on no other.
func _offers_reach(mounted: Kit.Mounted, actor: BattleUnit) -> bool:
	var battle := mounted.view.battle
	var blow := battle.kit(actor.id)[0]
	var reach := battle.targets(actor.id)
	var right := true
	for foe: BattleUnit in battle.units:
		if foe.side != actor.side and not foe.down:
			var button := mounted.panel.button_for(blow + ":" + foe.id)
			right = right and (button != null) == reach.has(foe.id)
	return right


## Moves the mouse onto the blow button on the first foe in reach: {"hint": the button's hover
## text there, "expected": the words for Battle.odds' chance}.
func _read_hover(mounted: Kit.Mounted, actor: BattleUnit) -> Dictionary:
	var battle := mounted.view.battle
	var blow := battle.kit(actor.id)[0]
	var target := battle.targets(actor.id)[0]
	var button := mounted.panel.button_for(blow + ":" + target)
	if button == null:
		return {"hint": "no button"}
	_hover(button)
	await _tree.process_frame
	var odds := battle.odds({"type": blow, "target": target})
	return {
		"hint": button.get_tooltip(button.get_local_mouse_position()),
		"expected": Text.t("battle.odds.hit", {"chance": odds.get("chance", -1)}),
	}


func _hover(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()


func _play_turn(mounted: Kit.Mounted, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		mounted.view.click_cell(mounted.origin + to)
		await _tree.process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if action.has("target"):
		choice_id = "%s:%s" % [kind, action.get("target")]
	await InputKit.click(_tree, mounted.panel.button_for(choice_id))
