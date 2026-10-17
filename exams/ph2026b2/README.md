# PH2026B2 practice exams

Two RHEL 9 mock exams built only from PH2026B2 Practical Exams 1–3. Questions that appeared in
more than one paper are merged into one task.

- **Mock 1** follows every source question with the same logic, using different names and values.
  As in PE3, node2 is already an NFS server.
- **Mock 2** is the harder version. Nothing is set up for you: you configure the ISO repositories
  on both nodes, build node2's NFS server, and write and build the container image yourself. Each
  task also adds a variation.

| | Paper | Answer key | Grader |
|---|---|---|---|
| Mock 1 | [RHCSA9_Mock_Exam_1.docx](mock-1/RHCSA9_Mock_Exam_1.docx) | [Key](mock-1/RHCSA9_Mock_Exam_1_Key.docx) | [rhcsa9-mock-1-grade.sh](mock-1/rhcsa9-mock-1-grade.sh) |
| Mock 2 | [RHCSA9_Mock_Exam_2.docx](mock-2/RHCSA9_Mock_Exam_2.docx) | [Key](mock-2/RHCSA9_Mock_Exam_2_Key.docx) | [rhcsa9-mock-2-grade.sh](mock-2/rhcsa9-mock-2-grade.sh) |

**Lab:** two RHEL 9 VMs on one subnet, with the RHEL 9 DVD ISO attached to both:
- **node1** has three spare disks (5 GiB, 5 GiB, and 1 GiB or more) and internet access for
  container images.
- **node2** becomes the NFS server and SSH client.
- Fixed IPs on the shared network. Hostnames don't matter: the graders tell the nodes apart by IP.

**Mock 1 needs no setup:** start from two clean VMs and a snapshot. Mock 2 has a five-line setup
block that plants two faults to find. Repositories always use `gpgcheck=0`.

## Where each source question went

| Source question | Mock 1 | Mock 2 |
|---|---|---|
| Root password reset (PE1, PE2, PE3; merged) | 1, 2 | 1, 2 |
| BaseOS repo from the mounted ISO (PE1); ISO as local repo (PE3; merged) | 3, 4 (both nodes) | 3, 4 (both nodes) |
| NFS server already configured (PE3) | 5 (you build it) | 5 (you build it, node1 only, one share ro) |
| GPT disk, 2 partitions, XFS + vFAT, persistent mounts (PE1) | 6 | 6 |
| User in a group, home on the XFS mount (PE1) | 7 | 7 |
| Group sudo restricted to one command (PE1) | 8 | 8 |
| Shared group directory, no deleting others' files (PE1, extra points) | 9 | 9 |
| Script writing to a log, daily cron (PE2) | 10 | 10 |
| Rootless httpd-24 container: host dir as docroot, port, SELinux, persists (PE2) | 11 | 11 (self-built image) |
| SELinux enforcing, persistent (PE2) | 12 | 12 |
| 1 GiB swap on an attached volume (PE2) | 13 | 13 |
| Persistent journal (PE2) | 14 | 14 |
| Whole-disk PV, VG with PE size, thin pool, thin LV, XFS mount (PE3) | 15 | 15 |
| LV swap of exact extents from the remaining space (PE3) | 16 | 16 |
| httpd at boot, index page, firewall, curl from the other node (PE3) | 17 | 17 |
| User on both nodes, key-based SSH from node2 (PE3) | 18 | 18 |
| SSH hardening: password and keyboard-interactive off, one user allowed (PE3) | 19 | 19 |
| autofs for two NFS shares by IP, not fstab (PE3) | 20 | 20 |

The two swap tasks are kept apart because they build swap differently: a disk or partition
versus an LV sized in extents.

## Grading

Reboot both nodes, edit `NODE1_IP`, `NODE2_IP` and the disk names at the top of the grader, then
run it as root on each node. The grader is read-only.

Graders are built from `helpers.sh` and each mock's `checks.sh`. Rebuild them with
`bash exams/ph2026b2/build.sh` after editing either file.

Both graders pass `bash -n` but **have not yet been run on a live lab**. On the first sitting,
run each grader on the untouched snapshot (every task should FAIL) before trusting its scores.
