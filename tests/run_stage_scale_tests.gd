extends "res://tests/run_stage_tests.gd"
## Stage scale suite (docs/specs/phase1_visual_proof.md §2-§3, tools/pipeline/camera_rig.json):
## one sprite texel lands on one logical pixel, square, at the look-at point for every
## sample-set-1 pitch and height, so a factory sheet is drawn at integer scale with no
## shimmer; the stage texel matches the camera rig; the sprite stands with its pivot on
## the ground; and a factory sheet frame loads by facing.
## Seeded by design: the stage has no randomness; the walker is stepped with a fixed delta.
##   godot --headless --path . --script tests/run_stage_scale_tests.gd

const CAMERA_RIG := "res://tools/pipeline/camera_rig.json"
const GOOD_SHEET := "res://tests/fixtures/pipeline/sheets/good/average_m_body_rest.json"
const TEXEL_TOLERANCE_PX := 0.01
const SAMPLE_PITCHES: Array[float] = [30.0, 35.0, 40.0]
const SAMPLE_HEIGHTS: Array[int] = [40, 48, 56]
## Feet positions nearer to and further from the camera than the look-at point.
const DEPTH_PROBES: Array[Vector3] = [Vector3(-3.0, 0.0, 6.0), Vector3(3.0, 0.0, -6.0)]
const PERSPECTIVE_GROWTH := 1.05


func suite_name() -> String:
	return "Stage scale"


func run_checks() -> void:
	_stage_data = _load_stage_data()
	await _check_texel_scale()
	await _check_rig_contract()
	await _check_feet_on_ground()
	await _check_sheet()
	await _check_depth_scale()


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _json_num(block: Dictionary, key: String) -> float:
	var value: Variant = block.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0


## Every sample-set-1 cell (pitch 30/35/40 × height 40/48/56): at the look-at point one
## texel spans one logical pixel across and up, so the factory's pixels are neither
## stretched nor squashed (square, integer scale, no shimmer).
func _check_texel_scale() -> void:
	var worst := Vector2.ZERO
	var worst_label: Array[String] = ["", ""]
	for pitch: float in SAMPLE_PITCHES:
		for height_px: int in SAMPLE_HEIGHTS:
			var error := ((await _texel_span_px(pitch, height_px)) - Vector2.ONE).abs()
			var label := "%s°/%d px" % [pitch, height_px]
			if error.x >= worst.x:
				worst.x = error.x
				worst_label[0] = label
			if error.y >= worst.y:
				worst.y = error.y
				worst_label[1] = label
	check(
		worst.y < TEXEL_TOLERANCE_PX,
		(
			"one texel spans one logical pixel vertically in all nine cells; worst %s is off by %s px"
			% [worst_label[1], worst.y]
		)
	)
	check(
		worst.x < TEXEL_TOLERANCE_PX,
		(
			"one texel spans one logical pixel horizontally in all nine cells; worst %s is off by %s px"
			% [worst_label[0], worst.x]
		)
	)


## Logical pixels covered by one sprite texel at the look-at point, (across, up).
func _texel_span_px(pitch: float, height_px: int) -> Vector2:
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.WHOLE_SCREEN, height_px, pitch)
	var camera: Camera3D = stage.camera()
	var merc: Sprite3D = stage.merc()
	var anchor: Vector3 = (stage.get_node("%CameraRail") as Node3D).global_position
	var right: Vector3 = camera.global_transform.basis.x
	var origin: Vector2 = camera.unproject_position(anchor)
	var across: Vector2 = camera.unproject_position(anchor + right * merc.pixel_size * merc.scale.x)
	var up: Vector2 = camera.unproject_position(
		anchor + camera.global_transform.basis.y * merc.pixel_size * merc.scale.y
	)
	await _despawn(stage)
	return Vector2(across.distance_to(origin), up.distance_to(origin))


## The stage and the sprite factory agree: at the camera rig's pitch and figure height,
## one stage texel is 1 / px_per_m of tools/pipeline/camera_rig.json.
func _check_rig_contract() -> void:
	var rig := _load_json(CAMERA_RIG)
	var pitch := _json_num(rig, "pitch_deg")
	var height_px := int(_json_num(rig, "char_height_px"))
	var reference_m := _json_num(rig, "reference_height_m")
	var px_per_m := float(height_px) / (reference_m * cos(deg_to_rad(pitch)))
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, height_px, pitch)
	var texel: float = stage.merc().pixel_size
	check(
		(
			height_px > 0
			and is_equal_approx(reference_m, _knob("sprite", "merc_height_m"))
			and absf(texel * px_per_m - 1.0) < EPSILON
		),
		(
			"at the camera rig's %s° and %d px the stage texel is 1 / %s m, not %s m"
			% [pitch, height_px, px_per_m, texel]
		)
	)
	await _despawn(stage)


## The sprite's lowest world point, after its transform (scale included).
## The pivot texel sits on the sprite's origin (Sprite3D draws y up from offset.y) and the
## origin is on the ground. Camera-facing sprites report an oversized AABB, so the anchor is
## checked through the offset rather than the bounds.
func _pivot_on_ground(merc: Sprite3D, frame: Vector2, pivot: Vector2) -> bool:
	var expected := Vector2(-pivot.x, pivot.y - frame.y)
	return (
		not merc.centered
		and merc.offset.is_equal_approx(expected)
		and absf(merc.global_position.y) < SNAP_TOLERANCE_M
	)


func _check_feet_on_ground() -> void:
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	stage.step(FIXED_DELTA)
	var merc := stage.merc()
	var size := merc.region_rect.size
	check(
		_pivot_on_ground(merc, size, Vector2(size.x / HALF, size.y)),
		"the capsule's bottom-centre texel is its origin, on the ground (offset %s)" % merc.offset
	)
	await _despawn(stage)


## A factory sheet (tools/pipeline, mercs.sheet/1) shows one frame per facing with its
## pivot on the ground; an unknown facing is refused.
func _check_sheet() -> void:
	var sheet := _load_json(GOOD_SHEET)
	var frame := Vector2(_json_num(sheet, "frame_w"), _json_num(sheet, "frame_h"))
	var pivot: Dictionary = sheet.get("pivot", {})
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.CRISP, 48, 35.0)
	var merc: Sprite3D = stage.merc()
	var can_load := stage.has_method("use_sheet")
	check(can_load, "the stage can show a factory sheet frame (use_sheet)")
	var loaded := false
	if can_load:
		loaded = stage.call("use_sheet", GOOD_SHEET, "S")
	check(
		loaded and merc.region_enabled and merc.region_rect.size == frame,
		"facing S of the good sheet shows one %s frame, not %s" % [frame, merc.region_rect.size]
	)
	stage.step(FIXED_DELTA)
	var pivot_px := Vector2(_json_num(pivot, "x"), _json_num(pivot, "y"))
	check(
		loaded and _pivot_on_ground(merc, frame, pivot_px),
		(
			"the sheet's pivot %s is the sprite's origin, on the ground (offset %s)"
			% [pivot_px, merc.offset]
		)
	)
	var accepted := true
	if can_load:
		accepted = stage.call("use_sheet", GOOD_SHEET, "Q")
	check(not accepted, "use_sheet refuses an unknown facing")
	await _despawn(stage)


## Logical pixels one texel covers at the merc's own depth (measured at the look-at
## height above its feet), (across, up).
func _span_at_merc(stage: StreetStage) -> Vector2:
	var camera: Camera3D = stage.camera()
	var merc: Sprite3D = stage.merc()
	var anchor: Vector3 = merc.global_position
	var right: Vector3 = camera.global_transform.basis.x
	var origin: Vector2 = camera.unproject_position(anchor)
	var across: Vector2 = camera.unproject_position(anchor + right * merc.pixel_size * merc.scale.x)
	var up: Vector2 = camera.unproject_position(
		anchor + camera.global_transform.basis.y * merc.pixel_size * merc.scale.y
	)
	return Vector2(across.distance_to(origin), up.distance_to(origin))


## CONSTANT depth scale keeps one texel on one logical pixel nearer and further than the
## look-at point; PERSPECTIVE lets a nearer merc grow (the look question this exposes);
## stand_at holds the feet where it put them.
func _check_depth_scale() -> void:
	var stage: StreetStage = await _spawn(StreetStage.PixelMode.WHOLE_SCREEN, 48, 35.0)
	var worst := 0.0
	stage.depth_scale = StreetStage.DepthScale.CONSTANT
	for probe: Vector3 in DEPTH_PROBES:
		stage.stand_at(probe)
		var error := (_span_at_merc(stage) - Vector2.ONE).abs()
		worst = maxf(worst, maxf(error.x, error.y))
	check(
		worst < TEXEL_TOLERANCE_PX,
		(
			"CONSTANT depth scale keeps a texel within %s px of one pixel off the look-at depth, worst %s"
			% [TEXEL_TOLERANCE_PX, worst]
		)
	)
	stage.depth_scale = StreetStage.DepthScale.PERSPECTIVE
	stage.stand_at(DEPTH_PROBES[0])
	var near := _span_at_merc(stage)
	check(
		near.x > PERSPECTIVE_GROWTH,
		(
			"PERSPECTIVE depth scale lets a merc 6 m nearer grow past %s px per texel, not %s"
			% [PERSPECTIVE_GROWTH, near.x]
		)
	)
	stage.step(FIXED_DELTA)
	var moved: Vector3 = stage.merc().global_position
	check(
		(
			absf(moved.x - DEPTH_PROBES[0].x) < TEXEL_TOLERANCE_PX
			and absf(moved.z - DEPTH_PROBES[0].z) < TEXEL_TOLERANCE_PX
		),
		"stand_at holds the feet at %s after a step, not %s" % [DEPTH_PROBES[0], moved]
	)
	await _despawn(stage)
