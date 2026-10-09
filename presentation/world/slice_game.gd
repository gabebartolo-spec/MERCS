class_name SliceGame
extends Node
## The art direction slice, milestone M1 (docs/specs/art_direction_slice.md §1, §3): the
## street stage made playable. One merc walks the grid by keys (WASD or arrows, diagonals
## by two keys) or by a click on the ground; the camera follows in whole logical pixels; a
## crowd walks fixed routes; T steps the time of day, R toggles rain, F1 the key help, F3
## the frame time; the door in the street leads to the one interior and back. Numbers come
## from data/balance/slice.json and stage.json, text from data/text. Presentation only:
## nothing here is random, and walking the hub decides no outcome.

const STAGE_SCENE := preload("res://presentation/world/street_stage.tscn")
const SLICE_DATA := "res://data/balance/slice.json"
## The merc sheet Art publishes (rest pose now, walk and idle clips next); without it the
## stage's grey capsule stands in.
const MERC_SHEET := "res://assets/sprites/mercs/average_m/average_m_body_rest.json"
const ROUTE_PREFIX := "route_"
const MS_PER_S := 1000.0
const DIRECTION_BY_KEY := {
	KEY_W: Vector2i(0, -1),
	KEY_UP: Vector2i(0, -1),
	KEY_S: Vector2i(0, 1),
	KEY_DOWN: Vector2i(0, 1),
	KEY_A: Vector2i(-1, 0),
	KEY_LEFT: Vector2i(-1, 0),
	KEY_D: Vector2i(1, 0),
	KEY_RIGHT: Vector2i(1, 0),
}

## Read by tests and the frame-time readout; the merc the player walks.
var player := GridWalker.new()
var crowd: Array[GridWalker] = []

var _stage: StreetStage = null
var _data: StageData = null
var _routes: Array[Array] = []
var _route_step: Array[int] = []
var _frames := {}
var _shown := {}
var _held := {}
var _door := Vector2i.ZERO
var _street_return := Vector2i.ZERO
var _interior_entry := Vector2i.ZERO
var _interior_exit := Vector2i.ZERO
var _frame_ms := 0.0
var _help: Label = null
var _frame_label: Label = null


func _ready() -> void:
	_data = StageData.load_file(SLICE_DATA)
	_stage = STAGE_SCENE.instantiate() as StreetStage
	_stage.auto_walk = false
	var logical := Vector2i(
		int(_data.num("pixel", "logical_width_px")), int(_data.num("pixel", "logical_height_px"))
	)
	_stage.logical_size_px = logical
	_stage.integer_scale = maxi(1, int(get_viewport().get_visible_rect().size.y) / logical.y)
	_stage.sprite_height_px = int(_data.num("pixel", "sprite_height_px"))
	add_child(_stage)
	_setup_walkers()
	_load_frames()
	_build_hud()
	_sync()


func stage() -> StreetStage:
	return _stage


func _process(delta: float) -> void:
	step(delta)
	var smoothing := _data.num("hud", "frame_time_smoothing")
	_frame_ms = lerpf(_frame_ms, delta * MS_PER_S, smoothing)
	if _frame_label.visible:
		_frame_label.text = Text.t("slice.frame_time", {"ms": "%.1f" % _frame_ms})


## Advances every walker by delta seconds and redraws. Deterministic for the same inputs.
func step(delta: float) -> void:
	player.hold(_held_direction())
	player.advance(delta)
	_use_doors()
	for i: int in crowd.size():
		var walker := crowd[i]
		if not walker.is_moving():
			_next_waypoint(i)
		walker.advance(delta)
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and not key.echo:
		_on_key(key)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var cell := ground_cell_at(click.position)
		if cell.has(&"cell"):
			var target: Vector2i = cell[&"cell"]
			player.walk_to(target)


## The street cell under a window position, as {&"cell": Vector2i}, or {} off the ground.
func ground_cell_at(window_position: Vector2) -> Dictionary:
	var camera := _stage.camera()
	var screen := window_position
	if _stage.pixel_mode == StreetStage.PixelMode.WHOLE_SCREEN:
		screen = PixelScreen.to_logical(window_position, _stage.screen_scale())
	var origin := camera.project_ray_origin(screen)
	var normal := camera.project_ray_normal(screen)
	if normal.y >= 0.0:
		return {}
	var ground := origin + normal * (-origin.y / normal.y)
	return {&"cell": Vector2i(floori(ground.x), floori(ground.z))}


func _on_key(key: InputEventKey) -> void:
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if DIRECTION_BY_KEY.has(code):
		_held[code] = key.pressed
	elif not key.pressed:
		return
	elif code == KEY_T:
		var next := (int(_stage.time_of_day) + 1) % StageLighting.TimeOfDay.size()
		_stage.set_conditions(next as StageLighting.TimeOfDay, _stage.rain)
		_shown.clear()
	elif code == KEY_R:
		_stage.set_conditions(_stage.time_of_day, not _stage.rain)
		_shown.clear()
	elif code == KEY_F1:
		_help.visible = not _help.visible
	elif code == KEY_F3:
		_frame_label.visible = not _frame_label.visible


func _held_direction() -> Vector2i:
	var direction := Vector2i.ZERO
	for code: Variant in _held:
		if _held[code]:
			var step_dir: Vector2i = DIRECTION_BY_KEY[code]
			direction += step_dir
	return direction


func _setup_walkers() -> void:
	var stage_data := _stage.stage_data
	var walkable := StreetGrid.walkable_cells(_stage.street(), stage_data)
	var region := Rect2i()
	for key: Variant in walkable:
		var at: Vector2i = key
		region = Rect2i(at, Vector2i.ONE) if region.size == Vector2i.ZERO else region.expand(at)
	region = region.grow_individual(0, 0, 1, 1)
	var door := stage_data.cell("street", "door_cell")
	_door = Vector2i(door.x, door.z)
	_street_return = _door + Vector2i(0, 1)
	var entry := stage_data.cell("interior", "entry_cell")
	var exit := stage_data.cell("interior", "exit_cell")
	_interior_entry = Vector2i(entry.x, entry.z)
	_interior_exit = Vector2i(exit.x, exit.z)
	var start := _data.floats("player", "start_cell_xz")
	var speed := _data.num("player", "walk_speed_m_s")
	player.setup(region, walkable, Vector2i(int(start[0]), int(start[1])), speed)
	_setup_crowd(region, walkable)


## One crowd merc per "route_<n>" in slice.json, starting on its first waypoint.
func _setup_crowd(region: Rect2i, walkable: Dictionary) -> void:
	var index := 1
	while not _data.floats("crowd", ROUTE_PREFIX + str(index)).is_empty():
		var points := _data.floats("crowd", ROUTE_PREFIX + str(index))
		var route: Array[Vector2i] = []
		for i: int in range(0, points.size() - 1, 2):
			route.append(Vector2i(int(points[i]), int(points[i + 1])))
		var walker := GridWalker.new()
		walker.setup(region, walkable, route[0], _data.num("crowd", "walk_speed_m_s"))
		crowd.append(walker)
		_routes.append(route)
		_route_step.append(0)
		_stage.add_merc(_ground(walker))
		index += 1


func _next_waypoint(i: int) -> void:
	var route: Array = _routes[i]
	if route.size() < 2:
		return
	_route_step[i] = (_route_step[i] + 1) % route.size()
	var target: Vector2i = route[_route_step[i]]
	crowd[i].walk_to(target)


## Stepping onto the street door enters the interior; onto the interior's exit, back out.
func _use_doors() -> void:
	if player.is_moving():
		return
	if player.cell == _door:
		player.teleport(_interior_entry)
	elif player.cell == _interior_exit:
		player.teleport(_street_return)


func _load_frames() -> void:
	if not FileAccess.file_exists(MERC_SHEET):
		return
	for facing: String in GridWalker.FACING_BY_STEP.values():
		var frame := SheetFrame.from_manifest(MERC_SHEET, facing)
		if frame != null:
			_frames[facing] = frame
	if not _frames.is_empty():
		_stage.use_sheet(MERC_SHEET, player.facing)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_help = Label.new()
	_help.text = Text.t("slice.help")
	_help.position = Vector2.ONE * _stage.screen_scale() * 2.0
	layer.add_child(_help)
	_frame_label = Label.new()
	_frame_label.visible = false
	_frame_label.position = _help.position + Vector2(0.0, _help.get_minimum_size().y)
	layer.add_child(_frame_label)


## Places every merc and the camera, and shows each merc's current facing.
func _sync() -> void:
	_stage.focus_on(_ground(player))
	_stage.stand_at(_ground(player))
	_face(_stage.merc(), player)
	var extras := _stage.extra_mercs()
	for i: int in crowd.size():
		_stage.move_extra(i, _ground(crowd[i]))
		_face(extras[i], crowd[i])


func _face(sprite: Sprite3D, walker: GridWalker) -> void:
	if _frames.is_empty() or _shown.get(sprite) == walker.facing:
		return
	var frame: SheetFrame = _frames.get(walker.facing, null)
	_stage.show_frame_on(sprite, frame)
	_shown[sprite] = walker.facing


func _ground(walker: GridWalker) -> Vector3:
	var at := walker.position_m()
	return Vector3(at.x, 0.0, at.y)
