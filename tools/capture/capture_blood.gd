extends SceneTree
## Captures the slice's fight with its blood and bodies (Phase 4 P6b): a flash frame at the
## first wound, the field mid-fight, and the field at the end, as full frames and a 2x crop of
## the battle area. Runs with a window (not --headless); the fight is played by BattleAi with
## the player's turns sent as the panel's choices, so the captures are the same fight every run.
##
##   APPDATA=<scratch> godot --path . --resolution 3840x2160 \
##     --script tools/capture/capture_blood.gd -- --out=<dir> [--seed=1009] [--mid_hits=4]
##
## Writes <dir>/flash.png, mid.png, end.png (full frame) and the same names with _crop.

const Kit := preload("res://tests/lib/battle_view_kit.gd")
const InputKit := preload("res://tests/lib/input_kit.gd")
const DEFAULT_SEED := 1009
const DEFAULT_MID_HITS := 4
const SHOW_SCALE := 4
const CROP := Rect2i(160, 140, 640, 400)
const SETTLE_FRAMES := 30
const FIGHT_FRAMES := 6000

var _args: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out := str(_args.get("out", "user://blood"))
	DirAccess.make_dir_recursive_absolute(out)
	var mounted := Kit.mount(self, int(str(_args.get("seed", DEFAULT_SEED))))
	var view := mounted.view
	var battle := view.battle
	var mid_hits := int(str(_args.get("mid_hits", DEFAULT_MID_HITS)))
	var flashed := false
	var mid_done := false
	for _frame: int in FIGHT_FRAMES:
		if battle.is_over():
			break
		mounted.stage.focus_on(view.centre())
		var actor := battle.current()
		if actor.side == BattleUnit.COMPANY:
			await _company_turn(mounted, BattleAi.choose(battle, actor, Kit.sight()))
		else:
			await process_frame
		if not flashed and view.fx().active() > 0:
			flashed = true
			await process_frame
			_save(out, "flash", mounted)
		if not mid_done and view.marks().splats.size() >= mid_hits and view.fx().active() == 0:
			mid_done = true
			await InputKit.frames(self, SETTLE_FRAMES)
			_save(out, "mid", mounted)
	await InputKit.frames(self, SETTLE_FRAMES)
	_save(out, "end", mounted)
	print(
		(
			"splats %d bodies %d over %s"
			% [view.marks().splats.size(), view.marks().bodies.size(), out]
		)
	)
	quit(0)


## The street's own logical image (the window's copy is cropped by the container), shown at
## whole 4x: one art pixel is a 4x4 block; and a crop of the battle area.
func _save(out: String, name: String, mounted: Kit.Mounted) -> void:
	var holder := mounted.stage.find_child("LogicalViewport", true, false) as SubViewport
	var logical := holder.get_texture().get_image()
	var big := logical.duplicate() as Image
	big.resize(
		logical.get_width() * SHOW_SCALE,
		logical.get_height() * SHOW_SCALE,
		Image.INTERPOLATE_NEAREST
	)
	big.save_png(out.path_join(name + ".png"))
	var crop := logical.get_region(CROP)
	crop.resize(
		crop.get_width() * SHOW_SCALE, crop.get_height() * SHOW_SCALE, Image.INTERPOLATE_NEAREST
	)
	crop.save_png(out.path_join(name + "_crop.png"))


func _company_turn(mounted: Kit.Mounted, action: Dictionary) -> void:
	var kind := str(action.get("type", ""))
	if kind == Battle.ACTION_MOVE:
		var to: Vector2i = action.get("to", Vector2i.ZERO)
		mounted.view.click_cell(mounted.origin + to)
		await process_frame
		return
	var choice_id := Battle.ACTION_WAIT
	if kind == Battle.ACTION_ATTACK:
		choice_id = "%s:%s" % [Battle.ACTION_ATTACK, action.get("target")]
	mounted.panel.chosen.emit(choice_id)
	await process_frame
