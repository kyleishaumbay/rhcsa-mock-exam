#!/bin/bash
# grader_lib.sh — shared helpers for generated RHCSA mock-exam graders.
# Paste this block verbatim at the top of every generated grader (graders ship as ONE file).
# Contract: READ-ONLY. Nothing in here or in any task check may write, restart, mount,
# relabel or "fix" anything. Checks observe persisted state and report.
#
# Usage inside a generated grader:
#   task 7 NET node1 "Static IPv4 on node1"
#   t7() { expect 'nmcli -g ipv4.method con show "$CON"' manual \
#            && expect_file_has /etc/hosts 'node2' ; }
#   requires 12 5        # task 12 depends on task 5 (reported, not skipped)
#   run_all; report
#
# Categories (Red Hat score-report names). RHEL 9 papers use every code except SW
# (software is DEP on RHEL 9); RHEL 10 papers use every code except CON.
declare -A CAT_NAME=(
  [TOOLS]="Understand and use essential tools"
  [SW]="Manage software (RHEL 10)"
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
CAT_ORDER=(TOOLS SW SH OPS STOR FS DEP NET USR SEC CON)
PASS_MARK=${PASS_MARK:-210}   # out of 300, as candidates report it

declare -A T_CAT T_NODE T_DESC T_RES T_WHY T_CMD T_DEPS
TASKS=()
THIS_NODE=${NODE:-$(hostname -s)}
_LAST_CMD=""; _LAST_WHY=""

task()     { TASKS+=("$1"); T_CAT[$1]=$2; T_NODE[$1]=$3; shift 3; T_DESC[${TASKS[-1]}]="$*"; }
requires() { local t=$1; shift; T_DEPS[$t]="$*"; }

# --- check primitives: each returns 0/1 and records what it looked at -----------------
_rec()  { _LAST_CMD=$1; _LAST_WHY=$2; }
# expect '<command>' '<expected output, exact after trimming>'
expect() {
  local out; out=$(bash -c "$1" 2>/dev/null | sed 's/[[:space:]]*$//')
  [[ "$out" == "$2" ]] && return 0
  _rec "$1" "expected '$2', got '${out:0:80}'"; return 1
}
# expect_match '<command>' '<extended regex>'
expect_match() {
  local out; out=$(bash -c "$1" 2>/dev/null)
  grep -Eq -- "$2" <<<"$out" && return 0
  _rec "$1" "output did not match /$2/"; return 1
}
# expect_ok '<command>'  — command must exit 0
expect_ok() { bash -c "$1" >/dev/null 2>&1 && return 0; _rec "$1" "command exited non-zero"; return 1; }
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

# --- runner ----------------------------------------------------------------------------
run_all() {
  echo "Reboot every node before grading. Grading runs as root and changes nothing."
  echo "Node: $THIS_NODE"; echo
  [[ $EUID -eq 0 ]] || { echo "Run as root."; exit 2; }
  local t
  for t in "${TASKS[@]}"; do
    if [[ ${T_NODE[$t]} != any && ${T_NODE[$t]} != "$THIS_NODE" ]]; then T_RES[$t]=SKIP; T_WHY[$t]="runs on ${T_NODE[$t]}"; continue; fi
    _LAST_CMD=""; _LAST_WHY=""
    if declare -F "t$t" >/dev/null && "t$t"; then T_RES[$t]=PASS
    elif ! declare -F "t$t" >/dev/null; then T_RES[$t]=SKIP; T_WHY[$t]="no check defined"
    else T_RES[$t]=FAIL; T_WHY[$t]=$_LAST_WHY; T_CMD[$t]=$_LAST_CMD; fi
  done
  for t in "${TASKS[@]}"; do
    local line; printf -v line '%-4s %-5s #%-3s %s' "${T_RES[$t]}" "${T_CAT[$t]}" "$t" "${T_DESC[$t]}"
    echo "$line"
    if [[ ${T_RES[$t]} == FAIL ]]; then
      echo "           why:   ${T_WHY[$t]}"
      echo "           check: ${T_CMD[$t]}"
      local dep; for dep in ${T_DEPS[$t]}; do
        [[ ${T_RES[$dep]} == FAIL ]] && echo "           note:  depends on #$dep, which also failed — fix that first"
      done
    fi
  done
}

report() {   # Red Hat-style per-objective breakdown; equal weight per task, scaled to 300
  local t c graded=0 passed=0; declare -A cp ct
  for t in "${TASKS[@]}"; do
    [[ ${T_RES[$t]} == SKIP ]] && continue
    c=${T_CAT[$t]}; ct[$c]=$(( ${ct[$c]:-0} + 1 )); graded=$((graded+1))
    [[ ${T_RES[$t]} == PASS ]] && { cp[$c]=$(( ${cp[$c]:-0} + 1 )); passed=$((passed+1)); }
  done
  echo; echo "Performance on exam objectives (this node):"
  for c in "${CAT_ORDER[@]}"; do
    [[ -n ${ct[$c]} ]] && printf '  %-45s %3d%%\n' "${CAT_NAME[$c]}:" $(( 100 * ${cp[$c]:-0} / ${ct[$c]} ))
  done
  (( graded == 0 )) && { echo "No tasks graded on this node."; return; }
  local score=$(( 300 * passed / graded ))
  echo; echo "Score (this node, equal weights): $score / 300   pass mark $PASS_MARK"
  local failed=(); for t in "${TASKS[@]}"; do [[ ${T_RES[$t]} == FAIL ]] && failed+=("$t"); done
  echo "Failed tasks: ${failed[*]:-none}"
  echo "Real exam weights are not published; this is a readiness signal, not a prediction."
}
