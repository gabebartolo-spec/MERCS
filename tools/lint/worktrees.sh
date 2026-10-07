#!/usr/bin/env bash
# worktrees.sh: guardrail C1, at most four live worktrees under ../MERCS-wt/.
#
# Reads `git worktree list --porcelain`, or the file named by $WORKTREE_LIST (the self-test
# feeds it captured listings). The first entry is the main worktree. Entries inside
# <parent directory of main>/MERCS-wt/ are counted. Other linked worktrees (such as the
# desktop app's <main>/.claude/worktrees/* sessions) are listed but never counted. A
# prunable entry is a stale registration rather than a live worktree: it is not counted
# either, and is reported with its fix.
#
#   WT-OVER       more than MAX_WORKTREES live worktrees under MERCS-wt   (error, exit 1)
#   WT-UNCOUNTED  a linked worktree outside MERCS-wt                       (warning)
#   WT-PRUNABLE   a stale entry: run `git worktree prune`                  (warning)
#
# Output follows the other lints: <source>:0: [warning ]RULE message, then `ok: ...`.
# Windows paths (C:/...) and POSIX paths both work; Windows paths compare case-blind.
#
# Usage: bash tools/lint/worktrees.sh

MAX_WORKTREES=4 # guardrail C1: at most four live worktrees under ../MERCS-wt/
WT_DIR_NAME="MERCS-wt"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_name="git-worktree-list"
if [ -n "${WORKTREE_LIST:-}" ]; then
  source_name="$(basename -- "$WORKTREE_LIST")"
fi

read_list() {
  if [ -n "${WORKTREE_LIST:-}" ]; then
    cat -- "$WORKTREE_LIST"
  else
    git -C "$repo_root" worktree list --porcelain 2>/dev/null
  fi
}

emit() { # emit <error|warning> <RULE> <message>
  local kind="$1" rule="$2" message="$3" tag=""
  if [ "$kind" = "warning" ]; then
    tag="warning "
  fi
  printf '%s:0: %s%s %s\n' "$source_name" "$tag" "$rule" "$message"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::%s file=%s,line=0::%s %s\n' "$kind" "$source_name" "$rule" "$message"
  fi
}

join_by() { # join_by <separator> <items...>
  local separator="$1" joined="" item
  shift
  for item in "$@"; do
    joined="${joined:+$joined$separator}$item"
  done
  printf '%s' "$joined"
}

lower_if_windows() { # Windows paths are case-insensitive, POSIX paths are not
  if [[ "$1" =~ ^[A-Za-z]:/ ]]; then
    printf '%s' "${1,,}"
  else
    printf '%s' "$1"
  fi
}

# Parse the porcelain listing: one block per worktree, blocks separated by a blank line.
paths=()
prunable=()
current=""
current_prune=""

flush_entry() {
  if [ -n "$current" ]; then
    paths+=("$current")
    prunable+=("$current_prune")
  fi
  current=""
  current_prune=""
}

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in
    "worktree "*)
      flush_entry
      current="${line#worktree }"
      current="${current//\\//}"
      current="${current%/}"
      ;;
    prunable*)
      current_prune="${line#prunable}"
      current_prune="${current_prune# }"
      current_prune="${current_prune:-stale entry}"
      ;;
    "") flush_entry ;;
  esac
done < <(read_list)
flush_entry

if [ "${#paths[@]}" -eq 0 ]; then
  echo "ok: no worktree list available (not a git checkout?), nothing to count"
  exit 0
fi

main_path="${paths[0]}"
wt_dir="${main_path%/*}/$WT_DIR_NAME"
prefix="$(lower_if_windows "$wt_dir/")"

counted=()
for ((i = 1; i < ${#paths[@]}; i++)); do
  path="${paths[i]}"
  if [ -n "${prunable[i]}" ]; then
    emit warning WT-PRUNABLE "$path is stale (${prunable[i]}); run: git worktree prune"
  elif [[ "$(lower_if_windows "$path")" == "$prefix"* ]]; then
    counted+=("${path:${#prefix}}")
  else
    emit warning WT-UNCOUNTED "$path is a linked worktree outside $wt_dir (not counted)"
  fi
done

count="${#counted[@]}"
if [ "$count" -gt "$MAX_WORKTREES" ]; then
  emit error WT-OVER "$count live worktrees under $wt_dir (max $MAX_WORKTREES, guardrail C1): $(join_by ', ' "${counted[@]}"). Tell Merge & CI and stop until pruned."
  exit 1
fi
echo "ok: $count of $MAX_WORKTREES live worktrees under $wt_dir"
