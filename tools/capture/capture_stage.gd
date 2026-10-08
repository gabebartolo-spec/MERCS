extends SceneTree
## Captures the Phase 1 grey-box stage (docs/specs/phase1_visual_proof.md §2) to PNG.
## Runs with a window, not --headless: the dummy renderer draws nothing. Loads
## presentation/world/street_stage.tscn, sets its exports from the arguments, steps the
## walker with a fixed delta so every capture is reproducible, renders, and saves the
## full frame plus a 2× crop of a 160 × 90 region centred on the sprite (sizes from
## data/balance/stage.json "capture"). --sequence saves a clip as numbered frames.
##
##   APPDATA=<scratch> godot --path . --resolution 1920x1080 \
##     --script tools/capture/capture_stage.gd -- --pitch=35 --height=48 \
##     --mode=crisp|whole --out=docs/audits/stage_samples/crisp_p35_h48.png \
##     [--walk=10] [--sequence=3] [--fps=30] [--sheet=<manifest.json> [--facing=S]]
##
## --walk is the seconds the sprite has walked before the still (default puts it beside
## the well); --sequence=<seconds> writes <out stem>/frame_000.png … at --fps instead.
## --sheet shows one facing of a factory sheet (mercs.sheet/1) instead of the capsule;
## render it at the same pitch and height as the capture.

const STAGE_SCENE := "res://presentation/world/street_stage.tscn"
const STAGE_DATA := "res://data/balance/stage.json"
const DEFAULT_OUT := "docs/audits/stage_samples/capture.png"
const DEFAULT_WALK_SECONDS := 10.0
const SEQUENCE_FRAME_PATTERN := "frame_%03d.png"

var _args: Dictionary = {}
var _capture: Dictionary = {}
var _stage: StreetStage = null


func _initialize() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_capture = _capture_knobs()
	if DisplayServer.get_name() == "headless":
		push_warning("capture_stage.gd needs a window: run without --headless")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_stage = _spawn_stage()
	root.add_child(_stage)
	await process_frame
	if (
		_args.has("sheet")
		and not _stage.use_sheet(_arg_string("sheet", ""), _arg_string("facing", "S"))
	):
		push_error("could not show sheet %s" % _arg_string("sheet", ""))
		quit(1)
		return
	_stage.step(_arg_float("walk", DEFAULT_WALK_SECONDS))
	for _frame: int in int(_knob("settle_frames")):
		await process_frame
	var out := _arg_string("out", DEFAULT_OUT)
	var ok := true
	if _args.has("sequence"):
		ok = await _save_sequence(out)
	else:
		ok = await _save_still(out)
	quit(0 if ok else 1)


func _spawn_stage() -> StreetStage:
	var packed: PackedScene = load(STAGE_SCENE) as PackedScene
	var stage: StreetStage = packed.instantiate() as StreetStage
	stage.auto_walk = false
	stage.pitch_degrees = _arg_float("pitch", stage.pitch_degrees)
	stage.sprite_height_px = int(_arg_float("height", stage.sprite_height_px))
	var mode := _arg_string("mode", "crisp")
	if mode == "whole":
		stage.pixel_mode = StreetStage.PixelMode.WHOLE_SCREEN
	else:
		stage.pixel_mode = StreetStage.PixelMode.CRISP
	return stage


func _save_still(out: String) -> bool:
	var frame := await _render_frame()
	if frame == null:
		return false
	var ok := _save(frame, out)
	var crop := _crop_around_merc(frame)
	ok = _save(crop, out.get_basename() + "_crop.png") and ok
	return ok


func _save_sequence(out: String) -> bool:
	var fps := _arg_float("fps", _knob("clip_fps"))
	var seconds := _arg_float("sequence", _knob("clip_seconds"))
	var dir := out.get_basename()
	DirAccess.make_dir_recursive_absolute(dir)
	var count := int(roundf(seconds * fps))
	for index: int in count:
		var frame := await _render_frame()
		if frame == null or not _save(frame, dir.path_join(SEQUENCE_FRAME_PATTERN % index)):
			return false
		_stage.step(1.0 / fps)
	print("saved %d frames to %s" % [count, dir])
	return true


func _render_frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		push_error("no viewport texture: is the run headless?")
		return null
	return texture.get_image()


## The crop region sits on the sprite's window position; in whole-screen mode the
## sprite's viewport pixels scale up by the integer scale.
func _crop_around_merc(frame: Image) -> Image:
	var size := Vector2i(int(_knob("crop_width_px")), int(_knob("crop_height_px")))
	var centre: Vector2 = _stage.merc_centre_screen_position()
	if _stage.pixel_mode == StreetStage.PixelMode.WHOLE_SCREEN:
		centre *= _integer_scale()
	var origin := Vector2i(centre.round()) - size / 2
	origin = origin.clamp(Vector2i.ZERO, Vector2i(frame.get_width(), frame.get_height()) - size)
	var crop := frame.get_region(Rect2i(origin, size))
	var scale := int(_knob("crop_scale"))
	crop.resize(size.x * scale, size.y * scale, Image.INTERPOLATE_NEAREST)
	return crop


func _integer_scale() -> float:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var pixel: Dictionary = data.get("pixel", {})
		var value: Variant = pixel.get("integer_scale", 1.0)
		if value is float or value is int:
			return value
	return 1.0


func _save(image: Image, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := image.save_png(path)
	if error != OK:
		push_error("could not save %s: %s" % [path, error_string(error)])
		return false
	print("saved %s (%d x %d)" % [path, image.get_width(), image.get_height()])
	return true


func _capture_knobs() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGE_DATA))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var capture: Variant = data.get("capture", {})
		if capture is Dictionary:
			return capture
	push_warning("stage data missing or invalid: %s" % STAGE_DATA)
	return {}


func _knob(key: String) -> float:
	var value: Variant = _capture.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0


## "--key=value" and "--flag" after the "--" separator become {key: value|""}.
func _parse_args(raw: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {}
	for arg: String in raw:
		if not arg.begins_with("--"):
			continue
		var body := arg.trim_prefix("--")
		var key := body.get_slice("=", 0)
		parsed[key] = body.substr(key.length() + 1) if body.contains("=") else ""
	return parsed


func _arg_string(key: String, fallback: String) -> String:
	var value: String = _args.get(key, fallback)
	return fallback if value.is_empty() else value


func _arg_float(key: String, fallback: float) -> float:
	var value: String = _args.get(key, "")
	return float(value) if value.is_valid_float() else fallback
