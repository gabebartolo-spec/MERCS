extends "res://tests/lib/runner.gd"
## Impact suite (Phase 4 P6c, director 2026-10-16): blood thrown by each blow lands exactly on
## the splat BattleMarks laid for that hit (each drop on one of the splat's own pixels), and the
## splat shows only once a drop has landed, then stays; drops face the camera, are one blood red,
## 1 to 3 logical pixels at the figures' pixel size, 10 to 16 per hit; they leave the struck
## figure at torso height, burst out past its silhouette along the blow within 3 frames, and are
## never drawn over the body (lead QC round 1, tests/lib/spray_checks.gd); the same fight throws
## the same drops in two runs. Hit-stop (director 03:17, "Subtle, a few frames", no
## screen shake) holds only the picture: the same fight with it on and off (the Settings toggle)
## gives the same battle log, and with it on the presentation takes longer by the held frames,
## held only after big hits, with the camera still. The fight is the slice's on the street at
## 1920x1080, the player's turns as real clicks. Seeded: Rng.from_seed; both sides by BattleAi.
##   godot --headless --fixed-fps 60 --path . --script tests/run_impact_tests.gd

const Kit := preload("res://tests/lib/battle_view_kit.gd")
const Spray := preload("res://tests/lib/spray_checks.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const DATA_PATH := "res://data/balance/battle_view.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
const SEED := 1009
const FIGHT_FRAMES := 20000
const SETTLE := 60
const LAND_TOLERANCE_M := 0.0005
const TEXEL_TOLERANCE := 0.15
const SUBTLE_MIN_FRAMES := 3
const SUBTLE_MAX_FRAMES := 5
const MID := 0.5
## Lead QC round 1: 10 to 16 drops a hit.
const MIN_DROPS := 10
const MAX_DROPS := 16
const DROP_REFS: Array[String] = ["blood:0", "blood:1"]


## What one played fight showed.
class Run:
	extends RefCounted
	var log_text := ""
	var drops_text := ""
	var drops: Array[Dictionary] = []
	var end_frames := 0
	var held := 0
	var big_hits := 0
	var hidden_until_land := true
	var flew := false
	var looks := true
	var texel := true
	var on_splat := true
	var shown_at_end := true
	var still_camera := true
	var held_after_big := true
	var behind := true
	var torso := false
	var along := false
	var counts := false
	var sizes: Array[int] = []
	var clear: Array[int] = []


func suite_name() -> String:
	return "Impact"


func run_checks() -> void:
	root.size = WINDOW_SIZE
	await _t("_test_data")
	await _t("_test_threshold")
	var on := await _play(true)
	var again := await _play(true)
	var off := await _play(false)
	_report(on, off)
	check(on.flew and on.drops.size() > 0, "blows throw drops that fly (%d)" % on.drops.size())
	check(on.hidden_until_land, "a splat shows only once its first drop has landed")
	check(on.shown_at_end, "every splat is on the field at the end and every drop has landed")
	check(on.on_splat, "every drop lands on one of its own splat's pixels (the splat spot)")
	check(on.looks, "a drop faces the camera, is one blood red, 1 to drop_px_max pixels square")
	check(on.texel, "a drop's pixel is the figures' pixel size where it flies")
	await _t("_test_shape", [on])
	check(on.drops_text == again.drops_text, "the same fight throws the same drops in two runs")
	check(on.log_text == off.log_text, "hit-stop on or off: the battle log is identical")
	check(on.held > 0 and off.held == 0, "hit-stop holds frames on (%d), none off" % on.held)
	check(
		on.end_frames > off.end_frames,
		"hit-stop lengthens the presentation (%d vs %d frames)" % [on.end_frames, off.end_frames]
	)
	check(on.big_hits > 0 and on.held_after_big, "the picture is held only after a big hit")
	check(on.still_camera, "a hit-stop holds the camera still (no screen shake)")
	check(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale is never touched")


## The spray as the lead's QC asked (round 1): count, sizes, torso start, burst, not over the body.
func _test_shape(on: Run) -> void:
	check(on.counts, "every hit throws 10 to 16 drops")
	check(on.sizes == [1, 2, 3], "drops come in mixed sizes, 1 to 3 pixels (%s)" % [on.sizes])
	check(on.torso, "drops leave the struck figure's picture at torso height")
	check(on.along, "drops burst out along the blow on screen, away from the attacker")
	check(Spray.spread_ok(on.drops), "each hit's drops spray out in a cone, not one line")
	check(
		on.clear[0] * 2 > on.drops.size() and on.clear[1] > 0 and on.clear[2] == on.clear[1],
		(
			"by their 3rd frame drops are out past the silhouette (%d of %d; sideways blows %d of %d)"
			% [on.clear[0], on.drops.size(), on.clear[2], on.clear[1]]
		)
	)
	check(on.behind, "a drop over the struck figure is drawn behind it (never over the body)")


## One line of figures for the PR's evidence.
func _report(on: Run, off: Run) -> void:
	print(
		(
			"IMPACT drops %d, clear by frame 3 %d (sideways %d of %d), frames on %d off %d, held %d"
			% [
				on.drops.size(),
				on.clear[0],
				on.clear[2],
				on.clear[1],
				on.end_frames,
				off.end_frames,
				on.held
			]
		)
	)


## The director's ruling in the data: a few frames, on by default.
func _test_data() -> void:
	var data := StageData.load_file(DATA_PATH)
	var frames := int(data.num("hit_stop", "frames"))
	check(
		frames >= SUBTLE_MIN_FRAMES and frames <= SUBTLE_MAX_FRAMES,
		"hit-stop is subtle: %d frames (3 to 5)" % frames
	)
	var on_text := var_to_str(data.section("hit_stop").get("on", false))
	check(on_text == "true", "hit-stop is on by default (data)")
	var settings := root.get_node_or_null(^"/root/Settings")
	var toggle := var_to_str(settings.get(&"hit_stop")) if settings != null else ""
	check(toggle == "true", "the player's toggle starts on")


## Big means damage at least min_damage, or at least max_hp_share of the target's health.
func _test_threshold() -> void:
	var data := StageData.load_file(DATA_PATH)
	var battle := Kit.fight(SEED).battle
	var impact := BattleImpact.new()
	var target := battle.units[0]
	var least := int(data.num("hit_stop", "min_damage"))
	var share := ceili(data.num("hit_stop", "max_hp_share") * target.max_hp)
	var hit := {"type": BattleMarks.EVENT_HIT, "target": target.id, "damage": least}
	check(impact.is_big(hit, battle), "a hit of min_damage is big")
	hit["damage"] = 1
	check(
		not impact.is_big(hit, battle),
		"a 1-damage hit on a %d-health fighter is not big" % [target.max_hp]
	)
	hit["damage"] = share
	check(impact.is_big(hit, battle), "a hit of max_hp_share of the target's health is big")


## Plays the slice's fight to its end with hit-stop on or off (the player's toggle), the
## player's turns as real clicks once the picture is not held.
func _play(hit_stop: bool) -> Run:
	var settings := root.get_node(^"/root/Settings")
	settings.set(&"hit_stop", hit_stop)
	var mounted := Kit.mount(self, SEED)
	var view := mounted.view
	var run := Run.new()
	var held_before := 0
	for _frame: int in FIGHT_FRAMES:
		if view.battle.is_over():
			break
		var actor := view.battle.current()
		var hits := view.marks.splats.size()
		var eye := mounted.stage.camera().global_transform
		if actor.side == BattleUnit.COMPANY and not view.impact.holding():
			await _company_turn(mounted, BattleAi.choose(view.battle, actor, Kit.sight()))
		else:
			await process_frame
		if view.impact.held_total > held_before:
			run.still_camera = run.still_camera and mounted.stage.camera().global_transform == eye
			held_before = view.impact.held_total
		run.big_hits += _big_hits(view, hits)
		_look(mounted, run)
	run.end_frames = view.impact.frames
	run.held = view.impact.held_total
	run.held_after_big = run.held <= run.big_hits * SUBTLE_MAX_FRAMES
	await InputKit.frames(self, SETTLE)
	_look(mounted, run)
	_check_landed(mounted, run)
	_check_spray(mounted, run)
	run.log_text = var_to_str(view.battle.log)
	run.drops.assign(view.impact.spray.drops.duplicate(true))
	run.drops_text = var_to_str(run.drops)
	view.clear()
	Kit.unmount(mounted)
	settings.set(&"hit_stop", true)
	await process_frame
	return run


## The spray's on-screen shape after the fight, before it is cleared (tests/lib/spray_checks.gd).
func _check_spray(mounted: Kit.Mounted, run: Run) -> void:
	var spray := mounted.view.impact.spray
	var share := StageData.load_file(DATA_PATH).num("spray", "torso_share")
	run.torso = Spray.torso_ok(spray, mounted.stage, share)
	run.along = Spray.along_blow_ok(spray, mounted.stage)
	run.clear = Spray.clear_counts(spray, mounted.stage)
	run.counts = Spray.counts_ok(spray.drops, MIN_DROPS, MAX_DROPS)
	run.sizes = Spray.sizes(spray.drops)


## How many of the splats laid since `before` came from a big hit.
func _big_hits(view: BattleView, before: int) -> int:
	var count := 0
	for i: int in range(before, view.marks.splats.size()):
		var splat: Dictionary = view.marks.splats[i]
		var hit := {"target": splat["unit"], "damage": splat["damage"]}
		count += 1 if view.impact.is_big(hit, view.battle) else 0
	return count


## One frame: splats hidden until a drop lands, and every drop in the air drawn right.
func _look(mounted: Kit.Mounted, run: Run) -> void:
	var spray := mounted.view.impact.spray
	var landed := {}
	for drop: Dictionary in spray.drops:
		if drop["landed"]:
			landed[drop["splat"]] = true
	for drop: Dictionary in spray.drops:
		var node := mounted.view.marks.node_of(mounted.view.marks.splats[Merc.whole(drop["splat"])])
		if node != null:
			var shown := landed.has(drop["splat"])
			run.hidden_until_land = run.hidden_until_land and node.visible == shown
	run.behind = run.behind and Spray.behind_ok(spray, mounted.stage)
	for number: int in spray.drops.size():
		var sprite := spray.node_of_drop(number)
		if sprite == null or not sprite.visible:
			continue
		run.flew = true
		run.looks = run.looks and _drop_looks(sprite)
		run.texel = run.texel and _texel_matches(mounted, sprite, spray.drops[number])


func _drop_looks(sprite: Sprite3D) -> bool:
	var data := StageData.load_file(DATA_PATH)
	var image := sprite.texture.get_image()
	var size_ok := image.get_width() == image.get_height()
	size_ok = size_ok and image.get_width() <= int(data.num("spray", "drop_px_max"))
	var colour := image.get_pixel(0, 0)
	var red := false
	for ref: String in DROP_REFS:
		red = red or colour.is_equal_approx(Palette.colour(ref))
	for y: int in image.get_height():
		for x: int in image.get_width():
			red = red and image.get_pixel(x, y) == colour
	return size_ok and red and sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED


## A drop's pixel against the struck fighter's figure pixel (same camera depth, near enough).
func _texel_matches(mounted: Kit.Mounted, sprite: Sprite3D, drop: Dictionary) -> bool:
	var fighter := mounted.view.battle.unit(str(drop["unit"]))
	var figure := mounted.stage.extra_mercs[mounted.view.battle.units.find(fighter)]
	return absf(sprite.pixel_size / figure.pixel_size - 1.0) < TEXEL_TOLERANCE


## After the fight: every drop landed on a solid pixel of its splat, at that pixel's ground point.
func _check_landed(mounted: Kit.Mounted, run: Run) -> void:
	var marks := mounted.view.marks
	var spray := mounted.view.impact.spray
	run.shown_at_end = spray.flying() == 0 and marks.splats.size() > 0
	for splat: Dictionary in marks.splats:
		var node := marks.node_of(splat)
		run.shown_at_end = run.shown_at_end and node != null and node.visible
	for drop: Dictionary in spray.drops:
		var splat: Dictionary = marks.splats[Merc.whole(drop["splat"])]
		var node := marks.node_of(splat)
		var pixel: Vector2i = drop["pixel"]
		var picture := marks.splat_image(
			Merc.whole(splat["index"]), Merc.whole(splat["damage"]), BattleSplat.FRESH
		)
		var land: Vector3 = drop["land"]
		var down: bool = drop["landed"]
		var spot := BattleSpray.pixel_point(node, pixel)
		var ends := spray.point_at(drop, 1.0)
		run.on_splat = (
			run.on_splat
			and down
			and picture.get_pixelv(pixel).a > MID
			and land.distance_to(spot) < LAND_TOLERANCE_M
			and ends.distance_to(land) < LAND_TOLERANCE_M
		)


func _company_turn(mounted: Kit.Mounted, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		mounted.view.click_cell(mounted.origin + to)
		await process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind != Battle.ACTION_WAIT and action.has("target"):
		# The weapon action BattleAi chose (kit(actor)[0]) or a learnt move: "<type>:<target>".
		choice_id = "%s:%s" % [kind, action.get("target")]
	await InputKit.click(self, mounted.panel.button_for(choice_id))
