# Dev Lead handoff, 2026-10-08 03:50 AEDT
Start from this file, CLAUDE.md, your brief (`agent-briefs/DEV_LEAD_OPUS.md`), and `docs/08_ROADMAP.md` §Phase 0 only.

## State: available
## Task
STATUS items 3, 4 and 7 (Phase 0): done, the Concept Lead's pre-merge rulings (D-021, in PR #2)
applied, and all three handed to Merge & CI. Waiting on merges. What comes next, in order:
1. After #4 merges: rebase #5 and #6 onto main. They have no CI until then (no workflow on main).
2. If #1 merges without a `bash tools/lint/run_all.sh` job in lint.yml: open a tiny follow-up PR
   adding it (D-021 item 9; the gate needs the lints in CI).
3. Once #1, #4 and #5 are on main: run `docs/audits/phase0_gate_plan.md` (in PR #2): sixteen
   planted violations on one never-merged branch, each with its expected rejecting check, plus
   a clean PR and a launch screenshot.
4. Do not start Phase 1 (`docs/specs/phase1_visual_proof.md`) until the gate is recorded PASS.
## Branch and commit
- Item 3: claude/p0-scaffold at d6f4a48, PR #4. CI green on e036606 (tests run 37632982389,
  build run 37632982535); d6f4a48 removes the Rng autoload per D-021.
- Item 4: claude/p0-lints at 7e864b4, PR #5.
- Item 7: claude/p0-skills (this commit), PR #6.
## Where my worktrees live (D-021 item 3: both places count toward four)
- `.claude/worktrees/mercs-dev-lead-setup-0b99b1`: this app session's own worktree, used for nothing.
- `../MERCS-wt/p0-scaffold`: one worktree for all three branches, checked out in turn. I removed
  p0-lints and p0-skills (clean, pushed) to get from six live worktrees back to four, and remove
  p0-scaffold at the end of this session. Recreate one when a task above needs it.
## Files I own right now
project.godot, export_presets.cfg, data/, presentation/autoload/, ui/screens/main.tscn, tests/,
tools/run_tests.sh, tools/test_run_tests.sh, tools/check_ci_shards.sh, tools/ci_shards.txt,
tools/lint/, .claude/skills/, .claude/.gdignore, agent-handoffs/dev_lead.md, and
.github/workflows/tests.yml and build.yml (written under item 3; Merge & CI maintains them).
## Unfinished changes
None. After #1 merges, each of my branches has a one-line STATUS.md conflict next to the
Merge & CI row: keep both rows.
## Evidence so far
- #4: data 88 / 0, smoke 24 / 0 (26 before the Rng autoload left), harness self-test 5/5,
  locally and in CI. Planted and rejected: untyped var (in an autoload the import fails, in a sim
  script the smoke suite names it), an extra autoload, re-adding Rng, a relaxed typing rule, an
  id without its prefix, a shard map missing a suite. The exported build loads main.tscn headless.
- #5: test_lints.py 10 of 10 fixtures exact; fail-first commits 8fd7f40 (0 of 10) and 9cfdcbf
  (8 of 10, for the rulings). Lints pass on #4's scaffold and reject a clock read in sim/ and a
  Color() in ui/. Live repo: 4 of 4 worktrees.
- #6: frontmatter and names checked, every cited path exists, no AFL vocabulary left.
## Attempts (for the fix-loop rule)
None open.
## Open decisions
No director questions. D-021 settled my findings on the Rng autoload, file naming and the
worktree count. Still with the Concept Lead unless PR #2 covers them:
1. 05 puts Text.gd in ui/, but B12 has presentation/ call Text.t, which layering forbids.
2. Unassigned Phase 0 pieces: gdlint/gdformat config and CI step, assets.yml, docs/godot-api/.
3. 05 "Tests" lists suites "from Phase 0" that cannot exist yet, and omits smoke.
4. 06 and 07 disagree on skin recolouring, the Phase 1 clip count (6 vs 14) and 48 px vs 1 m = 24 px.
Lint precision gaps are logged as a Phase 1 LOW item in STATUS.md (#5).
## Running jobs
None. Every Godot run went through `timeout`; nothing is left running.
## Rules learnt the hard way (keep under 10 lines)
- A failed `cd` in a multi-line Bash call does not stop it here: `cd X || exit 1`, or absolute paths.
- This Bash tool's heredocs turn `\\` into `\`: write JSON with regex escapes via Write or Python.
- `git checkout` here writes CRLF (autocrlf=true, no .gitattributes before #1): normalise before
  exact-text edits. Git Bash still runs CRLF .sh files.
- Godot 4.7 flags int()/float() of a Variant as an unsafe call argument: assign to a typed local.
- `--editor --import` compiles autoloads only; the smoke suite's compile-all catches the rest.
- Prove compile failures with `--check-only` in a separate process: an in-process reload of a
  broken script prints SCRIPT ERROR into the suite log.
- Count checks per rule, not per file or entry; fixtures and schemas each add their own checks.
