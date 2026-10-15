class_name BattleRows
extends RefCounted
## Where the rows of a battle grid stand on the street so that the figure in front never
## covers the one behind (read by BattleView). Every row is a figure's height and a little over
## below the one above on screen; perspective makes a metre cover fewer pixels far away, so the
## far rows stand further apart on the ground. The camera is a pinhole pitched at the look-at
## point: a ground point u metres nearer than it lands f * u * sin(p) / (D - u * cos(p)) pixels
## below the screen's middle, f being the pixels from the eye to the image plane and D the rail
## distance (StreetStage). Presentation only.

## A row is this much taller than the figure on screen (the far rows' perspective included).
const ROW_MARGIN := 1.04

var _stage: StreetStage = null
var _figure_px := 0.0


func _init(stage: StreetStage) -> void:
	_stage = stage


## Takes the figure's height from a fighter's frame (its opaque rows).
func learn(sprite: Sprite3D) -> void:
	_figure_px = float(_used(sprite).size.y)


## Screen pixels between two rows: the figure's height and a little over.
func pitch_px() -> float:
	return maxf(_figure_px, float(_stage.sprite_height_px)) * ROW_MARGIN


## Metres of ground depth from the middle row to a point `rows` rows away.
func depth_of(rows: float) -> float:
	var down := rows * pitch_px()
	var pitch := deg_to_rad(_stage.pitch_degrees)
	return down * _stage.rail_distance_m() / (_focal_px() * sin(pitch) + down * cos(pitch))


## The inverse of depth_of(): the (fractional) rows a ground depth is from the middle.
func rows_of(depth: float) -> float:
	var pitch := deg_to_rad(_stage.pitch_degrees)
	var down := _focal_px() * depth * sin(pitch) / (_stage.rail_distance_m() - depth * cos(pitch))
	return down / pitch_px()


## The screen rectangle the drawn figure covers (the opaque pixels of its frame, not the
## frame's empty cell), in the camera's viewport pixels.
func figure_rect(sprite: Sprite3D) -> Rect2:
	var camera := _stage.camera()
	var used := _used(sprite)
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var rect := Rect2(camera.unproject_position(sprite.global_position), Vector2.ZERO)
	for corner: Vector2 in [
		Vector2(used.position),
		Vector2(used.end),
		Vector2(used.position.x, used.end.y),
		Vector2(used.end.x, used.position.y)
	]:
		var rows := sprite.region_rect.size.y - corner.y
		var local := Vector2(corner.x + sprite.offset.x, rows + sprite.offset.y) * sprite.pixel_size
		var world := sprite.global_position + right * local.x + up * local.y
		rect = rect.expand(camera.unproject_position(world))
	return rect


func _focal_px() -> float:
	var half_fov := deg_to_rad(_stage.stage_data.num("camera", "fov_degrees")) / 2.0
	return _stage.logical_size().y / 2.0 / tan(half_fov)


func _used(sprite: Sprite3D) -> Rect2i:
	return sprite.texture.get_image().get_region(Rect2i(sprite.region_rect)).get_used_rect()
