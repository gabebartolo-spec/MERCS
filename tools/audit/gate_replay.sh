#!/usr/bin/env bash
# Phase 2 gate, structural audit evidence (docs/audits/phase2_gate/structural_evidence.md):
#   1. the same seed replays the same campaign: tools/audit/gate_replay.gd "full" run twice in
#      two Godot processes, final saves compared by md5 (and a second seed must differ);
#   2. save, reload and continue from every milestone's state: for each checkpoint a "split"
#      process writes the save, a separate "resume" process reads it and plays on to the end;
#      its final save must equal the uninterrupted run's, byte for byte.
# Both with Ironman Off and On; with On, two more checkpoints inside the fight (M4).
# Every Godot process gets its own APPDATA; processes run in parallel, waited on by PID.
#   GODOT=/path/to/godot tools/audit/gate_replay.sh [out_dir]
# Exits nonzero when any comparison fails.
set -u
cd "$(dirname "$0")/../.." || exit 1
GODOT="${GODOT:-godot}"
SEED="${SEED:-424308}"
OTHER_SEED="${OTHER_SEED:-424316}"
OUT="${1:-$(mktemp -d)}"
CHECKPOINTS=(m1_world m2_encounter m5_triage m6_hub m3_office m7_memory m7_storylet)
native() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi; }

godot_run() { # name, then the script's arguments; log in $OUT/<name>.log
	local name="$1"
	shift
	mkdir -p "$OUT/$name/appdata"
	APPDATA="$(native "$OUT/$name/appdata")" XDG_DATA_HOME="$OUT/$name/appdata" \
		timeout 600 "$GODOT" --headless --path . --script tools/audit/gate_replay.gd -- "$@" \
		> "$OUT/$name.log" 2>&1
}

pair() { # name, ironman, checkpoint, [fight action]: split then resume, two processes
	local name="$1" ironman="$2" cp="$3" act="${4:-}"
	godot_run "${name}_split" split "$SEED" "$ironman" "$cp" "$OUT/${name}_split" $act
	godot_run "${name}_resume" resume "$cp" "$OUT/${name}_split/cp_$cp.json" "$OUT/${name}_resume"
}

md5_of() { [ -f "$1" ] && md5sum "$1" | cut -c1-32 || echo missing; }

pids=()
for iron in 0 1; do
	godot_run "full_i${iron}_a" full "$SEED" "$iron" "$OUT/full_i${iron}_a" &
	pids+=($!)
	godot_run "full_i${iron}_b" full "$SEED" "$iron" "$OUT/full_i${iron}_b" &
	pids+=($!)
	godot_run "full_i${iron}_other" full "$OTHER_SEED" "$iron" "$OUT/full_i${iron}_other" &
	pids+=($!)
	for cp in "${CHECKPOINTS[@]}"; do
		pair "i${iron}_$cp" "$iron" "$cp" &
		pids+=($!)
	done
done
for pid in "${pids[@]}"; do wait "$pid"; done

# The fight's length and its first company fall, read from the uninterrupted Ironman run.
read -r total down < <(grep -oE "fight_actions [0-9]+ first_company_down -?[0-9]+" \
	"$OUT/full_i1_a.log" | awk '{print $2, $4}')
mid=$((total / 2))
after_fall=$((down + 1))
pair "i1_m4_fight_mid" 1 m4_fight "$mid" &
p1=$!
pair "i1_m4_fight_fall" 1 m4_fight "$after_fall" &
p2=$!
wait "$p1"
wait "$p2"

failed=0
row() { # label, expected file, actual file, want same (1) or different (0)
	local a b verdict
	a=$(md5_of "$2")
	b=$(md5_of "$3")
	if [ "$a" = missing ] || [ "$b" = missing ]; then
		verdict=FAIL
	elif [ "$4" = 1 ] && [ "$a" = "$b" ]; then
		verdict=pass
	elif [ "$4" = 0 ] && [ "$a" != "$b" ]; then
		verdict=pass
	else
		verdict=FAIL
	fi
	[ "$verdict" = FAIL ] && failed=1
	printf '| %s | %s | %s | %s |\n' "$1" "$a" "$b" "$verdict"
}
echo "fight: $total actions, first company merc down at action $down (Ironman run)"
echo "| Comparison | Expected md5 | Got md5 | Result |"
echo "|---|---|---|---|"
for iron in 0 1; do
	base="$OUT/full_i${iron}_a/final.json"
	row "Ironman $iron: same seed $SEED, process B" "$base" "$OUT/full_i${iron}_b/final.json" 1
	row "Ironman $iron: seed $OTHER_SEED differs" "$base" "$OUT/full_i${iron}_other/final.json" 0
	cps=("${CHECKPOINTS[@]}")
	[ "$iron" = 1 ] && cps+=(m4_fight_mid m4_fight_fall)
	for cp in "${cps[@]}"; do
		file_cp="$cp"
		case "$cp" in m4_fight_*) file_cp=m4_fight ;; esac
		row "Ironman $iron: reload at $cp" "$base" "$OUT/i${iron}_${cp}_resume/resumed_$file_cp.json" 1
	done
done
echo "Reload writes the save it read (canonical JSON):"
grep -H "reload_writes_same_save" "$OUT"/*_resume.log | sed "s#$OUT/##"
echo "Script errors in any log:"
grep -lE "SCRIPT ERROR|Parse Error" "$OUT"/*.log || echo "none"
echo "Logs and saves: $OUT"
exit "$failed"
