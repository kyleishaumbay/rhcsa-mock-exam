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

task 11 CON node1 "rootless cafe, owned by barista, from a self-built localhost/cafe-web:1.0 (Containerfile, CAFE_ENV=mock2): /srv/cafe -> docroot, port 28282, starts at boot"
t11() {
  must use_cuser barista cafe || return
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

task 18 SEC node2 "gatekeeper exists on node2 and logs in to workhorse (node1) as gatekeeper by key, no password"
t18() {
  must expect_ok "id gatekeeper" || return
  need key_login_ok gatekeeper workhorse
}
requires 18 22

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

task 20 FS node1 "autofs: /shares/reports rw and /shares/archive read-only from storage:/exports, not fstab (needs node2 task 5)"
t20() {
  must expect_ok "rpm -q autofs" || return
  need svc_persisted autofs
  need autofs_maps_to /shares/reports "storage(\.lab\.example)?:/exports/reports"
  need autofs_maps_to /shares/archive "storage(\.lab\.example)?:/exports/archive"
  need autofs_has_opt /shares/archive ro
  need expect_ok "! findmnt --fstab -n /shares/reports && ! findmnt --fstab -n /shares/archive"
}
requires 20 3 21

task 21 NET node1 "/etc/hosts on node1: storage and storage.lab.example -> node2"
t21() {
  need hosts_entry storage "$NODE2_IP"
  need hosts_entry storage.lab.example "$NODE2_IP"
}

task 22 NET node2 "/etc/hosts on node2: workhorse and workhorse.lab.example -> node1"
t22() {
  need hosts_entry workhorse "$NODE1_IP"
  need hosts_entry workhorse.lab.example "$NODE1_IP"
}

task 23 NET node2 "chrony serves time to node1's subnet; at boot; firewall allows NTP"
t23() {
  need svc_persisted chronyd
  need expect_match "grep -hE '^[[:space:]]*allow' /etc/chrony.conf /etc/chrony.d/*.conf 2>/dev/null" 'allow'
  need fw_has ntp 123/udp
}

task 24 NET node1 "chrony syncs only from storage (node2); at boot"
t24() {
  need svc_persisted chronyd
  need chrony_only_from "storage|storage\.lab\.example|${NODE2_IP//./\\.}"
}
requires 24 21

task 25 SEC node1 "SELinux boolean httpd_can_network_connect on, persistently"
t25() {
  need expect_match "getsebool httpd_can_network_connect" '--> on$'
  need expect_match "semanage boolean -l -C 2>/dev/null | grep -w httpd_can_network_connect" '\(on[[:space:]]*,[[:space:]]*on\)'
}

task 26 USR node1 "new users get a 45-day maximum password age (login.defs)"
t26() { need expect "awk '\$1==\"PASS_MAX_DAYS\"{print \$2}' /etc/login.defs" 45; }

run_all; report
