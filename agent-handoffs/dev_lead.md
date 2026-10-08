# Dev Lead handoff, 2026-10-08 23:12 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), and `docs/08_ROADMAP.md` §Phase 1 only,
plus `docs/specs/phase1_visual_proof.md` §2 and §4.

## State: working (supervising two subagents)
## Task
The director said "go with your gut" for the next item, then "assign your cloud team tasks".
The STATUS lint-precision LOW item had already been fixed in #21, so I picked the remaining Dev parts of
sample set 2 (spec §4) and gave them to two Sonnet 5.5 cloud sessions (brief: at most two):
1. session_01NTHHy4PUyNqfaSsEbK3xep → branch `claude/p1-crisp-snap`: CRISP mode snaps the sprite to
   whole multiples of integer_scale window pixels (spec says texels land on screen pixels), fail-first
   stage checks, stage floor raised. Reports texels-per-pixel at the well and at both path ends; does not
   change pixel_size (director's Q4–Q6).
2. session_014RfFNQ279Tcmc3yNdR9nwy → branch `claude/p1-frame-time`: `--frametime=<frames>` in
   `tools/capture/capture_stage.gd`, writes a CPU/GPU ms JSON per mode. Container numbers are not
   representative; the sheet numbers come from the director's PC.
Neither opens a PR. Next: review both branches (re-run suites and lints), then ask the director before
opening PRs and hand them to Merge & CI. A check-in fires at 12:52Z (trigger trig_01SVochZpNNz5ztogFjY3WYU).
Not assigned to anyone: the rain-night stage variant that §4 also wants. Its look is visual, so ask the
Art agent and the director first.
## Branch and commit
This file on `main-xlcsi2` (cloud session branch). Main at 3a12d1b.
## Where my worktrees live
None. The cloud container is at /home/user/MERCS, with Godot 4.7.2 downloaded to /tmp/claude-0/godot
(reclaimed with the container).
## Files I own right now
None open. Subagents touch street_stage.gd, run_stage_tests.gd, expected_checks.txt, capture_stage.gd,
data/balance/stage.json.
## Unfinished changes
None.
## Evidence so far
Main 3a12d1b in the cloud: data 88 / 0, smoke 24 / 0, stage 39 / 0, harness self-test passed;
run_all.sh 9 of 9 PASS.
## Attempts (for the fix-loop rule)
None open.
## Open decisions
- STATUS still shows the Dev Lead "awaiting merge" on #21, which has merged. Merge & CI should update the row.
- Spec §4 Mode B wants "exact 3×" texels, which a perspective camera gives only at one depth. Wait for
  subagent 1's measurement, then raise it with the Concept Lead if it matters.
## Running jobs
Two cloud sessions (above). No local Godot process.
## Rules learnt the hard way (keep under 10 lines)
- A failed `cd` in a multi-line Bash call does not stop it: `cd X || exit 1`, or absolute paths.
- Godot 4.7 flags int()/float() of a Variant as an unsafe call argument: assign to a typed local.
- Prove compile failures with `--check-only` in a separate process.
- Count checks per rule, not per file or entry.
- Cloud containers can download Godot 4.7.2 from GitHub releases and run all suites headless.
