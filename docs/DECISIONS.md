# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes.

## 2026-10-09 · D-046 · Lead (technical, same game) · Engine sprite sheets under `assets/sprites/` are plain git, not LFS; large binaries stay in LFS
Why: CI and the build check out without LFS, so LFS pointers were read as PNGs (#55's red CI). Sheets are small.
Changes: `.gitattributes`, `build.yml` comment (#56).

## 2026-10-09 · D-045 · Director · Sprites are rendered at a 45 degree sprite pitch inside the 55 degree world camera, at the same px per metre (about 82.27 px/m at 1x)
Why: chosen from labelled 4K street captures (Lead QC passed). The camera stays at 55 degrees (D-037).
Changes: `camera_rig.json`, `proportions.json` (#52); stage defaults (#57).

## 2026-10-09 · D-044 · Director · Merc pixel density is 84 px standing, on a 960x540 logical screen (x2 at 1080p, x4 at 4K); realistic proportions
Why: picked from the realistic density samples (B: 84 px) and the labelled street captures. Resolves D-042's open density; supersedes D-036 (56 px) and D-038 (proportion C).
Changes: rig freeze (#52); stage defaults (#57).

## 2026-10-09 · D-043 · Director · The Phase 1 gate is played in a playable "art direction slice" that includes a one-pass example of the core loop
Why: the director wants to test and assess the art direction before bulk assets and content. The question: "is this the look, and does it hold up in play?" Bulk assets and content wait for the gate. Lead note: the loop example is a sketch, shallow on systems and inside the hard rules; it does not pass the Phase 2 to 6 gates, which are still proved separately.
Changes: `docs/specs/art_direction_slice.md`, roadmap pointer (#51); slice M1 and M2 (#53, #54).

## 2026-10-09 · D-042 · Director · Proportion C is reversed: realistic proportions, a 4k pixel art look; pixel density stays open until the director picks from samples (density resolved by D-044)
Why: the director said "I don't like the big head, lets go for a realistic, 4k pixel art look." Supersedes D-038 (proportion C) and reopens D-036 (56 px standing height): the merc density candidates are 56, 84 or 112 px, picked from samples. D-037 (55 degree pitch) is not touched by this entry.
Changes: capture support `--logical=WxH` (#44); Art renders realistic density samples at 56 / 84 / 112 px; `06_STYLE_ART.md` follows the pick.

## 2026-10-08 · D-041 · Director · Authorisation: the Dev Lead may do what it thinks is best on making the re-rendered good fixture the stage's default merc
Why: the director said "go", then "do what you think is best" (recorded in #39). Scope is that item only; it is not a general authorisation for look or design calls.
Changes: captures default to the good sheet (#39).

## 2026-10-08 · D-040 · Lead (pending) · Sprites are camera-facing billboards, not Y-axis billboards
Why: upright Y billboards lean at the 55 degree pitch, which produces mixels (D-035).
Changes: the stage; `01_ENGINE_DECISION.md` (#36).

## 2026-10-08 · D-039 · Director · Testing cadence: major testing and audits only at milestones
Why: avoid heavy testing and audits between milestones. Per PR: run the existing suites and lints with one capture; new exhaustive suites, planted-defect rounds and audits wait for milestones. Narrows the amount of proof under `CLAUDE.md` rule 9, not the rule (#29; its suite was built before this).

## 2026-10-08 · D-038 · Director · Proportion is C pushed further, chosen as C: head 1.8x, hands 1.3x, thighs 0.85x, refit to 1.78 m (about 4.5 heads)
Why: chosen from `crop_p55_h56.png`; variant D (head 2.3x, about 3.5 heads) stays in the samples as the rejected option. Follow-up (needs assigning): freeze the look into the rig.
Changes: nothing yet (#28).

## 2026-10-08 · D-037 · Director · Game camera pitch is 55 degrees
Why: steep, as in the reference. `06_STYLE_ART.md` §3 and `camera_rig.json` (35 degrees, 48 px, 64 cell) change in a follow-up PR; spec §3's 30-40 degree range is superseded.
Changes: nothing yet (#28).

## 2026-10-08 · D-036 · Director · Standing figure height is 56 px at 1x
Why: chosen from review_p35/review_p55 and the 2x crops (#28).
Changes: nothing yet; rig follow-up.

## 2026-10-08 · D-035 · Director · Any art containing mixels is an automatic failure and must be fixed: one texel size per image or view
Why: director rule (#28). `contact_sheet.py` and the review sheets now draw text at the art's zoom; the 1x strip is a separate image.
Changes: `tools/pipeline/` (#28).

## 2026-10-08 · D-034 · Lead (pending) · Sprite normal maps: `normal_image`, camera-facing tangent space, OpenGL convention
Why: the factory and the engine must agree on one normal format (#26).
Changes: lit sprites, `stage_light` suite.

## 2026-10-08 · D-033 · Dev Lead as lead (pending) · The stage's rail distance is derived from pitch and figure height so one texel is one logical pixel at the look-at point
Why: a fixed rail stretched the sprite about 1.5x. Supersedes the spec's fixed 12 m rail and 160 x 90 crop; `docs/specs/phase1_visual_proof.md` §2 should say so (spec owner's edit).
Changes: `street_stage.gd`, `data/balance/stage.json` (#24).

## 2026-10-08 · D-032 · Director · Sprite scale is constant: one texel is one logical pixel anywhere; sprites never resample; distance shows by position
Why: answered from the sample set 2 depth sheet and clips.
Changes: stage default `depth_scale` (#25).

## 2026-10-08 · D-031 · Director · Pixel mode is A, whole screen: 640 x 360 SubViewport x3, sprites snapped
Why: answered from the sample set 2 pixel-mode sheet and clips.
Changes: node setup in `01_ENGINE_DECISION.md` (#25).

## 2026-10-08 · D-030 · Director · Merge & CI is autonomous for routine repository administration
Why: the director was being asked to run routine git and GitHub commands, and the merge brief contradicted itself on branch ownership, board commits and permissions, so a green, eligible PR (#19) sat unmerged. Rulings: (1) green + eligible = merge, without asking; (2) a routine git or GitHub permission refusal is a configuration bug fixed in `.claude/settings.json` by PR, never a command handed to the director; (3) the branch owner syncs and repairs their own branch, Merge & CI names the exact conflict once and never pushes to another agent's branch; (4) `docs/STATUS.md` and `docs/DECISIONS.md` change only through a docs-only board PR by Merge & CI after each merge (`main` is protected for admins too, so there is no direct commit); (5) GitHub settings match the docs: squash only, no merge commits, no rebase merges, no auto-merge; (6) routine merge-agent messages are one line. The director is reached only for look and design gates, spend, credentials and sign-ins, destructive recovery with real risk, permissions GitHub reserves for a human, and genuinely ambiguous policy.
Changes: `agent-briefs/MERGE_CI_AGENT.md` rewritten; `.claude/settings.json` (routine git allowed; force push, hard reset, forced branch deletion, admin merge and protection edits denied); `CLAUDE.md`; `03_TEAM_WORKFLOW.md`; `04_GUARDRAILS.md` C3, C5; `09_REPO_AND_HOSTING.md`; `mercs-pr`, `mercs-handoff`; PR template gains "Board and log". Amends D-021: a feature PR no longer writes `D-TBD` into `DECISIONS.md`; the decision text travels in the PR body.

## 2026-10-08 · D-029 · Director · The Art agent may drive mixamo.com in a browser session the director has signed in to
Why: fourteen Mixamo clips are needed for Phase 1 and the account is the director's. The agent never enters credentials; the director signs in, the agent downloads to `D:\MERCS-vault\clips`.
Changes: STATUS.md "Waiting on the director".

## 2026-10-08 · D-028 · Director · Mercs are men and women: two base bodies (male and female) share one skeleton
Why: recruits can be either; one skeleton keeps every clip shared. Logged after the merge of #13 (its body called it D-026, which was taken).
Changes: `tools/pipeline/bodies/bodies.json`. Phase 1 proves `average_m` first; `average_f` follows on the same skeleton. Every equipment piece is fit-checked on both bodies.

## 2026-10-08 · D-027 · Concept Lead · Phase 0 gate: PASS WITH NOTES
Why: 12 of 16 planted violations rejected by CI (PR #10); clean PR #11 green; build artefact launches. Four gaps (floor lowering, gitleaks test key, safetensors tripwire, file length) are machine-enforceable and become Phase 0 items 10–12 plus item 8, required before Phase 1 code merges. Full table in `docs/audits/phase0_gate_result.md`.
Changes: STATUS.md Phase 0 items 10–12 added; Art Factory may start Phase 1 rig freeze and samples now.

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
