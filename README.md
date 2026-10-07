# MERCS — project architecture pack

Working title **MERCS** (Mercenary Collector RPG). A grim low-fantasy 2.5D tactical RPG where the
collectible content is mortal people: recruit, train, equip and lose a small company of mercenaries
in a procedurally changing feudal realm.

This folder is the complete hand-off pack produced by the Concept Lead on 2026-10-08. It is meant to
be committed as the first commit of `github.com/gabebartolo-spec/MERCS` and read by AI agents
before they write a line of code or render a single sprite.

**Authority.** The director (the human owner) decides. The Concept Lead keeps the architecture and
roadmap honest. Every other agent executes an assigned item inside these documents. A document here
is context and constraint, never authorisation to start work.

## Read in this order

| # | File | Who must read it |
|---|------|------------------|
| 1 | [CLAUDE.md](CLAUDE.md) | Every Claude Code session, every time |
| 2 | [docs/00_VISION.md](docs/00_VISION.md) | Everyone |
| 3 | [docs/08_ROADMAP.md](docs/08_ROADMAP.md) | Everyone (read your phase, not the whole file) |
| 4 | [docs/04_GUARDRAILS.md](docs/04_GUARDRAILS.md) | Everyone |
| 5 | [agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md](agent-briefs/DIRECTOR_QUESTION_PROTOCOL.md) | Everyone |
| 6 | Your own brief in [agent-briefs/](agent-briefs/) | The agent in that role |
| 7 | [docs/05_STYLE_CODE.md](docs/05_STYLE_CODE.md) | Dev Lead, Merge & CI agent |
| 8 | [docs/06_STYLE_ART.md](docs/06_STYLE_ART.md), [docs/07_ASSET_PIPELINE.md](docs/07_ASSET_PIPELINE.md) | Art agent, Dev Lead |
| 9 | [docs/10_LICENSING_REGISTER.md](docs/10_LICENSING_REGISTER.md) | Art agent before any model or tool is used |

Reference documents (read when needed, by section):
[01_ENGINE_DECISION](docs/01_ENGINE_DECISION.md) ·
[02_MACHINE_AND_LOCAL_AI](docs/02_MACHINE_AND_LOCAL_AI.md) ·
[03_TEAM_WORKFLOW](docs/03_TEAM_WORKFLOW.md) ·
[09_REPO_AND_HOSTING](docs/09_REPO_AND_HOSTING.md) ·
[11_OPEN_QUESTIONS](docs/11_OPEN_QUESTIONS.md) ·
[DECISIONS](docs/DECISIONS.md) ·
[STATUS](docs/STATUS.md)

## The team at a glance

| Role | Model / tool | Owns |
|------|--------------|------|
| Director | human | vision, taste, approvals, money |
| Concept Lead | Claude Fable 5.1 (this chat) | architecture, research, roadmap gates, audits, briefs |
| Dev Lead | Claude Code, Opus 5.5 | game code, tests, phase deliverables |
| Merge & CI | Claude Code, Sonnet 5.5 | merges, CI, branch hygiene, STATUS.md, document upkeep and weekly summary |
| Art Factory | Claude Code, Opus 5.5 | asset pipeline, renders, portraits, style validators |

Only three Claude Code chats run at once (Dev Lead, Merge & CI, Art Factory). Details in
[docs/03_TEAM_WORKFLOW.md](docs/03_TEAM_WORKFLOW.md).

## Headline decisions (full reasoning in the linked docs)

- **Engine: Godot 4.7.2, GDScript with static typing enforced.** Not Unity. See 01.
- **Platform: Windows PC first, Steam.** Mouse and keyboard primary. Mobile is out of scope.
- **Characters are one canonical hidden 3D body rendered to pixel sprites** with modular equipment
  layers and injury overlays. Diffusion never produces sprite frames. See 07.
- **Portraits are the one shipped generative-image asset**, produced only from commercially
  cleared models and gated by a style validator and the director. See 06, 10.
- **Two installed models are banned from production:** Qwen-Image 2.1 and Anima (non-commercial
  licences). See 10.
- **No runtime AI of any kind in the shipped game.**
- **Repo goes private, mono-repo, Git LFS for binaries, raw assets in a local vault on D:.** See 09.
- **Nothing scales until the vertical-slice success test passes** (a procedural mercenary becomes
  memorable through recruitment, combat, injury, relationships and death). See 08.
