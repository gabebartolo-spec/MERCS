# Dev Lead handoff, 2026-10-08 01:30 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), and `docs/08_ROADMAP.md` §Phase 0 only.

## State: available
## Task
STATUS items 3, 4 and 7 (Phase 0): all three done and handed to Merge & CI. Nothing else is
assigned to the Dev Lead. Next, when asked: answer review on #4, #5 and #6, then assemble the
Phase 0 evidence pack for the gate review (item 8).
## Branch and commit
- Item 3: claude/p0-scaffold, worktree ../MERCS-wt/p0-scaffold, PR #4. CI green on e036606
  (tests run 37632982389, build run 37632982535).
- Item 4: claude/p0-lints, worktree ../MERCS-wt/p0-lints, PR #5.
- Item 7: claude/p0-skills, worktree ../MERCS-wt/p0-skills, PR #6.
All three tips end with the same commit content in docs/STATUS.md (one identical Dev Lead row),
so the three merge cleanly with each other in any order.
## Files I own right now
project.godot, export_presets.cfg, data/, presentation/autoload/, ui/screens/main.tscn, tests/,
tools/run_tests.sh, tools/test_run_tests.sh, tools/check_ci_shards.sh, tools/ci_shards.txt,
tools/lint/, .claude/skills/, .claude/.gdignore, agent-handoffs/dev_lead.md, and
.github/workflows/tests.yml and build.yml (written under item 3; Merge & CI maintains them).
## Unfinished changes
None. If #1 merges first, rebase each branch onto main: the one conflict is the STATUS.md Dev
Lead row beside the Merge & CI row #1 changed. Keep both rows.
## Evidence so far
- #4: data 88 checks / 0 failures, smoke 26 / 0, harness self-test 5/5, locally and in CI.
  Fail-first at fec562a. Planted and rejected: untyped var (in an autoload the import fails; in
  a sim script the smoke suite names it), a seventh autoload, a relaxed typing rule, an id
  without its prefix, a shard map missing a suite. Windows export 109 MB; headless launch loads
  res://ui/screens/main.tscn; CI uploads MERCS-windows.
- #5: test_lints.py 10 of 10 fixtures exact (0 of 10 at 8fd7f40, before any lint existed).
  The lints pass on #4's scaffold and reject a clock read in sim/ and a Color() in ui/ planted
  into a copy of it.
- #6: frontmatter and names checked, every cited path exists, no AFL vocabulary left.
## Attempts (for the fix-loop rule)
None open.
## Open decisions
No director questions. Findings for the Concept Lead (pack owner), none blocking Phase 0:
1. The autoload `Rng` (B8, roadmap) and a sim class `Rng` (05 layout, `Rng.from_seed`) cannot
   both exist: Godot rejects a class_name equal to an autoload name. Suggest the sim stream
   class be `RngStream` in sim/core/rng.gd. Decide before Phase 1 writes it.
2. 05 "Naming" says snake_case files; 05's layout, B2, D3, 06 and 07 say Rng.gd, UiKit.gd,
   Text.gd, CharacterSheets.gd. I followed the naming rule; the lints accept either spelling
   for the Rng and UiKit owners.
3. 05 puts Text.gd in ui/, but B12 has presentation/ call Text.t, which layering forbids
   (presentation may not use a ui class). Text belongs in presentation/ or lower.
4. Unassigned Phase 0 deliverables: gdlint/gdformat config and its CI step, assets.yml, the
   docs/godot-api/ doctool dump (B4).
5. 05 "Tests" lists suites "from Phase 0" that cannot exist yet, and omits smoke.
6. 06 and 07 disagree: skin recoloured by shader or not (06 §2 vs §3); Phase 1 clip count
   (06 §3 lists 6, 07 §2.2 lists 14); 48 px average height vs "1 m = 24 px" (06 §3).
7. CLAUDE.md calls a roadmap over 400 lines a docs bug; 03 caps the roadmap at 600.
8. 09 still says private and 2,000 Actions minutes; D-016 in #1 makes the repo public.
Sent to Merge & CI with the hand-off: #1 and #2 both add a D-016; lint.yml needs
`bash tools/lint/run_all.sh` as a required job; their brief's agent-handoffs seeding is done in #6.
## Running jobs
None. Every Godot run went through `timeout`; nothing is left running.
## Rules learnt the hard way (keep under 10 lines)
- A failed `cd` in a multi-line Bash call does not stop it here: `cd X || exit 1`, or absolute paths.
- This Bash tool's heredocs turn `\\` into `\`: write JSON with regex escapes via Write or Python.
- Godot 4.7 flags int()/float() of a Variant as an unsafe call argument: assign to a typed local.
- `--editor --import` compiles autoloads only; the smoke suite's compile-all catches the rest.
- GDScript.reload() of a broken script prints SCRIPT ERROR into the suite log: prove compile
  failures with `--check-only` in a separate process (tools/test_run_tests.sh does).
- Count checks per rule, not per file or entry, or content changes trip the floors.
