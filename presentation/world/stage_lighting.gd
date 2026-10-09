class_name StageLighting
extends RefCounted
## Time of day and rain for the street stage, switchable at runtime (the art direction
## slice's T and R keys, docs/specs/art_direction_slice.md). Reads data/balance/stage.json:
## "light" (day), "dusk" and "rain_night" (night: moon key, sky, torch, rain). Torches burn
## at dusk and night; rain is independent of the time. Presentation only, nothing random.

enum TimeOfDay { DAY, DUSK, NIGHT }

const NIGHT_BLOCK := "rain_night"
const DUSK_BLOCK := "dusk"


## Applies a time of day and rain to the stage's light, environment and world, adding or
## removing the torch and rain nodes, and returns the modulate an unshaded sprite takes.
static func apply(
	data: StageData,
	key_light: DirectionalLight3D,
	ambient: WorldEnvironment,
	world: Node3D,
	time: TimeOfDay,
	raining: bool
) -> Color:
	var light := _light_block(time)
	key_light.rotation_degrees = Vector3(
		-data.num(light, "elevation_degrees"), data.num(light, "azimuth_degrees"), 0.0
	)
	key_light.light_color = data.rgb(light, "color_rgb")
	key_light.light_energy = data.num(light, "energy")
	key_light.shadow_enabled = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = data.num(light, "ambient_energy")
	var tint := Color.WHITE
	if time == TimeOfDay.DAY:
		environment.background_color = data.grey("shades", "sky")
		environment.ambient_light_color = data.grey(light, "ambient_grey")
	else:
		var block := DUSK_BLOCK if time == TimeOfDay.DUSK else NIGHT_BLOCK
		environment.background_color = data.rgb(block, "sky_rgb")
		environment.ambient_light_color = data.rgb(light, "ambient_rgb")
		tint = data.rgb(block, "sprite_tint_rgb")
	ambient.environment = environment
	_keep(world, StageWeather.TORCH_NAME, time != TimeOfDay.DAY, StageWeather.torch.bind(data))
	_keep(world, StageWeather.RAIN_NAME, raining, StageWeather.rain.bind(data))
	return tint


static func _light_block(time: TimeOfDay) -> String:
	match time:
		TimeOfDay.DUSK:
			return DUSK_BLOCK + "/light"
		TimeOfDay.NIGHT:
			return NIGHT_BLOCK + "/light"
	return "light"


## Makes sure the world has a child of this name exactly when wanted, building it with make.
static func _keep(world: Node3D, node_name: StringName, wanted: bool, make: Callable) -> void:
	var existing := world.get_node_or_null(NodePath(node_name))
	if existing != null and not wanted:
		world.remove_child(existing)
		existing.queue_free()
	elif existing == null and wanted:
		var made: Node = make.call()
		world.add_child(made)
