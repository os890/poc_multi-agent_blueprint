#!/usr/bin/env bash
# guard-main.sh - PreToolUse hook (Bash), multi-agent milestone workflow v1.
# Blocks: any `git push`; `git commit`, `git merge`, `git cherry-pick`, `git revert`, `git am` while the target
# checkout is on `main` or a `milestone-*` branch (only the watcher merges there; exception for review mode
# `milestone`: see milestone_merge_ok below). Exit 2 + one line on stderr blocks; exit 0 allows. Same rule for every agent.
# Branch name of main: MILESTONE_MAIN_BRANCH (default: main).
set -u
MAIN="${MILESTONE_MAIN_BRANCH:-main}"

input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0
[ -n "$dir" ] || dir=$PWD

block() { echo "blocked by guard-main: $1" >&2; exit 2; }

# Review mode `milestone` (interim hand merge by the task manager): on `milestone-<slug>` only these are allowed, and
# only in the milestone checkout `<main checkout>.worktrees/milestone-<slug>`:
#   git merge --no-ff --no-commit task-<id>-...   if a validated agent review of that whole task exists
#                                                  (<C>/reviews/task-<id>-r*.findings.md)
#   git commit                                     only to complete that merge (MERGE_HEAD exists)
# Path-based, because the hook input does not reliably name the agent. Sets WHY when it refuses.
WHY=""
milestone_merge_ok() { # <gitdir> <branch> <sub> <args...>
  local g=$1 b=$2 sub=$3 top main exp a target id C
  shift 3
  top=$(cd "$(git -C "$g" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null && pwd -P)
  main=$(git -C "$g" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10); exit}')
  exp=$(cd "$main.worktrees/$b" 2>/dev/null && pwd -P)
  if [ -z "$exp" ] || [ "$top" != "$exp" ]; then WHY="only the watcher, or the task manager in $main.worktrees/$b"; return 1; fi
  case "$sub" in
    commit)
      [ -n "$(git -C "$g" rev-parse -q --verify MERGE_HEAD 2>/dev/null)" ] && return 0
      WHY="only to complete a task merge (no merge in progress)"; return 1 ;;
    merge)
      case " $* " in *" --no-commit "*) ;; *) WHY="use --no-ff --no-commit, then the minimal suite"; return 1 ;; esac
      case " $* " in *" --no-ff "*) ;; *) WHY="use --no-ff --no-commit, then the minimal suite"; return 1 ;; esac
      target=""
      for a in "$@"; do case "$a" in task-[0-9]*-*) target=$a; break ;; esac; done
      id=$(printf '%s' "$target" | sed -n 's/^task-\([0-9][0-9]*\)-.*/\1/p')
      [ -n "$id" ] || { WHY="only task-<id>-<slug> branches are merged here"; return 1; }
      C="$(cd "$(git -C "$g" rev-parse --git-common-dir)" && pwd -P)/backlog-ng"
      ls "$C/reviews/task-$id-r"*.findings.md >/dev/null 2>&1 && return 0
      WHY="no validated agent review of TASK-$id ($C/reviews/task-$id-r*.findings.md)"; return 1 ;;
    *) WHY="only merge/commit of a task merge"; return 1 ;;
  esac
}

# Split the command into simple segments; follow `cd <dir>` between segments.
printf '%s\n' "$cmd" | tr ';&|' '\n\n\n' | {
  while IFS= read -r seg; do
    set -f; set -- $seg; set +f
    [ $# -gt 0 ] || continue
    if [ "$1" = "cd" ] && [ $# -ge 2 ]; then
      case "$2" in /*) dir=$2 ;; "~"*) dir="$HOME${2#\~}" ;; *) dir="$dir/$2" ;; esac
      continue
    fi
    case "$1" in git|*/git) ;; *) continue ;; esac
    shift
    gdir=$dir
    while [ $# -gt 0 ]; do
      case "$1" in
        -C) gdir=$2; shift 2 ;;
        -c) shift 2 ;;
        -*) shift ;;
        *) break ;;
      esac
    done
    [ $# -gt 0 ] || continue
    sub=$1
    [ "$sub" = "push" ] && block "agents never push (git push)"
    case "$sub" in
      commit|merge|cherry-pick|revert|am)
        case " $* " in *" --abort "*|*" --quit "*) continue ;; esac
        branch=$(git -C "$gdir" symbolic-ref --short -q HEAD 2>/dev/null)
        [ "$branch" = "$MAIN" ] && block "no git $sub on '$MAIN' (only the watcher merges into $MAIN)"
        case "$branch" in milestone-*)
          milestone_merge_ok "$gdir" "$branch" "$sub" "$@" \
            || block "no git $sub on '$branch' here ($WHY)"
          ;;
        esac
        ;;
    esac
  done
  exit 0
}
exit $?
