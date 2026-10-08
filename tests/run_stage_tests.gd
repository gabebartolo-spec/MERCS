extends "res://tests/lib/runner.gd"
## Stage suite (docs/specs/phase1_visual_proof.md §2): the grey-box capture stage loads
## with its street, light, camera and sprite as the spec and data/balance/stage.json say;
## the camera pitch export moves the camera; the sprite's pixel_size follows its height;
## both pixel modes instantiate (WHOLE_SCREEN through a 640 × 360 SubViewport scaled 3×
## with nearest filtering, sprite snapped to its pixel grid); and the walk loop completes.
## The scale contract (texel = logical pixel, sheets) is the stage_scale suite.
## Seeded by design: the stage has no randomness; the walker is stepped with a fixed delta.
##   godot --headless --path . --script tests/run_stage_tests.gd

const STAGE_SCENE := "res://presentation/world/street_stage.tscn"
const STAGE_DATA := "res://data/balance/stage.json"
const FIXED_DELTA := 1.0 / 60.0
const EPSILON := 0.001
const PITCH_PROBE := 40.0
const HEIGHT_PROBE := 56
const HALF := 2.0
const SNAP_SAMPLES := 40
## How far CRISP's snap to a 3 px window grid may move the feet: half a cell's diagonal
## at the test pitch is about 0.02 m, so this bounds position checks, not the snap itself.
const SNAP_TOLERANCE_M := 0.03
## A handful of fixed steps; one step can sit inside a single 3 px snap cell.
const MOVE_PROBE_STEPS := 10
## Odd deltas, none a multiple of the others, so the walker lands between pixels.
const ODD_DELTAS: Array[float] = [0.0137, 0.0291, 0.0053, 0.0419]

var _stage_data: Dictionary = {}


func suite_name() -> String:
	return "Stage"


func run_checks() -> void:
	_stage_data = _load_stage_data()
	check(not _stage_data.is_empty(), "%s parses as a JSON object" % STAGE_DATA)
	await _check_scene_loads()
	await _check_camera_pitch()
	await _check_sprite_pixel_size()
	await _check_pixel_modes()
	await _check_path_loop()
	await _check_lighting()


## A headless --script window is 64 × 64; CRISP snaps to the window's pixel grid, so give
## it the real window size (logical size × integer scale, project.godot's 1920 × 1080).
func _size_window() -> void:
	var scale := int(_knob("pixel", "integer_scale"))
	root.size = Vector2i(
		int(_knob("pixel", "logical_width_px")) * scale,
		int(_knob("pixel", "logical_height_px")) * scale
	)


func _load_stage_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA))
	if parsed is Dictionary:
		return parsed
	return {}


func _knob(section: String, key: String) -> float:
	var block: Dictionary = _stage_data.get(section, {})
	var value: Variant = block.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0


func _knob_list(section: String, key: String) -> Array:
	var block: Dictionary = _stage_data.get(section, {})
	var value: Variant = block.get(key, [])
	if value is Array:
		return value
	return []


## Instantiates the stage with the given exports and waits one frame so _ready ran.
## Depth scale is PERSPECTIVE so the texel measured at the look-at point is the reference
## texel wherever the walker stands; CONSTANT is checked on its own in the scale suite.
func _spawn(mode: StreetStage.PixelMode, height_px: int, pitch: float) -> StreetStage:
	_size_window()
	var packed: PackedScene = load(STAGE_SCENE) as PackedScene
	var stage: StreetStage = packed.instantiate() as StreetStage
	stage.pixel_mode = mode
	stage.depth_scale = StreetStage.DepthScale.PERSPECTIVE
	stage.lit_sprites = false
	stage.sprite_height_px = height_px
	stage.pitch_degrees = pitch
	stage.auto_walk = false
	root.add_child(stage)
	await process_frame
	return stage


func _despawn(stage: StreetStage) -> void:
	stage.queue_free()
	await process_frame


func _check_scene_loads() -> void:
	var packed: PackedScene = load(STAGE_SCENE) as PackedScene
	check(packed != null and packed.can_instantiate(), "%s loads as a scene" % STAGE_SCENE)
	if packed == null:
		return
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	check(stage.is_inside_tree(), "the stage stays in the tree after a frame")
	var street: GridMap = stage.street()
	var ground_cells := (
		int(_knob("street", "width_m") / _knob("street", "cell_size_m"))
		* int(_knob("street", "depth_m") / _knob("street", "cell_size_m"))
	)
	var houses := _knob_list("street", "house_cells_xz").size() / 2
	var expected_cells := ground_cells + houses + 3
	check(
		street.get_used_cells().size() == expected_cells,
		(
			"the GridMap holds %d cells (ground, %d houses, well, cart, door), not %d"
			% [expected_cells, houses, street.get_used_cells().size()]
		)
	)
	check(
		street.mesh_library != null and street.mesh_library.get_item_list().size() == 5,
		"the MeshLibrary has five placeholder items"
	)
	check(houses == 6, "the data places six houses, not %d" % houses)
	_check_camera_and_light(stage)
	_check_merc_material(stage.merc())
	await _despawn(stage)


func _check_camera_and_light(stage: StreetStage) -> void:
	var camera: Camera3D = stage.camera()
	check(
		(
			camera.projection == Camera3D.PROJECTION_PERSPECTIVE
			and is_equal_approx(camera.fov, _knob("camera", "fov_degrees"))
		),
		"the camera is perspective at FOV %s, not %s" % [_knob("camera", "fov_degrees"), camera.fov]
	)
	var light: DirectionalLight3D = stage.get_node("%KeyLight") as DirectionalLight3D
	check(
		(
			is_equal_approx(light.rotation_degrees.x, -_knob("light", "elevation_degrees"))
			and light.shadow_enabled
		),
		"the key light is pitched %s° with shadows on" % _knob("light", "elevation_degrees")
	)


func _check_merc_material(merc: Sprite3D) -> void:
	check(merc.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "the sprite faces the camera")
	check(
		merc.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "the sprite filters nearest"
	)
	check(merc.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "the sprite discards alpha")
	check(not merc.shaded and not merc.double_sided, "the sprite is unshaded and single sided")
	check(
		merc.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the sprite casts no shadow"
	)


## The rail distance that puts one texel on one logical pixel at the look-at point:
## a texel spans merc_height_m × cos(pitch) / height_px of the image plane, and the
## logical viewport spans 2 × distance × tan(fov / 2) of it over logical_height_px.
func _expected_distance(pitch: float, height_px: int) -> float:
	var texel := _knob("sprite", "merc_height_m") * cos(deg_to_rad(pitch)) / float(height_px)
	var half_fov := deg_to_rad(_knob("camera", "fov_degrees")) / HALF
	return texel * _knob("pixel", "logical_height_px") / (HALF * tan(half_fov))


func _check_camera_pitch() -> void:
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	var camera: Camera3D = stage.camera()
	var rail: Node3D = stage.get_node("%CameraRail") as Node3D
	var distance := _expected_distance(35.0, 48)
	check(
		is_equal_approx(camera.rotation_degrees.x, -35.0),
		"default pitch 35 tilts the camera to -35°, not %s" % camera.rotation_degrees.x
	)
	check(
		absf(camera.position.length() - distance) < EPSILON,
		"the camera sits %s m from the rail, not %s" % [distance, camera.position.length()]
	)
	check(
		is_equal_approx(rail.position.y, _knob("camera", "look_at_height_m")),
		"the rail sits at the look-at height"
	)
	stage.pitch_degrees = PITCH_PROBE
	check(
		is_equal_approx(camera.rotation_degrees.x, -PITCH_PROBE),
		"setting pitch_degrees to %s tilts the camera to -%s°" % [PITCH_PROBE, PITCH_PROBE]
	)
	var probe_distance := _expected_distance(PITCH_PROBE, 48)
	var expected_height := probe_distance * sin(deg_to_rad(PITCH_PROBE))
	check(
		absf(camera.position.y - expected_height) < EPSILON,
		"the camera rises to distance × sin(pitch) above the rail"
	)
	check(
		absf(camera.position.length() - probe_distance) < EPSILON,
		(
			"after a pitch change the camera re-derives its distance, %s m, not %s"
			% [probe_distance, camera.position.length()]
		)
	)
	await _despawn(stage)


## pixel_size is one texel of the image plane (merc_height_m × cos(pitch) / height px);
## the sprite stretches by 1 / cos(pitch) on Y so the standing figure is merc_height_m
## tall in the world and foreshortens back to height px on screen.
func _check_sprite_pixel_size() -> void:
	var height := _knob("sprite", "merc_height_m") * cos(deg_to_rad(35.0))
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	var merc: Sprite3D = stage.merc()
	check(
		is_equal_approx(merc.pixel_size, height / 48.0),
		"48 px sprite has pixel_size %s / 48, not %s" % [height, merc.pixel_size]
	)
	check(
		(
			merc.texture != null
			and merc.texture.get_height() == 48
			and merc.texture.get_width() == int(_knob("sprite", "texture_width_px"))
		),
		"the capsule texture is %s × 48 px" % _knob("sprite", "texture_width_px")
	)
	await _despawn(stage)
	var tall: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, HEIGHT_PROBE, 35.0)
	var tall_merc: Sprite3D = tall.merc()
	check(
		is_equal_approx(tall_merc.pixel_size, height / float(HEIGHT_PROBE)),
		"%d px sprite has pixel_size %s / %d" % [HEIGHT_PROBE, height, HEIGHT_PROBE]
	)
	check(
		tall_merc.texture != null and tall_merc.texture.get_height() == HEIGHT_PROBE,
		"the capsule texture follows sprite_height_px"
	)
	await _despawn(tall)


func _check_pixel_modes() -> void:
	await _check_crisp_mode()
	await _check_whole_screen_mode()


func _check_crisp_mode() -> void:
	var crisp: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	check(
		crisp.find_child("LogicalViewport", true, false) == null, "CRISP mode adds no SubViewport"
	)
	check(crisp.world().get_parent() == crisp, "CRISP mode keeps the world under the stage root")
	check(crisp.camera().current, "CRISP mode's camera is current")
	var samples := _walk_screen_positions(crisp)
	var step := _knob("pixel", "integer_scale")
	check(
		_off_grid(samples, step).is_empty(),
		(
			"CRISP snaps the sprite to whole multiples of %s window pixels; %d of %d off, first %s"
			% [step, _off_grid(samples, step).size(), samples.size(), samples[0]]
		)
	)
	check(_distinct(samples) > 1, "the CRISP sprite still walks across the screen")
	await _despawn(crisp)


func _check_whole_screen_mode() -> void:
	var whole: StreetStage = await _spawn(StreetStage.PixelMode.WHOLE_SCREEN, 48, 35.0)
	var viewport: SubViewport = whole.find_child("LogicalViewport", true, false) as SubViewport
	check(viewport != null, "WHOLE_SCREEN mode adds a SubViewport")
	if viewport == null:
		await _despawn(whole)
		return
	var logical := Vector2i(
		int(_knob("pixel", "logical_width_px")), int(_knob("pixel", "logical_height_px"))
	)
	check(viewport.size == logical, "the SubViewport is %s, not %s" % [logical, viewport.size])
	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	check(
		(
			container != null
			and container.stretch
			and container.stretch_shrink == int(_knob("pixel", "integer_scale"))
		),
		"the SubViewport stretches to the window at 1/%s" % _knob("pixel", "integer_scale")
	)
	check(
		container != null and container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"the SubViewport is drawn with nearest filtering"
	)
	check(
		whole.world().get_parent() == viewport,
		"WHOLE_SCREEN mode moves the world under the SubViewport"
	)
	check(
		whole.camera().get_viewport() == viewport and whole.camera().current,
		"WHOLE_SCREEN mode's camera renders the SubViewport"
	)
	_check_whole_screen_snap(whole)
	await _despawn(whole)


func _check_whole_screen_snap(whole: StreetStage) -> void:
	whole.step(FIXED_DELTA)
	var screen: Vector2 = whole.merc_screen_position()
	check(
		screen.distance_to(screen.round()) < EPSILON,
		"the sprite's origin snaps to a whole SubViewport pixel, at %s" % screen
	)
	var samples := _walk_screen_positions(whole)
	check(
		_off_grid(samples, 1.0).is_empty(),
		"WHOLE_SCREEN still snaps to whole SubViewport pixels; %d off" % _off_grid(samples, 1.0).size()
	)
	check(
		not _off_grid(samples, _knob("pixel", "integer_scale")).is_empty(),
		"WHOLE_SCREEN snaps to single pixels, not to multiples of the scale"
	)


## The merc's screen position after each of SNAP_SAMPLES steps at the odd deltas.
func _walk_screen_positions(stage: StreetStage) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i: int in SNAP_SAMPLES:
		stage.step(ODD_DELTAS[i % ODD_DELTAS.size()])
		positions.append(stage.merc_screen_position())
	return positions


## The positions that are not a whole multiple of step on both axes.
func _off_grid(positions: Array[Vector2], step: float) -> Array[Vector2]:
	var off: Array[Vector2] = []
	for position: Vector2 in positions:
		var cell := position / step
		if cell.distance_to(cell.round()) > EPSILON / step:
			off.append(position)
	return off


func _distinct(positions: Array[Vector2]) -> int:
	var seen := {}
	for position: Vector2 in positions:
		seen[position.round()] = true
	return seen.size()


func _check_path_loop() -> void:
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	var seconds := stage.loop_seconds()
	check(seconds > 0.0, "the walk loop has a length and a speed")
	var merc: Sprite3D = stage.merc()
	var start: Vector3 = merc.global_position
	var points := _knob_list("sprite", "path_xz")
	check(points.size() >= 4, "the walk path has at least two points")
	if points.size() < 4:
		await _despawn(stage)
		return
	var expected_x: float = points[0]
	var expected_z: float = points[1]
	check(
		absf(start.x - expected_x) < SNAP_TOLERANCE_M and absf(start.z - expected_z) < SNAP_TOLERANCE_M,
		"the sprite starts at the first path point"
	)
	for _i: int in MOVE_PROBE_STEPS:
		stage.step(FIXED_DELTA)
	check(merc.global_position.distance_to(start) > 0.0, "a few steps move the sprite")
	var steps := int(ceilf(seconds / FIXED_DELTA)) + 1
	for _i: int in steps:
		stage.step(FIXED_DELTA)
	check(
		stage.laps_completed == 1,
		"stepping one loop's worth of time completes exactly one lap, not %d" % stage.laps_completed
	)
	var speed := _knob("sprite", "walk_speed_m_s")
	var overshoot: float = (steps + MOVE_PROBE_STEPS) * FIXED_DELTA * speed - seconds * speed
	check(
		(
			merc.global_position.distance_to(
				Vector3(expected_x, merc.global_position.y, expected_z)
			)
			<= overshoot + SNAP_TOLERANCE_M
		),
		"after one lap the sprite is back near the first path point"
	)
	await _despawn(stage)


## DAY has no torch or rain and an untinted sprite; RAIN_NIGHT adds the torch and rain
## (fixed particle seed, so captures repeat), dims the key and tints the unshaded sprite.
func _check_lighting() -> void:
	var day: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	check(
		(
			day.find_child("Torch", true, false) == null
			and day.find_child("Rain", true, false) == null
		),
		"DAY lighting adds no torch and no rain"
	)
	check(day.merc().modulate == Color.WHITE, "DAY lighting leaves the sprite untinted")
	await _despawn(day)
	var packed: PackedScene = load(STAGE_SCENE) as PackedScene
	var night: StreetStage = packed.instantiate() as StreetStage
	night.lighting = StreetStage.Lighting.RAIN_NIGHT
	night.lit_sprites = false
	night.auto_walk = false
	root.add_child(night)
	await process_frame
	var night_data: Dictionary = _stage_data.get("rain_night", {})
	var rain_data: Dictionary = night_data.get("rain", {})
	var rain: GPUParticles3D = night.find_child("Rain", true, false) as GPUParticles3D
	var seed_value: float = rain_data.get("seed", -1.0)
	check(
		(
			night.find_child("Torch", true, false) is OmniLight3D
			and rain != null
			and rain.use_fixed_seed
			and rain.seed == int(seed_value)
		),
		"RAIN_NIGHT adds the torch and rain with the data's fixed seed"
	)
	var light: DirectionalLight3D = night.get_node("%KeyLight") as DirectionalLight3D
	var light_data: Dictionary = night_data.get("light", {})
	var energy: float = light_data.get("energy", -1.0)
	check(
		is_equal_approx(light.light_energy, energy) and night.merc().modulate != Color.WHITE,
		"RAIN_NIGHT dims the key to the data's energy and tints the unshaded sprite"
	)
	await _despawn(night)
