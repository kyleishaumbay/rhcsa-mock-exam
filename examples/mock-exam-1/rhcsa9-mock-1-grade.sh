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
  local cats=()
  for c in "${CAT_ORDER[@]}"; do
    [[ -n ${ct[$c]} ]] || continue
    printf '  %-45s %3d%%\n' "${CAT_NAME[$c]}:" $(( 100 * ${cp[$c]:-0} / ${ct[$c]} ))
    cats+=("$c=$(( 100 * ${cp[$c]:-0} / ${ct[$c]} ))")
  done
  (( graded == 0 )) && { echo "No tasks graded."; return; }
  local score=$(( 300 * passed / graded ))
  echo; echo "Score ($scope, equal weights): $score / 300   pass mark $PASS_MARK"
  local failed=(); for t in "${TASKS[@]}"; do [[ ${T_RES[$t]} == FAIL ]] && failed+=("$t"); done
  echo "Failed tasks: ${failed[*]:-none}"
  echo "Real exam weights are not published; this is a readiness signal, not a prediction."
  # one line for progress tracking
  printf 'SUMMARY|%s|%s|%s|%s/300|graded=%s|failed=%s|%s\n' "$(date +%F)" "$PAPER" "$scope" "$score" \
    "$graded" "$(IFS=,; echo "${failed[*]}")" "$(IFS=,; echo "${cats[*]}")"
}

# ==== paper checks (grader_tasks.sh) ====

# ======================================================================================
# RHCSA 9 Mock Exam 1 — LVM, NFS, AutoFS, Apache, Firewalld, Systemd
# Reboot BOTH nodes (node2 first), then as root on node1:   bash rhcsa9-mock-1-grade.sh --all
# (or run it on each node without --all). Read-only: it changes nothing.
# ======================================================================================
PAPER="RHCSA9 Mock Exam 1"
hosts node2=root@node2

N2RE='(node2(\.example\.com)?|192\.168\.100\.11)'

# fstab source for a mountpoint must be UUID= or LABEL=
fstab_by_id() {
  local src; src=$(awk -v m="$1" '$1 !~ /^#/ && $2==m {print $1}' /etc/fstab | tail -1)
  [[ $src =~ ^(UUID|LABEL)= ]] && return 0
  _rec "awk '\$2==\"$1\"' /etc/fstab" "fstab source for $1 is '${src:-none}', not UUID= or LABEL="; return 1
}
# SELinux label on a path matches policy (restorecon would change nothing)
ctx_matches_policy() { expect_match "matchpathcon -V $1" 'verified'; }
# run a command as appuser with its systemd/podman environment
_au() { runuser -l appuser -c "export XDG_RUNTIME_DIR=/run/user/$(id -u appuser 2>/dev/null); $1" 2>/dev/null; }
# PV(s) backing a VG
_pv_of() { pvs --noheadings -o pv_name,vg_name 2>/dev/null | awk -v v="$1" '$2==v{print $1}'; }

task 1 STOR node2 "vgnfs (PE 8 MiB) on /dev/sdb; lvexport 128 extents, xfs, on /srv/nfs by UUID/LABEL"
t1() {
  must expect_ok "vgs vgnfs" || return
  need expect "vgs --noheadings --units m -o vg_extent_size vgnfs | tr -d ' '" "8.00m"
  need expect_match "pvs --noheadings -o pv_name,vg_name | awk '\$2==\"vgnfs\"{print \$1}'" '^/dev/sdb[0-9]*$'
  need expect "lvs --noheadings -o seg_size_pe vgnfs/lvexport | tr -d ' '" "128"
  need expect "findmnt -n -o FSTYPE /srv/nfs" "xfs"
  need expect_match "findmnt -n -o SOURCE /srv/nfs" 'vgnfs-lvexport$'
  need mount_persisted /srv/nfs
  need fstab_by_id /srv/nfs
}

task 2 FS node2 "NFS server exports /srv/nfs/data and /srv/nfs/users rw to 192.168.100.0/24, at boot"
t2() {
  need expect_ok "test -f /srv/nfs/data/hosts"
  need expect "stat -c '%u %a' /srv/nfs/users/linda" "2001 700"
  need expect "stat -c '%u %a' /srv/nfs/users/anna" "2002 700"
  need expect_match "exportfs -s" '^/srv/nfs/data[[:space:]]+(192\.168\.100\.0/(24|255\.255\.255\.0)|\*)\([^)]*\brw\b'
  need expect_match "exportfs -s" '^/srv/nfs/users[[:space:]]+(192\.168\.100\.0/(24|255\.255\.255\.0)|\*)\([^)]*\brw\b'
  need expect_match "cat /etc/exports /etc/exports.d/*.exports 2>/dev/null | grep -v '^#'" '^/srv/nfs/users[[:space:]]'
  need svc_persisted nfs-server
}
requires 2 1

task 3 NET node2 "Firewall persistently allows NFS clients"
_fw_nfs() { fw_persisted public nfs || fw_persisted public 2049/tcp; }
t3() { need svc_persisted firewalld; need _fw_nfs; }
requires 3 2

task 4 USR node1 "Users linda 2001 (/home/users/linda), anna 2002 (/home/users/anna), appuser (local home)"
t4() {
  need expect "getent passwd linda | cut -d: -f3,6" "2001:/home/users/linda"
  need expect "getent passwd anna | cut -d: -f3,6" "2002:/home/users/anna"
  must expect_ok "getent passwd appuser" || return
  need expect_ok "test -d \$(getent passwd appuser | cut -d: -f6)"
  need expect_match "findmnt -n -o FSTYPE --target \$(getent passwd appuser | cut -d: -f6)" '^(xfs|ext4)$'
}

task 5 STOR node1 "2 GiB GPT LVM partition on /dev/sdb; vgweb PE 16 MiB; lvweb ext4 on /webfiles by UUID/LABEL"
t5() {
  need expect "lsblk -dno PTTYPE /dev/sdb" "gpt"
  must expect_ok "vgs vgweb" || return
  local pv; pv=$(_pv_of vgweb | head -1)
  need expect_match "echo $pv" '^/dev/sdb[0-9]+$'
  need expect "lsblk -dno PARTTYPE $pv" "e6d6d379-f507-44c2-a23c-238f2a3df928"
  need expect "lsblk -bdno SIZE $pv | awk '{print (\$1>=2040109465 && \$1<=2254857830) ? \"2GiB-ok\" : \$1}'" "2GiB-ok"
  need expect "vgs --noheadings --units m -o vg_extent_size vgweb | tr -d ' '" "16.00m"
  need expect "findmnt -n -o FSTYPE /webfiles" "ext4"
  need expect_match "findmnt -n -o SOURCE /webfiles" 'vgweb-lvweb$'
  need mount_persisted /webfiles
  need fstab_by_id /webfiles
}

task 6 FS node1 "Persistent NFS mount of node2:/srv/nfs/data on /mnt/nfsdata"
t6() {
  need expect_match "findmnt -n -o SOURCE /mnt/nfsdata" "^${N2RE}:/srv/nfs/data/?\$"
  need mount_persisted /mnt/nfsdata
  need expect_ok "test -f /mnt/nfsdata/hosts"
}
requires 6 2 3

task 7 OPS node1 "Persistent systemd journal"
t7() { need expect_ok "test -d /var/log/journal"; need journal_persisted; }

task 8 DEP node2 "Apache vhost sales.example.com -> /www/docs/sales; at boot; SELinux enforcing; port 80 open"
_fw_http() { fw_persisted public http || fw_persisted public 80/tcp; }
t8() {
  need expect "getenforce" "Enforcing"
  need svc_persisted httpd
  need expect "curl -s -m 5 -H 'Host: sales.example.com' http://127.0.0.1/" "Welcome to the sales server"
  need expect_match "httpd -S 2>/dev/null" 'sales\.example\.com'
  need expect_match "ls -Z /www/docs/sales/index.html" 'httpd_sys_(rw_)?content_t'
  need ctx_matches_policy /www/docs/sales/index.html
  need _fw_http
}

task 9 NET node1 "sales.example.com resolves to node2 and serves the sales page"
_sales_page() {
  expect "curl -s -m 5 http://sales.example.com/" "Welcome to the sales server" && return 0
  _LAST_WHY="$_LAST_WHY — if node2 task 8 failed, fix that first"; return 1
}
t9() {
  need expect_match "getent hosts sales.example.com" '^192\.168\.100\.11[[:space:]]'
  need _sales_page
}
requires 9 8

task 10 FS node1 "autofs: /shares/data mounts node2:/srv/nfs/data read-write; autofs at boot"
_shares_map() {   # indirect (/shares + key data) or direct (/- + key /shares/data)
  local l hit
  l="$(autofs_entry /shares | sed 's/^/I /')
$(autofs_entry /- | sed 's/^/D /')"
  hit=$(grep -E "^(I[[:space:]]+data|D[[:space:]]+/shares/data)[[:space:]]+\|.*${N2RE}:/srv/nfs/data/?([[:space:]]|\$)" <<<"$l" | head -1)
  [[ -n $hit ]] && ! grep -Eq '(^|[-,[:space:]])ro([,[:space:]]|$)' <<<"${hit#*|}" && return 0
  _rec "automount -m   (maps for /shares and /-)" "no read-write map entry for /shares/data -> node2:/srv/nfs/data (got: '$(tr '\n' ' ' <<<"$l" | cut -c1-90)')"; return 1
}
t10() { need svc_persisted autofs; need _shares_map; }
requires 10 2 3

task 11 SEC node1 "Apache DocumentRoot /webfiles with index 'hello world'; SELinux enforcing; at boot"
t11() {
  need expect "getenforce" "Enforcing"
  need svc_persisted httpd
  need expect_match "httpd -t -D DUMP_RUN_CFG 2>/dev/null" 'Main DocumentRoot: "/webfiles/?"'
  need expect "cat /webfiles/index.html" "hello world"
  need expect_match "ls -Z /webfiles/index.html" 'httpd_sys_(rw_)?content_t'
  need ctx_matches_policy /webfiles/index.html
  need expect_match "semanage fcontext -l -C" '^/webfiles'
}
requires 11 5

task 12 FS node1 "lvweb is 650-720 MiB and its file system grew with it"
t12() {
  must expect_ok "lvs vgweb/lvweb" || return
  need expect "lvs --noheadings --units m --nosuffix -o lv_size vgweb/lvweb | awk '{print (\$1>=650 && \$1<=720) ? \"size-ok\" : \$1}'" "size-ok"
  need expect "df -m --output=size /webfiles | tail -1 | awk '{print (\$1>=600) ? \"fs-ok\" : \$1}'" "fs-ok"
}
requires 12 5

task 13 DEP node1 "vsftpd installed, running, enabled at boot"
t13() { must expect_ok "rpm -q vsftpd" || return; need svc_persisted vsftpd; }

task 14 FS node1 "autofs wildcard: /home/users/<user> from node2:/srv/nfs/users/<user>"
_users_map() {
  local l; l=$(autofs_entry /home/users)
  grep -Eq "^[[:space:]]*\*[[:space:]]+\|.*${N2RE}:/srv/nfs/users/&" <<<"$l" && return 0
  _rec "automount -m   (map for /home/users)" "no wildcard '*' key mounting node2:/srv/nfs/users/& (got: '${l:0:80}')"; return 1
}
t14() { need svc_persisted autofs; need _users_map; need expect "getent passwd linda | cut -d: -f6" "/home/users/linda"; }
requires 14 2 3 4

task 15 SEC node1 "Apache listens on TCP 8090 only; SELinux port label; persistent firewall port"
t15() {
  need expect_match "semanage port -l -C" '^http_port_t[[:space:]]+tcp[[:space:]]+(.*[ ,])?8090(,|$)'
  need fw_persisted public 8090/tcp
  need expect_match "ss -Htln 'sport = :8090'" 'LISTEN'
  need expect "ss -Htln 'sport = :80' | grep -c LISTEN" "0"
  need expect "curl -s -m 5 http://127.0.0.1:8090/" "hello world"
}
requires 15 11

task 16 NET node1 "Firewall permanently allows ssh and ftp and does not allow cockpit"
t16() {
  need svc_persisted firewalld
  need fw_persisted public ssh
  need fw_persisted public ftp
  need expect "firewall-cmd --permanent --zone=public --list-services | tr ' ' '\n' | grep -c '^cockpit\$'" "0"
}

task 17 STOR node1 "512 MiB swap on LV vgweb/lvswap, active at boot, original swap kept"
t17() {
  must expect_ok "lvs vgweb/lvswap" || return
  local dev; dev=$(readlink -f /dev/vgweb/lvswap)
  need expect "lvs --noheadings --units m --nosuffix -o lv_size vgweb/lvswap | tr -d ' '" "512.00"
  need expect_match "swapon --show=NAME --noheadings | xargs -rn1 readlink -f" "^${dev}\$"
  need expect_match "for s in \$(findmnt --fstab -t swap -n -o SOURCE); do readlink -f \$(findfs \$s 2>/dev/null || echo \$s); done" "^${dev}\$"
  need expect_match "swapon --show=NAME --noheadings | wc -l" '^[2-9]$'
}
requires 17 5

task 18 DEP node1 "httpd restarts 10 s after failure and pulls in vsftpd; vendor unit file untouched"
t18() {
  need expect_match "systemctl show httpd -p Restart --value" '^(on-failure|always)$'
  need expect "systemctl show httpd -p RestartUSec --value" "10s"
  need expect_match "systemctl show httpd -p Wants -p Requires --value | tr ' ' '\n'" '^vsftpd\.service$'
  need expect "rpm -V httpd | grep -c 'httpd\.service\$'" "0"
}
requires 18 13

task 19 DEP node1 "Daily 23:00 root job: df -h /webfiles >> /var/log/webfiles-usage.log"
_cron_ok() {
  { crontab -l -u root 2>/dev/null
    cat /etc/cron.d/* /etc/crontab 2>/dev/null | sed -E 's/^(([^[:space:]]+[[:space:]]+){5})root[[:space:]]+/\1/'; } |
  grep -Ev '^[[:space:]]*#' |
  grep -Eq '^0?0[[:space:]]+23[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+.*df -h /webfiles.*>>[[:space:]]*/var/log/webfiles-usage\.log'
}
_timer_ok() {
  local t s
  for t in $(systemctl list-unit-files --type=timer --state=enabled --no-legend 2>/dev/null | awk '{print $1}'); do
    systemctl show "$t" -p TimersCalendar --value | grep -Eq 'OnCalendar=(\*-\*-\* )?23:00(:00)?' || continue
    s=$(systemctl show "$t" -p Triggers --value)
    systemctl show "$s" -p ExecStart --value | grep -q 'df -h /webfiles' &&
    systemctl show "$s" -p ExecStart --value | grep -q '/var/log/webfiles-usage\.log' && return 0
  done; return 1
}
_daily_job() {
  _cron_ok || _timer_ok && return 0
  _rec "crontab -l -u root; /etc/cron.d/*; /etc/crontab; enabled .timer units" "no daily 23:00 root job running: df -h /webfiles >> /var/log/webfiles-usage.log"; return 1
}
t19() { need _daily_job; }
requires 19 5

task 20 CON node1 "appuser container 'ticker' (sleep infinity, ~/ticker-data -> /data) as systemd user service at boot"
_ticker_running() {
  local ps; ps=$(_au 'podman ps --format "{{.Names}} {{.Image}} {{.Command}}"')
  grep -Eq '^ticker .*ubi-minimal.*sleep infinity' <<<"$ps" && return 0
  _rec "runuser -l appuser -c 'podman ps'" "no running 'ticker' container from ubi-minimal running sleep infinity (got: '${ps:0:80}')"; return 1
}
_ticker_volume() {
  local mnt; mnt=$(_au 'podman inspect ticker --format "{{range .Mounts}}{{.Source}}={{.Destination}} {{end}}"')
  grep -q '/home/appuser/ticker-data=/data' <<<"$mnt" && return 0
  _rec "runuser -l appuser -c 'podman inspect ticker'" "mounts are '${mnt:0:80}', expected /home/appuser/ticker-data -> /data"; return 1
}
_ticker_unit() {
  local u
  for u in $(_au 'systemctl --user list-unit-files --state=enabled --no-legend' | awk '{print $1}'); do
    _au "systemctl --user cat $u" | grep -q ticker && return 0
  done
  _rec "runuser -l appuser -c 'systemctl --user list-unit-files --state=enabled'" "no enabled user unit manages 'ticker'"; return 1
}
t20() {
  must expect_ok "getent passwd appuser" || return
  need expect "loginctl show-user appuser -p Linger --value" "yes"
  need _ticker_running
  need _ticker_volume
  need _ticker_unit
}
requires 20 4

task 21 DEP node1 "Default boot target is multi-user.target"
t21() { need expect "systemctl get-default" "multi-user.target"; }

run_all; report
