# Example: RHCSA 9 Mock Exam 1

A complete paper produced with this skill: **21 tasks, two nodes, 150 minutes**, focused on
LVM, NFS, AutoFS, Apache, Firewalld and Systemd (plus one rootless-container task).

| File | What it is |
|---|---|
| `RHCSA9_Mock_Exam_1.docx` | The paper. Sit it without opening the key. |
| `RHCSA9_Mock_Exam_1_Key.docx` | The key: dependency map, then per task the solution, proof, other correct answers and wrong answers that look right |
| `rhcsa9-mock-1-grade.sh` | Read-only grader. Run it as root on **each** node after rebooting both. |
| `source/` | How it was built: `exam_content.py` (single source for the paper and key), `build_docs.py`, `grader_tasks.sh`, and `solve_node1.sh` / `solve_node2.sh`, the key as scripts, used to validate the grader |

## Lab it assumes

- **node1** `node1.example.com` 192.168.100.10, **node2** `node2.example.com` 192.168.100.11, RHEL 9 (built on 9.0),
  each with three empty 5 GiB disks `/dev/sdb`, `/dev/sdc`, `/dev/sdd`.
- node1 has a working package repo (the RHEL 9 DVD is enough) and the image
  `registry.access.redhat.com/ubi9/ubi-minimal` already pulled.
- node2 already has `nfs-utils`, `httpd`, `autofs` and `firewalld`. It needs no repo.
- root on node1 can `ssh node2` with a key. SELinux enforcing, firewalld running.

Different hostnames, IPs or disks? Ask Claude to adapt the paper to your lab, or edit
`source/exam_content.py` and `source/grader_tasks.sh`, then run `source/build.sh`
(needs `pip install python-docx`).

## How it was verified

On a VirtualBox two-node lab: the grader scored **0/300 on the untouched nodes**, with no free passes.
The key's solution (`solve_node*.sh`) was then applied, both nodes were rebooted, and the grader scored
**300/300 on each node**. Three planted wrong answers were each failed: ftp allowed only until the
next reboot, a `/webfiles` label not written to policy, and autofs started but not enabled.

## Grading

Reboot node2, then node1. Then, as root on node1:

```
bash rhcsa9-mock-1-grade.sh --all      # grades node1, then node2 over ssh: one combined report
```

No root ssh from node1 to node2? Copy the grader to each node and run it there without `--all`.

Paste the output (or both outputs, if you ran it per node) to Claude with this skill installed for a task-by-task explanation.
