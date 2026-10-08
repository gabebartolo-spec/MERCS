extends RefCounted
## Engine-side checks for a factory sprite sheet (schema mercs.sheet/1). The Python
## validator (tools/pipeline/validate_sheet.py) owns the pixel rules (palette, alpha,
## clipping, empty frames); these are the rules only the engine can check, so a sheet that
## passes the factory still shows correctly in Godot:
##   ENGINE-LOAD     Godot cannot read the image, or SheetFrame refuses a listed facing
##   ENGINE-FACINGS  the facings differ from tools/pipeline/camera_rig.json's order, or a
##                   facing has no frame
##   ENGINE-FRAME    the frame size differs from the camera rig's frame_px, or a frame rect
##                   lies outside the image
##   ENGINE-PIVOT    the pivot differs from the camera rig's pivot_px (every sheet must share
##                   one anchor so layers and bodies line up on the ground)
##   ENGINE-NORMAL   a named normal_image does not load or differs in size from the image
## check(manifest_path) returns one "RULE: detail" line per problem; empty means clean.

const CAMERA_RIG := "res://tools/pipeline/camera_rig.json"
const SHEET_FRAME := preload("res://presentation/world/sheet_frame.gd")


static func check(manifest_path: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var manifest := _json(manifest_path)
	var rig := _json(CAMERA_RIG)
	var image := _image(manifest_path, str(manifest.get("image", "")))
	if image == null:
		problems.append("ENGINE-LOAD: image %s does not load" % manifest.get("image", "?"))
		return problems
	_check_facings(manifest, rig, problems)
	_check_frames(manifest, rig, image.get_size(), problems)
	_check_pivot(manifest, rig, problems)
	var before_normal := problems.size()
	_check_normal(manifest_path, manifest, image.get_size(), problems)
	if problems.size() > before_normal:
		return problems  # SheetFrame refuses a bad normal map; ENGINE-NORMAL already says why.
	for facing: Variant in _list(manifest, "facings"):
		if SHEET_FRAME.from_manifest(manifest_path, str(facing)) == null:
			problems.append("ENGINE-LOAD: SheetFrame refuses facing %s" % facing)
	return problems


static func _check_facings(
	manifest: Dictionary, rig: Dictionary, problems: PackedStringArray
) -> void:
	var facings_block: Variant = rig.get("facings", {})
	var order: Array = []
	if facings_block is Dictionary:
		var block: Dictionary = facings_block
		order = block.get("order", [])
	if _list(manifest, "facings") != order:
		problems.append(
			"ENGINE-FACINGS: facings %s, camera rig %s" % [manifest.get("facings"), order]
		)
	var framed := {}
	for frame: Dictionary in _frames(manifest):
		framed[str(frame.get("facing", ""))] = true
	for facing: Variant in order:
		if not framed.has(str(facing)):
			problems.append("ENGINE-FACINGS: no frame for facing %s" % facing)


static func _check_frames(
	manifest: Dictionary, rig: Dictionary, image_size: Vector2i, problems: PackedStringArray
) -> void:
	var cell := int(_num(rig, "frame_px"))
	if int(_num(manifest, "frame_w")) != cell or int(_num(manifest, "frame_h")) != cell:
		problems.append(
			(
				"ENGINE-FRAME: frame %sx%s, camera rig %d"
				% [manifest.get("frame_w"), manifest.get("frame_h"), cell]
			)
		)
	var bounds := Rect2i(Vector2i.ZERO, image_size)
	for frame: Dictionary in _frames(manifest):
		var rect := Rect2i(
			int(_num(frame, "x")),
			int(_num(frame, "y")),
			int(_num(frame, "w")),
			int(_num(frame, "h"))
		)
		if not bounds.encloses(rect):
			problems.append(
				"ENGINE-FRAME: frame %s at %s lies outside the image" % [frame.get("facing"), rect]
			)


static func _check_pivot(
	manifest: Dictionary, rig: Dictionary, problems: PackedStringArray
) -> void:
	var pivot_value: Variant = manifest.get("pivot", {})
	var pivot: Dictionary = pivot_value if pivot_value is Dictionary else {}
	var rig_pivot := _list(rig, "pivot_px")
	var expected := Vector2i(-1, -1)
	if rig_pivot.size() >= 2:
		var px: float = rig_pivot[0]
		var py: float = rig_pivot[1]
		expected = Vector2i(int(px), int(py))
	var actual := Vector2i(int(_num(pivot, "x")), int(_num(pivot, "y")))
	if actual != expected:
		problems.append("ENGINE-PIVOT: pivot %s, camera rig %s" % [actual, expected])


static func _check_normal(
	manifest_path: String, manifest: Dictionary, image_size: Vector2i, problems: PackedStringArray
) -> void:
	var normal_name := str(manifest.get("normal_image", ""))
	if normal_name.is_empty():
		return
	var normal := _image(manifest_path, normal_name)
	if normal == null:
		problems.append("ENGINE-NORMAL: normal_image %s does not load" % normal_name)
	elif normal.get_size() != image_size:
		problems.append(
			"ENGINE-NORMAL: normal_image is %s, image is %s" % [normal.get_size(), image_size]
		)


static func _image(manifest_path: String, file_name: String) -> Image:
	if file_name.is_empty():
		return null
	var path := manifest_path.get_base_dir().path_join(file_name)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return image


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


static func _list(block: Dictionary, key: String) -> Array:
	var value: Variant = block.get(key, [])
	if value is Array:
		return value
	return []


static func _frames(manifest: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in _list(manifest, "frames"):
		if entry is Dictionary:
			out.append(entry)
	return out


static func _num(block: Dictionary, key: String) -> float:
	var value: Variant = block.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0
