#!/usr/bin/env bash
# milestone-wait.sh - event wait of the multi-agent milestone workflow v1 (see v1/INTERFACES.md, "Scripts").
#
#   milestone-wait.sh <slug> --caller tm|coordinator|worker-1|worker-2|review --sources <list> [--timeout 540]
#   (sources: answers,watcher,status,inbox,events)
#
# Blocks in the foreground until at least one new event, prints one line per event and exits 0;
# exit 3 = timeout without events (call it again); exit 2 = usage or setup error.
#   answer <path>                       new file in <C>/answers/ (*.md)
#   watcher <log line>                  new Watcher log line about a task-* branch or milestone-<slug>
#   status TASK-<id> <old> -> <new>     a board task changed status (`$BNG cli task list --plain`)
#   inbox <path>                        a *.md file in <C>/milestone/inbox/<caller>/ (not yet renamed to .read or
#                                       .done by its reader); reported on every call until the reader renames it, so
#                                       a replacement session (k+1) also gets the open assignment
#   event <line>                        new line in <C>/milestone/events.log
# Read positions: <C>/milestone/wait-<caller>.state, written only when the events are printed, so nothing is
# reported twice or missed between calls (inbox: see above). First call: existing answers and events.log lines are
# reported; the watcher log starts at its current end; task statuses are recorded without reporting them.
# Polls inside the script: files every 5 s, the board every 30 s. Call it from the Bash tool with a tool timeout
# above --timeout (e.g. 600000 ms for the default 540 s), or the tool's default limit ends it early.
# Needs: bash, git; portable to macOS (bash 3.2, BSD tools) and Linux. Writes only the state file (and creates
# <C>/answers, <C>/milestone/inbox/<caller> if missing).
set -u

usage() { echo "usage: milestone-wait.sh <slug> --caller tm|coordinator|worker-1|worker-2|review --sources <list> [--timeout <sec>]" >&2; exit 2; }
[ $# -ge 1 ] || usage
SLUG=$1; shift
CALLER=""; SOURCES=""; TIMEOUT=540
while [ $# -gt 0 ]; do
  case "$1" in
    --caller) CALLER=${2:-}; shift 2 ;;
    --sources) SOURCES=${2:-}; shift 2 ;;
    --timeout) TIMEOUT=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done
case "$CALLER" in tm|coordinator|worker-1|worker-2|review) ;; *) usage ;; esac
[ -n "$SOURCES" ] || usage
for src in $(echo "$SOURCES" | tr ',' ' '); do
  case "$src" in answers|watcher|status|inbox|events) ;;
    *) echo "error: unknown source '$src' (answers,watcher,status,inbox,events)" >&2; exit 2 ;; esac
done
case "$TIMEOUT" in ''|*[!0-9]*) usage ;; esac
FILE_POLL=${MILESTONE_WAIT_POLL:-5}
BOARD_POLL=${MILESTONE_WAIT_BOARD_POLL:-30}

has() { case ",$SOURCES," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: not in a git checkout" >&2; exit 2; }
C="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)/backlog-ng"
mkdir -p "$C/milestone/inbox/$CALLER" "$C/answers" || { echo "error: cannot create $C/milestone" >&2; exit 2; }
STATE="$C/milestone/wait-$CALLER.state"
TMP="$C/milestone/.wait-$CALLER-$$"
trap 'rm -f "$TMP".*' EXIT

claude_key() {
  awk -v k="$1" '
    /^## / { insec = ($0 ~ /^## Milestone workflow[ \t]*$/); next }
    insec && index($0, "- " k ":") == 1 {
      v = substr($0, length(k) + 4); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v ~ /^`.*`$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$top/CLAUDE.md" 2>/dev/null
}
WLOG=$(claude_key "Watcher log"); WLOG=${WLOG/#\~/$HOME}
BNG=$(claude_key "BNG"); BNG=${BNG/#\~/$HOME}
has watcher && [ -z "$WLOG" ] && { echo "error: CLAUDE.md has no 'Watcher log'" >&2; exit 2; }
has status && [ -z "$BNG" ] && { echo "error: CLAUDE.md has no 'BNG'" >&2; exit 2; }

# ---- state: lines "<kind>\t<key>\t<value>" (seen answer/inbox names, file offsets, task statuses) ----
FIRST=0; [ -f "$STATE" ] || FIRST=1
: > "$TMP.state"; [ -f "$STATE" ] && cp "$STATE" "$TMP.state"
get() { awk -F'\t' -v k="$1" -v n="$2" '$1 == k && $2 == n { print $3; exit }' "$TMP.state"; }
put() { awk -F'\t' -v k="$1" -v n="$2" '!($1 == k && $2 == n)' "$TMP.state" > "$TMP.s2"
        printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TMP.s2"; mv "$TMP.s2" "$TMP.state"; }
save() { mv "$TMP.state" "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }

: > "$TMP.ev"
emit() { printf '%s\n' "$1" >> "$TMP.ev"; }

# new complete lines of <file> after offset <kind>/<file>; prints them; updates the offset in the state
new_lines() { # <state-key> <file> <start-at-end-if-new: 0|1>
  local key=$1 f=$2 atend=$3 off size keep last
  [ -f "$f" ] || return 0
  size=$(wc -c < "$f" | tr -d ' ')
  off=$(get off "$key")
  if [ -z "$off" ]; then [ "$atend" = 1 ] && { put off "$key" "$size"; return 0; }; off=0; fi
  [ "$size" -lt "$off" ] && off=0              # rotated or truncated
  [ "$size" -eq "$off" ] && return 0
  tail -c +$((off + 1)) "$f" | head -c $((size - off)) > "$TMP.chunk"
  if [ "$(tail -c 1 "$TMP.chunk" | od -An -c | tr -d ' ')" != '\n' ]; then   # drop a partial last line
    last=$(tail -n 1 "$TMP.chunk" | wc -c | tr -d ' ')
    keep=$((size - off - last))
    head -c "$keep" "$TMP.chunk" > "$TMP.c2"; mv "$TMP.c2" "$TMP.chunk"
    put off "$key" $((off + keep))
  else
    put off "$key" "$size"
  fi
  cat "$TMP.chunk"
}

check_files() {
  local f n line
  if has answers; then
    for f in "$C/answers"/*.md; do
      [ -f "$f" ] || continue; n=${f##*/}
      [ -n "$(get answer "$n")" ] && continue
      put answer "$n" 1; emit "answer $f"
    done
  fi
  if has inbox; then
    for f in "$C/milestone/inbox/$CALLER"/*.md; do
      [ -f "$f" ] && emit "inbox $f"
    done
  fi
  if has events; then
    new_lines events "$C/milestone/events.log" 0 > "$TMP.lines"
    while IFS= read -r line; do [ -n "$line" ] && emit "event $line"; done < "$TMP.lines"
  fi
  if has watcher; then
    new_lines watcher "$WLOG" 1 > "$TMP.lines"
    while IFS= read -r line; do
      case "$line" in *task-[0-9]*|*"milestone-$SLUG"*) emit "watcher $line" ;; esac
    done < "$TMP.lines"
  fi
}

check_board() { # report status changes; on the very first call only record them
  local id st old
  (cd "$top" && $BNG cli task list --plain) 2>/dev/null | awk '
    /^[^ \t].*:[ \t]*$/ { st = $0; sub(/:[ \t]*$/, "", st); next }
    { if (match($0, /[Tt][Aa][Ss][Kk]-[0-9]+/) && st != "") print "TASK-" substr($0, RSTART + 5, RLENGTH - 5) "\t" st }
  ' > "$TMP.board"
  while IFS="$(printf '\t')" read -r id st; do
    [ -n "$id" ] || continue
    old=$(get status "$id")
    [ "$old" = "$st" ] && continue
    put status "$id" "$st"
    [ "$FIRST" = 1 ] && continue
    emit "status $id ${old:-none} -> $st"
  done < "$TMP.board"
}

deadline=$(( $(date +%s) + TIMEOUT ))
next_board=0
while :; do
  check_files
  now=$(date +%s)
  if has status && [ "$now" -ge "$next_board" ]; then check_board; next_board=$((now + BOARD_POLL)); fi
  if [ -s "$TMP.ev" ]; then save; cat "$TMP.ev"; exit 0; fi
  FIRST=0
  if [ "$(date +%s)" -ge "$deadline" ]; then save; exit 3; fi
  sleep "$FILE_POLL"
done
