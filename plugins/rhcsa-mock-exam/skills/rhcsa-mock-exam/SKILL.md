---
name: "rhcsa-mock-exam"
description: "Run RHCSA (EX200) hands-on exam practice for RHEL 9: generate a timed two-node mock exam with a separate answer key and a read-only bash grader that prints a Red Hat-style per-objective score; write an answer key for a practice test the user supplies (book exams, repo labs, forum tasks); grade an attempt from grader output or pasted commands; coach how to read, attack and verify a task, drill one objective or look up a command; and, in Claude Code on the VM host, prepare VirtualBox or KVM lab VMs and grade them directly. Use whenever the user mentions RHCSA or EX200 practice, mock exams, practice tests, exam simulation, 'how do I answer this task', an objective cheat sheet, root password reset, or asks whether their commands were correct — even if they don't say 'mock exam'."
---

# RHCSA hands-on mock exam and coach

EX200 is performance-based: live systems, no internet, no notes beyond what
is installed on the box, graded by automated checks on **rebooted**
machines. There are no questions, only work, and a task is complete only if
it survives a reboot. Everything here follows from that.

## RHEL 9 only

This skill covers the **RHEL 9 version of EX200** and nothing else.

- RHEL 9 has a graded **Manage containers** section. Software (repos,
  installs) is part of Deploy.
- Build every task, key and check from the RHEL 9 objectives in
  `references/objectives.md`, and draw only on RHEL 9 material.

## Pick the mode, then read only its file

| Mode | The user wants | Read |
|---|---|---|
| A — mock exam | a paper, answer key and grader | `modes/exam.md`, `modes/grade.md` (grader section), `references/objectives.md`, `references/exam-intel.md`, `references/lab-setup.md`; `references/cheatsheet.md` for the key |
| B — key for their test | answers for tasks they bring | `modes/key.md`, `references/cheatsheet.md`, `references/objectives.md` |
| C — grade an attempt | grader output or commands judged | `modes/grade.md`, `references/cheatsheet.md` |
| D — coach | how to attack a task, drill an objective, a command, study resources | `modes/coach.md`; `references/cheatsheet.md` or `references/resources.md` |
| E — prepare the lab | VMs found, checked, seeded and snapshotted; grading run for them | `modes/lab.md` (Claude Code on the VM host only) |

Pick from the request; if it is genuinely ambiguous, ask once. **Do only
what was asked:** one request, one result. Don't chain modes, offer
follow-up work, or keep state between requests.

## Rules for every mode

- Persisted state is all that counts: a result that doesn't survive a
  reboot is a fail, and is taught as one.
- Graders are **read-only**, check the outcome rather than the method, and
  are built with `scripts/build_grader.sh` from a checks file. The library
  (`scripts/grader_lib.sh`) is never retyped.
- Never guess that something works. Unproven is **Can't tell**, with the
  command that would prove it.
- Nothing off the RHEL 9 objectives; no Stratis or VDO. No exam
  dumps: real items are under NDA (see `modes/key.md`).
- Keep it light: read only the files the mode needs, deliver documents and
  graders as files rather than pasting them, and keep chat answers short.
  `references/cheatsheet.md` is large (~9k tokens). Look up the sections you
  need by their `### <objective>` headings (e.g. `grep -n -A22 '### Configure
  autofs'`), and read it whole only to build the full cheat sheet.

## Files

| File | Holds |
|---|---|
| `references/objectives.md` | Red Hat's RHEL 9 objective wording, grader category codes |
| `references/exam-intel.md` | How the real exam and its grader behave; common forum advice corrected |
| `references/cheatsheet.md` | Per objective (one `###` section each): do it, prove it, the trap. Look up sections; don't read it whole |
| `references/lab-setup.md` | A practice lab that behaves like the exam; preconditions to seed |
| `references/resources.md` | Books, repos, sites and videos, with cautions |
| `scripts/grader_lib.sh` | Grader runtime: checks, `need`/`must`, `--all` across nodes, score report |
| `scripts/build_grader.sh` | `build_grader.sh <checks.sh> <grader.sh>`: prepends the library and syntax-checks |
