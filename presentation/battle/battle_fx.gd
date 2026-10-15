class_name BattleFx
extends RefCounted
## The hit and death flash (director ruling Q-G; P6b). A wounded fighter shows a bone-white
## silhouette of its own frame for a moment (data/balance/battle_view.json "flash"); the fighter
## who falls shows it a little longer, then the sprite goes and BattleMarks keeps the body.
## Presentation only: it reads the sim's "hit" and "down" events and decides nothing, and it
## runs on the delta the caller hands it (no clock). PLACEHOLDER until the Art agent's hit and
## fall frames per facing replace the flat silhouette.

const DATA_PATH := "res://data/balance/battle_view.json"
const FLASH_REF := "bone:4"
const OPAQUE := 0.5

var _data: StageData = StageData.load_file(DATA_PATH)
## Fighter id -> {"left": seconds still to show, "original": the material to put back}.
var _flashing: Dictionary = {}
## Source texture instance id -> its all-bone twin.
var _twins: Dictionary = {}


## Starts a flash for each wound and each fall in one action's events.
func play(events: Array[Dictionary], sprites: Dictionary) -> void:
	for event: Dictionary in events:
		var kind := str(event.get("type", ""))
		if kind == BattleMarks.EVENT_HIT:
			_flash(str(event.get("target", "")), _data.num("flash", "hit_s"), sprites)
		elif kind == BattleMarks.EVENT_DOWN:
			_flash(str(event.get("unit", "")), _data.num("flash", "death_s"), sprites)


## Counts the flashes down; a finished one puts the frame back (or hides a fallen fighter).
func tick(delta: float, sprites: Dictionary, battle: Battle) -> void:
	for id: Variant in _flashing.keys():
		var entry: Dictionary = _flashing[id]
		var left: float = entry["left"]
		entry["left"] = left - delta
		if left - delta <= 0.0:
			_restore(str(id), sprites, battle)


## The sprite's own material: the one it will get back when a flash ends, else its current one.
func plain_material(unit_id: String, sprite: Sprite3D) -> ShaderMaterial:
	if _flashing.has(unit_id):
		var entry: Dictionary = _flashing[unit_id]
		var original: ShaderMaterial = entry["original"]
		return original
	return sprite.material_override as ShaderMaterial


## How many fighters are flashing now.
func active() -> int:
	return _flashing.size()


## Whether this fighter is showing its flash frame.
func is_flashing(unit_id: String) -> bool:
	return _flashing.has(unit_id)


## Ends every flash at once (the fight's figures are about to be cleared).
func clear(sprites: Dictionary, battle: Battle) -> void:
	for id: Variant in _flashing.keys():
		_restore(str(id), sprites, battle)


func _flash(unit_id: String, seconds: float, sprites: Dictionary) -> void:
	var sprite: Sprite3D = sprites.get(unit_id, null)
	if sprite == null:
		return
	if not _flashing.has(unit_id):
		var original := sprite.material_override as ShaderMaterial
		if original == null:
			return
		_flashing[unit_id] = {"left": 0.0, "original": original}
		sprite.material_override = _twin_material(original)
	var entry: Dictionary = _flashing[unit_id]
	var left: float = entry["left"]
	entry["left"] = maxf(left, seconds)
	sprite.visible = true


func _restore(unit_id: String, sprites: Dictionary, battle: Battle) -> void:
	var entry: Dictionary = _flashing[unit_id]
	_flashing.erase(unit_id)
	var sprite: Sprite3D = sprites.get(unit_id, null)
	if sprite == null:
		return
	var original: ShaderMaterial = entry["original"]
	sprite.material_override = original
	var fighter := battle.unit(unit_id)
	sprite.visible = fighter != null and not fighter.down


## The sprite's material, flat and unlit, drawing every pixel of its frame in bone.
func _twin_material(original: ShaderMaterial) -> ShaderMaterial:
	var twin := original.duplicate() as ShaderMaterial
	twin.shader = SheetFrame.UNLIT_SHADER
	var texture: Texture2D = original.get_shader_parameter(&"albedo_texture")
	if texture != null:
		twin.set_shader_parameter(&"albedo_texture", _bone_of(texture))
	return twin


func _bone_of(texture: Texture2D) -> Texture2D:
	var key := texture.get_instance_id()
	if _twins.has(key):
		var known: Texture2D = _twins[key]
		return known
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var bone := Palette.colour(FLASH_REF)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= OPAQUE:
				image.set_pixel(x, y, bone)
	var twin := ImageTexture.create_from_image(image)
	_twins[key] = twin
	return twin
