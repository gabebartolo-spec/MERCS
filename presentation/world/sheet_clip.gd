class_name SheetClip
extends RefCounted
## A whole factory sheet (mercs.sheet/1) loaded once for playback: every facing's frames
## sharing one texture and one normal map, plus the clip's timing. A sheet lists
## frames_per_facing frames per facing, each with "facing" and "frame" (0..n-1; a rest
## sheet has one frame per facing and may omit "frame"); a facing short of a frame is
## dropped, so a broken sheet shows the rest pose instead of a stutter. Clip keys: "fps" (frames per
## second at the clip's real timing), "loop", and for a walk "ground_speed_mps" (the speed
## the planted foot travels, so a merc moved at it never slides). Presentation only.

var fps := 0.0
var loop := true
var ground_speed_mps := 0.0

var _frames := {}


## The clip in a manifest, or null when the manifest, its image or its normal map is broken.
static func load_manifest(manifest_path: String) -> SheetClip:
	var paths: Array[String] = [manifest_path]
	return load_layers(paths)


## One clip drawn from stacked layers, bottom first: body, then gear, head and injury layers
## (director, 2026-10-09: "permanent injuries must be considered for all spritework"). Every
## layer is a whole mercs.sheet/1 sheet on the same grid: same image size, frames and pivot.
## Each opaque layer pixel replaces the one below, in colour and in the normal map, so any
## mix of stage, returning variant and injuries is one sheet and one sprite. Null when a
## layer does not load or does not match the first.
static func load_layers(manifest_paths: Array[String]) -> SheetClip:
	if manifest_paths.is_empty():
		return null
	var base := _read(manifest_paths[0])
	if base.is_empty():
		return null
	var image: Image = base["image"]
	var normal: Image = base["normal"]
	var manifest: Dictionary = base["manifest"]
	for path: String in manifest_paths.slice(1):
		var layer := _read(path)
		if layer.is_empty() or not _same_grid(manifest, layer):
			return null
		var layer_image: Image = layer["image"]
		if layer_image.get_size() != image.get_size():
			return null
		_stack(image, layer_image, layer_image)
		var layer_normal: Image = layer["normal"]
		if normal != null and layer_normal != null:
			_stack(normal, layer_normal, layer_image)
	return _from(manifest, image, normal)


## {"manifest", "image", "normal" (or null)} for one sheet, or {} when broken.
static func _read(manifest_path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return {}
	var manifest: Dictionary = parsed
	var base := manifest_path.get_base_dir()
	var image := SheetFrame.load_image(base.path_join(str(manifest.get("image", ""))))
	if image == null or image.is_empty():
		return {}
	image.convert(Image.FORMAT_RGBA8)
	var normal: Image = null
	var normal_name := str(manifest.get("normal_image", ""))
	if not normal_name.is_empty():
		normal = SheetFrame.load_image(base.path_join(normal_name))
		if normal == null or normal.get_size() != image.get_size():
			return {}
		normal.convert(Image.FORMAT_RGBA8)
	return {"manifest": manifest, "image": image, "normal": normal}


## Same frames (facing, frame and rect) and pivot as the base sheet.
static func _same_grid(base: Dictionary, layer: Dictionary) -> bool:
	var other: Dictionary = layer["manifest"]
	return (
		str(base.get("frames")) == str(other.get("frames"))
		and str(base.get("pivot")) == str(other.get("pivot"))
	)


## Copies every pixel of top whose mask pixel is not transparent onto bottom.
static func _stack(bottom: Image, top: Image, mask: Image) -> void:
	bottom.blit_rect_mask(top, mask, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)


static func _from(manifest: Dictionary, image: Image, normal: Image) -> SheetClip:
	var clip := SheetClip.new()
	clip.fps = _num(manifest, "fps")
	clip.loop = manifest.get("loop", true) == true
	clip.ground_speed_mps = _num(manifest, "ground_speed_mps")
	var pivot_value: Variant = manifest.get("pivot", {})
	var pivot_block: Dictionary = pivot_value if pivot_value is Dictionary else {}
	var pivot := Vector2(_num(pivot_block, "x"), _num(pivot_block, "y"))
	var texture := ImageTexture.create_from_image(image)
	var normal_texture := ImageTexture.create_from_image(normal) if normal != null else null
	clip._index_frames(manifest, texture, normal_texture, pivot)
	return clip if not clip._frames.is_empty() else null


func frame_count(facing: String) -> int:
	var list: Array = _frames.get(facing, [])
	return list.size()


## The frame of a facing at a time into the clip: looped, or held on the last frame. Null
## for a facing the sheet does not have.
func frame_at(facing: String, seconds: float) -> SheetFrame:
	var count := frame_count(facing)
	if count == 0:
		return null
	var index := floori(maxf(seconds, 0.0) * fps)
	index = posmod(index, count) if loop else mini(index, count - 1)
	var list: Array = _frames[facing]
	return list[index]


func _index_frames(
	manifest: Dictionary, texture: ImageTexture, normal: ImageTexture, pivot: Vector2
) -> void:
	var entries: Variant = manifest.get("frames", [])
	if not entries is Array:
		return
	var list: Array = entries
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var block: Dictionary = entry
		var frame := SheetFrame.new()
		frame.texture = texture
		frame.normal = normal
		frame.pivot = pivot
		frame.region = Rect2(_num(block, "x"), _num(block, "y"), _num(block, "w"), _num(block, "h"))
		var facing := str(block.get("facing", ""))
		var frames: Array = _frames.get(facing, [])
		var at := int(_num(block, "frame"))
		while frames.size() <= at:
			frames.append(null)
		frames[at] = frame
		_frames[facing] = frames
	# Every facing needs the full count (frames_per_facing, else the longest facing).
	var full := int(_num(manifest, "frames_per_facing"))
	for facing: Variant in _frames:
		var counted: Array = _frames[facing]
		full = maxi(full, counted.size())
	for facing: Variant in _frames.keys():
		var frames: Array = _frames[facing]
		if frames.has(null) or frames.size() < full:
			_frames.erase(facing)


static func _num(block: Dictionary, key: String) -> float:
	var value: Variant = block.get(key, 0.0)
	if value is float or value is int:
		return value
	return 0.0
