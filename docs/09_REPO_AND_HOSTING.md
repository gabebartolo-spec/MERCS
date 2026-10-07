# 09 — Repo, hosting and CI

## Decision: local working copies + private GitHub mono-repo + local vault on D:

| Where | What lives there | Why |
|-------|------------------|-----|
| `github.com/gabebartolo-spec/MERCS` (**make it private**) | code, data, docs, engine-ready assets (LFS), CI | one source of truth; free private repos; 2,000 Actions minutes/month; 10 GiB LFS storage and bandwidth free |
| `C:\Users\DANTE\Documents\GitHub\MERCS` | the main checkout | fast NVMe; C: has 84 GB free so only the checkout lives here |
| `C:\Users\DANTE\Documents\GitHub\MERCS-wt\<topic>` | at most four worktrees | isolation per task; pruned on merge |
| `D:\MERCS-vault\` | models, raw renders at 4×, concept outputs, Mixamo clips, Blender sources, logs, backups | 375 GB free; these are large, regenerable or non-redistributable, and must not hit LFS quota |
| Backup of the vault | director's choice (external drive or cloud); not provisioned by agents | spend decision |

The repo is currently **public and empty**. Making it private is the first action, because the
design documents and generated assets of a commercial game should not be public, and because the
licence posture of some models is per-user.

## Why one repo, not two

The AFL project used a separate pipeline repo. For MERCS the interface between the pipeline and
the game (sheet manifests, `CharacterSheets.gd`, the palette file, validators) is the riskiest
contract in the project; keeping both sides in one repo means a contract change and its consumer
change land in one PR and one CI run. The Art agent still works in its own worktree and touches
only `tools/pipeline/` and `assets/`.

## Git LFS rules (`.gitattributes`)

```
*.png  filter=lfs diff=lfs merge=lfs -text
*.glb  filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.wav  filter=lfs diff=lfs merge=lfs -text
*.ogg  filter=lfs diff=lfs merge=lfs -text
*.ttf  filter=lfs diff=lfs merge=lfs -text
*.otf  filter=lfs diff=lfs merge=lfs -text
*.safetensors filter=lfs diff=lfs merge=lfs -text   # should never be committed; rule is a tripwire
docs/**/*.png -filter -diff -merge                   # small review images stay plain git
assets/golden/*.png -filter -diff -merge
* text=auto eol=lf
*.gd text eol=lf
*.tscn text eol=lf
*.bat text eol=crlf
```

Budget: engine-ready sprites for the slice are tens of MB, portraits a few MB, environments under
100 MB. The 10 GiB free LFS tier covers Phases 0–8 if raw renders stay in the vault. The Merge & CI
agent reports LFS usage monthly in STATUS.md; at 8 GiB the director decides between pruning and
metered overage (US$0.07 per GiB-month).

`.gitignore`: `.godot/`, `*.import` for assets is **committed** (Godot needs them) but `.import`
churn is reverted in code PRs, `vault/`, `.env`, `__pycache__/`, `out/`, `review/`.

## Branching

- `main` is always green and always buildable. Protected: PR required, `test` check required,
  squash merge only, delete branch on merge, no force push, no auto-merge.
- Branches `claude/<topic>`; one PR per branch; rebase or merge `origin/main` before asking for
  merge.
- Tags `phase-N-pass` when a gate passes; `slice-vN` for playable builds.

## CI (GitHub Actions, free tier)

| Workflow | Trigger | What it does | Budget |
|----------|---------|--------------|--------|
| `tests.yml` | PR, push to main | plan → N shards (Godot headless suites) → aggregate `test`; skips docs-only PRs | ~6–8 min per run; keep under 30 runs/day |
| `lint.yml` | PR | gdlint, gdformat check, layering, magic numbers, strings, doc caps, worktree count file, gitleaks, JSON schema | ~2 min |
| `assets.yml` | PR touching `assets/` or `tools/pipeline/` | validators + Godot assets fixture + contact-sheet artefact | ~4 min |
| `build.yml` | push to main, tag | Windows export; artefact kept 14 days | ~5 min |
| `capture.yml` | manual | golden-scene captures and a short clip for director review | on demand |

Godot in CI: pinned 4.7.2 download (cached), `--headless --import` once, then suites with
`XDG_DATA_HOME` isolation. GPU work never runs in CI; the Art agent runs it locally and commits
the result with its validator artefact.

## Secrets and spend

No paid secrets in CI. Tripo or cloud keys, if ever approved, live in the Art agent's local `.env`
only. `gitleaks` blocks accidental commits.

## Recovery

- Vault has a `MANIFEST.json` listing every model with its hash and licence row so it can be
  rebuilt after a disk loss.
- `tools/pipeline/rebuild_all.sh` regenerates every shipped sprite sheet from the vault and the
  repo in one command (the Phase 1 gate proves it).
- Weekly `git bundle` of the repo to the vault by the Merge & CI agent.
