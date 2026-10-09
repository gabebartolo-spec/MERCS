# Learnings log (mercs-pr)

Only findings that proved effective on MERCS: a method that caught or prevented a real defect, a
recurring failure whose fix was verified (test, capture or green CI), or a measured time saving.
Each entry: `## YYYY-MM-DD · topic`, then **Finding**, **Evidence** (PR, commit, run id, capture),
**Lesson**. If a finding contradicts SKILL.md, fix SKILL.md instead of appending; mark entries
"promoted" once moved into it. A lesson that is true for every project goes to the general skill's
log instead (github-hygiene, game-architecture, art-qa-critic, ask-the-director, ai-game-dev-playbook
in ~/.claude/skills).

## 2026-10-09 · mark ready, then push
**Finding.** `tests.yml` skips the Godot shards for a draft PR, and the run started by "ready for review" can still read the PR as a draft. `plan` then reports "draft pull request" and the aggregate `test` goes green with zero suites run.
**Evidence.** #66, run 37890243865 on b6ac99a: `plan=success code=false shards=skipped extras=skipped`, "The Godot checks were skipped (draft pull request...)", while the PR was already ready. #67 hit the same on its first ready run. After one fresh commit pushed while ready, #66's run showed shard 1 and the harness self-test running and passing (935cf46), and #67 likewise (2ce31b8).
**Lesson.** A draft going ready proves nothing. Mark the PR ready, then push one new commit (an empty `ci:` commit is enough), and read the run's `plan=... code=... shards=...` line before calling the PR proven. Merge & CI checks that line on the exact head for any PR that was ever a draft.
