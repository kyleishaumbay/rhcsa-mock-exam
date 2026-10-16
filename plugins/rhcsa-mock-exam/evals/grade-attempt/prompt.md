---
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
runs: 1
tags: [grade, light]
---

I sat my RHCSA mock exam and ran the grader with --all on node1. I only attempted tasks 2, 3, 4, 6, 8, 9, 13, 14, 16 and 18. What did I get wrong and how do I fix it?

```
Reboot every node before grading. Grading runs as root and changes nothing.
Paper: RHCSA9 Mock Exam 1    Graded on: node1 node2

FAIL STOR  #1   node2  vgnfs (PE 8 MiB) on /dev/sdb; lvexport 128 extents, xfs, on /srv/nfs by UUID/LABEL
           - why:   command exited non-zero
             check: vgs vgnfs
           (checks after this one did not run: fix it, then grade again)
PASS FS    #2   node2  NFS server exports /srv/nfs/data and /srv/nfs/users rw to 192.168.100.0/24, at boot
PASS NET   #3   node2  Firewall persistently allows NFS clients
FAIL USR   #4   node1  Users linda 2001 (/home/users/linda), anna 2002 (/home/users/anna), appuser (local home)
           - why:   expected '2001:/home/users/linda', got '2001:/home/linda'
             check: getent passwd linda | cut -d: -f3,6
           - why:   expected '2002:/home/users/anna', got '2002:/home/anna'
             check: getent passwd anna | cut -d: -f3,6
FAIL STOR  #5   node1  2 GiB GPT LVM partition on /dev/sdb; vgweb PE 16 MiB; lvweb ext4 on /webfiles by UUID/LABEL
           - why:   expected 'gpt', got ''
             check: lsblk -dno PTTYPE /dev/sdb
PASS FS    #6   node1  Persistent NFS mount of node2:/srv/nfs/data on /mnt/nfsdata
FAIL DEP   #8   node2  Apache vhost sales.example.com -> /www/docs/sales; at boot; SELinux enforcing; port 80 open
           - why:   expected 'enabled', got 'disabled'
             check: systemctl is-enabled httpd
           - why:   expected 'Welcome to the sales server', got ''
             check: curl -s -m 5 -H 'Host: sales.example.com' http://127.0.0.1/
FAIL NET   #9   node1  sales.example.com resolves to node2 and serves the sales page
           - why:   expected 'Welcome to the sales server', got '' — if node2 task 8 failed, fix that first
             check: curl -s -m 5 http://sales.example.com/
           note:  depends on #8 (node2), which also failed — fix that first
FAIL DEP   #13  node1  vsftpd installed, running, enabled at boot
           - why:   expected 'enabled', got 'disabled'
             check: systemctl is-enabled vsftpd
FAIL FS    #14  node1  autofs wildcard: /home/users/<user> from node2:/srv/nfs/users/<user>
           - why:   no wildcard '*' key mounting node2:/srv/nfs/users/& (got: '  * | -rw node2:/srv/nfs/users&')
             check: automount -m   (map for /home/users)
           note:  depends on #4 (node1), which also failed — fix that first
PASS NET   #16  node1  Firewall permanently allows ssh and ftp and does not allow cockpit
FAIL DEP   #18  node1  httpd restarts 10 s after failure and pulls in vsftpd; vendor unit file untouched
           - why:   output did not match /^(on-failure|always)$/
             check: systemctl show httpd -p Restart --value
           - why:   expected '10s', got '100ms'
             check: systemctl show httpd -p RestartUSec --value

Score (all nodes, equal weights): 57 / 300   pass mark 210
SUMMARY|2026-10-16|RHCSA9 Mock Exam 1|all nodes|57/300|graded=21|failed=1,4,5,8,9,13,14,18|STOR=0,FS=67,DEP=0,NET=50,USR=0
```
