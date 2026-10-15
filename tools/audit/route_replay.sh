#!/usr/bin/env bash
# Phase 2 gate, structural audit evidence (gap 3): each route of tests/lib/route_kit.gd (a lost
# fight, a patrol's toll paid, a second fight, the campaign's end) played from one seed in two
# Godot processes, final save md5 compared; another seed must differ. Every Godot process gets
# its own APPDATA; processes run in parallel, waited on by PID.
#   GODOT=/path/to/godot tools/audit/route_replay.sh [out_dir]
# Exits nonzero when any comparison fails.
set -u
cd "$(dirname "$0")/../.." || exit 1
GODOT="${GODOT:-godot}"
SEED="${SEED:-424308}"
OTHER_SEED="${OTHER_SEED:-424316}"
OUT="${1:-$(mktemp -d)}"
ROUTES=(loss toll second_fight wipe)
native() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

play() { # route, seed, tag: the save in $OUT/<route>_<tag>.json, the log beside it
	local name="$1_$3"
	mkdir -p "$OUT/$name.appdata"
	APPDATA="$(native "$OUT/$name.appdata")" XDG_DATA_HOME="$OUT/$name.appdata" \
		timeout 600 "$GODOT" --headless --path . --script tools/audit/route_replay.gd -- \
		"$1" "$2" "$(native "$OUT/$name.json")" > "$OUT/$name.log" 2>&1
}

pids=()
for route in "${ROUTES[@]}"; do
	play "$route" "$SEED" a &
	pids+=($!)
	play "$route" "$SEED" b &
	pids+=($!)
	play "$route" "$OTHER_SEED" other &
	pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done

md5_of() { [ -f "$1" ] && md5sum "$1" | cut -c1-32 || echo missing; }
failed=0
echo "| Route | Seed $SEED process A | Seed $SEED process B | Seed $OTHER_SEED | Result |"
echo "|---|---|---|---|---|"
for route in "${ROUTES[@]}"; do
	a=$(md5_of "$OUT/${route}_a.json")
	b=$(md5_of "$OUT/${route}_b.json")
	o=$(md5_of "$OUT/${route}_other.json")
	verdict=FAIL
	[ "$a" != missing ] && [ "$a" = "$b" ] && [ "$a" != "$o" ] && [ "$o" != missing ] && verdict=pass
	[ "$verdict" = FAIL ] && failed=1
	printf '| %s | %s | %s | %s | %s |\n' "$route" "$a" "$b" "$o" "$verdict"
done
echo "Stages reached (process A):"
grep -H "AUDIT route" "$OUT"/*_a.log | sed "s#$OUT/##"
echo "Script errors in any log:"
grep -lE "SCRIPT ERROR|Parse Error" "$OUT"/*.log || echo "none"
echo "Logs and saves: $OUT"
exit "$failed"
