# 04 — Guardrails against AI game-development pitfalls

Each guardrail names the pitfall, the evidence it is real (most come from the AFL project's own
audit trail), the rule, and how it is enforced. "Enforced by CI" means a PR cannot merge without
it. "Enforced by review" means the Merge & CI agent or Concept Lead checks it by hand.

## A. Scope and product pitfalls

### A1. Decorative systems
*Pitfall:* an agent builds a system that exists in code and UI but changes nothing the player can
feel. The AFL reality audit found a game plan discarded at the first bounce and a momentum meter
that was pure decoration; the design audit called the result "a list-quality simulator with a
coaching skin".
*Rule:* every system PR includes a **player-effect fixture**: a seeded scenario where the system
on vs off produces a different, visible outcome (a different death, recruit, line of dialogue,
battle result or screen). No fixture, no merge.
*Enforced by:* CI (`tests/effect/` suite must contain a case tagged with the system id) and the
phase-gate review.

### A2. Content multiplication
*Pitfall:* every system cross-products with every other; equipment × injury × direction × animation
explodes.
*Rule:* hard counts per phase (`08_ROADMAP.md` lists them). Adding a background, weapon class,
animation state or facing outside the phase count is a director decision, not a PR.
*Enforced by:* `tools/lint/content_counts.py` reads `data/` and fails over cap.

### A3. World before people
*Pitfall:* a big procedural map hides a weak character game.
*Rule:* no region generation beyond one authored town plus three procedural sites until Phase 8's
success test passes.
*Enforced by:* roadmap gate; Concept Lead review.

### A4. Roadmap as authorisation
*Pitfall:* agents start items because they are listed.
*Rule:* an item starts when STATUS.md shows it assigned by the director or Dev Lead. Done means
stop, report, recommend, wait.
*Enforced by:* review; the PR template's "Assigned in" field must point at a STATUS line.

### A5. Grimdark monotony and cruelty-as-maturity
*Rule:* the storylet library must keep at least 25 % of scenes tagged `warmth`, `humour` or
`ordinary_life`, measured by `tools/lint/storylet_lint.py`. Moral gates present competing
obligations, never a sadism slider.
*Enforced by:* CI lint; Concept Lead review of each storylet batch.

### A9. Gamified rarity and disposable death
*Pitfall:* agents reach for Common/Rare/Epic/Legendary labels, coloured borders and star ratings
because every loot game has them; and a dead mercenary vanishes like a used item.
*Rule:* no rarity tiers, labels, colours or badges anywhere; a mercenary is rare because an
unusual combination happened and the player recognises it. Every member who ever served has a
chronicle entry that survives death and retirement.
*Enforced by:* `strings.py` banned-word list for UI labels (`rare`, `epic`, `legendary`); the
`chronicle` fixture in Phase 4; review.

## B. Engineering pitfalls

### B1. "It compiles, so it works"
*Rule:* evidence by change type (see `agent-briefs/HANDOFF_TEMPLATE.md`). UI flows are proven by a
real click at the control's screen position through the GUI, not by calling the handler. Art is
proven by asserting the asset the game actually loaded. New checks are shown failing on a known-bad
input before they are trusted.
*Enforced by:* review of the PR evidence section; the `assets` and `ui` suites.

### B2. Non-determinism
*Rule:* all randomness flows from `Rng` objects created from a seed held in the save. The clock is
never read inside `sim/`. Tests pin seeds. A flaky test is fixed by pinning, never by re-running.
*Enforced by:* CI greps `sim/` for `randi(`, `randf(`, `Time.get_` and fails on any hit outside
`Rng.gd`.

### B3. Sim/presentation tangling
*Rule:* `sim/` scripts extend `RefCounted` only, never `Node`. They emit typed event records;
`presentation/` consumes them. No scene path, no `get_node`, no `await` on frames in `sim/`.
*Enforced by:* `tools/lint/layering.py` (import-direction check: `data` → `sim` → `presentation`
→ `ui`, never backwards) in CI.

### B4. Hallucinated or wrong-version APIs
*Rule:* Godot 4.7.2 only. Before using an unfamiliar class or method, the agent reads the
online 4.7 class reference (or a local `godot --doctool` dump if one is ever committed; not
required). Static typing is on so wrong signatures fail at parse.
*Enforced by:* CI runs `godot --headless --import` then every suite; a `SCRIPT ERROR` fails the
run even when checks pass.

### B5. Fix loops
*Rule:* after two similar failed fixes of one problem, the agent stops, gathers different evidence
(minimal repro, last good commit, runtime state, event path) and writes what it learned in the PR
before trying again.
*Enforced by:* review; the handoff's "Attempts" field.

### B6. Test gaming
*Rule:* check floors only go up. Threshold widening in a test (the AFL commit "widen rating-parity
limit to 32") needs a one-line justification in `docs/DECISIONS.md` and a Concept Lead ack. A test
deleted to get green is a revert.
*Enforced by:* CI floor file (`tests/expected_checks.txt`); review.

### B7. Save-breaking changes
*Rule:* versioned saves from the first save. New keys have defaults; renames need a migration and
an old-save fixture. Save → reload → continue round-trip test on every persisted-state PR.
*Enforced by:* `tests/save/` suite with fixtures from every prior phase; `mercs-sim-review` skill.

### B8. God files and autoload sprawl
*Rule:* 400 lines per GDScript file, 40 per function, at most 5 autoloads (`GameData`,
`EventBus`, `SaveSystem`, `Settings`, `Debug`). `Rng` is a plain RefCounted class in `sim/`, not
an autoload, because sim must not depend on the scene tree (D-021). A new autoload is a decision.
*Enforced by:* `gdlint` config in CI (`max-file-lines`, `max-public-methods`); layering lint.

### B9. Magic numbers and hidden balance
*Rule:* every tunable number lives in `data/balance/*.json` with a comment key. A literal numeric
constant in `sim/` other than 0, 1, -1 and 100 is flagged.
*Enforced by:* `tools/lint/magic_numbers.py` (warning in Phase 1–2, error from Phase 3).

### B10. Secrets and spend
*Rule:* no API keys in the repo; `.env` is git-ignored; CI has no paid secrets. No agent calls a
paid API without a DECISIONS.md entry.
*Enforced by:* `gitleaks` action in CI (MIT); review.

### B11. Performance budgets
*Rule:* 60 fps at 1920×1080 on this PC with the slice content; world tick under 50 ms for a
year of simulated time; battle load under 2 s. Measured by the `perf` suite from Phase 3.
*Enforced by:* CI perf suite with floors; a regression over 20 % fails.

### B12. Text hard-coded in scripts
*Rule:* every player-visible string comes from `data/text/*.json` via `Text.t("key")` from day one,
so localisation and a copy pass are never a rewrite.
*Enforced by:* lint for string literals in `ui/` and `presentation/` outside `Text` calls.

## C. Process pitfalls

### C1. Worktree and branch sprawl (128 worktrees, 99 remote branches on AFL)
*Rule:* at most four live worktrees, whether under `../MERCS-wt/<topic>` or the app's
`.claude/worktrees/` (both counted, D-021); a worktree is removed when its PR merges or is
closed; remote branches are deleted on merge (squash merge, delete branch).
*Enforced by:* Merge & CI weekly prune; `tools/lint/worktrees.sh` run at session start.

### C2. Unreadable documents
*Rule:* caps in `03_TEAM_WORKFLOW.md`. Documents are read by section. A doc past its cap is a
bug assigned to the Merge & CI agent.
*Enforced by:* the `doc-caps` job in `lint.yml` (includes `CLAUDE.md` at 120).

### C3. Status and decision drift
*Rule:* a decision exists only in `docs/DECISIONS.md`. STATUS.md is updated in the same PR that
changes state. The Merge & CI agent's weekly upkeep catches the rest.
*Enforced by:* review; weekly summary diff.

### C4. Idle agents and busywork
*Rule:* agents end their turn with a state line. "Available" is a valid state. Nobody invents work
to look busy, and nobody is re-fed by a cron.
*Enforced by:* STATUS.md state column; director spot checks.

### C5. Permission laundering
*Rule:* an agent refused a permission takes it to the director; it never asks another agent to do
it instead.

### C6. Context bloat
*Rule:* fresh session at task boundaries; handoff file ≤ 120 lines; routine work at 50–100k
context.

### C7. Director fatigue
*Rule:* questions follow the protocol: one decision each, recommended option first, game impact
in plain words, labelled images for anything visual, at most four per message. Nothing else is
sent to the director unasked except gate reviews and the weekly summary.

## D. Art and style pitfalls

### D1. Generated-art inconsistency
*Rule:* no diffusion-generated sprite frames. Characters come from one rig, one camera rig, one
light rig, one palette, one post-process. Portraits are the single generative asset class and must
pass the portrait validator (palette, framing, size, style-LoRA provenance) and the director gate.
*Enforced by:* `tools/pipeline/validate_sprite.py`, `validate_portrait.py` in CI on every asset PR.

### D2. Style drift over time
*Rule:* `docs/06_STYLE_ART.md` holds golden reference images under `assets/golden/`. Every asset
PR renders its contact sheet beside the golden sheet. Palette compliance is machine-checked;
"looks like the golden sheet" is the director's call.
*Enforced by:* validators + director gate.

### D3. Generic AI-template UI
*Rule:* the AFL anti-slop list applies: no rounded-card stacks, no pill soup, no SaaS palettes, no
gradients and glows, no all-caps metadata, typography and spacing make hierarchy. UI lives in one
kit (`ui/UiKit.gd`). The review test: without the title, is this recognisably MERCS?
*Enforced by:* review; UiKit is the only source of colours, fonts and radii (lint rejects literal
colours in `ui/`).

### D4. Number vomit
*Rule:* primary screens answer what is happening, what matters, what I can do. Numbers appear
when they change a decision; detail lives behind inspect.
*Enforced by:* review; the director's playtest notes.

### D5. Licence contamination
*Rule:* nothing ships, trains or seeds a shipped asset unless its row in
`docs/10_LICENSING_REGISTER.md` says CLEARED. Civitai models are PENDING until their permissions
page is quoted in the row.
*Enforced by:* every asset's provenance manifest names the model/tool; `validate_provenance.py`
cross-checks against the register.
