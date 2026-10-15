extends SceneTree
## Captures one big hit of the slice's fight (Phase 4 P6c): the hit-stop frame, the drops out past
## the silhouette (3 frames on), mid-arc, landing, and the stain they leave, as full frames of the
## street's logical image shown at a whole-number scale and 2x crops framing the attacker and the
## struck fighter together (so the blow's direction reads). Runs with a window (not
## --headless); the fight is played by BattleAi with the player's turns sent as the panel's
## choices, so the captures are the same fight every run. The view's processing is paused while
## a picture is read back, so the five stages are the visual times named below.
##
##   APPDATA=<scratch> godot --path . --fixed-fps 60 --resolution 1920x1080 \
##     --script tools/capture/capture_impact.gd -- --out=<dir> [--seed=1009] [--hit=1]
##
## --hit counts the big hits whose blow runs across the screen (attacker beside the target, so
## the direction reads); a blow along the camera's view is skipped.
##
## Writes <dir>/1_hold.png, 2_out.png, 3_midarc.png, 4_landing.png, 5_stain.png, each with _crop.

const Kit := preload("res://tests/lib/battle_view_kit.gd")
const DEFAULT_SEED := 1009
const WINDOW_SIZE := Vector2i(1920, 1080)
const DEFAULT_HIT := 1
const UHD_WIDTH := 3840
## Logical pixels of ground kept around the two figures in the crop.
const CROP_PAD_PX := 120
const CROP_ZOOM := 2
const FIGHT_FRAMES := 20000
## Frames run after the hit-stop ends before each later picture (60 fps; the flight is 24).
const OUT_FRAMES := 3
const MIDARC_FRAMES := 3
const LANDING_FRAMES := 17
const STAIN_FRAMES := 40

var _args: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	root.size = WINDOW_SIZE
	await process_frame
	var out := str(_args.get("out", "user://impact"))
	DirAccess.make_dir_recursive_absolute(out)
	var mounted := Kit.mount(self, int(str(_args.get("seed", DEFAULT_SEED))))
	var view := mounted.view
	var wanted := int(str(_args.get("hit", DEFAULT_HIT)))
	var seen := 0
	for _frame: int in FIGHT_FRAMES:
		if view.battle.is_over():
			break
		mounted.stage.focus_on(view.centre())
		var actor := view.battle.current()
		if actor.side == BattleUnit.COMPANY and not view.impact.holding():
			_company_turn(mounted, BattleAi.choose(view.battle, actor, Kit.sight()))
		if view.impact.holding() and _sideways(mounted):
			seen += 1
			if seen == wanted:
				await _shoot(out, mounted)
				break
			while view.impact.holding():
				await process_frame
		await process_frame
	quit(0)


## Whether the blow now held runs more across the screen than along it.
func _sideways(mounted: Kit.Mounted) -> bool:
	var splat: Dictionary = mounted.view.marks.splats[-1]
	var attacker := mounted.view.battle.unit(str(splat["by"]))
	var struck := mounted.view.battle.unit(str(splat["unit"]))
	if attacker == null or struck == null:
		return false
	var camera := mounted.stage.camera()
	var step := (
		camera.unproject_position(mounted.view.world_point(struck.cell))
		- camera.unproject_position(mounted.view.world_point(attacker.cell))
	)
	return absf(step.x) > absf(step.y)


## The five pictures of the hit now being held.
func _shoot(out: String, mounted: Kit.Mounted) -> void:
	var view := mounted.view
	var splat: Dictionary = view.marks.splats[-1]
	print("big hit: %s on %s, damage %s" % [splat["by"], splat["unit"], splat["damage"]])
	var area := _frame_both(mounted, str(splat["by"]), str(splat["unit"]))
	await _save(out, "1_hold", mounted, area)
	while view.impact.holding():
		await process_frame
	await _run_frames(OUT_FRAMES)
	await _save(out, "2_out", mounted, area)
	await _run_frames(MIDARC_FRAMES)
	await _save(out, "3_midarc", mounted, area)
	await _run_frames(LANDING_FRAMES)
	await _save(out, "4_landing", mounted, area)
	await _run_frames(STAIN_FRAMES)
	await _save(out, "5_stain", mounted, area)


## The logical pixels covering the attacker's and the struck fighter's figures, padded.
func _frame_both(mounted: Kit.Mounted, by: String, struck: String) -> Rect2i:
	var area := Rect2()
	for unit_id: String in [by, struck]:
		var fighter := mounted.view.battle.unit(unit_id)
		if fighter == null:
			continue
		var sprite := mounted.stage.extra_mercs[mounted.view.battle.units.find(fighter)]
		var rect: Rect2 = BattleDropAim.figure(mounted.stage, sprite, 0.0)["rect"]
		area = rect if area.size == Vector2.ZERO else area.merge(rect)
	return Rect2i(area.grow(CROP_PAD_PX))


func _run_frames(count: int) -> void:
	for _i: int in count:
		await process_frame


## The street's own logical image at a whole-number scale to 4K width, and a 2x crop of the
## area; the view is paused while it is read back.
func _save(out: String, name: String, mounted: Kit.Mounted, area: Rect2i) -> void:
	mounted.view.set_process(false)
	await RenderingServer.frame_post_draw
	var holder := mounted.stage.find_child("LogicalViewport", true, false) as SubViewport
	holder.get_texture().get_image()  # the first read of a texture can return an old frame
	await RenderingServer.frame_post_draw
	var logical := holder.get_texture().get_image()
	mounted.view.set_process(true)
	var scale := maxi(1, UHD_WIDTH / logical.get_width())
	var big := logical.duplicate() as Image
	big.resize(logical.get_width() * scale, logical.get_height() * scale, Image.INTERPOLATE_NEAREST)
	big.save_png(out.path_join(name + ".png"))
	var inside := area.intersection(Rect2i(Vector2i.ZERO, logical.get_size()))
	var crop := logical.get_region(inside)
	var zoom := scale * CROP_ZOOM
	crop.resize(crop.get_width() * zoom, crop.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join(name + "_crop.png"))
	print("%s: logical %s, crop %s at x%d" % [name, logical.get_size(), inside, zoom])


func _company_turn(mounted: Kit.Mounted, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		mounted.view.click_cell(mounted.origin + to)
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	mounted.panel.chosen.emit(choice_id)
