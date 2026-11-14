#!/usr/bin/env bash
# guard-web.sh - PreToolUse hook (WebFetch, WebSearch, Bash curl/wget), multi-agent milestone workflow v1.
# Allows web access only to domains in ~/.claude/allowed-domains.txt (one per line, subdomains included, # comments,
# "*" allows all). WebSearch needs allowed_domains, all of them whitelisted.
# Compatible with an existing global hook: for a tool that ~/.claude/settings.json already guards with a PreToolUse
# hook whose command mentions "domain" (not one of these milestone hooks), this hook allows and leaves the decision
# to it. Bash curl/wget is always checked here unless such a global hook exists for Bash. MILESTONE_GUARDS_FORCE=1
# always checks. Exit 2 + one line on stderr blocks; exit 0 allows.
set -u
LIST="${MILESTONE_ALLOWED_DOMAINS:-$HOME/.claude/allowed-domains.txt}"

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

global_covers() { # <tool> <regex>
  [ "${MILESTONE_GUARDS_FORCE:-0}" = 1 ] && return 1
  [ -f "$HOME/.claude/settings.json" ] || return 1
  jq -r --arg t "$1" '.hooks.PreToolUse[]?
      | select((.matcher // "") as $m | ($m == "" or $m == "*" or ($t | test("^(" + $m + ")$"))))
      | .hooks[]?.command // empty' "$HOME/.claude/settings.json" 2>/dev/null \
    | grep -v 'milestone/hooks/' | grep -Eqi "$2"
}
block() { echo "blocked by guard-web: $1" >&2; exit 2; }

allowed() { # <hostname>
  local h d
  h=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  [ -f "$LIST" ] || return 1
  while IFS= read -r d; do
    d=$(printf '%s' "$d" | tr -d '[:space:]' | tr 'A-Z' 'a-z')
    case "$d" in ""|"#"*) continue ;; "*") return 0 ;; esac
    [ "$h" = "$d" ] && return 0
    case "$h" in *".$d") return 0 ;; esac
  done < "$LIST"
  return 1
}
host_of() { printf '%s' "$1" | sed -E 's#^[a-zA-Z]+://##; s#^[^@/]*@##; s#[/:?\#].*$##'; }

case "$tool" in
  WebFetch)
    global_covers WebFetch 'domain' && exit 0
    url=$(printf '%s' "$input" | jq -r '.tool_input.url // empty')
    h=$(host_of "$url")
    allowed "$h" || block "domain '$h' not in $LIST"
    ;;
  WebSearch)
    global_covers WebSearch 'domain' && exit 0
    doms=$(printf '%s' "$input" | jq -r '.tool_input.allowed_domains[]? // empty')
    [ -n "$doms" ] || block "WebSearch needs allowed_domains from $LIST"
    for d in $doms; do allowed "$d" || block "domain '$d' not in $LIST"; done
    ;;
  Bash)
    global_covers Bash 'domain' && exit 0
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])(curl|wget)([[:space:]]|$)' || exit 0
    for url in $(printf '%s' "$cmd" | grep -Eo '[a-zA-Z]+://[^[:space:]"'"'"'<>|;)]+'); do
      h=$(host_of "$url")
      allowed "$h" || block "domain '$h' not in $LIST"
    done
    ;;
esac
exit 0
