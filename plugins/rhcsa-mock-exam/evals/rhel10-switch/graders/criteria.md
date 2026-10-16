---
type: llm
weight: 1
---

The task list fits the RHEL 10 EX200:

1. It contains NO container (podman/skopeo) tasks: Manage containers is not on RHEL 10.
2. It contains Flatpak tasks (a remote added and an app installed in a stated scope).
3. It includes a systemd timer task, and partition tasks use GPT only (no MBR-only task).
4. It still covers the core areas: node2 root password reset, networking, a repository, users/groups/sudo, storage (LVM and swap), file systems (NFS and autofs), SELinux and firewalld, and a shell script.
5. It has roughly 18-22 tasks and names a node for each.

Score 1 only if all five hold.
