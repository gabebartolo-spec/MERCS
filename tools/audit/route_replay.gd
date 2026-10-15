extends SceneTree
## Evidence for the Phase 2 gate (docs/audits/phase2_gate/structural_evidence.md, gap 3): one
## of the routes in tests/lib/route_kit.gd played from a seed in this process, its final save
## written for comparison. tools/audit/route_replay.sh runs each route twice in two processes
## and compares the files' md5. Every line it prints starts "AUDIT ". Tooling only.
##   godot --headless --path . --script tools/audit/route_replay.gd -- loss 424308 <out_file>

const Routes := preload("res://tests/lib/route_kit.gd")


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or args[0] not in Routes.ROUTES:
		print("AUDIT usage: <route> <seed> <out_file>")
		quit(1)
		return
	var played := Routes.run(args[0], args[1].to_int())
	var text: String = played["save"]
	print("AUDIT route %s stages %s" % [args[0], JSON.stringify(played["stages"])])
	var file := FileAccess.open(args[2], FileAccess.WRITE)
	if file == null:
		print("AUDIT cannot write %s" % args[2])
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("AUDIT wrote %s md5 %s" % [args[2], text.md5_text()])
	quit(0)
