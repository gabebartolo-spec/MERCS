extends RefCounted
## Real input for the UI suites (mercs-proof-evidence: a real click, not a handler call): key
## taps and mouse clicks sent through Input.parse_input_event, as a player's would arrive,
## each followed by a frame so the game reacts. Static: the suite passes its SceneTree.

const LAYOUT_FRAMES := 3


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
