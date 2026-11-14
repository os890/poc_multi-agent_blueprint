#!/usr/bin/env bash
# milestone-check.sh - step 0 prerequisites of the multi-agent milestone workflow v1 (see v1/INTERFACES.md).
#
#   milestone-check.sh start|resume      run in the maintainer's main checkout
#
# Prints `missing: <what>` (-> exit 1), `warn: <what>`, `open: milestone-<slug>` for each open milestone, and a
# last line `result: ok|missing`. start with an open milestone -> exit 1; resume without exactly one -> exit 1.
# Minimal on purpose (for the spike). Its only write: `git worktree prune`. A milestone checkout on the branch
# (not detached) is reported for resume; any worktree with the branch checked out would block the watcher's merge.
set -u
MODE=${1:-}
case "$MODE" in start|resume) ;; *) echo "usage: milestone-check.sh start|resume" >&2; exit 2 ;; esac
MAIN="${MILESTONE_MAIN_BRANCH:-main}"
CL="$HOME/.claude"
missing=0
miss() { echo "missing: $1"; missing=1; }
# one-time project setup, committed on main before the first milestone (not a milestone task: the check runs on main)
SETUP=" - one-time setup on $MAIN, see README Setup"
warn() { echo "warn: $1"; }

top=$(git rev-parse --show-toplevel 2>/dev/null) || { miss "a git repository (run in the main checkout)"; echo "result: missing"; exit 1; }
[ "$(cd "$(git rev-parse --git-dir)" && pwd -P)" = "$(cd "$(git rev-parse --git-common-dir)" && pwd -P)" ] \
  || miss "the main checkout (this is a linked worktree)"

# --- CLAUDE.md keys ---
key() {
  awk -v k="$1" '
    /^## / { insec = ($0 ~ /^## Milestone workflow[ \t]*$/); next }
    insec && index($0, "- " k ":") == 1 {
      v = substr($0, length(k) + 4); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v ~ /^`.*`$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$top/CLAUDE.md" 2>/dev/null
}
if ! grep -q '^## Milestone workflow' "$top/CLAUDE.md" 2>/dev/null; then
  miss "CLAUDE.md section '## Milestone workflow'"
else
  for k in "BNG" "Minimal test command" "Full test command" "Docs to check against" "Test reports"; do
    [ -n "$(key "$k")" ] || miss "CLAUDE.md key '$k'"
  done
  for k in "Single test command" "Watcher log" "Supported platforms"; do
    [ -n "$(key "$k")" ] || warn "CLAUDE.md key '$k' not set"
  done
  bng=$(key "BNG")
  if [ -n "$bng" ]; then
    set -f; set -- $bng; set +f
    bng_exe=${1/#\~/$HOME}
    command -v "$bng_exe" >/dev/null 2>&1 || [ -x "$bng_exe" ] || miss "\$BNG executable: $1"
  fi
  lessons=$(key "Lessons file"); lessons=${lessons:-docs/lessons-learned.md}
  [ -f "$top/$lessons" ] || warn "lessons file $lessons does not exist yet"
  wlog=$(key "Watcher log"); wlog=${wlog/#\~/$HOME}
  if [ -n "$wlog" ]; then
    [ -f "$wlog" ] || miss "watcher log $wlog (is the backlog-ng watcher running?)"
    [ -f "$wlog" ] && [ -z "$(find "$wlog" -mmin -1440 2>/dev/null)" ] && warn "watcher log not written for 24 h: is the watcher running?"
  fi
fi

# --- skills, agents, command, scripts, hooks installed (user level, or project level and committed) ---
# Required committed (or in ~/.claude): the worker and review sessions and their sub-agents work in task worktrees
# and the milestone checkout, which see the project's .claude/ only as committed in git, never an uncommitted copy.
inst() { # <path under .claude>
  [ -e "$CL/$1" ] && return 0
  git -C "$top" cat-file -e "HEAD:.claude/$1" 2>/dev/null && return 0
  if [ -e "$top/.claude/$1" ]; then miss ".claude/$1 is not committed (sessions in worktrees won't see it)"
  else miss ".claude/$1 (in $CL or the project)"; fi
}
for s in milestone-coordinator milestone-task-manager milestone-worker milestone-implementer milestone-review milestone-review-type milestone-validator milestone-goal-check; do
  inst "skills/$s/SKILL.md"
done
for a in milestone-implementer milestone-review-type milestone-validator milestone-goal-check; do inst "agents/$a.md"; done
for old in milestone-orchestrator; do   # dropped skill (before the coordinator/task-manager split)
  { [ -e "$CL/skills/$old" ] || [ -e "$top/.claude/skills/$old" ]; } && warn "old skill $old is still installed (dropped in v1; remove it, see README)"
done
inst "commands/milestone.md"
# Scripts and hooks run only from ~/.claude/milestone/ (a trial-run lesson): any session can write the project,
# so a project copy could switch the guards off or fake a green suite.
for f in scripts/milestone-test.sh scripts/milestone-wait.sh hooks/guard-main.sh hooks/guard-rewrite.sh hooks/guard-install.sh hooks/guard-web.sh; do
  [ -f "$CL/milestone/$f" ] || miss "$CL/milestone/$f (scripts and hooks run only from there)"
done
[ -e "$top/.claude/milestone" ] && miss "no project copy $top/.claude/milestone (remove it; scripts and hooks run only from $CL/milestone)"
git -C "$top" check-ignore -q .claude/milestone/x 2>/dev/null || warn ".claude/milestone/ is not in .gitignore (a project copy could be committed)$SETUP"
hooks_cfg=$( (git -C "$top" show HEAD:.claude/settings.json; cat "$CL/settings.json") 2>/dev/null)
for h in guard-main guard-rewrite guard-install guard-web; do
  printf '%s' "$hooks_cfg" | grep -q "$h.sh" \
    || miss "hook $h.sh in the committed .claude/settings.json or in $CL/settings.json (see settings-snippet.json)$SETUP"
done
printf '%s' "$hooks_cfg" | grep -q 'CLAUDE_PROJECT_DIR' \
  && miss "hook commands that reference \$CLAUDE_PROJECT_DIR (a project file could replace a guard; use $CL/milestone/hooks only)"
[ -f "$top/.claude/settings.local.json" ] && grep -q 'guard-' "$top/.claude/settings.local.json" \
  && warn "hooks only in .claude/settings.local.json don't count (commit them in .claude/settings.json)"

# --- open milestones, milestone checkout, main checkout ---
git worktree prune 2>/dev/null
open=""
for ref in $(git for-each-ref --format='%(refname:short)' 'refs/heads/milestone-*'); do
  git merge-base --is-ancestor "$ref" "$MAIN" 2>/dev/null && continue
  echo "open: $ref"; open="$open $ref"
done
nopen=$(echo $open | wc -w | tr -d ' ')
if [ "$MODE" = start ] && [ "$nopen" -gt 0 ]; then miss "no other open milestone (use resume, or close it first)"; fi
if [ "$MODE" = resume ]; then
  [ "$nopen" -eq 1 ] || miss "exactly one open milestone to resume (found $nopen)"
  for ref in $open; do
    # the task manager's milestone checkout must be detached: the watcher merges into the branch, nobody commits on it
    wt=$(git worktree list --porcelain | awk -v b="refs/heads/$ref" '/^worktree /{w=substr($0,10)} $0=="branch " b {print w; exit}')
    # review mode `milestone`: the task manager's checkout <top>.worktrees/<ref> is on the branch (hand merges);
    # review mode `per task`: it must be detached. Any other worktree on the branch is wrong in both modes.
    if [ -n "$wt" ]; then
      if [ "$(cd "$wt" && pwd -P)" = "$(cd "$top.worktrees/$ref" 2>/dev/null && pwd -P)" ]; then
        warn "milestone checkout $wt is on $ref: right for review mode 'milestone'; in 'per task' mode detach it (git -C \"$wt\" checkout --detach $ref)"
      else
        miss "no other worktree on $ref ($wt has it checked out)"
      fi
    fi
  done
fi
[ -x "$top/tools/verify.sh" ] || miss "tools/verify.sh, executable (the watcher's quality gate before each merge)$SETUP"
# escalations are board tasks with the label `escalation` (inline `labels: [...]` or a block list under `labels:`)
awk '/^labels:/ { inl = 1; if ($0 ~ /escalation/) f = 1; next }
     inl && /^[ \t]*-/ { if ($0 ~ /escalation/) f = 1; next }
     { inl = 0 }
     END { exit !f }' "$top/backlog/config.yml" 2>/dev/null \
  || miss "label 'escalation' in backlog/config.yml (escalations are board tasks)$SETUP"
[ -x "$(dirname "$0")/milestone-wait.sh" ] || miss "milestone-wait.sh next to milestone-check.sh"
# board files created in the main checkout (milestone, tasks, escalations) stay untracked there; if the milestone
# branch also has them, the watcher's merge into main fails ("untracked working tree files would be overwritten")
for ref in $open; do
  clash=$(git -C "$top" ls-files --others --exclude-standard -- backlog | while IFS= read -r f; do
    git -C "$top" cat-file -e "$ref:$f" 2>/dev/null && echo "$f"; done | head -3)
  [ -n "$clash" ] && warn "untracked board files in the main checkout that $ref also has; the merge into $MAIN will fail until they are removed or committed: $(echo $clash)"
done
[ -n "$(git -C "$top" status --porcelain --untracked-files=no 2>/dev/null)" ] \
  && warn "uncommitted changes in the main checkout (the watcher's merge into $MAIN would fail)"

if [ $missing -eq 1 ]; then echo "result: missing"; exit 1; fi
echo "result: ok"; exit 0
