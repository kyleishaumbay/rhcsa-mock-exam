
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
