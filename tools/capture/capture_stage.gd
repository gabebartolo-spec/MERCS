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
##     [--lighting=day|rain_night] [--depth=perspective|constant] [--at=x,z]
##     [--frametime[=<frames>]] [--region=x,y,w,h] [--unlit] [--extra=x,z;x,z]
##
## --walk is the seconds the sprite has walked before the still (default puts it beside
## the well); --sequence=<seconds> writes <out stem>/frame_000.png … at --fps instead.
## --sheet shows one facing of a factory sheet (mercs.sheet/1) instead of the capsule;
## render it at the same pitch and height as the capture. --at holds the merc's feet at
## world x, z. --frametime steps the stage at the fixed capture delta for that many rendered
## frames (default: stage.json "capture" frametime_frames) after the settle frames, with vsync
## off, reads each frame's CPU and GPU render time from RenderingServer (the root viewport,
## plus the logical SubViewport in whole mode), writes <out stem>_frametime.json (mean / p50 /
## p95 / max ms, mode, pitch, height, resolution, Godot version, renderer, adapter) and prints
## "frame_time_ms <wall mean> over N frames" plus a cpu/gpu summary. A measurement tool, never
## a test: values vary per machine, GPU time is 0 headless, and only the director's PC counts.
## --region crops every --sequence frame to that window-pixel rectangle. --unlit draws the
## sprite unshaded (night tint) even when it has a normal map.
## --extra adds a standing merc at each x,z (same frame and rules as the walker).

const STAGE_SCENE := "res://presentation/world/street_stage.tscn"
const STAGE_DATA := "res://data/balance/stage.json"
const DEFAULT_OUT := "docs/audits/stage_samples/capture.png"
const DEFAULT_WALK_SECONDS := 10.0
const SEQUENCE_FRAME_PATTERN := "frame_%03d.png"
const USEC_PER_MS := 1000.0

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
	for spot: String in _arg_string("extra", "").split(";", false):
		var xz := spot.split_floats(",")
		if xz.size() >= 2:
			_stage.add_merc(Vector3(xz[0], 0.0, xz[1]))
	if _args.has("at"):
		var xz := _arg_string("at", "0,0").split_floats(",")
		if xz.size() >= 2:
			_stage.stand_at(Vector3(xz[0], 0.0, xz[1]))
	for _frame: int in int(_knob("settle_frames")):
		await process_frame
	var out := _arg_string("out", DEFAULT_OUT)
	if _args.has("frametime"):
		await _measure_frame_time(int(_arg_float("frametime", _knob("frametime_frames"))), out)
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
	if _args.has("unlit"):
		stage.lit_sprites = false
	if _arg_string("lighting", "day") == "rain_night":
		stage.lighting = StreetStage.Lighting.RAIN_NIGHT
	# Without --depth or --mode the stage's defaults apply (constant, whole screen).
	if _args.has("depth"):
		var constant := _arg_string("depth", "") == "constant"
		stage.depth_scale = (
			StreetStage.DepthScale.CONSTANT if constant else StreetStage.DepthScale.PERSPECTIVE
		)
	if _args.has("mode"):
		var whole := _arg_string("mode", "") == "whole"
		stage.pixel_mode = (
			StreetStage.PixelMode.WHOLE_SCREEN if whole else StreetStage.PixelMode.CRISP
		)
	return stage


func _measure_frame_time(frames: int, out: String) -> void:
	if frames <= 0:
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rids := _measured_viewports()
	var series: Dictionary = {}
	for key: String in rids:
		var rid: RID = rids[key]
		RenderingServer.viewport_set_measure_render_time(rid, true)
		series[key] = {"cpu": PackedFloat64Array(), "gpu": PackedFloat64Array()}
	await process_frame
	var delta := 1.0 / _knob("clip_fps")
	var start := Time.get_ticks_usec()
	for _frame: int in frames:
		_stage.step(delta)
		await RenderingServer.frame_post_draw
		_sample_viewports(rids, series)
	var wall_ms := float(Time.get_ticks_usec() - start) / frames / USEC_PER_MS
	_write_frame_report(out, frames, wall_ms, series)


## Viewports whose render time is read: the root, plus the logical one in whole mode.
func _measured_viewports() -> Dictionary:
	var rids: Dictionary = {"root": root.get_viewport_rid()}
	var logical := _stage.find_child("LogicalViewport", true, false) as SubViewport
	if logical != null:
		rids["logical"] = logical.get_viewport_rid()
	return rids


func _sample_viewports(rids: Dictionary, series: Dictionary) -> void:
	for key: String in rids:
		var rid: RID = rids[key]
		var entry: Dictionary = series[key]
		var cpu: PackedFloat64Array = entry["cpu"]
		var gpu: PackedFloat64Array = entry["gpu"]
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))


func _frame_report(frames: int, wall_ms: float, series: Dictionary) -> Dictionary:
	var size := root.size
	var report: Dictionary = {
		"mode": "whole" if _stage.pixel_mode == StreetStage.PixelMode.WHOLE_SCREEN else "crisp",
		"pitch_degrees": _stage.pitch_degrees,
		"height_px": _stage.sprite_height_px,
		"resolution": [size.x, size.y],
		"frames": frames,
		"wall_ms_mean": wall_ms,
		"godot": Engine.get_version_info().get("string", ""),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display_driver": DisplayServer.get_name(),
	}
	for key: String in series:
		var entry: Dictionary = series[key]
		var cpu: PackedFloat64Array = entry["cpu"]
		var gpu: PackedFloat64Array = entry["gpu"]
		report[key] = {"cpu_ms": _stats(cpu), "gpu_ms": _stats(gpu)}
	return report


func _write_frame_report(out: String, frames: int, wall_ms: float, series: Dictionary) -> void:
	var report := _frame_report(frames, wall_ms, series)
	var path := out.get_basename() + "_frametime.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	var root_stats: Dictionary = report["root"]
	var cpu_ms: Dictionary = root_stats["cpu_ms"]
	var gpu_ms: Dictionary = root_stats["gpu_ms"]
	var size: Array = report["resolution"]
	print("frame_time_ms %.3f over %d frames" % [wall_ms, frames])
	print(
		"%s %dx%d cpu mean %.3f p95 %.3f, gpu mean %.3f p95 %.3f ms -> %s"
		% [report["mode"], size[0], size[1], cpu_ms["mean"], cpu_ms["p95"], gpu_ms["mean"], gpu_ms["p95"], path]
	)


## Mean, p50, p95 and max of a series of ms readings (nearest rank).
func _stats(values: PackedFloat64Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var count := sorted.size()
	var total := 0.0
	for value: float in sorted:
		total += value
	return {
		"mean": total / count,
		"p50": sorted[_rank(count, _knob("percentile_median"))],
		"p95": sorted[_rank(count, _knob("percentile_high"))],
		"max": sorted[count - 1],
	}


func _rank(count: int, percentile: float) -> int:
	return clampi(ceili(percentile / 100.0 * count) - 1, 0, count - 1)


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
		if frame != null and _args.has("region"):
			frame = frame.get_region(_region())
		if frame == null or not _save(frame, dir.path_join(SEQUENCE_FRAME_PATTERN % index)):
			return false
		_stage.step(1.0 / fps)
	print("saved %d frames to %s" % [count, dir])
	return true


func _region() -> Rect2i:
	var v := _arg_string("region", "").split_floats(",")
	if v.size() < 4:
		return Rect2i()
	return Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))


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
