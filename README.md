# RHCSA Mock Exam — a Claude skill

Hands-on practice for the **Red Hat Certified System Administrator (EX200)** exam, run by Claude.
EX200 has no questions, only work on live systems, graded by scripts after a reboot. This skill
practises it that way.

**RHEL 9 by default.** Ask for RHEL 10 and it switches syllabus: no containers, Flatpak added.

## What it does

| Mode | Ask something like | You get |
|---|---|---|
| **Mock exam** | "Make me a full RHCSA mock exam" · "a practice exam on LVM, NFS and Apache" | The paper (`.docx`, no answers), a separate answer key (`.docx`), and a grader script (`.sh`) |
| **Answer key for your test** | "Here are the practice tasks from my book — write the key" | Commands, proof and persistence checks per task. Outdated or off-syllabus tasks are flagged. |
| **Grading** | Paste the grader output, or your commands | A Red Hat-style per-objective score, a table of what failed and why, and the root cause behind repeated misses |
| **Retry pack** | "Give me more practice on what I got wrong" | 4–8 new tasks aimed at your misses and the traps behind them, with new values each time, plus a mini grader |
| **Progress** | "How am I doing?" · "Am I ready?" | Your attempts over time, per-objective trends, weakest areas, and what to do next |
| **Coaching** | "How do I attack task 7?" · "Drill me on autofs" · "Command for SELinux port labels?" | Step-by-step reasoning, drills graded one at a time, cheat-sheet lookups, study resources |
| **Prepare the lab** (Claude Code on the VM host) | "Get my VMs ready for the exam" · "Grade my VMs for me" | VirtualBox/KVM VMs found, checked, seeded and snapshotted, so you just start the exam. Afterwards, it grades them directly. |

**The grader** is plain bash, run as root after rebooting every node. It is **read-only**: it never
changes, mounts or restarts anything. It checks persisted state, accepts any correct method, and lists
**every** failed check in a task. Run it once from node1 with `--all` to grade all nodes over ssh in a
single report:

```
FAIL FS    #14  node1  autofs wildcard: /home/users/<user> from node2:/srv/nfs/users/<user>
           - why:   no wildcard '*' key mounting node2:/srv/nfs/users/& (got: '* | -rw node2:/srv/nfs/users&')
             check: automount -m   (map for /home/users)
           note:  depends on #4 (node1), which also failed — fix that first

Performance on exam objectives (all nodes):
  Configure local storage:                      100%
  Create and configure file systems:             75%
  ...
Score (all nodes, equal weights): 237 / 300   pass mark 210
```

**Lightweight.** About 340 tokens are always loaded (the skill's description). Each use loads a
~1.1k-token router plus only the files that mode needs: about 0.4–1.8k tokens per mode, with the
big cheat sheet looked up by section. Graders are assembled by a build script, so Claude never
retypes the grader library.

## Install

### Claude Code

```
/plugin marketplace add kyleishaumbay/rhcsa-mock-exam
/plugin install rhcsa-mock-exam@rhcsa-mock-exam
```

Or from a local clone: `/plugin marketplace add /path/to/rhcsa-mock-exam`.

### Claude.ai (web / desktop)

1. Download `rhcsa-mock-exam.zip` from the Releases page, or build it: `./tools/package-skill.sh`
   (needs only `python3`; writes `dist/rhcsa-mock-exam.zip`).
2. Claude.ai → **Settings → Capabilities → Skills → Upload skill** → choose the zip.

Then just talk about RHCSA practice. The skill triggers on its own.

## What you need for the exam itself

A practice lab of RHEL 9 VMs you can snapshot and revert. A **two-node** lab is the default: node1 to
work on and node2 as the second exam system, plus optionally a utility host serving the repo, NFS
and a container registry. A single VM works too, and the paper will say so. Full setup, including an
offline repo and container registry and the preconditions to seed before the clock starts, is in
[`references/lab-setup.md`](plugins/rhcsa-mock-exam/skills/rhcsa-mock-exam/references/lab-setup.md).

Use the RHEL 9 DVD ISO (free with a Red Hat Developer subscription), not the boot ISO. Rocky or Alma
work for most drills, but sit your final mocks on RHEL.

Tell Claude your lab (hostnames, IPs, spare disks, package source) when you ask for an exam, and the
tasks and grader are written to match it.

Want to see the output first? [`examples/mock-exam-1`](examples/mock-exam-1) is a complete 21-task
paper with its key and grader. It scored 0/300 on an untouched two-node lab, and 300/300 after the
key was applied and both nodes rebooted.

## Repository layout

```
.claude-plugin/marketplace.json          Claude Code marketplace (this repo)
plugins/rhcsa-mock-exam/
  .claude-plugin/plugin.json             plugin manifest
  skills/rhcsa-mock-exam/
    SKILL.md                             router: picks the mode, shared rules (~1.1k tokens)
    modes/*.md                           one file per mode, loaded only when that mode runs
    references/objectives.md             EX200 objectives (RHEL 9, RHEL 10 delta), grader categories
    references/exam-intel.md             how the real exam and grader behave; common forum myths corrected
    references/cheatsheet.md             per-objective: do it / prove it / trap
    references/lab-setup.md              practice lab that behaves like the exam
    references/resources.md              books, repos and courses, with cautions
    scripts/grader_lib.sh                grader runtime: need/must checks, --all across nodes, score report
    scripts/build_grader.sh              builds a grader from a paper's checks file + the runtime
examples/mock-exam-1/                    a full, lab-verified paper + key + grader (and how it was built)
tools/package-skill.sh                   builds the claude.ai upload zip
```

## Ground rules

- **No exam dumps.** Real EX200 items are under NDA and dumps are often wrong. The skill writes its
  own tasks from Red Hat's published objectives, and says so if you paste something that looks like
  a dump.
- **Graded like the real thing:** after a reboot, with no partial credit, and only what persists counts.
- Not affiliated with or endorsed by Red Hat. RHCSA, RHEL and Red Hat are trademarks of Red Hat, Inc.

## License

No license is granted: all rights reserved. You may view and fork this repository on GitHub, but
reusing or redistributing its contents needs the author's permission.
