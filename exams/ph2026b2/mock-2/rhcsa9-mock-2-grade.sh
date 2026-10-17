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
  echo; echo "Score ($scope, equal weights): $score / 300   pass mark $PASS_MARK"
  local failed=(); for t in "${TASKS[@]}"; do [[ ${T_RES[$t]} == FAIL ]] && failed+=("$t"); done
  echo "Failed tasks: ${failed[*]:-none}"
  echo "Real exam weights are not published; this is a readiness signal, not a prediction."
}

# ==== paper checks (tmp.vbdIlVbvNs) ====
# PH2026B2 mocks — shared read-only check helpers, prepended to each paper's checks by build.sh
# ------------------------------------------------------------
root_pw_is() {   # <password> — compares against root's hash in /etc/shadow
  local h; h=$(awk -F: '$1=="root"{print $2}' /etc/shadow)
  python3 -c 'import crypt,sys; sys.exit(0 if crypt.crypt(sys.argv[1], sys.argv[2]) == sys.argv[2] else 1)' "$1" "$h" 2>/dev/null && return 0
  _rec "compare root's hash in /etc/shadow with '$1'" "root's password is not '$1'"; return 1
}
on_gpt_disk() {  # <mountpoint> <disk> <min MiB> <max MiB>
  local src disk pt size
  src=$(findmnt -no SOURCE "$1" 2>/dev/null); disk=$(lsblk -no PKNAME "$src" 2>/dev/null | head -1)
  pt=$(lsblk -dno PTTYPE "/dev/$disk" 2>/dev/null); size=$(( $(lsblk -bdno SIZE "$src" 2>/dev/null || echo 0) / 1048576 ))
  [[ $disk == "$2" ]] || { _rec "lsblk -no PKNAME $src" "$1 is not on a partition of /dev/$2 (got: '${disk:-none}')"; return 1; }
  [[ $pt == gpt ]] || { _rec "lsblk -dno PTTYPE /dev/$disk" "/dev/$disk has no GPT label (got: '${pt:-none}')"; return 1; }
  (( size >= $3 && size <= $4 )) || { _rec "lsblk -bdno SIZE $src" "$src is ${size} MiB, expected $3-$4 MiB"; return 1; }
}
swap_dev_on_disk() {  # <disk> — prints the active swap device(s) on that disk
  local d r
  awk 'NR>1{print $1}' /proc/swaps | while read -r d; do
    r=$(readlink -f "$d"); [[ $(lsblk -no PKNAME "$r" 2>/dev/null) == "$1" || ${r##*/} == "$1" ]] && echo "$r"
  done
}
swap_persisted() {    # <device> — active now AND an fstab swap entry resolving to it
  local want src r; want=$(readlink -f "$1")
  awk 'NR>1{print $1}' /proc/swaps | xargs -r -n1 readlink -f | grep -qx "$want" \
    || { _rec "cat /proc/swaps" "$1 is not active swap"; return 1; }
  while read -r src; do
    r=$(findfs "$src" 2>/dev/null || readlink -f "$src"); [[ $(readlink -f "$r") == "$want" ]] && return 0
  done < <(findmnt --fstab -n -t swap -o SOURCE)
  _rec "findmnt --fstab -t swap" "no /etc/fstab swap entry for $1 (by UUID, LABEL or path)"; return 1
}
cron_has() {          # <regex> — root's crontab, /etc/crontab or /etc/cron.d
  { crontab -l -u root 2>/dev/null; cat /etc/crontab /etc/cron.d/* 2>/dev/null; } | grep -v '^\s*#' | grep -Eq -- "$1" && return 0
  _rec "crontab -l -u root; cat /etc/crontab /etc/cron.d/*" "no cron entry matching /$1/"; return 1
}
fw_has() {            # <service> <port/proto> — in the default zone, permanent AND runtime
  local z; z=$(firewall-cmd --get-default-zone 2>/dev/null)
  local rx="services:(.* )?$1( |\$)|ports:(.* )?$2( |\$)"
  expect_match "firewall-cmd --permanent --zone=$z --list-all" "$rx" || return 1
  expect_match "firewall-cmd --zone=$z --list-all" "$rx"
}
autofs_maps_to() {    # <path> <source regex> — indirect (parent dir) or direct (/-) map
  local mp=${1%/*} key=${1##*/}
  { autofs_entry "$mp" | awk -F'|' -v k="$key" '{gsub(/ /,"",$1)} $1==k{print $2}'
    autofs_entry /-    | awk -F'|' -v k="$1"   '{gsub(/ /,"",$1)} $1==k{print $2}'; } \
    | grep -Eq "(^|[[:space:]])$2/?([[:space:]]|\$)" && return 0
  _rec "automount -m" "no autofs entry mapping $1 to $2"; return 1
}
same_dev() {          # <mountpoint> <device> — the mount's source is that device
  [[ $(readlink -f "$(findmnt -no SOURCE "$1" 2>/dev/null)") == "$(readlink -f "$2")" ]] && return 0
  _rec "findmnt -no SOURCE $1" "$1 is not mounted from $2"; return 1
}
key_login_ok() {      # <user> <host> — that user logs in to the host by key, with no prompt
  runuser -u "$1" -- ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 "$1@$2" true </dev/null >/dev/null 2>&1 && return 0
  _rec "runuser -u $1 -- ssh -o BatchMode=yes $1@$2 true" "key login as $1 to $2 failed (if the other node's SSH task failed, fix that first)"; return 1
}
CUSER=""
find_cuser() {        # <container> — the lingering rootless user running it
  local f u
  for f in /var/lib/systemd/linger/*; do
    [[ -e $f ]] || continue; u=${f##*/}
    runuser -l "$u" -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) podman ps --format "{{.Names}}"' 2>/dev/null | grep -qx "$1" \
      && { CUSER=$u; return 0; }
  done
  _rec "podman ps, as each user in /var/lib/systemd/linger/" "no lingering user has a running container named $1"; return 1
}
asu() { echo "runuser -l $CUSER -c 'XDG_RUNTIME_DIR=/run/user/\$(id -u) $1'"; }
user_unit_for() {     # <container> — its systemd --user service is active and enabled/generated
  local u; u=$(bash -c "$(asu 'systemctl --user list-units --all --type=service --no-legend --plain')" 2>/dev/null | awk '{print $1}' | grep -m1 "$1")
  [[ -n $u ]] || { _rec "$(asu 'systemctl --user list-units --all --type=service')" "no systemd user service for $1"; return 1; }
  expect "$(asu "systemctl --user is-active $u")" active || return 1
  expect_match "$(asu "systemctl --user is-enabled $u")" '^(enabled|generated)$'
}
autofs_opts() {       # <path> — options+source autofs loaded for that path (indirect or direct)
  local mp=${1%/*} key=${1##*/}
  autofs_entry "$mp" | awk -F'|' -v k="$key" '{gsub(/ /,"",$1)} $1==k{print $2}'
  autofs_entry /-    | awk -F'|' -v k="$1"   '{gsub(/ /,"",$1)} $1==k{print $2}'
}
fstab_source() {      # <mountpoint> — the fstab SOURCE field as written (UUID=…, LABEL=…, /dev/…)
  awk -v m="$1" '$0!~/^[[:space:]]*#/ && $2==m{print $1}' /etc/fstab
}
autofs_has_opt() {    # <path> <option> — the loaded autofs entry for path carries that mount option
  autofs_opts "$1" | grep -Eq "(^|[-, ])$2(,|[[:space:]]|\$)" && return 0
  _rec "automount -m" "autofs entry for $1 lacks the '$2' option (got: '$(autofs_opts "$1" | head -1)')"; return 1
}
iso_repos() {         # <mountpoint> — ISO mounted there at boot; BaseOS + AppStream repos from it
  need mount_persisted "$1"
  need expect_ok "test -d $1/AppStream/repodata"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" "file://$1/BaseOS/?\$"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" "file://$1/AppStream/?\$"
}
nfs_export_is() {     # <path> <rw|ro> [any] — exported now and in /etc/exports(.d) with that mode; only to NODE1_IP unless "any"
  local live   # one path may span several lines (one per client, or options on a continuation line)
  live=$(exportfs -s 2>/dev/null | awk -v p="$1" '/^\//{cur=$1; $1=""} cur==p{print}' | paste -sd' ')
  [[ -n $live ]] || { _rec "exportfs -s" "$1 is not exported"; return 1; }
  grep -rhsEq "^\s*$1\s" /etc/exports /etc/exports.d/*.exports \
    || { _rec "grep $1 /etc/exports /etc/exports.d/*.exports" "$1 is exported now but not in /etc/exports or /etc/exports.d"; return 1; }
  [[ $3 == any || $(grep -oE '[^ ()]+\(' <<<"$live" | tr -d '(' | sort -u | paste -sd' ') =~ ^$NODE1_IP(/32)?$ ]] \
    || { _rec "exportfs -s" "$1 is exported to '$(grep -oE '[^ ()]+\(' <<<"$live" | tr -d '(' | paste -sd' ')', not only $NODE1_IP"; return 1; }
  grep -Eq "\(([^)]*,)?$2(,|\))" <<<"$live" && return 0
  _rec "exportfs -s" "$1 is not exported $2 (got: '${live# }')"; return 1
}
node_by_ip() {        # which node this is, from its IP (lab hostnames can be anything)
  [[ -n $NODE ]] && return 0
  ip -4 -o addr 2>/dev/null | grep -q " $NODE1_IP/" && THIS_NODE=node1
  ip -4 -o addr 2>/dev/null | grep -q " $NODE2_IP/" && THIS_NODE=node2
  return 0
}
iso_repo_baseos() {   # <mountpoint> — ISO mounted there at boot; a BaseOS repo from it
  need mount_persisted "$1"
  need expect_ok "test -d $1/BaseOS/repodata"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" "file://$1/BaseOS/?\$"
}
# PH2026B2 Mock 2 — grader checks (built into rhcsa9-mock-2-grade.sh by ../build.sh)
PAPER="PH2026B2 Mock 2"

# ---- edit these to match your lab before grading ----------------------------------
NODE1_IP=${NODE1_IP:-192.168.56.101}
NODE2_IP=${NODE2_IP:-192.168.56.102}
XDISK=${XDISK:-sdb}        # 5 GiB disk for the GPT partitions (task 6)
THINDISK=${THINDISK:-sdc}  # 5 GiB disk for the thin pool (task 13)
SWAPDISK=${SWAPDISK:-sdd}  # 1 GiB disk for swap (task 11)
# -------------------------------------------------------------------------------------
hosts node2=root@$NODE2_IP
node_by_ip

task 1 OPS node2 "root password reset to practice-root-202"
t1() { need root_pw_is 'practice-root-202'; }

task 2 OPS node1 "root password reset to practice-root-202"
t2() { need root_pw_is 'practice-root-202'; }

task 3 DEP node1 "ISO mounted persistently at /media/rhel9; BaseOS + AppStream repos"
t3() { iso_repos /media/rhel9; }

task 4 DEP node2 "ISO mounted persistently at /media/rhel9; BaseOS + AppStream repos"
t4() { iso_repos /media/rhel9; }

task 5 FS node2 "NFS server: /exports/reports rw and /exports/archive ro, to node1 only; README files; at boot; firewall"
t5() {
  need expect_file_has /exports/reports/README '^Mock2 reports share$'
  need expect_file_has /exports/archive/README '^Mock2 archive share$'
  need svc_persisted nfs-server
  need nfs_export_is /exports/reports rw
  need nfs_export_is /exports/archive ro
  need fw_has nfs 2049/tcp
}
requires 5 4

task 6 STOR node1 "GPT on $XDISK: 1.5 GiB XFS label XDATA on /vol/xdata (by LABEL); 2 GiB vfat on /vol/fat owned by marmalade:jars"
t6() {
  local g; g=$(getent group jars | cut -d: -f3)
  need expect "findmnt -no FSTYPE /vol/xdata" xfs
  need mount_persisted /vol/xdata
  need on_gpt_disk /vol/xdata "$XDISK" 1450 1600
  need expect "lsblk -no LABEL \$(findmnt -no SOURCE /vol/xdata)" XDATA
  need expect "awk -v m=/vol/xdata '\$0!~/^[[:space:]]*#/ && \$2==m{print \$1}' /etc/fstab" LABEL=XDATA
  need expect "findmnt -no FSTYPE /vol/fat" vfat
  need mount_persisted /vol/fat
  need on_gpt_disk /vol/fat "$XDISK" 1950 2150
  need expect_match "findmnt -no OPTIONS /vol/fat" '(^|,)uid=2050(,|$)'
  need expect_match "findmnt -no OPTIONS /vol/fat" "(^|,)gid=${g:-jars}(,|\$)"
  need expect_match "findmnt --fstab -no OPTIONS /vol/fat" '(^|,)uid=(2050|marmalade)(,|$)'
}
requires 6 7

task 7 USR node1 "marmalade: UID 2050, in jars, home /vol/xdata/home/marmalade, password max age 60 days"
t7() {
  must expect_ok "id marmalade" || return
  need expect "id -u marmalade" 2050
  need expect_match "id -nG marmalade" '(^| )jars( |$)'
  need expect "getent passwd marmalade | cut -d: -f6" /vol/xdata/home/marmalade
  need expect "stat -c %U /vol/xdata/home/marmalade" marmalade
  need expect "findmnt -no TARGET -T /vol/xdata/home/marmalade" /vol/xdata
  need expect "getent shadow marmalade | cut -d: -f5" 60
}

task 8 USR node1 "group jars may sudo only 'systemctl restart httpd', with no password"
t8() {
  must expect_ok "id marmalade" || return
  need expect_ok "visudo -c"
  need expect_ok "grep -rEqs '^\s*%jars\s' /etc/sudoers /etc/sudoers.d/"
  need expect_match "sudo -l -U marmalade" 'NOPASSWD:\s*/usr/bin/systemctl restart httpd(\.service)?\s*$'
  need expect_ok "! sudo -l -U marmalade | grep -Eq '\)\s*(NOPASSWD:\s*)?ALL\s*$'"
}
requires 8 7

task 9 FS node1 "/shared/pantry: group jars, 3770, new files group-writable by default ACL"
t9() {
  need expect "stat -c '%a %G' /shared/pantry" "3770 jars"
  need expect_match "getfacl -p /shared/pantry 2>/dev/null" '^default:group::rwx'
  need expect_ok "! getfacl -p /shared/pantry 2>/dev/null | grep -Eq '^default:mask::(-|r-|r-x|--x|-w)'"
}
requires 9 7

task 10 SH node1 "/usr/local/bin/disk-report.sh appends date + df -h / to /var/log/disk-report.log; root cron Mon-Fri 18:30"
t10() {
  must expect_ok "test -x /usr/local/bin/disk-report.sh" || return
  need expect_ok "bash -n /usr/local/bin/disk-report.sh"
  need expect_file_has /usr/local/bin/disk-report.sh '\bdate\b'
  need expect_file_has /usr/local/bin/disk-report.sh '\bdf\b.*-h'
  need expect_file_has /usr/local/bin/disk-report.sh '(>>|tee\s+-a)\s*"?/var/log/disk-report\.log'
  need cron_has '^\s*30\s+18\s+\*\s+\*\s+(1-5|[Mm]on-[Ff]ri|1,2,3,4,5)\s+(root\s+)?.*disk-report\.sh'
  need svc_persisted crond
}

task 11 CON node1 "rootless cafe from a self-built localhost/cafe-web:1.0 (Containerfile, CAFE_ENV=mock2): /srv/cafe -> docroot, port 28282, starts at boot"
t11() {
  must find_cuser cafe || return
  need expect_ok "test -s ~$CUSER/cafe/Containerfile"
  need expect_match "$(asu 'podman image inspect localhost/cafe-web:1.0 --format "{{.Config.Env}}"')" 'CAFE_ENV=mock2'
  need expect_match "$(asu 'podman inspect cafe --format {{.ImageName}}')" '^localhost/cafe-web:1\.0$'
  need expect_match "$(asu 'podman port cafe')" ':28282$'
  need expect_match "$(asu 'podman inspect cafe --format "{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}"')" '(^| )/srv/cafe/?:/var/www/html/?( |$)'
  need expect_match "curl -s --max-time 5 http://localhost:28282/" 'Mock2 container OK'
  need fw_has none 28282/tcp
  need expect "loginctl show-user $CUSER -p Linger" Linger=yes
  need user_unit_for cafe
}
requires 11 3

task 12 SEC node1 "SELinux enforcing now and at every boot"
t12() {
  need expect getenforce Enforcing
  need expect "awk -F= '/^SELINUX=/{print \$2}' /etc/selinux/config" enforcing
  need expect_ok "! grep -Eqw 'enforcing=0|selinux=0' /proc/cmdline"
  need expect_ok "! grubby --info=ALL 2>/dev/null | grep -E '^args=' | grep -Eqw 'enforcing=0|selinux=0'"
}

task 13 STOR node1 "768 MiB swap partition on $SWAPDISK, priority 10, active and persistent"
t13() {
  local d; d=$(swap_dev_on_disk "$SWAPDISK" | head -1)
  [[ -n $d ]] || { _rec "cat /proc/swaps" "no active swap on /dev/$SWAPDISK"; _fail; return; }
  need expect "lsblk -no TYPE $d" part
  need expect_ok "s=\$(( \$(lsblk -bdno SIZE $d) / 1048576 )); test \$s -ge 740 -a \$s -le 800"
  need swap_persisted "$d"
  need expect "swapon --show=NAME,PRIO --noheadings | awk -v d=$d '\$1==d{print \$2}'" 10
  need expect_match "findmnt --fstab -n -t swap -o SOURCE,OPTIONS" '(^|[ ,])pri=10(,|$)'
}

task 14 OPS node1 "journal persistent (overriding the seeded volatile drop-in); SystemMaxUse=200M"
t14() {
  need journal_persisted
  need expect "systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E '^\s*SystemMaxUse=' | tail -1 | tr -d ' '" SystemMaxUse=200M
}

task 15 STOR node1 "vg_pool (PE 16 MiB) on all of $THINDISK; 2 GiB pool tp_main; thin lv_vault 800 GiB, XFS on /vault by UUID"
t15() {
  must expect_ok "vgs vg_pool" || return
  need expect "vgs --noheadings --units m -o vg_extent_size vg_pool | tr -d ' '" 16.00m
  need expect "pvs --noheadings -o pv_name,vg_name | awk '\$2==\"vg_pool\"{print \$1}'" "/dev/$THINDISK"
  need expect "lvs --noheadings -o segtype vg_pool/tp_main | tr -d ' '" thin-pool
  need expect "lvs --noheadings --units g -o lv_size vg_pool/tp_main | tr -d ' '" 2.00g
  must expect_ok "lvs vg_pool/lv_vault" || return
  need expect "lvs --noheadings -o segtype,pool_lv vg_pool/lv_vault | xargs" "thin tp_main"
  need expect "lvs --noheadings --units g -o lv_size vg_pool/lv_vault | tr -d ' '" 800.00g
  need expect "findmnt -no FSTYPE /vault" xfs
  need same_dev /vault /dev/vg_pool/lv_vault
  need mount_persisted /vault
  need expect_match "awk -v m=/vault '\$0!~/^[[:space:]]*#/ && \$2==m{print \$1}' /etc/fstab" '^UUID='
}

task 16 STOR node1 "lv_swp: exactly 48 extents of vg_pool, swap, active and persistent"
t16() {
  must expect_ok "lvs vg_pool/lv_swp" || return
  need expect "lvs --noheadings -o seg_size_pe vg_pool/lv_swp | tr -d ' '" 48
  need swap_persisted /dev/vg_pool/lv_swp
}
requires 16 15

task 17 SEC node1 "httpd on port 8989 instead of 80, 'Mock2 Apache OK', SELinux label + firewall persistent"
t17() {
  must expect_ok "rpm -q httpd" || return
  need svc_persisted httpd
  need expect_match "semanage port -l | awk '\$1==\"http_port_t\"'" '[ ,]8989(,|$)'
  need expect_ok "ss -ltnH 'sport = :8989' | grep -q ."
  need expect_ok "! ss -ltnpH 'sport = :80' | grep -q httpd"
  need expect_match "curl -s --max-time 5 http://localhost:8989/" '^Mock2 Apache OK'
  need fw_has none 8989/tcp
}
requires 17 3

task 18 SEC node2 "gatekeeper exists on node2 and logs in to node1 as gatekeeper by key, no password"
t18() {
  must expect_ok "id gatekeeper" || return
  need key_login_ok gatekeeper "$NODE1_IP"
}

task 19 SEC node1 "sshd: no password/keyboard-interactive auth, no root login, only group sshlogin allowed"
t19() {
  must expect_ok "id gatekeeper" || return
  need expect_match "id -nG gatekeeper" '(^| )sshlogin( |$)'
  need expect_ok "test -s ~gatekeeper/.ssh/authorized_keys"
  need expect "sshd -T 2>/dev/null | awk '\$1==\"passwordauthentication\"{print \$2}'" no
  need expect "sshd -T 2>/dev/null | awk '\$1==\"kbdinteractiveauthentication\"{print \$2}'" no
  need expect "sshd -T 2>/dev/null | awk '\$1==\"permitrootlogin\"{print \$2}'" no
  need expect "sshd -T 2>/dev/null | awk '\$1==\"allowgroups\"{print \$2}' | sort -u | paste -sd' '" sshlogin
  need svc_persisted sshd
}

task 20 FS node1 "autofs: /shares/reports rw and /shares/archive read-only from $NODE2_IP:/exports, not fstab (needs node2 task 5)"
t20() {
  must expect_ok "rpm -q autofs" || return
  need svc_persisted autofs
  need autofs_maps_to /shares/reports "$NODE2_IP:/exports/reports"
  need autofs_maps_to /shares/archive "$NODE2_IP:/exports/archive"
  need autofs_has_opt /shares/archive ro
  need expect_ok "! findmnt --fstab -n /shares/reports && ! findmnt --fstab -n /shares/archive"
}
requires 20 3

run_all; report
