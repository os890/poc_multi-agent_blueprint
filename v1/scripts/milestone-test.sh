#!/usr/bin/env bash
# milestone-test.sh - test script of the multi-agent milestone workflow v1 (see v1/INTERFACES.md, "Scripts").
#
#   milestone-test.sh minimal|full <dir>          run the suite in <dir> as it is (also an uncommitted merge)
#   milestone-test.sh bisect <good> <bad> <test>... first-parent bisect per test in its own detached worktree
#   milestone-test.sh repro <dir> <command>       run one command (5-min limit) to reproduce a finding
#
# Exit codes: minimal|full|bisect 0 green, 1 red, 2 error (could not run);
#             repro 0 reproduced (command failed), 1 not reproduced, 2 error.
# The last stdout line is always `report: <path>`. Writes only under <C>/tests/
# (<C> = $(git rev-parse --git-common-dir)/backlog-ng), plus the bisect worktree there (removed afterwards).
#
# Reads from the project's CLAUDE.md, section `## Milestone workflow`: `Minimal test command`, `Full test command`,
# `Single test command` ({test} = JUnit <classname>.<name>), `Test reports` (JUnit XML glob, relative to <dir>).
# Needs: bash, git >= 2.29, jq is not needed here. Portable to macOS (bash 3.2, BSD tools) and Linux.
set -u

MAX_RERUNS=${MILESTONE_MAX_RERUNS:-10}       # failed tests rerun alone (flaky check)
MAX_BISECT=${MILESTONE_MAX_BISECT:-5}        # tests bisected per call
REPRO_LIMIT=${MILESTONE_REPRO_TIMEOUT:-300}  # seconds

# ---------- helpers ----------
abspath() { (cd "$1" 2>/dev/null && pwd -P); }
common_dir() { (cd "$1" && cd "$(git rev-parse --git-common-dir)" && pwd -P) 2>/dev/null; }

claude_key() { # <toplevel> <Key>
  awk -v k="$2" '
    /^## / { insec = ($0 ~ /^## Milestone workflow[ \t]*$/); next }
    insec && index($0, "- " k ":") == 1 {
      v = substr($0, length(k) + 4); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v ~ /^`.*`$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$1/CLAUDE.md" 2>/dev/null
}

REPORT=""
finish() { # <exit code>  - prints the last line and exits
  echo "report: ${REPORT:--}"
  exit "$1"
}
early_error() { # <message>  - error before <C> is known
  REPORT="${TMPDIR:-/tmp}/milestone-test-error-$$.md"
  printf 'suite: %s\nresult: error\nerror: %s\n' "${MODE:-?}" "$1" > "$REPORT"
  echo "error: $1" >&2
  finish 2
}

# junit_failures <dir> <glob> <marker>: "#total <n>" then "<classname>.<name>\t<message>" per failed testcase,
# only from report files newer than <marker>.
junit_failures() {
  local f total=0
  [ -n "$2" ] || { echo "#total 0"; return; }
  find "$1" -type f -path "$1/$2" -newer "$3" 2>/dev/null | while IFS= read -r f; do
    awk 'BEGIN { RS = "\001" }
      function attr(s, a,   m) {
        if (match(s, "[ \t\r\n]" a "=\"[^\"]*\"")) { m = substr(s, RSTART + length(a) + 3, RLENGTH - length(a) - 4); return m }
        return ""
      }
      {
        n = split($0, p, "<testcase")
        for (i = 2; i <= n; i++) {
          seg = p[i]; head = seg; sub(/>.*/, "", head); total++
          if (head ~ /\/$/) continue
          body = seg; e = index(body, "</testcase>"); if (e) body = substr(body, 1, e)
          if (body ~ /<(failure|error)/) {
            ft = body; sub(/^.*<(failure|error)/, "", ft); sub(/>.*/, "", ft)
            msg = attr(" " ft, "message"); gsub(/[\t\r\n]+/, " ", msg)
            if (length(msg) > 200) msg = substr(msg, 1, 200) "..."
            print attr(head, "classname") "." attr(head, "name") "\t" msg
          }
        }
      }
      END { print "#total " total }' "$f"
  done | awk '/^#total / { t += $2; next } { print } END { print "#total " (t + 0) }'
}

run_in() { # <dir> <command> >> log ; returns the command's exit code
  (cd "$1" && bash -c "$2")
}

# ---------- minimal | full ----------
run_suite() { # <suite> <dir>
  local suite=$1 dir top C sha dirty base log key cmd single glob marker rc fails total
  dir=$(abspath "$2") || early_error "no such directory: $2"
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || early_error "not a git checkout: $dir"
  C="$(common_dir "$dir")/backlog-ng"; mkdir -p "$C/tests" || early_error "cannot create $C/tests"
  sha=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null) || sha=nohead
  dirty=""; [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ] && dirty=" (+ uncommitted changes)"
  base="$C/tests/$suite-$sha"; log="$base.log"; REPORT="$base.md"
  [ "$suite" = minimal ] && key="Minimal test command" || key="Full test command"
  cmd=$(claude_key "$top" "$key"); single=$(claude_key "$top" "Single test command"); glob=$(claude_key "$top" "Test reports")

  write_head() { printf 'suite: %s\ndir: %s\ncommit: %s%s\nresult: %s\ncounts: %s\nlog: %s\n' \
    "$suite" "$dir" "$sha" "$dirty" "$1" "$2" "$log" > "$REPORT"; }

  if [ -z "$cmd" ]; then
    : > "$log"; write_head error "-"; echo "error: CLAUDE.md has no '$key'" >> "$REPORT"; finish 2
  fi

  marker="$C/tests/.marker-$$"; : > "$marker"; sleep 1
  echo "### $key: $cmd" > "$log"
  run_in "$dir" "$cmd" >> "$log" 2>&1; rc=$?
  if [ $rc -eq 126 ] || [ $rc -eq 127 ]; then
    rm -f "$marker"; write_head error "-"; echo "error: the command could not start (exit $rc), see log" >> "$REPORT"; finish 2
  fi

  fails=$(junit_failures "$dir" "$glob" "$marker"); rm -f "$marker"
  total=$(printf '%s\n' "$fails" | sed -n 's/^#total //p'); fails=$(printf '%s\n' "$fails" | grep -v '^#total ')

  if [ -z "$fails" ]; then
    if [ $rc -eq 0 ]; then write_head green "$total tests, 0 failed, 0 flaky"; finish 0; fi
    write_head red "$total tests, exit $rc, no failed testcase found in the reports"
    printf '\nfailed 1\ntest: (unparsed, see log)\nerror: exit code %s\ncause: unknown\n' "$rc" >> "$REPORT"
    finish 1
  fi

  # rerun each failed test alone once: passes -> flaky
  local failed_out="" flaky_out="" nf=0 nk=0 n=0 id msg one
  while IFS="$(printf '\t')" read -r id msg; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    if [ -n "$single" ] && [ $n -le "$MAX_RERUNS" ]; then
      one=${single//\{test\}/$id}
      echo "### rerun alone: $one" >> "$log"
      if run_in "$dir" "$one" >> "$log" 2>&1; then
        nk=$((nk + 1)); flaky_out="$flaky_out
flaky $nk
test: $id
error: $msg
"
        continue
      fi
    fi
    nf=$((nf + 1)); failed_out="$failed_out
failed $nf
test: $id
error: $msg
cause: unknown
"
  done <<EOF
$fails
EOF
  if [ $nf -eq 0 ]; then
    write_head green "$total tests, 0 failed, $nk flaky"; printf '%s' "$flaky_out" >> "$REPORT"; finish 0
  fi
  write_head red "$total tests, $nf failed, $nk flaky"
  printf '%s%s' "$failed_out" "$flaky_out" >> "$REPORT"
  [ -z "$single" ] && echo "note: no 'Single test command', failed tests were not rerun (flaky check skipped)" >> "$REPORT"
  finish 1
}

# ---------- bisect ----------
run_bisect() { # <good> <bad> <test>...
  local good bad top C sbad base log wt single runner n=0 nf=0 ng=0 out="" t one first subj id cause
  [ $# -ge 3 ] || early_error "usage: bisect <good> <bad> <test>..."
  top=$(git rev-parse --show-toplevel 2>/dev/null) || early_error "run bisect inside the repository"
  good=$(git rev-parse -q --verify "$1^{commit}") || early_error "unknown commit: $1"
  bad=$(git rev-parse -q --verify "$2^{commit}") || early_error "unknown commit: $2"
  shift 2
  C="$(common_dir "$top")/backlog-ng"; mkdir -p "$C/tests" || early_error "cannot create $C/tests"
  sbad=$(git rev-parse --short "$bad"); base="$C/tests/bisect-$sbad"; log="$base.log"; REPORT="$base.md"
  wt="$C/tests/bisect-wt-$sbad"
  single=$(claude_key "$top" "Single test command")

  write_head() { printf 'suite: bisect\ndir: %s\ncommit: %s\nresult: %s\ncounts: %s\nlog: %s\n' \
    "$wt" "$sbad" "$1" "$2" "$log" > "$REPORT"; }
  if [ -z "$single" ]; then : > "$log"; write_head error "-"; echo "error: CLAUDE.md has no 'Single test command'" >> "$REPORT"; finish 2; fi

  git worktree remove --force "$wt" >/dev/null 2>&1; rm -rf "$wt"
  echo "### worktree $wt at $sbad (good: $(git rev-parse --short "$good"))" > "$log"
  if ! git worktree add --detach "$wt" "$bad" >> "$log" 2>&1; then
    write_head error "-"; echo "error: could not create the bisect worktree, see log" >> "$REPORT"; finish 2
  fi
  runner="$C/tests/.bisect-run-$$.sh"

  for t in "$@"; do
    n=$((n + 1)); [ $n -le "$MAX_BISECT" ] || { echo "### skipped (limit $MAX_BISECT): $t" >> "$log"; continue; }
    one=${single//\{test\}/$t}
    printf '#!/usr/bin/env bash\ncd %q || exit 125\nbash -c %q\nrc=$?\ncase $rc in 0) exit 0 ;; 126|127) exit 125 ;; *) exit 1 ;; esac\n' "$wt" "$one" > "$runner"
    git -C "$wt" checkout -q --detach "$bad" >> "$log" 2>&1
    echo "### test at bad: $one" >> "$log"
    if bash "$runner" >> "$log" 2>&1; then ng=$((ng + 1)); echo "### passes at bad, not bisected: $t" >> "$log"; continue; fi
    cause=unknown
    echo "### bisect: $t" >> "$log"
    if git -C "$wt" bisect start --first-parent "$bad" "$good" >> "$log" 2>&1 \
       && git -C "$wt" bisect run bash "$runner" >> "$log" 2>&1; then
      first=$(git -C "$wt" rev-parse -q --verify refs/bisect/bad)
      subj=$(git -C "$wt" log -1 --format=%s "$first")
      id=$(printf '%s' "$subj" | grep -Eio 'task-[0-9]+' | head -1 | sed 's/^[a-zA-Z]*-//')
      [ -n "$id" ] && cause="merge of TASK-$id ($(git -C "$wt" rev-parse --short "$first"))"
    fi
    git -C "$wt" bisect reset >> "$log" 2>&1
    nf=$((nf + 1)); out="$out
failed $nf
test: $t
error: fails at $sbad
cause: $cause
"
  done
  rm -f "$runner"
  git worktree remove --force "$wt" >> "$log" 2>&1
  if [ $nf -eq 0 ]; then write_head green "$n tests, 0 failing at bad, $ng passing"; finish 0; fi
  write_head red "$n tests, $nf failing at bad, $ng passing"; printf '%s' "$out" >> "$REPORT"; finish 1
}

# ---------- repro ----------
run_repro() { # <dir> <command>
  local dir C sha k base log rc pid wd result code
  [ $# -eq 2 ] || early_error "usage: repro <dir> <command>"
  dir=$(abspath "$1") || early_error "no such directory: $1"
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || early_error "not a git checkout: $dir"
  C="$(common_dir "$dir")/backlog-ng"; mkdir -p "$C/tests" || early_error "cannot create $C/tests"
  sha=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null) || sha=nohead
  k=1; while [ -e "$C/tests/repro-$sha-$k.md" ]; do k=$((k + 1)); done
  base="$C/tests/repro-$sha-$k"; log="$base.log"; REPORT="$base.md"
  echo "### repro: $2" > "$log"
  set -m
  (cd "$dir" && exec bash -c "$2") >> "$log" 2>&1 &
  pid=$!
  ( sleep "$REPRO_LIMIT"; kill -TERM -"$pid" 2>/dev/null && : > "$base.timeout" ) >/dev/null 2>&1 &
  wd=$!
  wait "$pid"; rc=$?
  kill "$wd" 2>/dev/null; set +m
  if [ -e "$base.timeout" ]; then
    rm -f "$base.timeout"; result="error"; code=2
    echo "### timed out after ${REPRO_LIMIT}s (may be the hang the finding describes)" >> "$log"
  elif [ $rc -eq 126 ] || [ $rc -eq 127 ]; then result="error"; code=2
  elif [ $rc -ne 0 ]; then result="reproduced"; code=0
  else result="not reproduced"; code=1
  fi
  printf 'suite: repro\ndir: %s\ncommit: %s\ncommand: %s\nresult: %s\nexit: %s\nlog: %s\n' \
    "$dir" "$sha" "$2" "$result" "$rc" "$log" > "$REPORT"
  finish $code
}

MODE=${1:-}
[ $# -ge 1 ] && shift
case "$MODE" in
  minimal|full) [ $# -eq 1 ] || early_error "usage: $MODE <dir>"; run_suite "$MODE" "$1" ;;
  bisect) run_bisect "$@" ;;
  repro) run_repro "$@" ;;
  *) early_error "usage: milestone-test.sh minimal|full <dir> | bisect <good> <bad> <test>... | repro <dir> <command>" ;;
esac
