# Changelog

## 1.1.0 — 2026-10-16

- **Grader reports every failure in a task.** Checks are written with `need`, and `must … || return`
  gates checks that only make sense after an earlier one. Graders in the old `&&` style still work.
- **One combined report across nodes:** run `bash <grader> --all` on node1, and it grades the other
  nodes over root ssh. Dependency notes work across nodes, and unreachable nodes are reported.
- **`SUMMARY|…` line** at the end of every report, used for progress tracking.
- **`scripts/build_grader.sh`** builds a grader from a checks file, so the library is never retyped.
- **New modes:** a retry pack for missed tasks (`modes/drill.md`), progress tracking across attempts
  (`modes/progress.md`), and preparing VirtualBox/KVM VMs from Claude Code on the VM host
  (`modes/lab.md`).
- **Lighter:** `SKILL.md` is now a ~1.1k-token router (was ~4.2k), each mode's rules load only when
  that mode runs, and the cheat sheet is looked up by section.
- **Grader checks from real attempts:** autofs accepts direct and indirect maps when the wording allows
  either, journal persistence is checked by its file rather than a boot count, and cross-node causes
  are named in the failure message.
- **New task-writing rules:** values must not already be satisfied on the lab, no internet
  dependencies, and a password is set for any user the candidate must log in as. Also a "prove the
  paper" step before hand-over.
- Example Mock Exam 1 rebuilt on the new grader runtime.

## 1.0.0 — 2026-10-16

- First public release: mock exam, answer key, grading and coaching modes, packaged as a Claude Code
  plugin marketplace with a claude.ai zip builder, and the example Mock Exam 1.
