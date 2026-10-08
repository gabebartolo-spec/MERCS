#!/usr/bin/env bash
# Sample set 2 (docs/specs/phase1_visual_proof.md section 4): pixel mode A (whole screen)
# vs B (crisp world), day and rain-night, plus the depth-scale comparison found in PR #24.
# Windowed Godot runs, one at a time, isolated APPDATA. Writes stills, frame times and
# clip frames to OUT (default: a temp dir), then builds the labelled sheets.
#   GODOT=<console exe> bash tools/capture/sample_set_2.sh [OUT]
set -euo pipefail
GODOT="${GODOT:?set GODOT to the Godot 4.7.2 console executable}"
OUT="${1:-$(mktemp -d)}"
SHEET="res://tests/fixtures/pipeline/sheets/good/average_m_body_rest.json"
SCRATCH="$(mktemp -d)"
STAND="2.5,0.5"          # beside the well, near the look-at depth
NEAR="-2,4"              # 4 m nearer the camera than the look-at point
FAR="-2,-2.5"            # in front of the far houses
WALK_START=12.5          # seconds of walk before the clip: approaching the well
CLIP_REGION="960,600,720,320"
mkdir -p "$OUT/stills" "$OUT/depth" "$OUT/clips"
: > "$OUT/frame_times.txt"

capture() {  # capture <out.png> <args...>
	local out="$1"; shift
	APPDATA="$SCRATCH" "$GODOT" --path . --resolution 1920x1080 \
		--script tools/capture/capture_stage.gd -- --pitch=35 --height=48 --sheet="$SHEET" \
		--facing=S --out="$out" "$@" 2>&1 | grep -E "saved|frame_time|ERROR" || true
}

for mode in whole crisp; do
	for light in day rain_night; do
		line=$(capture "$OUT/stills/${mode}_${light}.png" --mode=$mode --lighting=$light \
			--at=$STAND --frametime=300 | grep frame_time || true)
		echo "$mode $light $line" | tee -a "$OUT/frame_times.txt"
		capture "$OUT/clips/${mode}_${light}.png" --mode=$mode --lighting=$light \
			--walk=$WALK_START --sequence=3 --fps=20 --region=$CLIP_REGION > /dev/null
	done
done
for depth in perspective constant; do
	for spot in near far; do
		at=$NEAR; [ "$spot" = far ] && at=$FAR
		capture "$OUT/depth/${depth}_${spot}.png" --mode=whole --at=$at --depth=$depth > /dev/null
	done
done
python -I tools/capture/sample_sheet.py "$OUT"
echo "sample set 2 in $OUT"
