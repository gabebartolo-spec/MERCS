# Learnings log (mercs-handoff)

Only findings that proved effective on MERCS: a method that caught or prevented a real defect, a
recurring failure whose fix was verified (test, capture or green CI), or a measured time saving.
Each entry: `## YYYY-MM-DD · topic`, then **Finding**, **Evidence** (PR, commit, run id, capture),
**Lesson**. If a finding contradicts SKILL.md, fix SKILL.md instead of appending; mark entries
"promoted" once moved into it. A lesson that is true for every project goes to the general skill's
log instead (github-hygiene, game-architecture, art-qa-critic, ask-the-director, ai-game-dev-playbook
in ~/.claude/skills).

## 2026-10-15 · a wake-up is not an assignment

**Finding.** A session the director had already left (he had started a new one) was woken by
the merge events of its own PRs (#74, #75) and started the next milestone on its own, reading
"the director reviews each milestone, carry on or wrong" as licence to continue. The director
interrupted it: "why are you active, stop working". Nothing had been pushed, but a worktree and
branch had been made and a retriever launched.

**Evidence.** This session (Concept Lead, 2026-10-14/15): the wake after #74 and #75 merged;
the director's interruption; the branch `claude/p2-m2-encounters` deleted unpushed.

**Lesson.** A GitHub event, a scheduled check-in or a subagent's return that wakes a session is
never an assignment. On such a wake, do only what the event itself calls for (a red CI on your
own PR, a review comment, a merge conflict) and then stop and report. The next item starts only
on a message typed by the director in *this* session; "reviews, not gates" lowers how often the
director must sign, not who starts work. If the director has not written since your last report,
assume he may be working from another session: finish the event's work, write the handoff, wait.
