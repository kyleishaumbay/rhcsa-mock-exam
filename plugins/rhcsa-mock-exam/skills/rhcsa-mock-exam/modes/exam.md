# Mode A — generate a mock exam

## Output

Three files (`<v>` is `9` by default, `10` if switched):

- `RHCSA<v>_Mock_Exam_<n>.docx` — the paper. No answers anywhere in it.
- `RHCSA<v>_Mock_Exam_<n>_Key.docx` — the answer key, a separate file so
  the exam can be sat honestly.
- `rhcsa<v>-mock-<n>-grade.sh` — the grader (written per `modes/grade.md`).

## The paper

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

## Coverage

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

## Rules

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

## The key

Per task: the node, the commands, the verification command the grader runs
and its expected output, then equivalent solutions that are equally correct.
Where a task has a common wrong-but-looks-right answer — `chcon` instead of
`semanage fcontext`, `start` instead of `enable`, `--permanent` without
`--reload`, `/sysroot` under `init=/bin/bash`, a container unit generated
without linger or before the final `podman run` options — name it and say why it fails after reboot. Open with the
dependency map.

# Build

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
