# How the real exam behaves — field reports, distilled

Compiled from public candidate reports (Reddit threads, 2025–26),
Red Hat Learning Community threads, and community prep repos. Items are NDA-
safe: they describe format and failure modes, never exam content. Where a
report is wrong or incomplete, the correction is given. Use this to make mock
exams behave like the real one and to coach.

## Format

- Performance-based, live systems, no internet, no notes. Man pages and
  /usr/share/doc on the box are allowed.
- **Two systems** is the norm in reports ("configure the correct server
  according to the question, server 1 or 2"). Tasks name the node.
- Time: Red Hat's public page does not state it; candidates report 2.5–3
  hours for roughly 20 items. Mock default stays 150 minutes.
- Pass mark 210/300 (widely reported; Red Hat doesn't publish it on the page).
  There is one free retake on a first-attempt individual purchase, per
  third-party summaries of Red Hat's terms.

## The score report

Candidates receive a per-objective percentage, not per-task results. One
real report, shared publicly by a passing candidate. Its "Manage software"
line shows it was a RHEL 10 sitting; a **RHEL 9 report has no Manage
software line and adds "Manage containers"** — the grader prints whichever
categories the paper used:

    Passing score: 210    Your score: 237    Result: PASS
    Understand and use essential tools: 82%
    Manage software: 100%
    Create simple shell scripts: 100%
    Operate running systems: 100%
    Configure local storage: 75%
    Create and configure file systems: 67%
    Deploy, configure and maintain systems: 67%
    Manage basic networking: 100%
    Manage users and groups: 100%
    Manage security: 100%

The grader library reproduces this shape so mock results read like the real
thing. When grading (Mode C), always show this breakdown.

## How grading fails people

1. **Reboot first, then check.** Reports agree the systems are rebooted and
   scripts then validate the configuration. Anything runtime-only scores 0.
2. **Tasks stack.** A missing user or group breaks later permission, sudo,
   script, cron and container checks — "missing the users/groups section
   would block security, container and shell-script tests." One report put
   it bluntly: users-and-groups must be 100%. Mock exams must reproduce this
   stacking, and the grader must point at the root cause (`requires`).
3. **Precision.** "Only do what's asked." Extra configuration can break a
   check the task never mentioned. Coaching must call out every "extra".
4. **Wrong node.** Doing a correct task on the other system is a zero.
5. **Network changes that don't survive reboot** take the whole node's
   remote checks with them. "Reboot your VMs, especially after network
   tasks."
6. **Enable the service** after installing the package ("always remember to
   enable it, else your whole setup would fail") — autofs, chronyd, atd,
   tuned, httpd, firewalld.

## Root password reset — what the reports actually show

Forum posts commonly make three claims. Reconciled for RHEL 9:

- "init=/bin/bash, then `mount -o rw,remount /sysroot`" — **cannot work as
  written.** Under init=/bin/bash the real root is mounted at `/`; `/sysroot`
  only exists in the rd.break (initramfs) environment.
- "rd.break enforcing=0 did not work in my exam" — consistent with a Red Hat
  Learning Community thread on RHEL 9 labs (2024): rd.break stopped short
  until the `console=` arguments were deleted from the kernel line; others
  in the thread got in with `init=/bin/sh`. One exam-taker's report there
  says rd.break dropped them to an emergency-mode password prompt.
- "rd.break does not work in v10" — a RHEL 10 thread (Jan 2026) reports the
  rd.break shell missing `chroot`. Irrelevant on RHEL 9, but it explains the
  forum noise.
- Teach for RHEL 9: **rd.break primary, after deleting console=/rhgb/quiet;
  init=/bin/bash as a rehearsed fallback.** Always `touch /.autorelabel`.

## Containers on RHEL 9 — what candidates say

- "Focus on full workflows: volume mounts, ports, persistence, autostart.
  You should be able to do it all fast and clean."
- The failure pattern is persistence: no linger, the unit generated before
  the final `podman run` options (so the volume or port is missing), the
  original container left running so the `--new` unit clashes on its name,
  or the work done via `su` so `systemctl --user` never worked.

## Strategy reports agree on

- Read every task first; note node and dependencies.
- Easy tasks first, hard last. Time-box at ~2x the average per task.
- Storage early: a partition mistake late in the exam can't be redone in
  time.
- Add both nodes to /etc/hosts so ssh by name is fast.
- Know man-page navigation cold (`/pattern`, `n`, `G`); it replaces Google.
- `fdisk` is faster than `parted` for most people. Either is correct; `g`
  in fdisk destroys an existing table.
- Know fstab format well enough to write it without looking; validate with
  `findmnt --verify` before any reboot.
- "Know cron and systemd timers", "password expiry", "find", "grep to a
  file", "dnf config-manager to add a repo" (Flatpak tips in the same threads
  are RHEL 10 only) — all recur.

## Claims to correct when they come up

| Claim | Reality |
|---|---|
| For autofs, add firewall services nfs, mountd, rpc-bind | Those open an NFS **server**. RHCSA is the client side; the client needs no inbound rule. Only do it if a task makes the node a server. |
| Enable root password SSH login so you can jump between nodes | Allowed but it is unrequested config. Prefer ssh as a normal user + sudo, or the console. Never do it if any task sets an sshd policy. |
| Containers are gone from RHCSA | Only from the RHEL 10 version. On RHEL 9 they are a full graded section. |
| rd.break doesn't work | On RHEL 9 it does once console= args are removed; keep init=/bin/bash as the fallback. |
| `setenforce 0` to get a service working | Graded state is enforcing unless told otherwise; fix the label, port or boolean. |
| Dumps "match the real exam" | NDA-covered items; dumps are frequently wrong. Never use them. |

## Practice-lab behaviour worth copying

- RHLS `lab grade` scripts are reported as the closest thing to the real
  grader. Our grader imitates that style: outcome checks, persisted state.
- Community exam repos seed deliberate preconditions before the clock starts:
  unknown root password on one node, a disk left over, wrong default target,
  no network on node2. Mock exams should do the same (see lab-setup.md).
