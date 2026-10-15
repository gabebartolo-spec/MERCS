extends SceneTree
## Captures the game's five screens (overworld, storylet, hub, company, battle) to PNG at the
## window's size, for the look review. Needs a window (no --headless). Drives the game with
## real key taps and button clicks, as the story and slice suites do.
##
##   APPDATA=<scratch> godot --path . --resolution 3840x2160 --windowed --position 8000,8000 \
##     --script tools/capture/capture_screens.gd -- --out=D:/MERCS-vault/renders/<dir> --tag=after

const InputKit := preload("res://tests/lib/input_kit.gd")
const SLICE_SCENE := "res://presentation/world/slice_game.tscn"
const SETTLE_FRAMES := 12
const DEAD := "recruit_1"
const LOOP_CHOICES: Array[String] = ["continue", "hire", "accept", "continue"]

var _out := "user://screens"
var _tag := "shot"
var _game: SliceGame = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--tag="):
			_tag = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_game = (load(SLICE_SCENE) as PackedScene).instantiate() as SliceGame
	root.add_child(_game)
	await _frames(SETTLE_FRAMES)
	var story := _game.get_node("StoryDirector") as StoryDirector
	var ids: Array[String] = []
	for merc: Merc in _game.company_director().company.roster:
		ids.append(merc.id)
	story.memory.on_death(DEAD, ids, 2, Memory.KEY_COMRADE_DIED)
	await InputKit.tap(self, KEY_M)
	var map := _game.overworld_director()
	await _click(map.panel.button_for(OverworldDirector.IRONMAN_OFF))
	await _shot("overworld")
	await _click(map.panel.button_for("rest"))
	await _frames(SETTLE_FRAMES)
	await _shot("storylet")
	await _click(story.panel.button_for("attempt:mourner"))
	await _frames(SETTLE_FRAMES)
	await _click(story.panel.button_for("close"))
	await InputKit.tap(self, KEY_ESCAPE)
	await InputKit.tap(self, KEY_B)
	await _frames(SETTLE_FRAMES)
	await _shot("hub")
	await InputKit.tap(self, KEY_ESCAPE)
	await InputKit.tap(self, KEY_C)
	await _frames(SETTLE_FRAMES)
	await _shot("company")
	await InputKit.tap(self, KEY_ESCAPE)
	await _battle()
	quit(0)


func _battle() -> void:
	_game.queue_free()
	await _frames(SETTLE_FRAMES)
	_game = (load(SLICE_SCENE) as PackedScene).instantiate() as SliceGame
	root.add_child(_game)
	await _frames(SETTLE_FRAMES)
	_game.start_loop()
	var director := _game.loop_director()
	for choice: String in LOOP_CHOICES:
		await _frames(SETTLE_FRAMES)
		await _click(director.panel.button_for(choice))
	await _click(director.panel.button_for("fight"))
	await _frames(SETTLE_FRAMES)
	await _shot("battle")


func _frames(count: int) -> void:
	await InputKit.frames(self, count)


func _shot(screen: String) -> void:
	await _frames(SETTLE_FRAMES)
	var image := root.get_texture().get_image()
	var path := "%s/%s_%s.png" % [_out, screen, _tag]
	image.save_png(path)
	print("captured %s (%dx%d)" % [path, image.get_width(), image.get_height()])


## A real left click on the button's centre, scaled from canvas to window pixels (the 4K window
## stretches the 1920x1080 canvas, so InputKit.click, made for a 1080p window, would miss).
func _click(button: Button) -> void:
	await _frames(SETTLE_FRAMES)
	if button == null or not is_instance_valid(button):
		push_warning("capture: a button to click is missing")
		return
	var at := root.get_final_transform() * button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
