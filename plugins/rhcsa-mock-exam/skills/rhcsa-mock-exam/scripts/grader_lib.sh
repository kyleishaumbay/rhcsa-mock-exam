#!/bin/bash
# grader_lib.sh v2 — shared runtime for generated RHCSA mock-exam graders.
# A grader ships as ONE file: this library followed by the paper's checks
# (tools/build_grader.sh does the concatenation, so the library is never retyped).
# Contract: READ-ONLY. Nothing in here or in any check may write, restart, mount,
# relabel or "fix" anything on the exam nodes. Checks observe persisted state and report.
#
# Writing the checks:
#   PAPER="RHCSA9 Mock 3"
#   hosts node2=root@node2          # optional: how --all reaches a node (default root@<node>)
#   task 5 STOR node1 "vgweb (PE 16 MiB) on a GPT partition; lvweb ext4 on /webfiles"
#   t5() {
#     must expect_ok "vgs vgweb" || return     # gate: the checks below make no sense without it
#     need expect "vgs --noheadings --units m -o vg_extent_size vgweb | tr -d ' '" "16.00m"
#     need mount_persisted /webfiles           # every failing 'need' is reported; the task goes on
#   }
#   requires 12 5                              # 12 depends on 5 (works across nodes with --all)
#   run_all; report
# Older graders that chain checks with && still work: their first failure is reported.
#
# Running (as root, after rebooting every node):
#   bash grader.sh          grade the node you are on
#   bash grader.sh --all    grade this node, then every other node over ssh -> one combined report

declare -A CAT_NAME=(
  [TOOLS]="Understand and use essential tools"
  [SH]="Create simple shell scripts"
  [OPS]="Operate running systems"
  [STOR]="Configure local storage"
  [FS]="Create and configure file systems"
  [DEP]="Deploy, configure and maintain systems"
  [NET]="Manage basic networking"
  [USR]="Manage users and groups"
  [SEC]="Manage security"
  [CON]="Manage containers"
)
CAT_ORDER=(TOOLS SH OPS STOR FS DEP NET USR SEC CON)
PASS_MARK=${PASS_MARK:-210}   # out of 300, as candidates report it
PAPER=${PAPER:-"RHCSA mock exam"}

declare -A T_CAT T_NODE T_DESC T_RES T_FAILS T_STOP T_NOTE T_DEPS NODE_HOST
TASKS=(); REMOTE_OK=()
THIS_NODE=${NODE:-$(hostname -s)}
_SELF=${BASH_SOURCE[0]}
_LAST_CMD=""; _LAST_WHY=""; _TF=(); _TSTOP=0
GRADE_ALL=0; EMIT=0
for _a in "$@"; do
  case $_a in
    --all) GRADE_ALL=1 ;;
    --emit) EMIT=1 ;;
    -h|--help) echo "usage: bash ${_SELF##*/} [--all]   (run as root after rebooting every node)"; exit 0 ;;
  esac
done

task()     { TASKS+=("$1"); T_CAT[$1]=$2; T_NODE[$1]=$3; shift 3; T_DESC[${TASKS[-1]}]="$*"; }
requires() { local t=$1; shift; T_DEPS[$t]="$*"; }
hosts()    { local kv; for kv in "$@"; do NODE_HOST[${kv%%=*}]=${kv#*=}; done; }

# --- check primitives: each returns 0/1 and records what it looked at -----------------
_rec()  { _LAST_CMD=$1; _LAST_WHY=$2; }
# expect '<command>' '<expected output, exact after trimming>'
expect() {
  local out; out=$(bash -c "$1" 2>/dev/null </dev/null | sed 's/[[:space:]]*$//')
  [[ "$out" == "$2" ]] && return 0
  _rec "$1" "expected '$2', got '${out:0:80}'"; return 1
}
# expect_match '<command>' '<extended regex>'
expect_match() {
  local out; out=$(bash -c "$1" 2>/dev/null </dev/null)
  grep -Eq -- "$2" <<<"$out" && return 0
  _rec "$1" "output did not match /$2/"; return 1
}
# expect_ok '<command>'  — command must exit 0
expect_ok() { bash -c "$1" >/dev/null 2>&1 </dev/null && return 0; _rec "$1" "command exited non-zero"; return 1; }
# expect_file_has <file> '<extended regex>'
expect_file_has() {
  [[ -r $1 ]] || { _rec "test -r $1" "$1 missing or unreadable"; return 1; }
  grep -Eq -- "$2" "$1" && return 0
  _rec "grep -E '$2' $1" "no matching line in $1"; return 1
}
# Persistence pairs — use these instead of hand-rolling them.
svc_persisted() { expect "systemctl is-enabled $1" enabled || return 1; expect "systemctl is-active $1" active; }
mount_persisted() {   # <mountpoint> — live mount AND an fstab (or autofs/systemd) source
  expect_ok "findmnt -n $1" || return 1
  expect_ok "findmnt --fstab -n $1" || { _rec "findmnt --fstab -n $1" "mounted now but not in /etc/fstab"; return 1; }
}
fw_persisted() {      # <zone> <service-or-port>
  expect_match "firewall-cmd --permanent --zone=$1 --list-all" "(^|[[:space:]])$2([[:space:]]|$)"
}
# autofs_entry <mountpoint|/->  — "key | options source" lines autofs actually loaded for that
# mount point (read via automount -m, so any master/map file layout grades the same).
# Direct maps live under mount point "/-" with absolute keys.
autofs_entry() { automount -m 2>/dev/null | awk -v m="$1" '/^Mount point: /{mp=$3} mp==m && /\|/'; }
# journal_persisted — journald is writing to disk now and Storage= is not volatile/none.
# Don't count boots: a correct setup that wasn't flushed before the grading reboot shows only one.
journal_persisted() {
  expect_ok "test -s /var/log/journal/\$(cat /etc/machine-id)/system.journal" || return 1
  expect_ok "! systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E '^Storage=' | tail -1 | grep -Eq 'volatile|none'"
}

# --- need / must: run every check in a task --------------------------------------------
_fail() { _TF+=("${_LAST_WHY:-check failed}"$'\x1f'"${_LAST_CMD:-$*}"); }
need() { _LAST_CMD=""; _LAST_WHY=""; "$@" && return 0; _fail "$@"; return 0; }
must() { _LAST_CMD=""; _LAST_WHY=""; "$@" && return 0; _fail "$@"; _TSTOP=1; return 1; }

# --- runner ----------------------------------------------------------------------------
_grade_local() {
  local t rc
  for t in "${TASKS[@]}"; do
    if [[ ${T_NODE[$t]} != any && ${T_NODE[$t]} != "$THIS_NODE" ]]; then T_RES[$t]=SKIP; continue; fi
    if ! declare -F "t$t" >/dev/null; then T_RES[$t]=SKIP; T_NOTE[$t]="no check defined"; continue; fi
    _TF=(); _TSTOP=0; _LAST_CMD=""; _LAST_WHY=""
    "t$t" </dev/null; rc=$?
    if (( ${#_TF[@]} )); then
      T_RES[$t]=FAIL; T_FAILS[$t]=$(printf '%s\n' "${_TF[@]}"); T_STOP[$t]=$_TSTOP
    elif (( rc )); then            # legacy && chain: only the first failure is known
      T_RES[$t]=FAIL; T_FAILS[$t]="${_LAST_WHY:-check failed}"$'\x1f'"${_LAST_CMD:-t$t}"; T_STOP[$t]=1
    else
      T_RES[$t]=PASS
    fi
  done
}

_emit() {   # machine-readable results, used by --all on the remote side
  local t l
  for t in "${TASKS[@]}"; do
    [[ ${T_RES[$t]} == SKIP && -z ${T_NOTE[$t]} ]] && continue
    printf '@@R\t%s\t%s\t%s\n' "$t" "${T_RES[$t]}" "${T_STOP[$t]:-0}"
    [[ ${T_RES[$t]} == FAIL ]] || continue
    while IFS= read -r l; do [[ -n $l ]] && printf '@@F\t%s\t%s\n' "$t" "$l"; done <<<"${T_FAILS[$t]}"
  done
}

_grade_remote() {
  local nodes=() n t host out line tag rest res stop
  for t in "${TASKS[@]}"; do
    n=${T_NODE[$t]}; [[ $n == any || $n == "$THIS_NODE" ]] && continue
    [[ " ${nodes[*]} " == *" $n "* ]] || nodes+=("$n")
  done
  for n in "${nodes[@]}"; do
    host=${NODE_HOST[$n]:-root@$n}
    # The script travels on stdin and is read fully before it runs, so checks never see it.
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new "$host" \
          "NODE=$n bash -c \"\$(cat)\" grader --emit" < "$_SELF" 2>/dev/null)
    if ! grep -q $'^@@R\t' <<<"$out"; then
      for t in "${TASKS[@]}"; do
        [[ ${T_NODE[$t]} == "$n" ]] && T_NOTE[$t]="not graded: could not reach $n as $host over ssh. Run this grader on $n, or give root on $THIS_NODE a key to it."
      done
      continue
    fi
    REMOTE_OK+=("$n")
    while IFS= read -r line; do
      IFS=$'\t' read -r tag t rest <<<"$line"
      case $tag in
        @@R) IFS=$'\t' read -r res stop <<<"$rest"; T_RES[$t]=$res; T_STOP[$t]=$stop; T_FAILS[$t]="" ;;
        @@F) T_FAILS[$t]+="$rest"$'\n' ;;
      esac
    done <<<"$out"
  done
}

run_all() {
  [[ $EUID -eq 0 ]] || { echo "Run as root."; exit 2; }
  _grade_local
  if (( EMIT )); then _emit; exit 0; fi
  echo "Reboot every node before grading. Grading runs as root and changes nothing."
  (( GRADE_ALL )) && _grade_remote
  local graded="$THIS_NODE${REMOTE_OK[*]:+ ${REMOTE_OK[*]}}"
  echo "Paper: $PAPER    Graded on: $graded"; echo
  local t line why cmd dep other=()
  for t in "${TASKS[@]}"; do
    if [[ ${T_RES[$t]} == SKIP && -z ${T_NOTE[$t]} ]]; then other+=("$t"); continue; fi
    printf -v line '%-4s %-5s #%-3s %-6s %s' "${T_RES[$t]}" "${T_CAT[$t]}" "$t" "${T_NODE[$t]}" "${T_DESC[$t]}"
    echo "$line"
    [[ -n ${T_NOTE[$t]} ]] && echo "           note:  ${T_NOTE[$t]}"
    [[ ${T_RES[$t]} == FAIL ]] || continue
    while IFS=$'\x1f' read -r why cmd; do
      [[ -z $why && -z $cmd ]] && continue
      echo "           - why:   $why"
      echo "             check: $cmd"
    done <<<"${T_FAILS[$t]}"
    [[ ${T_STOP[$t]} == 1 ]] && echo "           (checks after this one did not run: fix it, then grade again)"
    for dep in ${T_DEPS[$t]}; do
      [[ ${T_RES[$dep]} == FAIL ]] && echo "           note:  depends on #$dep (${T_NODE[$dep]}), which also failed — fix that first"
    done
  done
  (( ${#other[@]} )) && { echo; echo "Not graded here (other node): ${other[*]}. Run with --all from $THIS_NODE to include them."; }
}

report() {   # Red Hat-style per-objective breakdown; equal weight per task, scaled to 300
  local t c graded=0 passed=0 scope; declare -A cp ct
  for t in "${TASKS[@]}"; do
    [[ ${T_RES[$t]} == PASS || ${T_RES[$t]} == FAIL ]] || continue
    c=${T_CAT[$t]}; ct[$c]=$(( ${ct[$c]:-0} + 1 )); graded=$((graded+1))
    [[ ${T_RES[$t]} == PASS ]] && { cp[$c]=$(( ${cp[$c]:-0} + 1 )); passed=$((passed+1)); }
  done
  scope="this node"; (( ${#REMOTE_OK[@]} )) && scope="all nodes"
  echo; echo "Performance on exam objectives ($scope):"
  for c in "${CAT_ORDER[@]}"; do
    [[ -n ${ct[$c]} ]] || continue
    printf '  %-45s %3d%%\n' "${CAT_NAME[$c]}:" $(( 100 * ${cp[$c]:-0} / ${ct[$c]} ))
  done
  (( graded == 0 )) && { echo "No tasks graded."; return; }
  local score=$(( 300 * passed / graded ))
  echo; echo "Tasks passed ($scope): $passed / $graded"
  echo "Score ($scope, equal weights): $score / 300   pass mark $PASS_MARK"
  local failed=(); for t in "${TASKS[@]}"; do [[ ${T_RES[$t]} == FAIL ]] && failed+=("$t"); done
  echo "Failed tasks: ${failed[*]:-none}"
  echo "Real exam weights are not published; this is a readiness signal, not a prediction."
}
