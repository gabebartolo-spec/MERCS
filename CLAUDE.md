# MERCS: working rules for every Claude Code session

Godot 4.7.2, GDScript (static typing on). Windows PC first. Read this file, then your brief in
`agent-briefs/`, then only the roadmap phase you were assigned (`docs/08_ROADMAP.md`, by section).
Never read `docs/08_ROADMAP.md` or `docs/STATUS.md` whole if they exceed 400 lines; that is a bug
in the docs, report it to the Merge & CI agent.

## Philosophy (permanent)

**Designed by a person, developed with AI, never designed by AI.** The director supplies vision,
taste and final judgement. Agents supply execution, evidence and honest pushback.

- **The mercenaries are the game.** Every system is judged by whether it makes one of the
  hand-made mercs more memorable. A system that does not change what the player sees, decides or
  remembers is cut, not polished.
- **A roadmap item is context, not authorisation.** Start only what the director or the Dev Lead
  assigned. When an assigned task is done: stop, report with evidence, recommend the next step,
  wait.
- **Simplest viable option first.** Prefer the version with fewer systems, fewer numbers and fewer
  files. Challenge over-ambitious items and say what the simpler alternative is.
- **Challenge the director** when a request conflicts with these rules, the vision in
  `docs/00_VISION.md` or a guardrail. Say so in one paragraph, propose the better option, then do
  what the director decides.
- **Ask, don't ponder.** When the next step depends on a judgement call that is the director's,
  ask at once using `agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md`. Never park a question in a
  wall of text, and never guess at a visual decision.

## Hard rules

1. **No runtime AI.** No LLM, diffusion or network model in the shipped game, ever. AI is a
   development tool only.
2. **Determinism.** Every simulation path is seeded and replayable. A test that uses the clock is
   a bug. A flaky test is a seed to pin, not a rerun.
3. **Sim is the authority.** `sim/` has no Node, Scene, Viewport or UI dependency and runs headless.
   Presentation reads sim events; it never decides outcomes. If presentation and sim disagree,
   presentation yields.
4. **Data, not code, holds content.** Backgrounds, traits, equipment, storylets, injuries, factions
   and balance numbers live in `data/` (JSON validated by schema). Magic numbers in GDScript are
   rejected in review.
5. **Mortality is final.** No resurrection, no respawn, no save-scum helpers built in.
6. **The AI opponent is not psychic.** Enemy factions and units act only on information they
   could plausibly have.
7. **Licensing.** Nothing enters `assets/` or `tools/` unless `docs/10_LICENSING_REGISTER.md`
   lists it as CLEARED. Qwen-Image 2.1 and Anima are BANNED for anything that touches the product.
8. **No spend.** No paid API call, credit purchase, subscription or model download over 10 GB
   without the director's written yes in `docs/DECISIONS.md`. Exception (D-014): Tripo credits
   already exist; a session that would spend more than 500 of them asks first.
9. **Proof before "done".** A change is done when its evidence is in the PR body
   (`agent-briefs/HANDOFF_TEMPLATE.md` section "Evidence"). "It works" is not evidence; what the
   game did is.
10. **Change method after two failed fixes.** After two similar failed attempts at the same problem,
    stop patching. Gather different evidence (a capture, a trace, a minimal reproduction) and
    rethink before trying again.

## Machine rules (shared PC, one GPU)

- One Godot process per agent at a time. Isolate every run: `APPDATA=<your scratch dir>`.
  Never kill Godot by image name; kill by the PID you recorded.
- ComfyUI and Blender renders are the Art agent's. Other agents do not start GPU jobs.
- Worktrees: `git worktree add -b claude/<topic> ../MERCS-wt/<topic> origin/main`, or the app's
  own `.claude/worktrees/`. Remove the worktree when the PR merges. More than four live worktrees
  in total is a violation; the Merge & CI agent prunes.
- Only the Merge & CI agent edits `docs/STATUS.md` and `docs/DECISIONS.md`, in a docs-only board
  PR after each merge. Every other PR leaves those files alone and states its status and decision
  changes in the PR body ("Board and log" section). This is what stops PRs conflicting.
- Windows line endings: edit with tools that preserve them; never commit a whole-file CRLF flip.
- Bash heredocs choke on long GDScript. Write a scratch file and run it.
- Stage files by name. Never `git add -A`. Revert `.import` churn before committing.

## Style

Code: `docs/05_STYLE_CODE.md`. Art: `docs/06_STYLE_ART.md`. Both are enforced by CI validators
where a machine can check them, and by the director's eye where it cannot. The review test for
any screen or asset: without the name on it, would it still look like this game, or like any
AI-generated fantasy RPG? If the latter, it is not done.

## Sessions and context

- Fresh session at every task boundary. Write the handoff first (`agent-briefs/HANDOFF_TEMPLATE.md`).
- Aim for 50–100k tokens of context on routine work. Past 150k, hand off.
- Say which state you are in when you report: working, running a check, awaiting director,
  blocked, available. Waiting is valid; invented busywork is not.

## Skills improve over time (director, 2026-10-08, all projects, both accounts)

- **Learnings, with an evidence bar.** Any agent may add a finding to a skill's
  `references/learnings.md`, but only once it has proved effective: a quality-check method that
  caught or prevented a real defect; a recurring failure whose fix was verified afterwards by a
  test, capture or green CI; or a measured time saving. Each entry names the date, project,
  evidence (PR, commit, run or capture) and the general lesson. No hunches or untested ideas. If a
  finding contradicts the skill, correct the skill itself instead of appending a note. A lesson
  that keeps holding true is promoted into the skill's main text.
- **Project spin-off skills.** An agent may create a project-specific skill in this repo, named
  `mercs-<topic>`, when a general skill needs project-only detail. It says which general skill it
  extends, and general lessons still go back into the general skill so other projects benefit.
