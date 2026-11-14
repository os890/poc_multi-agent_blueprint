#!/usr/bin/env bash
# guard-rewrite.sh - PreToolUse hook (Bash), multi-agent milestone workflow v1.
# Nothing merged is rewritten. Blocks:
#  - any `git rebase` (except --abort/--quit): agents never rebase;
#  - `git reset <commit>` to another commit, and `git commit --amend`, when the checkout is on a `milestone-*`
#    branch or its HEAD is already merged into one (= HEAD is an ancestor of a `milestone-*` branch);
#  - `git push --force|-f|--force-with-lease` (guard-main blocks every push anyway).
# `git reset` without a commit (unstage, --hard to HEAD) and `git merge --abort` stay allowed.
# Exit 2 + one line on stderr blocks; exit 0 allows. Same rule for every agent.
set -u

input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0
[ -n "$dir" ] || dir=$PWD

block() { echo "blocked by guard-rewrite: $1" >&2; exit 2; }

# protected <gitdir>: on milestone-*, or HEAD already merged into a milestone-* branch
protected() {
  local g=$1 b ref
  b=$(git -C "$g" symbolic-ref --short -q HEAD 2>/dev/null)
  case "$b" in milestone-*) return 0 ;; esac
  for ref in $(git -C "$g" for-each-ref --format='%(refname)' 'refs/heads/milestone-*' 2>/dev/null); do
    git -C "$g" merge-base --is-ancestor HEAD "$ref" 2>/dev/null && return 0
  done
  return 1
}

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
    sub=$1; shift
    case "$sub" in
      rebase)
        case " $* " in *" --abort "*|*" --quit "*) continue ;; esac
        block "agents never rebase (git rebase)"
        ;;
      push)
        case " $* " in *" --force"*|*" -f "*|*" +"*) block "no force push" ;; esac
        ;;
      commit)
        case " $* " in *" --amend"*) protected "$gdir" && block "no --amend of a commit on or merged into a milestone branch" ;; esac
        ;;
      reset)
        target=""
        for a in "$@"; do
          case "$a" in --) break ;; -*) ;; *) target=$a; break ;; esac
        done
        [ -n "$target" ] || continue
        t=$(git -C "$gdir" rev-parse -q --verify "$target^{commit}" 2>/dev/null) || continue   # a path, not a commit
        h=$(git -C "$gdir" rev-parse -q --verify HEAD 2>/dev/null)
        [ "$t" = "$h" ] && continue
        protected "$gdir" && block "no git reset to another commit on or merged into a milestone branch"
        ;;
    esac
  done
  exit 0
}
exit $?
