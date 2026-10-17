# PH2026B2 Mock 1 — grader checks (built into rhcsa9-mock-1-grade.sh by ../build.sh)
PAPER="PH2026B2 Mock 1"

# ---- edit these to match your lab before grading ----------------------------------
NODE1_IP=${NODE1_IP:-192.168.56.101}
NODE2_IP=${NODE2_IP:-192.168.56.102}
XDISK=${XDISK:-sdb}        # 5 GiB disk for the GPT partitions (task 6)
THINDISK=${THINDISK:-sdc}  # 5 GiB disk for the thin pool (task 15)
SWAPDISK=${SWAPDISK:-sdd}  # disk for swap, 1 GiB or more (task 13)
# -------------------------------------------------------------------------------------
hosts node2=root@$NODE2_IP
node_by_ip

# ---- tasks ----------------------------------------------------------------------------
task 1 OPS node2 "root password reset to practice-root-101"
t1() { need root_pw_is 'practice-root-101'; }

task 2 OPS node1 "root password reset to practice-root-101"
t2() { need root_pw_is 'practice-root-101'; }

task 3 DEP node1 "ISO mounted persistently at /mnt/rhel9-iso; BaseOS repo from the mounted ISO"
t3() {
  need mount_persisted /mnt/rhel9-iso
  need expect_ok "test -d /mnt/rhel9-iso/BaseOS/repodata"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" 'file:///mnt/rhel9-iso/BaseOS/?$'
}

task 4 DEP node2 "ISO mounted persistently at /mnt/rhel9-iso; packages install from it (BaseOS repo)"
t4() { iso_repo_baseos /mnt/rhel9-iso; }

task 5 FS node2 "NFS server: /exports/projects and /exports/docs rw; README files; at boot; firewall"
t5() {
  need expect_file_has /exports/projects/README '^Mock1 projects share$'
  need expect_file_has /exports/docs/README '^Mock1 docs share$'
  need svc_persisted nfs-server
  need nfs_export_is /exports/projects rw any
  need nfs_export_is /exports/docs rw any
  need fw_has nfs 2049/tcp
}
requires 5 4

task 6 STOR node1 "GPT on $XDISK: 2 GiB XFS on /mnt/xfs_vol, 2 GiB vfat on /mnt/vfat_vol, persistent"
t6() {
  need expect "findmnt -no FSTYPE /mnt/xfs_vol" xfs
  need mount_persisted /mnt/xfs_vol
  need on_gpt_disk /mnt/xfs_vol "$XDISK" 1900 2150
  need expect "findmnt -no FSTYPE /mnt/vfat_vol" vfat
  need mount_persisted /mnt/vfat_vol
  need on_gpt_disk /mnt/vfat_vol "$XDISK" 1900 2150
}

task 7 USR node1 "user biscuit in group tin, home /mnt/xfs_vol/home/biscuit on the XFS file system"
t7() {
  must expect_ok "id biscuit" || return
  need expect_match "id -nG biscuit" '(^| )tin( |$)'
  need expect "getent passwd biscuit | cut -d: -f6" /mnt/xfs_vol/home/biscuit
  need expect "stat -c %U /mnt/xfs_vol/home/biscuit" biscuit
  need expect "findmnt -no TARGET -T /mnt/xfs_vol/home/biscuit" /mnt/xfs_vol
}
requires 7 6

task 8 USR node1 "group tin may sudo only: cat /var/log/messages"
t8() {
  must expect_ok "id biscuit" || return
  need expect_ok "visudo -c"
  need expect_ok "grep -rEqs '^\s*%tin\s' /etc/sudoers /etc/sudoers.d/"
  need expect_match "sudo -l -U biscuit" '/usr/bin/cat /var/log/messages\s*$'
  need expect_ok "! sudo -l -U biscuit | grep -Eq '\)\s*(NOPASSWD:\s*)?ALL\s*$'"
}
requires 8 7

task 9 FS node1 "/larder: group tin, set-GID + sticky, group rwx"
t9() { need expect_match "stat -c '%a %G' /larder" '^3[0-7]7[0-7] tin$'; }
requires 9 7

task 10 SH node1 "/root/load-report.sh writes uptime to /root/load.log; root cron daily 03:15"
t10() {
  must expect_ok "test -x /root/load-report.sh" || return
  need expect_ok "bash -n /root/load-report.sh"
  need expect_file_has /root/load-report.sh 'uptime'
  need expect_file_has /root/load-report.sh '/root/load\.log'
  need cron_has '^\s*15\s+0?3\s+\*\s+\*\s+\*\s+(root\s+)?.*(/root/)?load-report\.sh'
  need svc_persisted crond
}

task 11 CON node1 "rootless webfront (ubi9/httpd-24): /srv/site -> docroot, host port 35565, starts at boot"
t11() {
  must find_cuser webfront || return
  need expect_match "$(asu 'podman inspect webfront --format {{.ImageName}}')" 'ubi9/httpd-24'
  need expect_match "$(asu 'podman port webfront')" ':35565$'
  need expect_match "$(asu 'podman inspect webfront --format "{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}"')" '(^| )/srv/site/?:/var/www/html/?( |$)'
  need expect_match "curl -s --max-time 5 http://localhost:35565/" 'Mock1 container OK'
  need fw_has none 35565/tcp
  need expect "loginctl show-user $CUSER -p Linger" Linger=yes
  need user_unit_for webfront
}
requires 11 3

task 12 SEC node1 "SELinux enforcing now and at every boot"
t12() {
  need expect getenforce Enforcing
  need expect "awk -F= '/^SELINUX=/{print \$2}' /etc/selinux/config" enforcing
  need expect_ok "! grep -Eqw 'enforcing=0|selinux=0' /proc/cmdline"
  need expect_ok "! grubby --info=ALL 2>/dev/null | grep -E '^args=' | grep -Eqw 'enforcing=0|selinux=0'"
}

task 13 STOR node1 "1 GiB swap on $SWAPDISK, active and persistent"
t13() {
  local d; d=$(swap_dev_on_disk "$SWAPDISK" | head -1)
  [[ -n $d ]] || { _rec "cat /proc/swaps" "no active swap on /dev/$SWAPDISK"; _fail; return; }
  need swap_persisted "$d"
  need expect_ok "test \$(( \$(lsblk -bdno SIZE $d) / 1048576 )) -ge 900"
}

task 14 OPS node1 "systemd journal persistent across reboots"
t14() { need journal_persisted; }

task 15 STOR node1 "vg_store (PE 32 MiB) on all of $THINDISK; 3 GiB thin pool; thin lv_bulk 500 GiB, XFS on /bulk"
t15() {
  must expect_ok "vgs vg_store" || return
  need expect "vgs --noheadings --units m -o vg_extent_size vg_store | tr -d ' '" 32.00m
  need expect "pvs --noheadings -o pv_name,vg_name | awk '\$2==\"vg_store\"{print \$1}'" "/dev/$THINDISK"
  must expect_ok "lvs vg_store/lv_bulk" || return
  need expect "lvs --noheadings -o segtype vg_store/lv_bulk | tr -d ' '" thin
  need expect "lvs --noheadings --units g -o lv_size vg_store/lv_bulk | tr -d ' '" 500.00g
  need expect "lvs --noheadings --units g -o lv_size vg_store/\$(lvs --noheadings -o pool_lv vg_store/lv_bulk | tr -d ' ') | tr -d ' '" 3.00g
  need expect "findmnt -no FSTYPE /bulk" xfs
  need same_dev /bulk /dev/vg_store/lv_bulk
  need mount_persisted /bulk
}

task 16 STOR node1 "lv_xswap: exactly 32 extents of vg_store, swap, active and persistent"
t16() {
  must expect_ok "lvs vg_store/lv_xswap" || return
  need expect "lvs --noheadings -o seg_size_pe vg_store/lv_xswap | tr -d ' '" 32
  need swap_persisted /dev/vg_store/lv_xswap
}
requires 16 15

task 17 DEP node1 "httpd enabled, serves 'Mock1 Apache OK', http allowed through the firewall persistently"
t17() {
  must expect_ok "rpm -q httpd" || return
  need svc_persisted httpd
  need expect_match "curl -s --max-time 5 http://localhost/" '^Mock1 Apache OK'
  need fw_has http 80/tcp
}
requires 17 3

task 18 SEC node2 "sysop exists on node2 and logs in to node1 as sysop by key, no password"
t18() {
  must expect_ok "id sysop" || return
  need key_login_ok sysop "$NODE1_IP"
}

task 19 SEC node1 "sshd: no password or keyboard-interactive auth; only sysop may log in"
t19() {
  must expect_ok "id sysop" || return
  need expect_ok "test -s ~sysop/.ssh/authorized_keys"
  need expect "sshd -T 2>/dev/null | awk '\$1==\"passwordauthentication\"{print \$2}'" no
  need expect "sshd -T 2>/dev/null | awk '\$1==\"kbdinteractiveauthentication\"{print \$2}'" no
  need expect "sshd -T 2>/dev/null | awk '\$1==\"allowusers\"{print \$2}' | sort -u | paste -sd' '" sysop
  need svc_persisted sshd
}

task 20 FS node1 "autofs: /remote/projects and /remote/docs from $NODE2_IP:/exports/{projects,docs}, not fstab (needs node2 task 5)"
t20() {
  must expect_ok "rpm -q autofs" || return
  need svc_persisted autofs
  need autofs_maps_to /remote/projects "$NODE2_IP:/exports/projects"
  need autofs_maps_to /remote/docs "$NODE2_IP:/exports/docs"
  need expect_ok "! findmnt --fstab -n /remote/projects && ! findmnt --fstab -n /remote/docs"
}
requires 20 3

run_all; report
