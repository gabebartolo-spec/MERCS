# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes.

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

## 2026-10-08 · D-006 · Concept Lead (pending) · Team is three Claude Code chats (Dev Lead Opus, Merge & CI Sonnet, Art Factory Opus) plus ChatGPT as doc steward; no idle-monitoring crons; document caps enforced in CI
Why: AFL lessons: coordination load, idle agents, 6,600-line roadmap.
Changes: `03_TEAM_WORKFLOW.md`, `04_GUARDRAILS.md`.

## 2026-10-08 · D-007 · Concept Lead (pending) · Private mono-repo with LFS; vault on D:
Why: `09_REPO_AND_HOSTING.md`.

## 2026-10-08 · D-008 · Concept Lead (pending) · Generative video and the Three.js lab are parked until after Phase 8
Why: 12 GB VRAM; no production need in the slice; fewer runtimes.

## 2026-10-08 · D-009 · Concept Lead (pending) · No spend without a decision entry
Why: director's instruction.
