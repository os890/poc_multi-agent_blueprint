#!/usr/bin/env bash
# guard-install.sh - PreToolUse hook (Bash), multi-agent milestone workflow v1.
# Blocks npm/pnpm/yarn/bun installs without --ignore-scripts.
# Compatible with an existing global hook: if ~/.claude/settings.json already has a PreToolUse hook for Bash whose
# command mentions "install" (not one of these milestone hooks), this hook allows and leaves the decision to it, so
# nothing is blocked twice. MILESTONE_GUARDS_FORCE=1 always checks.
# Exit 2 + one line on stderr blocks; exit 0 allows.
set -u

input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" = "Bash" ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

global_covers() { # <tool> <regex>
  [ "${MILESTONE_GUARDS_FORCE:-0}" = 1 ] && return 1
  [ -f "$HOME/.claude/settings.json" ] || return 1
  jq -r --arg t "$1" '.hooks.PreToolUse[]?
      | select((.matcher // "") as $m | ($m == "" or $m == "*" or ($t | test("^(" + $m + ")$"))))
      | .hooks[]?.command // empty' "$HOME/.claude/settings.json" 2>/dev/null \
    | grep -v 'milestone/hooks/' | grep -Eqi "$2"
}
global_covers Bash 'install' && exit 0

if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])(npm|pnpm|yarn|bun)[[:space:]]+(install|i|ci|add)([[:space:]]|$)' \
   && ! printf '%s' "$cmd" | grep -q -- '--ignore-scripts'; then
  echo "blocked by guard-install: package installs only with --ignore-scripts" >&2
  exit 2
fi
exit 0
