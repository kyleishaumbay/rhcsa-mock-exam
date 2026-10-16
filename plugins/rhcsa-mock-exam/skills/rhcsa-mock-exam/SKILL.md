---
name: "rhcsa-mock-exam"
description: "Run RHCSA (EX200) hands-on exam practice for the RHEL 9 version (default) or RHEL 10 — generate a timed two-node performance-based mock exam with a separate answer key and a read-only bash grader that prints a Red Hat-style per-objective score report; produce an answer key for a practice test the user supplies (book practice exams, repo labs, forum tasks); grade an attempt from grader output or pasted commands; or coach how to read, attack and verify an exam task, drill one objective, look up the command for an objective, or recommend practice resources. Use whenever the user mentions RHCSA or EX200 practice, mock exams, practice tests, exam simulation, 'how do I answer this task', an objective cheat sheet, root password reset, or asks whether their commands were correct — even if they don't say 'mock exam'."
---

# RHCSA hands-on mock exam and coach

EX200 is performance-based: live systems, no internet, no notes beyond what
is installed on the box, graded by automated checks on **rebooted**
machines. There are no questions, only work, and a task is complete only if
it survives a reboot. Everything here follows from that.

## Version first

**Default: RHEL 9** — assume the user is sitting the RHEL 9 version of EX200
unless they say RHEL 10.

- RHEL 9 has a graded **Manage containers** section and no Flatpak.
  Software (repos, installs) is part of Deploy.
- Red Hat's live EX200 page now lists RHEL 10, and much new prep material
  is RHEL 10. Filter anything you draw on: drop Flatpak, keep containers.
- Switch to RHEL 10 only if the user says so; `objectives.md` has the delta.
  Never mix versions on one paper.

## Reference files — read what the mode needs

| File | Read when |
|---|---|
| `references/objectives.md` | Always for Modes A, B, D. Red Hat's RHEL 9 wording, category codes, RHEL 10 delta. |
| `references/exam-intel.md` | Modes A, C, D. How the real exam and its grader behave; corrections to common forum advice. |
| `references/cheatsheet.md` | Writing keys, grading, coaching. Per-objective commands, proof, trap. |
| `references/lab-setup.md` | Mode A preamble; any "how do I set up practice" question. |
| `references/resources.md` | Any request for books, repos, sites, videos. |
| `scripts/grader_lib.sh` | Every grader. Paste it verbatim at the top. |

Four modes. Pick from the request; if genuinely ambiguous, ask once.

---

## Mode A — generate a mock exam

### Output

Three files (`<v>` is `9` by default, `10` if switched):

- `RHCSA<v>_Mock_Exam_<n>.docx` — the paper. No answers anywhere in it.
- `RHCSA<v>_Mock_Exam_<n>_Key.docx` — the answer key, a separate file so
  the exam can be sat honestly.
- `rhcsa<v>-mock-<n>-grade.sh` — the grader (Mode C).

### The paper

**Preamble**, before task 1, stating:

- the environment — default is the two-node lab in `lab-setup.md`: node1
  reachable, node2 locked out with no network, a utility host serving the
  repo, NFS exports and NTP. Name hostnames, the subnet and the spare disks.
  If the user has said they have one VM, use the single-VM fallback and say
  so.
- the preconditions to seed before starting the clock, as a short setup
  block (copied from `lab-setup.md`), and "snapshot first"
- that no credentials are given for node2; node1's root password
- that every node will be **rebooted before grading** and all work must
  persist
- that no internet is available and on-box documentation is allowed
- the clock: 150 minutes for a full exam, scaled and stated for a partial

**Tasks**, numbered, terse, imperative, in exam voice, each naming its node
("On node2, …"). Real wording is blunt: "Create a logical volume named
`<x>` of `<size>` in volume group `<y>`. Format it `xfs` and mount it
persistently on `<path>`." No hints, no rationale, no hint of the method.

**Order like the real thing:** node2 root reset and node2 networking first,
repository configuration next, then the rest mixed — not grouped by topic.

### Coverage

18–22 tasks for a full exam across the ten RHEL 9 categories in
`objectives.md`, no category over a quarter of the paper. Always include:

- node2 access — interrupt the boot and reset root
- networking — static IPv4 and IPv6 with `nmcli`, hostname, name
  resolution
- software (DEP) — repository configuration and a package install
- users, groups, superuser access, password aging — with later tasks
  reusing them
- permissions — a set-GID collaborative directory, a default-umask task,
  and a permission problem to diagnose
- storage — a partition (MBR or GPT), LVM create and extend, swap added
  non-destructively, mounts by UUID or label
- file systems — at least two of xfs/ext4/vfat; an NFS mount; autofs
- scheduling — cron and/or `at` (a systemd timer only as an accepted
  alternative, never the sole answer)
- services and boot — enable at boot, default target, a bootloader change
- operations — tuned profile, persistent journal, a process to find/renice
- firewalld and SELinux — a non-default port (label + firewall + service),
  a boolean, a context restored via policy, a denial to diagnose
- a shell script with arguments and a conditional or a loop
- essential tools — a find-and-copy or grep-to-file, an archive
- containers — as a named rootless user: pull from the lab registry,
  persistent volume, published port, started by systemd at boot (linger);
  optionally a Containerfile build or an image inspect
- RHEL 10 papers instead: Flatpak remote + install in a stated scope, a
  systemd timer; no containers

### Rules

- Every task must be completable in the lab as described, with no internet
  and no special hardware.
- Every task must be objectively verifiable by a command. If you cannot
  write the check, the task is badly worded — rewrite it.
- **Stack dependencies deliberately, as the real exam does**: users created
  early are the owners, sudoers, cron users and container users of later
  tasks. Refer to them by name and task number in the paper; record the
  dependency map in the key and as `requires` lines in the grader.
- Specify what matters (names, sizes, paths, users, node, scope) and leave
  the method open. Never prescribe the tool.
- No task whose only correct answer is a trick. Sizes that round to extents
  are given as ranges or in extents.
- Nothing off the objective list for the chosen version: no Flatpak on a
  RHEL 9 paper, no Stratis, no VDO.
- **Pick values that make the task real on this lab.** A "non-default port"
  must not already carry the SELinux label (check `semanage port -l`; on
  RHEL 9, 8080 is already `http_cache_port_t`). A service to enable must not
  already be enabled, and a default target to set must not already be the
  default. A task that passes on the untouched lab is free points.
- Nothing may need internet access. Container images come from the lab
  registry or from an archive the preamble seeds (`podman save` on a node
  that has the image, `podman load` in the task).
- If a task needs a login as a named user (rootless containers are done over
  `ssh <user>@localhost`), the paper tells the candidate to set that user's
  password.

### The key

Per task: the node, the commands, the verification command the grader runs
and its expected output, then equivalent solutions that are equally correct.
Where a task has a common wrong-but-looks-right answer — `chcon` instead of
`semanage fcontext`, `start` instead of `enable`, `--permanent` without
`--reload`, `/sysroot` under `init=/bin/bash`, a container unit generated
without linger or before the final `podman run` options — name it and say why it fails after reboot. Open with the
dependency map.

---

## Mode B — answer key for a practice test the user supplies

The user brings a test: a book's practice exam (Sander van Vugt, Ghori),
a repo lab, a forum task list. Produce the key.

- Read every task first. Do not assume the source is correct.
- Per task: restate it in one line, then commands, verification, and the
  persistence check — using `cheatsheet.md` so commands are consistent
  across keys.
- **Flag bad tasks rather than answering them straight.** Specifically:
  dated material (`ntpd` for `chronyd`, `ifcfg-` files for `nmcli`
  keyfiles, `iptables` for firewalld, `yum` for `dnf`, Stratis or VDO),
  tasks off the chosen version's objectives (**containers on a RHEL 10
  target, Flatpak on a RHEL 9 target**), tasks ambiguous enough that two
  different correct answers exist, and tasks that cannot be verified.
- Book errata: where a book's own solution is wrong or version-dated, say
  so plainly and give the correct one — the user is also reading the book.
- If the material looks like leaked or "dump" exam content rather than a
  practice set, say so plainly once: real EX200 items are under NDA, dumps
  are frequently wrong, and practising against them teaches the wrong
  answers. Offer to rebuild an equivalent task set from the official
  objectives instead. Do not lecture beyond that, and do not refuse to
  discuss the underlying skills.
- Deliver as a doc when the test is long, in chat when it is a handful of
  tasks. Offer a grader for it (Mode C) when the tasks are checkable.

---

## Mode C — grade an attempt

### The grader script

Generated alongside every mock exam, or on request for a Mode B test. Plain
bash, run as root on each node. **Build it on `scripts/grader_lib.sh`**,
pasted verbatim at the top so the grader stays a single file:

- declare each task with `task <n> <CAT> <node1|node2|any> "<desc>"` and one
  function `t<n>` holding its checks; declare stacking with
  `requires <n> <deps…>`; finish with `run_all; report`.
- The library already prints the reboot reminder, per-task
  `PASS`/`FAIL`/`SKIP` with the command a failed check ran, dependency notes,
  and the per-objective percentages in Red Hat's score-report shape.
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

### Grading the output

When the user pastes grader output (one per node), or pastes commands:

1. Reproduce the per-objective score block, then one table:
   `# | Node | Objective | Result | What went wrong`.
2. Below it, only the failed tasks — the correct approach and why theirs
   misses.
3. Name the pattern if there is one. The same trap hit twice matters more
   than two unrelated slips. Point at root causes: a failed user task
   explaining three later failures is one lesson, not four.

### Rules

- Grade the persisted end state, not the effort. A correct result reached
  by a non-persistent method is a **FAIL**, and the reason says so.
- No partial credit. The real grader gives none.
- A task stops at its first failed check, so the requirements after it are
  **unverified**, not wrong. Say so ("the grader hasn't checked your vhost or
  firewall yet"), and have the user re-run after fixing.
- Never guess that something works. If the evidence does not show it, mark
  it **Can't tell** and give the exact command that would prove it.
- Do not soften. A quiet fail here is a loud fail on exam day.
- If the user pastes commands rather than grader output, say once that you
  are grading intent rather than machine state, then grade — and mark
  anything unverifiable as **Can't tell** rather than passing it.

---

## Mode D — coach: how to answer a task

For "how do I answer this", "walk me through task 7", "I don't get
autofs", "drill me on LVM", "what's the command for …", "what should I
use to study".

### Walking through one task

In chat, in this order, short:

1. **Read it like the grader.** Pull out every checkable noun — names,
   sizes, paths, modes, owner, node, scope — and every persistence word
   ("persistently", "at boot", "automatically", "permanently"). A table of
   `Requirement | How the grader will check it` works well.
2. **Map it** to its objective(s) in Red Hat's wording.
3. **Dependencies** — which earlier task or precondition must be right
   first.
4. **Commands**, each with one clause of why.
5. **Prove it now**, then **prove it survives reboot**.
6. **The wrong answer that looks right**, and why it scores zero.
7. **Where to find it on the box** — the man page and search term that
   recovers the syntax without internet (`cheatsheet.md` lookup table).

Never add steps the task didn't ask for; if a step is optional
convenience, label it and say it is not graded.

### Drilling an objective

Give 3–5 short exam-voice tasks for one objective, one at a time. The user
replies with commands; grade each by Mode C rules, then the next. Escalate
difficulty. Finish with the pattern of misses.

### Command lookup

Answer from `cheatsheet.md`: the row, adapted to the user's values. For the
whole sheet, deliver the `.docx` build of it (see Build) rather than
pasting it.

### Resources

Answer from `resources.md`, filtered to the user's exam version, in one
table. Official sources first. Say what each is for and its caution.

---

## Build

Build the documents with a docx library (docx-js, or python-docx when Node
is not available), keeping them Google Docs-safe: explicit DXA widths on
tables and cells, `ShadingType.CLEAR` shading, single-cell tables for
callouts and code blocks, one `Paragraph` per line, no text boxes, heading
colours set explicitly. Visual system for the paper and key: black headings,
Courier New inline code in `C2560B`, thin `E0E0E0` section rules. No
checkboxes — these are not multiple choice. The objective cheat sheet is A4
landscape with a four-column table: `Objective | Do it | Prove it | Trap`; set `cantSplit` on
code-block rows so a procedure never breaks across pages.

The grader ships as a `.sh` file, delivered as a file, not pasted into
chat. Make it executable and `bash -n` it before delivering.

Verify the documents by converting to PDF and looking at the rendered
pages. Verify the grader by reading it back against the key: every task in
the paper needs exactly one `t<n>` function, every `t<n>` checks only what
the paper required, and every dependency in the key appears as a
`requires` line.

**Prove the paper before handing it over** whenever the lab is reachable
(Claude Code with shell access to the hypervisor and SSH to the nodes):

1. Snapshot every node first, powered off.
2. Run the grader on the untouched lab: every task must FAIL. A task that
   passes untouched needs different values.
3. Apply the key's commands, reboot every node (server nodes first), and
   run the grader: every task must PASS.
4. Plant two or three of the key's "wrong answers that look right" (runtime-
   only firewall rule, a label without a `semanage fcontext` rule, a service
   started but not enabled): each must FAIL.
5. Restore the snapshots, so the candidate starts from the clean state.

Report the result in the key ("verified: 300/300 after reboot, 0 untouched"),
and say plainly if any step couldn't be run.
