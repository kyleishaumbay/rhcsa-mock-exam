# RHCSA 9 (EX200) per-objective command reference

Objective wording is Red Hat's RHEL 9 list (68 objectives), verbatim. Used by Mode A (keys), Mode C (grading) and Mode D (coaching) on RHEL 9 papers. Every row is: what to run, how to prove it, and the trap that loses the mark. For a RHEL 10 paper, see the RHEL 10 delta in objectives.md: drop the containers section, add Flatpak (flatpak remote-add --if-not-exists [--user], flatpak install [--user] <remote> <app.id>).

## Exam-day runbook

- **First 5 minutes.** Read every task. Note which node each one targets. Mark dependencies: users/groups before permissions, scripts, sudo; repositories before any install; node network before anything remote.
- **Locked-out node.** Reset root on it first, from the console (rd.break; fall back to init=/bin/bash). Then its network (nmtui/nmcli), then /etc/hosts entries on both nodes.
- **Container tasks.** Do them as the named user over ssh (ssh bob@localhost), not su. Enable linger as root. Run → verify → generate the unit → remove the original → enable the unit → reboot-check.
- **Order.** Repos → storage (mistakes here are cheapest to redo early) → users/groups → everything else. Easy tasks first, hard last.
- **Time box.** Available minutes ÷ number of tasks = your average. At double it, move on and come back.
- **Every task.** Do exactly what's asked — no extra config. Run the verify command. Persistent form, never runtime-only.
- **Reboots.** After network, storage and bootloader tasks. Final reboot of every node with ~15 minutes left, then re-run your checks.
- **Stuck on syntax.** man -k <word>, then /EXAMPLE inside the page. nmcli-examples, systemd.timer, semanage-fcontext, 5 crontab, 5 autofs all have one.

## Where to look on the box (no internet on the exam)

| Need the syntax for | Open |
|---|---|
| fstab fields / mount options | `man 5 fstab; man 8 mount` |
| cron time fields | `man 5 crontab (also /etc/crontab header)` |
| systemd timer OnCalendar | `man 5 systemd.timer; man 7 systemd.time` |
| autofs map syntax | `man 5 autofs; man 5 auto.master` |
| nmcli property names | `man nmcli-examples; man 5 nm-settings` |
| SELinux fcontext regex | `man semanage-fcontext (EXAMPLES)` |
| SELinux port / boolean | `man semanage-port; man semanage-boolean` |
| sudoers lines | `man 5 sudoers (search: EXAMPLES)` |
| sshd options | `man 5 sshd_config` |
| chrony server line | `man 5 chrony.conf` |
| repo file keys | `man 5 dnf.conf (search: baseurl)` |
| firewalld rich rules | `man 5 firewalld.richlanguage` |
| password aging | `man chage; man 5 login.defs` |
| journald storage | `man 5 journald.conf` |
| podman run options | `man podman-run (search: --volume, --publish)` |
| container systemd unit | `man podman-generate-systemd; man podman-systemd.unit (Quadlet)` |
| Containerfile instructions | `man Containerfile` |
| registry search list | `man containers-registries.conf` |
| SELinux denials | `man ausearch; man sealert` |
| star archiving | `man star` |

## Understand and use essential tools

_Rarely a whole task on its own — these are the verbs every other task is built from. The graded ones are grep-to-file, tar archives, links, find-and-copy, and permissions._

### Access a shell prompt and issue commands with correct syntax

```bash
command -options arguments
type <cmd>; which <cmd>
<cmd> --help | less
# verify
echo $?   # 0 = success
```
**Trap:** Read the whole error. Most exam-day failures here are a typo, not a knowledge gap.

### Use input-output redirection (>, >>, |, 2>, etc.)

```bash
cmd > out        # overwrite
cmd >> out       # append
cmd 2> err       # stderr only
cmd &> all       # stdout+stderr
cmd > f 2>&1     # same, portable
cmd 2>/dev/null | tee -a log
# verify
cat out; wc -l out
```
**Trap:** Order matters: 2>&1 > f sends stderr to the terminal, not the file. > on the wrong path silently truncates a file.

### Use grep and regular expressions to analyze text

```bash
grep -E '^root|nologin$' /etc/passwd
grep -v '^#' f | grep -v '^$'
grep -rl 'pattern' /etc
grep -inw 'word' file    # case-insens, line no, whole word
grep 'strato' /usr/share/dict/words > /root/lines
# verify
wc -l /root/lines; head /root/lines
```
**Trap:** Save exactly what was asked, in original order, to the exact path. Don't add -n or -c unless asked — the checker diffs the file.

### Access remote systems using ssh

```bash
ssh user@node2
ssh -p 2222 user@node2
ssh node2 'hostname; id'
echo '192.168.1.11 node2.lab.example.com node2' >> /etc/hosts
# verify
ssh node2 hostname
```
**Trap:** An /etc/hosts entry saves typing all exam. Only change sshd_config if a task asks — an extra PermitRootLogin change is config the grader never asked for.

### Log in and switch users in multi-user targets

```bash
su - bob            # login shell, bob's env
su - bob -c 'umask'
sudo -i
Ctrl+Alt+F2..F6      # text consoles
# verify
whoami; id; echo $HOME
```
**Trap:** su bob (no dash) keeps root's environment — umask, PATH and HOME tests then give the wrong answer.

### Archive, compress, unpack, and uncompress files using tar, star, gzip, and bzip2

```bash
dnf install -y star; star -c f=/root/etc.star /etc; star -t f=/root/etc.star   # see man star
tar -czvf /root/etc.tar.gz /etc     # gzip
tar -cjvf /root/etc.tar.bz2 /etc    # bzip2
tar -cJvf /root/etc.tar.xz /etc     # xz
tar -tvf archive     # list
tar -xzf a.tar.gz -C /dest
gzip f / gunzip f.gz; bzip2 f / bunzip2 f.bz2
# verify
file /root/etc.tar.gz
tar -tf /root/etc.tar.gz | head
```
**Trap:** Compression flag must match the extension asked for (z/j/J). tar strips the leading / — that is normal, not an error.

### Create and edit text files

```bash
vim f:  i  Esc  :wq  :q!  /text  n  dd  yy p  u
:%s/old/new/g
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
cat > f <<'EOF' ... EOF
# verify
cat -A f   # shows tabs/line ends
```
**Trap:** nano may not be installed. Be fluent enough in vim that editing fstab is not scary.

### Create, delete, copy, and move files and directories

```bash
mkdir -p /a/b/c; touch f; rmdir d; rm -rf d
cp -a src dst    # keeps owner, perms, times, context
mv old new
find / -user bob -type f -exec cp -a {} /root/found/ \;
find /etc -name '*.conf' -size +3k -mtime -7
find / -perm -4000 -type f 2>/dev/null
# verify
ls -la /root/found | head
find /root/found -type f | wc -l
```
**Trap:** find tasks are common. -exec ... \; needs the escaped semicolon. cp without -a loses ownership the task may check.

### Create hard and soft links

```bash
ln /data/file /data/hard       # hard: same inode
ln -s /data/file /root/soft    # soft: use absolute target
# verify
ls -li /data/file /data/hard   # same inode no.
readlink -f /root/soft
```
**Trap:** Hard links can't cross filesystems or point to directories. A relative symlink resolves from the link's own directory.

### List, set, and change standard ugo/rwx permissions

```bash
chmod 750 f; chmod u+x,g-w,o= f
chown bob:devs f; chgrp devs d
chmod 2770 /shared    # setgid: new files get dir's group
chmod 1777 /tmpdir   # sticky: only owner deletes
# verify
stat -c '%a %U %G %n' f
ls -ld /shared
```
**Trap:** Collaborative-directory tasks want group owner + setgid (2xxx). Octal digit order is special,user,group,other.

### Locate, read, and use system documentation including man, info, and files in /usr/share/doc

```bash
man -k keyword  (or apropos)   # empty? run: mandb
man 5 fstab   man 5 crontab   man 5 systemd.timer
man semanage-fcontext   man nmcli-examples
inside man:  /EXAMPLE  n  N  G  q
rpm -qd <pkg>; ls /usr/share/doc/<pkg>
# verify
man -k timer | head
```
**Trap:** No internet on the exam. Know which man page holds the example you'd otherwise Google — see the 'Where to look' table.

## Create simple shell scripts

_The checker runs your script with its own arguments and compares output or files. Exact output wording and exit codes matter._

### Conditionally execute code (use of: if, test, [], etc.)

```bash
if [ -f "$1" ]; then echo exists
elif [ -d "$1" ]; then echo dir
else echo missing; exit 1; fi
tests: -f -d -e -z -n  -eq -ne -lt -gt  = !=
if grep -q root /etc/passwd; then ...; fi
# verify
bash -n script   # syntax only
./script x; echo $?
```
**Trap:** Spaces inside [ ] are mandatory. Quote "$1" or an empty argument breaks the test.

### Use Looping constructs (for, etc.) to process file, command line input

```bash
for u in $(cat /root/users.txt); do useradd "$u"; done
while read -r line; do echo "$line"; done < file
for arg in "$@"; do echo "$arg"; done
for i in {1..5}; do ...; done
# verify
bash -x ./script   # trace every line
```
**Trap:** while read keeps lines with spaces intact; for over $(cat) splits on spaces.

### Process script inputs ($1, $2, etc.)

```bash
#!/bin/bash
if [ $# -ne 1 ]; then
  echo "Usage: $0 <user>" >&2; exit 1
fi
$1 $2 = args, $# = count, "$@" = all, $0 = name
# verify
./script; echo $?   # usage path
./script bob
```
**Trap:** If the task specifies the usage message, match it character for character.

### Processing output of shell commands within a script

```bash
count=$(grep -c bash /etc/passwd)
for f in $(find /etc -name '*.conf' -size -2k); do ...; done
result=$?   # exit status of last command
chmod +x /usr/local/bin/script   # on PATH for everyone
# verify
which script; script arg
```
**Trap:** Forgetting chmod +x or the #! line is the classic zero-point script. Put it where the task says.

## Operate running systems

_Interrupting the boot is the task that decides the exam: without root on that node, every task on it is lost. Rehearse both methods until boring._

### Boot, reboot, and shut down a system normally

```bash
systemctl reboot; systemctl poweroff
shutdown -r now; shutdown -h +10
# verify
uptime; journalctl --list-boots
```
**Trap:** Reboot after network, storage and bootloader tasks, then re-verify. The grader reboots before it checks.

### Boot systems into different targets manually

```bash
GRUB: e → end of linux line → systemd.unit=rescue.target  → Ctrl+X
systemd.unit=emergency.target
running: systemctl isolate multi-user.target
# verify
systemctl get-default; who -r
```
**Trap:** isolate changes it now only; set-default is the persistent one (Deploy section).

### Interrupt the boot process in order to gain access to a system

```bash
RHEL 9 primary — rd.break:
GRUB: e → linux line: delete console=… / rhgb / quiet, append rd.break → Ctrl+X
mount -o remount,rw /sysroot
chroot /sysroot
passwd root
touch /.autorelabel
exit; exit
Fallback — init=/bin/bash: remount,rw /  (not /sysroot) → passwd → touch /.autorelabel → exec /sbin/init
# verify
log in as root with the new password
getenforce   # still Enforcing
```
**Trap:** Don't mix the two: with init=/bin/bash the real root is /, not /sysroot. Serial console= args hide the shell — remove them. Skipping .autorelabel = password set but login fails.

### Identify CPU/memory intensive processes and kill processes

```bash
top   # P=CPU sort, M=mem sort, k=kill
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head
kill PID; kill -9 PID; pkill -u bob; killall name
pgrep -a name
# verify
ps -p PID || echo gone
```
**Trap:** Kill by PID after you've confirmed the command column — don't pkill a pattern that also matches a system process.

### Adjust process scheduling

```bash
nice -n 10 cmd &
renice -n 5 -p PID
service: systemctl edit <svc> → [Service] Nice=5
# verify
ps -o pid,ni,cmd -p PID
```
**Trap:** Only root can set a negative nice. renice is lost when the process ends — a unit drop-in is the persistent form.

### Manage tuning profiles

```bash
dnf install -y tuned; systemctl enable --now tuned
tuned-adm list; tuned-adm recommend
tuned-adm profile virtual-guest
# verify
tuned-adm active; tuned-adm verify
systemctl is-enabled tuned
```
**Trap:** The profile survives reboot only if tuned is enabled. 'Set the recommended profile' means run recommend first — don't guess.

### Locate and interpret system log files and journals

```bash
journalctl -u sshd -b; journalctl -p err --since '1 hour ago'
journalctl -f; journalctl _PID=1234
/var/log/messages  /var/log/secure  /var/log/cron
ausearch -m AVC -ts recent   # SELinux denials
logger -p user.notice 'test'
# verify
journalctl -b -p warning | tail
```
**Trap:** A 'find the error and save it to a file' task wants the matching lines redirected to the exact path given.

### Preserve system journals

```bash
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' > /etc/systemd/journald.conf.d/persist.conf
systemctl restart systemd-journald
(Storage=auto default: mkdir /var/log/journal is enough)
# verify
ls /var/log/journal/$(cat /etc/machine-id)/   # system.journal present = writing to disk
after reboot: journalctl --list-boots   # >1 boot
```
**Trap:** Restart journald or nothing changes until reboot. The drop-in works whether or not /etc/systemd/journald.conf exists.

### Start, stop, and check the status of network services

```bash
systemctl start|stop|restart|reload sshd
systemctl status httpd
# verify
systemctl is-active httpd
ss -tlnp | grep :80
```
**Trap:** start ≠ enable. Nothing started-but-not-enabled survives the grader's reboot.

### Securely transfer files between systems

```bash
scp file user@node2:/path/
scp -r dir node2:/tmp/
scp -P 2222 file node2:   # capital P for scp
sftp user@node2   (put / get)
rsync -av -e ssh src/ node2:/dst/
# verify
ssh node2 ls -l /path/file
```
**Trap:** scp -P (port) vs ssh -p (port). scp -p lowercase preserves times — a different thing.

## Configure local storage

_Do storage early and carefully: a broken fstab sends the node into emergency mode on the grader's reboot and every check on it fails._

### List, create, and delete partitions on MBR and GPT disks

```bash
lsblk; fdisk -l /dev/vdb
MBR: fdisk: o (new DOS label, EMPTY disk only); p primary ×3, e extended, then l logical
fdisk /dev/vdb: g (new GPT, EMPTY disk only) → n → Enter → Enter → +1G → t → lvm|swap → w
parted -s /dev/vdb mklabel gpt mkpart p1 1MiB 1025MiB set 1 lvm on
delete: fdisk d  |  parted /dev/vdb rm 1
partprobe /dev/vdb; udevadm settle
# verify
lsblk /dev/vdb
parted /dev/vdb print
```
**Trap:** o / g / mklabel wipes the partition table. MBR allows 4 primaries — the 4th slot as extended if you need more. On a disk that already has partitions, only add (n). Non-destructive is an objective.

### Create and remove physical volumes

```bash
pvcreate /dev/vdb1
pvremove /dev/vdb1   # after vgreduce
# verify
pvs; pvdisplay /dev/vdb1
```
**Trap:** pvcreate refuses a partition with a filesystem signature — wipefs only if the task makes it yours to wipe.

### Assign physical volumes to volume groups

```bash
vgcreate -s 16M vgdata /dev/vdb1   # -s = PE size
vgextend vgdata /dev/vdc1
vgreduce vgdata /dev/vdc1
# verify
vgs; vgdisplay vgdata | grep 'PE Size'
```
**Trap:** If the task gives an extent size, it wants -s at vgcreate time; you cannot change it later without rebuilding.

### Create and delete logical volumes

```bash
lvcreate -n lvdata -L 500M vgdata
lvcreate -n lvx -l 20 vgdata        # 20 extents
lvcreate -n lvall -l 100%FREE vgdata
lvremove /dev/vgdata/lvdata
# verify
lvs -o lv_name,lv_size,seg_size_pe vgdata
```
**Trap:** -L is size, -l is extents. 'Size of 20 extents' with -L 20M is wrong unless PE is 1 MiB.

### Configure systems to mount file systems at boot by Universally Unique ID (UUID) or label

```bash
blkid /dev/vgdata/lvdata
UUID=<uuid>  /data  xfs  defaults  0 0
xfs_admin -L data /dev/vgdata/lvdata   # unmounted
e2label /dev/vdb2 backup; fatlabel /dev/vdb3 USB
LABEL=backup  /backup  ext4  defaults  0 0
mkdir -p /data; systemctl daemon-reload; mount -a
# verify
findmnt --verify
findmnt /data
grep /data /etc/fstab
```
**Trap:** Never reboot on an unverified fstab. mount -a + findmnt --verify every time. A /dev/vdb1 entry is not 'by UUID or label'.

### Add new partitions and logical volumes, and swap to a system non-destructively

```bash
mkswap /dev/vdb2      # or an LV: /dev/vgdata/lvswap
UUID=<uuid>  none  swap  defaults  0 0
swapon -a
# verify
swapon --show; free -h
```
**Trap:** Add swap, don't replace the existing one. pri=N in the options field only if a priority is asked for.

## Create and configure file systems

_RHCSA only asks you to be the NFS client. Mount it, automount it, make it survive reboot._

### Create, mount, unmount, and use vfat, ext4, and xfs file systems

```bash
mkfs.xfs /dev/vgdata/lvdata
mkfs.ext4 /dev/vdb2
mkfs.vfat /dev/vdb3        # needs dosfstools
mount /dev/vdb2 /mnt/x; umount /mnt/x
vfat owner: defaults,uid=bob,gid=devs,umask=027
# verify
df -hT /mnt/x; findmnt /mnt/x
blkid /dev/vdb3
```
**Trap:** vfat has no Unix permissions — chown on it fails; ownership comes from mount options.

### Mount and unmount network file systems using NFS

```bash
dnf install -y nfs-utils
showmount -e nfs.lab.example.com
mount -t nfs nfs.lab.example.com:/exports/share /mnt/share
fstab: nfs.lab.example.com:/exports/share  /mnt/share  nfs  defaults,_netdev  0 0
# verify
findmnt -t nfs,nfs4
umount /mnt/share; mount -a
```
**Trap:** _netdev stops boot trying to mount before the network is up. Client needs no firewall change — nfs/mountd/rpc-bind services are for the server.

### Configure autofs

```bash
dnf install -y autofs
/etc/auto.master.d/remote.autofs:
  /rhome  /etc/auto.rhome
/etc/auto.rhome (indirect, wildcard):
  *  -rw,sync  nfs.lab.example.com:/exports/home/&
direct map: /-  /etc/auto.direct
  /mnt/docs  -ro  nfs.lab.example.com:/exports/docs
systemctl enable --now autofs
# verify
ls /rhome/user1    # triggers the mount
mount | grep /rhome
systemctl is-enabled autofs
```
**Trap:** The .autofs extension is required in auto.master.d. Leading dash on options. * matches the key, & reuses it. Don't pre-create subdirectories under the autofs mount point. A direct map (`/-` + absolute key) is equally correct when the task only names the path; an indirect map is needed for '/X is an automount directory' or wildcards. A typo in the source (`users&` instead of `users/&`) loads fine and fails silently on access, so test with `su - <user> -c pwd`.

### Extend existing logical volumes

```bash
lvextend -r -L +300M /dev/vgdata/lvdata   # -r grows the FS too
lvextend -r -L 1G /dev/vgdata/lvdata      # absolute size
manual: xfs_growfs /data  |  resize2fs /dev/vgdata/lvdata
no free space? vgextend first
# verify
lvs vgdata; df -h /data
```
**Trap:** Without -r the LV grows but df doesn't. XFS cannot shrink. +300M vs 300M — relative vs absolute.

### Create and configure set-GID directories for collaboration

```bash
groupadd devs; mkdir -p /shared/devs
chgrp devs /shared/devs
chmod 2770 /shared/devs      # rwx for owner+group, setgid, nothing for others
optional delete-protection: chmod 3770 (adds sticky)
# verify
ls -ld /shared/devs   # drwxrws---
su - bob -c 'touch /shared/devs/x'; ls -l /shared/devs/x   # group devs
```
**Trap:** The s in the group x slot is the point: new files inherit the directory's group. Lowercase s = setgid + x; capital S = setgid without x (broken).

### Diagnose and correct file permission problems

```bash
namei -l /path/to/file    # perms of every component
id bob; ls -ld dir
chmod o+x /parent   # traverse needs x on every dir
setfacl -m u:bob:rw file; getfacl file
ls -Z file; restorecon -v file
# verify
su - bob -c 'cat /path/to/file'
```
**Trap:** Test as the user, not as root. If rwx look right, check ACLs and SELinux context next.

## Deploy, configure, and maintain systems

_On RHEL 9 this section also owns software: repository access is usually one of the first tasks and every install depends on it. Almost every task here has a start-now half and a survive-reboot half — the grader only sees the second._

### Schedule tasks using at and cron

```bash
at: systemctl enable --now atd; echo 'cmd' | at now + 5 minutes; atq; atrm N
cron: crontab -e -u bob   →   */5 9-17 * * 1-5  /usr/bin/logger hi
      fields: min hour day-of-month month day-of-week
optional (not named on v9, Sander ch.12 covers it) — timer:
       /etc/systemd/system/job.service  [Service] Type=oneshot  ExecStart=/usr/local/bin/job.sh
       /etc/systemd/system/job.timer  [Timer] OnCalendar=*-*-* 02:00:00  Persistent=true
                                       [Install] WantedBy=timers.target
systemctl daemon-reload; systemctl enable --now job.timer
# verify
crontab -l -u bob
systemctl list-timers job.timer
systemd-analyze calendar '*-*-* 02:00:00'
```
**Trap:** If the task says cron job, only cron scores. Right user (crontab -u). Absolute paths. Timers: enable the .timer, not the .service.

### Start and stop services and configure services to start automatically at boot

```bash
systemctl enable --now httpd
systemctl disable --now cockpit.socket
systemctl mask <svc>
change a unit without touching the vendor file:
  systemctl edit httpd   →  [Unit] Wants=vsftpd.service   [Service] Restart=on-failure  RestartSec=10s
  (or write /etc/systemd/system/httpd.service.d/override.conf, then systemctl daemon-reload)
# verify
systemctl is-enabled httpd; systemctl is-active httpd
systemctl show httpd -p Restart -p RestartUSec -p Wants
```
**Trap:** Both checks must say enabled + active. That pair is exactly what the grader runs. In `systemctl edit` on RHEL 9, anything typed below `### Lines below this comment will be discarded` is thrown away. Never edit /usr/lib/systemd/system/*.service.

### Configure systems to boot into a specific target automatically

```bash
systemctl set-default multi-user.target
# verify
systemctl get-default
```
**Trap:** Some exams leave a node on graphical.target or rescue as a trap — check get-default on both nodes early.

### Configure time service clients

```bash
dnf install -y chrony
/etc/chrony.conf: comment 'pool …', add  server classroom.lab.example.com iburst
systemctl enable --now chronyd; systemctl restart chronyd
timedatectl set-timezone Asia/Manila; timedatectl set-ntp true
# verify
chronyc sources -v   # ^* = synced
timedatectl
```
**Trap:** Restart chronyd after editing or it keeps the old sources. 'server' for one host, 'pool' for a pool name.

### Install and update software packages from Red Hat Network, a remote repository, or from the local file system — 1: repository access

```bash
# /etc/yum.repos.d/exam.repo
[BaseOS]
name=BaseOS
baseurl=http://repo.lab.example.com/BaseOS
enabled=1
gpgcheck=0          # or gpgkey= if a key is given
[AppStream]  ...same, /AppStream
# or: dnf config-manager --add-repo <url>
# verify
dnf repolist -v
dnf clean all; dnf makecache
```
**Trap:** --add-repo writes no gpgcheck line; unsigned repos then fail with a GPG error. Check the file it wrote. Local ISO: baseurl=file:///mnt/BaseOS and persist the ISO mount in fstab.

### Install and update software packages … — 2: install and remove

```bash
dnf install -y <pkg>; dnf remove <pkg>
dnf provides '*/semanage'
dnf search <term>; dnf info <pkg>
dnf group list; dnf group install '<group>'
rpm -qa | grep <pkg>; rpm -qf /path; rpm -ql <pkg>
# verify
rpm -q <pkg>
dnf history | head
```
**Trap:** Installing a service package does not start it. Most exam tasks want the service enabled too (systemctl enable --now).

### Install and update software packages … — 3: update, local and remote RPMs

```bash
dnf update -y; dnf upgrade <pkg>
dnf install ./local.rpm            # resolves deps
dnf install http://repo/pkgs/x.rpm
rpm -Uvh x.rpm                     # no dep resolution
RHN/CDN: subscription-manager register (lab only)
# verify
rpm -q <pkg>; dnf history info last
```
**Trap:** A kernel update becomes the default entry — check grubby --default-kernel if a task depends on which kernel boots.

### Modify the system bootloader

```bash
grubby --update-kernel=ALL --args='audit=1'
grubby --update-kernel=ALL --remove-args='rhgb quiet'
grubby --set-default /boot/vmlinuz-<ver>
/etc/default/grub: GRUB_TIMEOUT=10
grub2-mkconfig -o /boot/grub2/grub.cfg
# verify
grubby --info=DEFAULT
after reboot: cat /proc/cmdline
```
**Trap:** Editing /etc/default/grub does nothing until grub2-mkconfig. On RHEL 9/10 the path is /boot/grub2/grub.cfg for BIOS and UEFI.

## Manage basic networking

_A dead network on a node blocks every remote check on it. Configure from the console, reboot, and prove it came back._

### Configure IPv4 and IPv6 addresses

```bash
nmcli con show
nmcli con mod '<con>' ipv4.method manual ipv4.addresses 192.168.1.10/24 \
  ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.254 \
  ipv6.method manual ipv6.addresses fd00:1::10/64 connection.autoconnect yes
nmcli con up '<con>'
(nmtui is fine on the console)
# verify
ip -br a; ip r; ip -6 r
nmcli -g ipv4.method,ipv4.addresses con show '<con>'
```
**Trap:** Leaving ipv4.method auto gives you DHCP plus your address. Changes apply on con up or reboot, not on mod.

### Configure hostname resolution

```bash
hostnamectl hostname node1.lab.example.com
/etc/hosts: 192.168.1.11 node2.lab.example.com node2
nmcli con mod '<con>' ipv4.dns 192.168.1.254 ipv4.dns-search lab.example.com
# verify
hostname; getent hosts node2
cat /etc/resolv.conf
```
**Trap:** Don't hand-edit resolv.conf — NetworkManager rewrites it. Set DNS on the connection.

### Configure network services to start automatically at boot

```bash
systemctl enable --now sshd httpd
nmcli con mod '<con>' connection.autoconnect yes
# verify
systemctl is-enabled sshd NetworkManager
```
**Trap:** Same pair as every service: enabled AND active.

### Restrict network access using firewall-cmd/firewall

```bash
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --remove-service=cockpit
firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.0/24 service name=ssh reject'
firewall-cmd --reload
# verify
firewall-cmd --list-all
firewall-cmd --permanent --list-all
```
**Trap:** --permanent without --reload isn't live; without --permanent it's gone at reboot. Port needs /tcp or /udp.

## Manage users and groups

_Later tasks (permissions, scripts, sudo, cron, rootless containers) reuse these accounts. One wrong UID or missing group costs points far beyond this section._

### Create, delete, and modify local user accounts

```bash
useradd -u 2001 -c 'Bob B' -G devs -s /bin/bash bob
useradd -s /sbin/nologin svcuser      # no interactive shell
usermod -aG wheel bob                   # -a or you drop other groups
usermod -L bob; userdel -r bob
# verify
id bob; getent passwd bob
```
**Trap:** usermod -G without -a replaces all supplementary groups. 'No interactive shell' = /sbin/nologin.

### Change passwords and adjust password aging for local user accounts

```bash
echo 'P@ssw0rd' | passwd --stdin bob     # or: echo 'bob:P@ssw0rd' | chpasswd
chage -M 90 -m 7 -W 14 bob
chage -d 0 bob          # must change at next login
chage -E 2026-12-31 bob  # account expiry
new users: /etc/login.defs  PASS_MAX_DAYS 90
# verify
chage -l bob
grep ^PASS_ /etc/login.defs
```
**Trap:** login.defs affects only accounts created afterwards. Existing users need chage.

### Create, delete, and modify local groups and group memberships

```bash
groupadd -g 3000 devs; groupmod -n developers devs; groupdel old
gpasswd -a bob devs; gpasswd -d bob devs
# verify
getent group devs; id bob
```
**Trap:** Group membership only shows in a new login session — test with su - bob, not your existing shell.

### Configure superuser access

```bash
visudo -f /etc/sudoers.d/devs
  %devs ALL=(ALL) ALL
  bob   ALL=(ALL) NOPASSWD: ALL
  %ops  ALL=/usr/bin/systemctl restart httpd
or: usermod -aG wheel bob
# verify
visudo -c
sudo -l -U bob
```
**Trap:** A syntax error in sudoers breaks sudo for everyone — always visudo, never a plain editor.

## Manage security

_SELinux answers must be written to policy (semanage, setsebool -P) — runtime-only fixes vanish at reboot or relabel._

### Configure firewall settings using firewall-cmd/firewalld

```bash
systemctl enable --now firewalld
firewall-cmd --get-active-zones; firewall-cmd --set-default-zone=public
firewall-cmd --permanent --zone=internal --add-source=10.0.0.0/24
firewall-cmd --reload
# verify
firewall-cmd --permanent --list-all --zone=<z>
```
**Trap:** If firewalld was stopped, starting it is part of the task — check is-enabled.

### Manage default file permissions

```bash
umask 027                          # this shell only
per user: echo 'umask 027' >> ~bob/.bashrc
everyone: echo 'umask 022' > /etc/profile.d/umask.sh
math: files 666-umask, dirs 777-umask
# verify
su - bob -c umask
su - bob -c 'touch t; mkdir d; ls -ld t d'
```
**Trap:** Set it where the task's scope says (one user vs all). Test with su - (login shell) or the file isn't read.

### Configure key-based authentication for SSH

```bash
as the user: ssh-keygen -t ed25519 -N ''
ssh-copy-id bob@node2
server policy: /etc/ssh/sshd_config.d/50-exam.conf
  PasswordAuthentication no   |  PermitRootLogin no
sshd -t && systemctl reload sshd
# verify
ssh -o BatchMode=yes bob@node2 true && echo key-ok
stat -c '%a' ~/.ssh ~/.ssh/authorized_keys   # 700 / 600
```
**Trap:** Generate as the user the task names, not as root. Bad perms on ~/.ssh make sshd silently ignore the key.

### Set enforcing and permissive modes for SELinux

```bash
setenforce 1|0                       # runtime
/etc/selinux/config: SELINUX=enforcing  # persistent
# verify
getenforce; sestatus
grep ^SELINUX= /etc/selinux/config
```
**Trap:** Graded after reboot, so the config file is what counts. Never 'fix' a service by setting permissive.

### List and identify SELinux file and process context

```bash
ls -Z /var/www/html
ps -eZ | grep httpd
id -Z
semanage fcontext -l | grep '/var/www'
# verify
ls -Zd /web
```
**Trap:** Know the reference type to copy from: find a default directory for that service and read its label.

### Restore default file contexts

```bash
semanage fcontext -a -t httpd_sys_content_t '/web(/.*)?'
restorecon -Rv /web
moved files: restorecon -Rv /var/www/html
# verify
ls -Zd /web
semanage fcontext -l -C
```
**Trap:** chcon works until the next relabel — including the one your root reset triggered. Policy (semanage) + restorecon is the answer.

### Manage SELinux port labels

```bash
semanage port -l | grep http_port_t
semanage port -a -t http_port_t -p tcp 82
semanage port -m -t http_port_t -p tcp 82   # if already defined
then: firewall + systemctl restart <svc>
# verify
semanage port -l -C
ss -tlnp | grep :82
```
**Trap:** A non-standard port needs three things: SELinux label, firewall rule, service config/restart. Miss one and it fails.

### Use Boolean settings to modify system SELinux settings

```bash
getsebool -a | grep httpd
semanage boolean -l | grep home
setsebool -P httpd_enable_homedirs on
# verify
getsebool httpd_enable_homedirs
semanage boolean -l -C
```
**Trap:** Without -P the boolean resets at reboot.

### Diagnose and address routine SELinux policy violations

```bash
ausearch -m AVC -ts recent
journalctl -t setroubleshoot   # if setroubleshoot-server installed
sealert -a /var/log/audit/audit.log
read scontext / tcontext / tclass, then fix with restorecon, semanage fcontext|port, or setsebool -P
# verify
the service works with getenforce = Enforcing
ausearch -m AVC -ts recent   # no new denials
```
**Trap:** The fix is a label, port or boolean — never setenforce 0 and never audit2allow a custom module on an RHCSA task.

## Manage containers

_Almost always rootless, as a named user, and graded after reboot: the container must come back on its own. Candidates' advice: drill the full workflow — pull, volume, port, persistence, autostart — until it's fast and clean._

### Find and retrieve container images from a remote registry

```bash
ssh bob@localhost           # rootless work: log in as the user, don't su
podman login registry.lab.example.com
podman search registry.lab.example.com/<term>
podman pull registry.lab.example.com/<repo>/<image>:<tag>
search list: /etc/containers/registries.conf  unqualified-search-registries
# verify
podman images
```
**Trap:** Pull as the user who will run it — root's images are invisible to bob and vice versa.

### Inspect container images

```bash
skopeo inspect docker://registry.lab.example.com/<repo>/<image>:<tag>   # no pull needed
podman image inspect <image>
podman image inspect --format '{{.Config.Cmd}} {{.Config.ExposedPorts}}' <image>
# verify
the exposed port, user and entrypoint you need for the run
```
**Trap:** Read ExposedPorts and User before running — they decide the -p mapping and volume ownership.

### Perform container management using commands such as podman and skopeo

```bash
podman images; podman rmi <image>; podman tag <image> <newname>
skopeo copy docker://<src> docker://<dst>
podman ps -a; podman rm -f <name>
# verify
podman ps -a --format '{{.Names}} {{.Status}}'
```
**Trap:** podman rm -f on the wrong name loses work; list first.

### Build a container from a Containerfile

```bash
podman build -t myimg:1.0 -f /path/Containerfile /path   # last arg = build context
Containerfile: FROM, RUN, COPY, EXPOSE, USER, CMD
# verify
podman images myimg
podman run --rm myimg:1.0
```
**Trap:** Tag exactly as asked (name:tag). The context directory must contain every COPY source.

### Perform basic container management such as running, starting, stopping, and listing running containers

```bash
podman run -d --name web <image>
podman stop web; podman start web; podman restart web
podman logs web; podman exec -it web /bin/bash
# verify
podman ps
podman ps -a
```
**Trap:** -d or your terminal is captured. Container name exactly as the task gives it — systemd unit names derive from it.

### Run a service inside a container

```bash
podman run -d --name web -p 8080:8080 -e KEY=value <image>
firewall-cmd --permanent --add-port=8080/tcp; firewall-cmd --reload   # as root
# verify
curl -s localhost:8080 | head
podman port web
```
**Trap:** Rootless can't bind host ports below 1024. The host firewall still applies.

### Configure a container to start automatically as a systemd service

```bash
as root: loginctl enable-linger bob
as bob (ssh): mkdir -p ~/.config/systemd/user; cd ~/.config/systemd/user
podman generate systemd --name web --files --new
podman stop web; podman rm web     # --new unit creates its own
systemctl --user daemon-reload; systemctl --user enable --now container-web.service
RHEL 9.2+ alternative — Quadlet: ~/.config/containers/systemd/web.container, [Install] WantedBy=default.target
# verify
systemctl --user is-enabled container-web; systemctl --user is-active container-web
loginctl show-user bob -p Linger   # Linger=yes
```
**Trap:** No linger = not started at boot. su - bob breaks systemctl --user (no session bus) — ssh in. Leaving the original container running makes the --new unit fail on a name clash.

### Attach persistent storage to a container

```bash
mkdir -p ~/webdata
podman run -d --name web -p 8080:8080 -v ~/webdata:/var/www/html:Z <image>
container runs as non-root UID? podman unshare chown <uid>:<uid> ~/webdata
# verify
podman inspect web --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{end}}'
file written in container appears in ~/webdata
```
**Trap:** :Z relabels for SELinux; without it the container gets permission denied. Absolute host path, and the volume must be in the systemd unit too (generate after the final run).
