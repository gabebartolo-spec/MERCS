class_name StageWeather
extends RefCounted
## Builds the rain-night extras for the Phase 1 capture stage from
## data/balance/stage.json "rain_night": one warm torch by the well and a box of falling
## rain streaks. The rain uses a fixed particle seed, so the same frame count gives the
## same rain; it is presentation only and decides nothing.

const TORCH_NAME := &"Torch"
const RAIN_NAME := &"Rain"
const HALF := 2.0


static func torch(data: StageData) -> OmniLight3D:
	var block := "rain_night/torch"
	var light := OmniLight3D.new()
	light.name = TORCH_NAME
	light.position = data.vec3(block, "position_m")
	light.light_color = data.rgb(block, "color_rgb")
	light.light_energy = data.num(block, "energy")
	light.omni_range = data.num(block, "range_m")
	light.shadow_enabled = true
	return light


static func rain(data: StageData) -> GPUParticles3D:
	var block := "rain_night/rain"
	var particles := GPUParticles3D.new()
	particles.name = RAIN_NAME
	particles.position = data.vec3(block, "centre_m")
	particles.amount = int(data.num(block, "amount"))
	particles.lifetime = data.num(block, "lifetime_s")
	particles.preprocess = particles.lifetime
	particles.use_fixed_seed = true
	particles.seed = int(data.num(block, "seed"))
	particles.visibility_aabb = AABB(-data.vec3(block, "area_m"), data.vec3(block, "area_m") * HALF)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.process_material = _rain_motion(data, block)
	particles.draw_pass_1 = _streak(data, block)
	return particles


static func _rain_motion(data: StageData, block: String) -> ParticleProcessMaterial:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = data.vec3(block, "area_m") / HALF
	motion.direction = Vector3.DOWN
	motion.spread = 0.0
	motion.gravity = Vector3.ZERO
	motion.initial_velocity_min = data.num(block, "fall_m_s")
	motion.initial_velocity_max = data.num(block, "fall_m_s")
	return motion


static func _streak(data: StageData, block: String) -> QuadMesh:
	var streak := QuadMesh.new()
	var size := data.floats(block, "streak_m")
	if size.size() >= 2:
		streak.size = Vector2(size[0], size[1])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = data.rgb(block, "color_rgb")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	streak.material = material
	return streak
