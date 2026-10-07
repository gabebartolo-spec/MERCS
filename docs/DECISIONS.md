# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes.

## 2026-10-08 · D-026 · Concept Lead · Only the Merge & CI agent edits STATUS.md and DECISIONS.md, in one commit to main after each merge
Why: seven first-day PRs all edited the same two files, causing conflicts, rebases and colliding decision ids; the director found the GitHub flow confusing. PRs now state board and log changes in a "Board and log" body section instead.
Changes: `CLAUDE.md`, `03_TEAM_WORKFLOW.md`, `HANDOFF_TEMPLATE.md`, `MERGE_CI_AGENT.md`; the merge agent needs a direct-push exception for those two files on `main` (branch protection currently requires a PR; the Merge & CI agent proposes the smallest change).

## 2026-10-08 · D-025 · Director · The player appoints the next captain and the company reacts (Q13)
Why: director's answer. Reaction scenes (one to three voices from traits and memories, with morale and loyalty consequences; an unpopular pick can cause a departure) are Phase 5 content; the appointment flag ships in Phase 2.
Changes: `08_ROADMAP.md` Phases 2, 4, 5; `data/balance/captaincy.json` when created.

## 2026-10-08 · D-024 · Director · A campaign starts with a small inherited company and a sitting captain (Q14)
Why: director's answer. Keeps the captain mortal from the first hour; a short authored opening is Phase 8 content.
Changes: `08_ROADMAP.md` Phases 2 and 8.

## 2026-10-08 · D-023 · Director (clarified by Concept Lead; ratified with Q13–Q14) · The Three Pillars brief is integrated: the company is the player, the captain is a mortal office with succession, a company chronicle persists every member, down is not dead until triage, retreat is legitimate, regional recruitment pools, no rarity labels
Why: the director added `Mercenary_Collector_Three_Pillars_Claude_Brief.docx` to the repo on 2026-10-08; it extends the original brief and conflicts with nothing in the pack. Both briefs now live in `docs/source-briefs/`.
Changes: `00_VISION.md` (new section and additions table), `04_GUARDRAILS.md` A9, `08_ROADMAP.md` Phases 2–8, `11_OPEN_QUESTIONS.md` Q13–Q14, `12_SOURCES.md`. Director answers Q13 and Q14 before Phase 2.

## 2026-10-08 · D-022 · Director · The Merge & CI agent may run `gh pr merge`
Why: Claude Code's auto-mode classifier refused the merge agent's `gh pr merge` as "Merge Without Review", leaving the director to merge by hand. The director chose a shared allow rule over per-merge prompts or manual merges.
Changes: `.claude/settings.json` (shared) allows only `gh pr merge`. All other review guards stand: PR required, green `test`, template, director look gates, audit comments.

## 2026-10-08 · D-021 · Concept Lead · Phase 0 review rulings
Why: the first six PRs exposed gaps in the pack, found by the Concept Lead's pre-merge audit.
1. **No `Rng` autoload.** Sim code must not depend on autoloads (guardrail B3), so the random
   stream wrapper is a RefCounted class `Rng` in `sim/core/rng.gd`, constructed from the seed in
   the save model. The autoload list is five: `GameData`, `EventBus`, `SaveSystem`, `Settings`,
   `Debug`. `05_STYLE_CODE.md` and `04_GUARDRAILS.md` B8 amended; PR #4 drops the autoload.
2. **File names are snake_case** (`rng.gd`, `merc_gen.gd`); class names PascalCase. The layout
   listing in `05_STYLE_CODE.md` is corrected; lints grep `rng.gd`.
3. **Worktrees may live under `../MERCS-wt/<topic>` or the app's `.claude/worktrees/`.** The
   four-worktree cap counts both. Guardrail C1 and `CLAUDE.md` amended.
4. **Decision ids are assigned at merge.** A PR writes `D-TBD-<slug>`; the Merge & CI agent
   assigns the next free number when it merges and fixes references in the same squash. This ends
   the id collisions seen across PRs #1, #2 and #3.
5. **Doc caps** are enforced by the `doc-caps` job in `lint.yml` (inline), not a `doc_caps.py`
   script; it must also check `CLAUDE.md` at 120 lines. Docs amended.
6. **Build artefact retention** is 30 days (PR #4), docs amended.
7. **Agent-authored decisions** that clarify a director answer are attributed
   "Director (clarified by <agent>, from Qn)"; a decision with no question trail is
   "<agent> (pending director ratification)".
8. **Sim never references any autoload, including `EventBus`.** The `LAYER-AUTOLOAD` lint rule
   in PR #5 is correct. Sim objects expose their own signals or return typed event lists;
   presentation relays them onto `EventBus`. `05_STYLE_CODE.md` amended.
9. **The project lints must run in CI before the gate.** `lint.yml` gains a job that runs
   `bash tools/lint/run_all.sh` (PR #1 or a follow-up to #5); until then guardrails A2, B3, B9
   and B12 enforce nothing.
Changes: `03_TEAM_WORKFLOW.md`, `04_GUARDRAILS.md`, `05_STYLE_CODE.md`, `09_REPO_AND_HOSTING.md`,
`CLAUDE.md`, `MERGE_CI_AGENT.md`; `docs/audits/phase0_gate_plan.md` and
`docs/specs/phase1_visual_proof.md` added.

## 2026-10-08 · D-020 · Director · ChatGPT is removed from the team; document upkeep and the weekly summary belong to the Merge & CI agent
Why: director's instruction.
Changes: `README.md`, `03_TEAM_WORKFLOW.md`, `04_GUARDRAILS.md` C3, `MERGE_CI_AGENT.md`, `KICKOFF_PROMPTS.md`; `agent-briefs/CHATGPT_DOCS.md` deleted. D-006 is amended accordingly.

## 2026-10-08 · D-019 · Director · Repo is public (Q-BP). Reverses D-011.
Why: GitHub Free refuses branch protection on private repos; director chose public over paying for Pro. Merge & CI flagged that this exposes design docs, history and every future commit, and that `gitleaks` plus the licensing register become the only guard on what ships in the open.
Changes: STATUS.md item 1; `09_REPO_AND_HOSTING.md` ("make it private" no longer applies). No banned or PENDING-licence asset may enter `assets/` while public.

## 2026-10-08 · D-018 · Director (clarified by Art agent, from Q12) · The "Pixel-ART Style (Pony)" file is removed and its register row dropped
Why: the file was a saved web page from a failed PixAI download (137 KB of HTML), not a model.
Changes: `10_LICENSING_REGISTER.md` row removed; file sent to the Recycle Bin.

## 2026-10-08 · D-017 · Art agent (pending director ratification) · The two Civitai-only models stay PENDING (concept only) because Civitai is region-blocked here
Why: Civitai answers `REGION_BLOCKED` from this machine, so the permissions block cannot be read. Sprites are rendered (D-002), so these were only ever concept tools.
Changes: `10_LICENSING_REGISTER.md` rows for `pixelArtDiffusionXL_spriteShaper` and the sprite-sheet LoRA carry the hash and the reason; neither may ship or train the portrait LoRA.

## 2026-10-08 · D-016 · Director (clarified by Art agent, from Q12) · Uninstall four Unity editors; keep 6000.3.23f1
Why: five editors were installed, not four; the director's Orc-Survivor project uses 6000.3.23f1. Clarifies D-015.
Changes: `02_MACHINE_AND_LOCAL_AI.md` and `tools/machine_profile.json` list one remaining Unity editor.

## 2026-10-08 · D-015 · Director · Banned Qwen-Image 2.1 files, Realistic Vision and the four unused Unity installs may be deleted (Q12)
Changes: STATUS.md item 5 is unblocked; the Art agent deletes rather than quarantines.

## 2026-10-08 · D-014 · Director · Tripo is available: 25,000 credits exist; any session that would spend more than 500 credits asks first (Q11)
Why: director's instruction. Cloud GPU hours and LFS overage remain unapproved until asked.
Changes: `CLAUDE.md` rule 8, `02_MACHINE_AND_LOCAL_AI.md`, `07_ASSET_PIPELINE.md`, `10_LICENSING_REGISTER.md` (paid tier: full rights, no attribution), `ART_AGENT.md`. The base body stays CC0 (D-002); Tripo serves equipment, props and concept meshes.

## 2026-10-08 · D-013 · Director · Roster cap in the slice is twelve, six deployed (Q10)

## 2026-10-08 · D-012 · Director · Square grid, eight facings (Q3). Ratifies D-005.

## 2026-10-08 · D-011 · Director · Repo is private (Q2). Ratifies D-007.

## 2026-10-08 · D-010 · Director · PC first, mouse and keyboard, Steam (Q1)
Changes: UI rules in `06_STYLE_ART.md` §7 and `05_STYLE_CODE.md` assume hover and right-click inspect.

## 2026-10-08 · D-001 · Concept Lead (pending director ratification) · Engine is Godot 4.7.2, GDScript static-typed
Why: MIT licence, headless CLI, text scenes, existing team tooling from the AFL project.
Changes: `01_ENGINE_DECISION.md`. Unity installs unused.

## 2026-10-08 · D-002 · Concept Lead (pending) · Characters are rendered from one CC0 base body with modular equipment; no diffusion sprite frames
Why: consistency by construction, no per-character generation cost, no licence exposure.
Changes: `06_STYLE_ART.md`, `07_ASSET_PIPELINE.md`. Overrides the brief's Tripo-first character path.

## 2026-10-08 · D-003 · Concept Lead (pending) · Qwen-Image 2.1 and Anima are BANNED from the product
Why: research-only and non-commercial licences.
Changes: `10_LICENSING_REGISTER.md`. The Art agent moves the files out of the models root in Phase 0.

## 2026-10-08 · D-004 · Concept Lead (pending) · Portraits are the only shipped generative asset, from CLEARED models with a project-trained style LoRA
Why: close-up payoff needs richness the sprite pipeline cannot give; a style LoRA and validator keep it consistent.
Changes: `06_STYLE_ART.md` §5.

## 2026-10-08 · D-005 · Concept Lead (pending) · Square grid, eight facings, shared between overworld and battle
Why: one facing set; see `11_OPEN_QUESTIONS.md` Q3 for the director's call.

## 2026-10-08 · D-006 · Concept Lead (pending) · Team is three Claude Code chats (Dev Lead Opus, Merge & CI Sonnet, Art Factory Opus); no idle-monitoring crons; document caps enforced in CI. (Amended by D-020: ChatGPT removed.)
Why: AFL lessons: coordination load, idle agents, 6,600-line roadmap.
Changes: `03_TEAM_WORKFLOW.md`, `04_GUARDRAILS.md`.

## 2026-10-08 · D-007 · Concept Lead (pending) · Private mono-repo with LFS; vault on D:
Why: `09_REPO_AND_HOSTING.md`.

## 2026-10-08 · D-008 · Concept Lead (pending) · Generative video and the Three.js lab are parked until after Phase 8
Why: 12 GB VRAM; no production need in the slice; fewer runtimes.

## 2026-10-08 · D-009 · Concept Lead (pending) · No spend without a decision entry
Why: director's instruction.
