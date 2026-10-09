class_name StreetStage
extends Node
## Phase 1 grey-box capture stage (docs/specs/phase1_visual_proof.md §1 step 2, §2).
## A 40 × 20 m street of placeholder boxes in a GridMap (StreetGrid), one warm key light
## with flat ambient, a perspective camera on a rail above the street centre line, one
## Sprite3D merc (a capsule, or a factory sheet frame via use_sheet) that walks a loop past
## the well, and any standing mercs added with add_merc. Every number that is not an
## exported var comes from data/balance/stage.json (stage.md explains each knob).
##
## Scale contract (tools/pipeline/camera_rig.json): a texel is
## merc_height_m × cos(pitch) / sprite_height_px of the image plane (the factory renders
## the figure foreshortened at the same pitch), the sprite faces the camera, and the rail
## distance is derived so one texel covers one logical pixel at the look-at depth.
## The scene is presentation only: nothing here decides an outcome, and nothing is random.
##
## pixel_mode WHOLE_SCREEN renders the 3D world through a 640 × 360 SubViewport scaled
## 3× with nearest filtering, and snaps the sprite to that viewport's pixel grid each
## step. CRISP renders the world at window resolution with the sprite unsnapped.

enum PixelMode { CRISP, WHOLE_SCREEN }
enum Lighting { DAY, RAIN_NIGHT }
enum DepthScale { PERSPECTIVE, CONSTANT }

const STAGE_DATA_PATH := "res://data/balance/stage.json"
const HALF := 2.0

## Camera pitch below the horizon, in degrees. Applies at once when changed.
@export var pitch_degrees: float = 55.0:
	set = _set_pitch_degrees
## How the 3D world reaches the window; see the class comment.
@export var pixel_mode: PixelMode = PixelMode.WHOLE_SCREEN
## On-screen figure height in logical pixels (the factory's char_height_px); the
## texel size and the rail distance follow from it.
@export var sprite_height_px: int = 56
## DAY: warm key and flat grey sky. RAIN_NIGHT: dim cool key, a torch by the well, rain,
## and the unshaded sprite tinted to match (data "rain_night").
@export var lighting: Lighting = Lighting.DAY
## PERSPECTIVE: the sprite is sized by the camera like the world, so a texel is one logical
## pixel only at the look-at depth. CONSTANT: the texel is rescaled by depth so it is one
## logical pixel wherever the merc stands; only screen position shows distance.
@export var depth_scale: DepthScale = DepthScale.CONSTANT
## When true, a frame with a normal map is drawn shaded, lit by the scene's lights; a
## frame without one (or with this off) is unshaded and tinted at night.
@export var lit_sprites: bool = true
## When false the walker only moves through step(), which captures and tests call.
@export var auto_walk: bool = true
## Logical (pixel-art) resolution in WHOLE_SCREEN; zero takes data "pixel". Set before the
## stage enters the tree. Captures use it to compare pixel densities.
@export var logical_size_px: Vector2i = Vector2i.ZERO
## Integer upscale of the logical viewport; zero takes data "pixel" "integer_scale".
@export var integer_scale: int = 0

## Current time of day and rain (set_conditions). The lighting export picks the start:
## DAY is day and dry, RAIN_NIGHT is night and raining.
var time_of_day := StageLighting.TimeOfDay.DAY
var rain := false
## Times the walker has wrapped past the end of its loop since the stage was ready.
var laps_completed: int = 0

## The stage's data (data/balance/stage.json), for scenes built on the stage.
var stage_data: StageData:
	get:
		return _data

var _data: StageData = null
var _loop_length_m: float = 0.0
var _walk_speed: float = 0.0
var _merc_height_m: float = 0.0
var _standing := false
var _stand_point := Vector3.ZERO
var _frame: SheetFrame = null
var _extras: Array[Sprite3D] = []
var _extra_points: Array[Vector3] = []
var _sprite_tint := Color.WHITE

@onready var _world: Node3D = %World
@onready var _street: GridMap = %Street
@onready var _key_light: DirectionalLight3D = %KeyLight
@onready var _ambient: WorldEnvironment = %Ambient
@onready var _rail: Node3D = %CameraRail
@onready var _camera: Camera3D = %Camera
@onready var _path: Path3D = %WalkPath
@onready var _walker: PathFollow3D = %Walker
@onready var _merc: Sprite3D = %PlaceholderMerc


func _ready() -> void:
	_data = StageData.load_file(STAGE_DATA_PATH)
	StreetGrid.build(_street, _data)
	var night := lighting == Lighting.RAIN_NIGHT
	set_conditions(StageLighting.TimeOfDay.NIGHT if night else StageLighting.TimeOfDay.DAY, night)
	_setup_camera()
	_setup_path()
	_setup_merc()
	_apply_pixel_mode()
	_place_merc()


func _process(delta: float) -> void:
	if auto_walk:
		step(delta)


## Advances the walker by delta seconds and places the sprite. Deterministic: the
## same sequence of deltas always gives the same positions.
func step(delta: float) -> void:
	if _loop_length_m <= 0.0:
		return
	var before: float = _walker.progress
	_walker.progress = before + _walk_speed * delta
	if _walker.progress < before:
		laps_completed += 1
	_place_merc()


func _set_pitch_degrees(value: float) -> void:
	pitch_degrees = value
	if is_node_ready():
		_apply_pitch()


## Seconds one full walk of the loop takes at the data's walk speed.
func loop_seconds() -> float:
	if _walk_speed <= 0.0:
		return 0.0
	return _loop_length_m / _walk_speed


func camera() -> Camera3D:
	return _camera


func merc() -> Sprite3D:
	return _merc


func world() -> Node3D:
	return _world


func street() -> GridMap:
	return _street


## The sprite's feet in the pixels of the viewport the camera renders to (the
## 640 × 360 logical viewport in WHOLE_SCREEN, the window in CRISP).
func merc_screen_position() -> Vector2:
	return _camera.unproject_position(_merc.global_position)


## The middle of the sprite as drawn (its world bounds, so any depth scaling counts), in
## the same pixels as merc_screen_position().
func merc_centre_screen_position() -> Vector2:
	return _camera.unproject_position((_merc.global_transform * _merc.get_aabb()).get_center())


## Switches time of day and rain at runtime (StageLighting); unshaded sprites take the
## matching tint at once.
func set_conditions(time: StageLighting.TimeOfDay, raining: bool) -> void:
	time_of_day = time
	rain = raining
	_sprite_tint = StageLighting.apply(_data, _key_light, _ambient, _world, time, raining)
	if _frame != null:
		for sprite: Sprite3D in _all_mercs():
			_show_frame(sprite, _frame)


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = _data.num("camera", "fov_degrees")
	_camera.near = _data.num("camera", "near_m")
	_camera.far = _data.num("camera", "far_m")
	_rail.position = Vector3(0.0, _data.num("camera", "look_at_height_m"), 0.0)
	_apply_pitch()


## Metres of the camera's image plane one sprite texel covers.
func texel_m() -> float:
	if sprite_height_px <= 0:
		return 0.0
	return _data.num("sprite", "merc_height_m") * cos(deg_to_rad(pitch_degrees)) / sprite_height_px


## The rail distance at which one texel covers one logical pixel at the look-at point:
## the logical viewport spans 2 × distance × tan(fov / 2) of the image plane.
func rail_distance_m() -> float:
	var half_fov := deg_to_rad(_data.num("camera", "fov_degrees")) / HALF
	return texel_m() * logical_size().y / (HALF * tan(half_fov))


## The logical viewport size: logical_size_px, or data "pixel" when that is zero.
func logical_size() -> Vector2i:
	if logical_size_px != Vector2i.ZERO:
		return logical_size_px
	return Vector2i(
		int(_data.num("pixel", "logical_width_px")), int(_data.num("pixel", "logical_height_px"))
	)


## The integer upscale from logical pixels to the window: integer_scale, or the data's.
func screen_scale() -> int:
	return integer_scale if integer_scale > 0 else int(_data.num("pixel", "integer_scale"))


## The rail sits on the look-at point; the camera hangs rail_distance_m() away along a
## ray pitched pitch_degrees below the horizon, looking back at the rail. The sprite's
## texel and stretch follow the pitch.
func _apply_pitch() -> void:
	var distance := rail_distance_m()
	var pitch := deg_to_rad(pitch_degrees)
	_camera.position = Vector3(0.0, distance * sin(pitch), distance * cos(pitch))
	_camera.rotation_degrees = Vector3(-pitch_degrees, 0.0, 0.0)
	if _frame != null:
		for sprite: Sprite3D in _all_mercs():
			_apply_texel(sprite)


## Sprites face the camera fully (BILLBOARD_ENABLED), so each lies in a plane parallel to
## the image and projects at one uniform scale: no lean or shear at the screen edges. A
## texel is texel_m() of the image plane; in CONSTANT depth scale it grows with the
## sprite's depth over the rail distance, so it is one logical pixel wherever the merc
## stands.
func _apply_texel(sprite: Sprite3D) -> void:
	sprite.pixel_size = texel_m()
	sprite.scale = Vector3.ONE
	if depth_scale != DepthScale.CONSTANT or rail_distance_m() <= 0.0:
		return
	var forward: Vector3 = -_camera.global_transform.basis.z
	var depth := (sprite.global_position - _camera.global_position).dot(forward)
	sprite.pixel_size *= depth / rail_distance_m()


## Shows one frame of a factory sheet (tools/pipeline, schema mercs.sheet/1) with its
## pivot on the ground. Returns false, changing nothing, for an unknown facing or a
## sheet that does not load. The sheet must be rendered at this stage's pitch and height.
func use_sheet(manifest_path: String, facing: String) -> bool:
	var frame := SheetFrame.from_manifest(manifest_path, facing)
	if frame == null:
		return false
	_frame = frame
	for sprite: Sprite3D in _all_mercs():
		_show_frame(sprite, frame)
	_place_merc()
	return true


## Shows a frame with its pivot texel (x from the left, y from the top) on the node's
## origin, so the node's position is the merc's feet. Sprite3D draws y up from offset.y.
func _show_frame(sprite: Sprite3D, frame: SheetFrame) -> void:
	sprite.texture = frame.texture
	sprite.region_enabled = true
	sprite.region_rect = frame.region
	sprite.centered = false
	sprite.offset = Vector2(-frame.pivot.x, frame.pivot.y - frame.region.size.y)
	var lit := lit_sprites and frame.normal != null
	sprite.material_override = frame.lit_material() if lit else frame.unlit_material()
	sprite.modulate = _sprite_tint if not lit else Color.WHITE


func _setup_path() -> void:
	var curve := Curve3D.new()
	var points := _data.floats("sprite", "path_xz")
	for i: int in range(0, points.size() - 1, 2):
		curve.add_point(Vector3(points[i], 0.0, points[i + 1]))
	if curve.point_count > 0:
		curve.add_point(curve.get_point_position(0))
	_path.curve = curve
	_loop_length_m = curve.get_baked_length()
	_walk_speed = _data.num("sprite", "walk_speed_m_s")
	_walker.loop = true
	_walker.rotation_mode = PathFollow3D.ROTATION_NONE
	_walker.progress = 0.0


func _setup_merc() -> void:
	_merc_height_m = _data.num("sprite", "merc_height_m")
	var width := int(_data.num("sprite", "texture_width_px"))
	var fill := _data.grey("sprite", "fill_grey")
	var outline := _data.grey("sprite", "outline_grey")
	_frame = SheetFrame.capsule(width, sprite_height_px, fill, outline, lit_sprites)
	_configure(_merc)
	_apply_texel(_merc)


## Another merc standing at a world point, drawn with the current frame and the same
## placement, snapping and depth-scale rules as the walker (crowd, occlusion and sorting).
func add_merc(point: Vector3) -> Sprite3D:
	var sprite := Sprite3D.new()
	_world.add_child(sprite)
	_configure(sprite)
	_extras.append(sprite)
	_extra_points.append(point)
	_place_merc()
	return sprite


func extra_mercs() -> Array[Sprite3D]:
	return _extras


## Moves an added merc's feet to a world point (the slice's crowd walks).
func move_extra(index: int, point: Vector3) -> void:
	if index >= 0 and index < _extra_points.size():
		_extra_points[index] = point
		_place_sprite(_extras[index], point)


## Shows a frame (one facing of a sheet) on one merc only; the walker is merc().
func show_frame_on(sprite: Sprite3D, frame: SheetFrame) -> void:
	if frame != null:
		_show_frame(sprite, frame)
		_apply_texel(sprite)


## Centres the camera rail on a ground point, moved in whole logical pixels at the look-at
## depth (x by one texel, z by one texel over sin(pitch)), so the world never swims as the
## camera follows; then re-places every merc on the new pixel grid.
func focus_on(point: Vector3) -> void:
	var texel := texel_m()
	var pitch_sin := sin(deg_to_rad(pitch_degrees))
	if texel <= 0.0 or pitch_sin <= 0.0:
		return
	_rail.position.x = snappedf(point.x, texel)
	_rail.position.z = snappedf(point.z, texel / pitch_sin)
	_place_merc()


func _all_mercs() -> Array[Sprite3D]:
	var all: Array[Sprite3D] = [_merc]
	all.append_array(_extras)
	return all


## Depth-tested, alpha-cut, nearest, camera-facing: occlusion by walls and sorting between
## mercs come from the depth buffer, not from draw order. The material override
## (SheetFrame, upright_sprite.gdshaderinc) takes depth and light where the figure stands
## upright at its feet, so a quad leaning back with the camera pitch never sinks into, or
## is shadowed by, what is behind it.
func _configure(sprite: Sprite3D) -> void:
	_show_frame(sprite, _frame)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_pixel_mode() -> void:
	if pixel_mode == PixelMode.WHOLE_SCREEN:
		PixelScreen.wrap(self, _world, logical_size(), screen_scale())
	_camera.current = true


## Holds the merc's feet at a world point (captures use it to compare depths); step()
## still advances the walker but no longer moves the sprite.
func stand_at(point: Vector3) -> void:
	_standing = true
	_stand_point = point
	_place_merc()


func _place_merc() -> void:
	var feet: Vector3 = _stand_point if _standing else _walker.global_position
	_place_sprite(_merc, feet)
	for i: int in _extras.size():
		_place_sprite(_extras[i], _extra_points[i])


func _place_sprite(sprite: Sprite3D, feet: Vector3) -> void:
	if pixel_mode == PixelMode.WHOLE_SCREEN:
		feet = _snap_to_pixel_grid(feet)
	sprite.global_position = feet
	_apply_texel(sprite)


## Moves a world point along the camera's view so it lands on a whole pixel of the
## camera's viewport, keeping its depth.
func _snap_to_pixel_grid(point: Vector3) -> Vector3:
	var forward: Vector3 = -_camera.global_transform.basis.z
	var depth: float = (point - _camera.global_position).dot(forward)
	var screen: Vector2 = _camera.unproject_position(point)
	return _camera.project_position(screen.round(), depth)
