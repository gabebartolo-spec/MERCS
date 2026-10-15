extends RefCounted
## Real input for the UI suites (mercs-proof-evidence: a real click, not a handler call): key
## taps and mouse clicks sent through Input.parse_input_event, as a player's would arrive,
## each followed by a frame so the game reacts. Static: the suite passes its SceneTree.

const LAYOUT_FRAMES := 3
const FIGHT_FRAMES := 6000
const BATTLE_DATA := "res://data/balance/battle.json"


static func frames(tree: SceneTree, count: int) -> void:
	for _frame: int in count:
		await tree.process_frame


## A left click at the button's centre; a freshly shown panel lays its buttons out first.
static func click(tree: SceneTree, button: Button) -> void:
	await frames(tree, LAYOUT_FRAMES)
	if button == null or not is_instance_valid(button):
		return
	var at := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await tree.process_frame


## A fresh campaign asks Ironman or saving by hand before anything moves: a real click on the
## answer when it stands (Off by default, so a suite that is not about Ironman plays as it did).
static func pick_mode(tree: SceneTree, director: OverworldDirector, ironman: bool = false) -> void:
	var id := OverworldDirector.IRONMAN_ON if ironman else OverworldDirector.IRONMAN_OFF
	await click(tree, director.panel.button_for(id))


static func key(tree: SceneTree, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await tree.process_frame


static func tap(tree: SceneTree, code: Key) -> void:
	await key(tree, code, true)
	await key(tree, code, false)


## Plays a road fight on screen to its end: the company's turns as BattleAi picks them, through
## the panel (attacks and waits are real clicks, a move calls click_cell()), the enemy's turns
## waited out. `on_turn` (optional) is called before each company turn. True when the company won.
static func finish_fight(
	tree: SceneTree, director: OverworldDirector, on_turn: Callable = Callable()
) -> bool:
	var battle := director.view.battle
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_DATA))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var rules: Dictionary = data.get("rules", {})
	var sight: int = rules.get("sight_cells", 0)
	for _frame: int in FIGHT_FRAMES:
		if battle.is_over():
			break
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			if on_turn.is_valid():
				on_turn.call()
			await _company_turn(tree, director, BattleAi.choose(battle, actor, sight))
		else:
			await tree.process_frame
	return battle.winner == BattleUnit.COMPANY


static func _company_turn(tree: SceneTree, director: OverworldDirector, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		director.view.click_cell(director.origin + to)
		await tree.process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind != Battle.ACTION_WAIT and action.has("target"):
		# The weapon action BattleAi chose (kit(actor)[0]) or a learnt move: "<type>:<target>".
		choice_id = "%s:%s" % [kind, action.get("target")]
	await click(tree, director.panel.button_for(choice_id))
