class_name SheetFrame
extends RefCounted
## One frame of a factory sprite sheet (tools/pipeline, schema mercs.sheet/1): the sheet
## texture, the frame's region in it, and the pivot (the feet centre, x from the left,
## y from the top of the frame). Presentation only; the Phase 1 street stage uses it to
## show factory output, or a placeholder capsule, before a full sheet loader exists.

const HALF := 2.0

var texture: ImageTexture = null
var region := Rect2()
var pivot := Vector2.ZERO


## The frame for a facing, or null for an unknown facing or a sheet that does not load.
static func from_manifest(manifest_path: String, facing: String) -> SheetFrame:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return null
	var manifest: Dictionary = parsed
	var found := _find_region(manifest, facing)
	if not found.has_area():
		return null
	var image_name := str(manifest.get("image", ""))
	var image_path := manifest_path.get_base_dir().path_join(image_name)
	var image := Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty():
		return null
	var pivot_value: Variant = manifest.get("pivot", {})
	var pivot_block: Dictionary = pivot_value if pivot_value is Dictionary else {}
	var frame := SheetFrame.new()
	frame.texture = ImageTexture.create_from_image(image)
	frame.region = found
	frame.pivot = Vector2(_num(pivot_block, "x"), _num(pivot_block, "y"))
	return frame


## A solid capsule with a 1-px outline on a transparent field, pivot at its bottom
## centre; deterministic.
static func capsule(width: int, height: int, fill: Color, outline: Color) -> SheetFrame:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var radius := width / HALF
	var centre_x := radius - 1.0 / HALF
	for y: int in height:
		for x: int in width:
			var axis_y: float = clampf(y, radius, height - radius)
			var distance := Vector2(x - centre_x, y - axis_y).length()
			if distance <= radius - 1.0 - 1.0 / HALF:
				image.set_pixel(x, y, fill)
			elif distance <= radius - 1.0 / HALF:
				image.set_pixel(x, y, outline)
	var frame := SheetFrame.new()
	frame.texture = ImageTexture.create_from_image(image)
	frame.region = Rect2(0.0, 0.0, width, height)
	frame.pivot = Vector2(width / HALF, height)
	return frame


static func _find_region(manifest: Dictionary, facing: String) -> Rect2:
	var frames: Variant = manifest.get("frames", [])
	if not frames is Array:
		return Rect2()
	var list: Array = frames
	for entry: Variant in list:
		if entry is Dictionary:
			var frame: Dictionary = entry
			if frame.get("facing", "") == facing:
				return Rect2(_num(frame, "x"), _num(frame, "y"), _num(frame, "w"), _num(frame, "h"))
	return Rect2()


static func _num(block: Dictionary, key: String) -> float:
	var value: Variant = block.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0
