# Mode C — grade an attempt

## The grader script

Generated alongside every mock exam, or on request for a Mode B test. Plain
bash, run as root. It ships as one file: `scripts/grader_lib.sh` followed by
the paper's checks.

- **Write only the checks file**, then build: `bash scripts/build_grader.sh
  <checks.sh> rhcsa<v>-mock-<n>-grade.sh` (prepends the library, makes it
  executable, runs `bash -n`). Never retype the library; that costs tokens
  and invites drift. Only when no shell is available, paste the library
  above the checks.
- Checks file shape: `PAPER="…"`; optional `hosts node2=root@<host>`; per
  task `task <n> <CAT> <node1|node2|any> "<desc>"`, a function `t<n>`, and
  `requires <n> <deps…>` for stacking; end with `run_all; report`.
- Inside `t<n>`, put **`need`** before every requirement so one run reports
  every failure in the task. Use **`must … || return`** only for a gate whose
  failure makes the rest noise (VG missing, so don't check its LVs). Custom
  helpers report with `_rec "<cmd>" "<why>"` and return 1.
- Tell the candidate to grade from node1 with **`bash <grader> --all`**. It
  runs itself on the other nodes over root ssh and prints one combined report,
  with cross-node `requires` notes. Without root ssh between nodes, they run
  it on each node instead.
- The library prints the reboot reminder, every failed check with the command
  it ran, gate and dependency notes, the per-objective percentages in Red
  Hat's score-report shape, and a final `SUMMARY|…` line for progress
  tracking (`modes/progress.md`).
- **Read-only. Always.** No `rm`, no writes, no config changes, no service
  restarts, no mounts. It observes and reports. A grader that repairs the
  system destroys the evidence.
- **Check the outcome, not the method.** Accept any solution that produces
  the required end state — `UUID=` or `LABEL=` in fstab, any volume group
  name the task did not specify, a systemd unit or a Quadlet file, a repo
  file with any name. A grader that hardcodes one path marks correct work
  wrong, which is worse than not grading it.
- Check **persisted** state, not just running state. Use the library's
  pairs: `svc_persisted`, `mount_persisted`, `fw_persisted`. SELinux
  contexts need `semanage fcontext -l` as well as `ls -Z`; booleans need
  `semanage boolean -l -C`; (RHEL 10) Flatpak installs are checked in the
  scope the task named; rootless container checks run as that user
  (`runuser -l <user> -c 'XDG_RUNTIME_DIR=/run/user/<uid> systemctl --user is-active <unit>'`)
  and also check `loginctl show-user <user> -p Linger`.
- **Read the loaded configuration, not one file.** Use `automount -m`
  (the library's `autofs_entry`), `exportfs -s`, `httpd -t -D DUMP_RUN_CFG`,
  `systemctl show <unit> -p <Prop>`, so every file layout the candidate
  chose is graded the same.
- **Checks that are easy to make too strict:**
  - autofs: when the task only says "accessing /X/Y mounts …", accept a
    direct map (`/-` with key `/X/Y`) as well as an indirect one. Demand an
    indirect map only when the wording says "/X is an automount directory"
    or needs a wildcard.
  - journal persistence: use the library's `journal_persisted`, which checks
    `/var/log/journal/<machine-id>/system.journal`. Never require a boot
    count; it fails a correct setup that wasn't flushed before the grading
    reboot.
- **Cross-node dependencies** don't appear in `requires` notes, because the
  other node's results aren't known. When a check on one node needs a task
  on the other (curl to node2's web server, an NFS mount from node2), say so
  in its failure message: "if node2 task N failed, fix that first".

## Grading the output

When the user pastes grader output (one combined `--all` report, or one per
node), or pastes commands:

1. Reproduce the per-objective score block, then one table:
   `# | Node | Objective | Result | What went wrong`.
2. Below it, only the failed tasks — the correct approach and why theirs
   misses.
3. Name the pattern if there is one. The same trap hit twice matters more
   than two unrelated slips. Point at root causes: a failed user task
   explaining three later failures is one lesson, not four.
4. If the user only attempted some tasks, ask which (once), and leave the
   unattempted ones out of the table and the lessons.
5. End with two one-line offers: a retry pack for the misses
   (`modes/drill.md`), and recording the attempt (`modes/progress.md`). In
   Claude Code, record it without asking if a progress file already exists.

## Rules

- Grade the persisted end state, not the effort. A correct result reached
  by a non-persistent method is a **FAIL**, and the reason says so.
- No partial credit. The real grader gives none.
- Requirements after a `(checks after this one did not run)` line are
  **unverified**, not wrong. That line marks a gate, or an older grader that
  stops at the first failure. Say so ("the grader hasn't checked your vhost or
  firewall yet"), and have the user re-run after fixing.
- Never guess that something works. If the evidence does not show it, mark
  it **Can't tell** and give the exact command that would prove it.
- Do not soften. A quiet fail here is a loud fail on exam day.
- If the user pastes commands rather than grader output, say once that you
  are grading intent rather than machine state, then grade — and mark
  anything unverifiable as **Can't tell** rather than passing it.
