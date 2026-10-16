# Changelog

## 1.3.0 — 2026-10-16

- **RHEL 9 only.** Removed the exam-version switch, the other version's objective list, the `SW`
  grader category, its eval case and the checker's `--rhel` flag.
- **Resources re-vetted for RHEL 9:** added Sander van Vugt's rhcsa9 repo and RHEL 9 video course,
  RedHatRanger/rhcsa9vagrant and the RHEL 9 documentation guides; dropped a simulator that is not
  RHEL 9 and an aggregator that links to dumps.
- **One request, one result.** Removed the retry-pack and progress-tracking modes (`modes/drill.md`,
  `modes/progress.md`), mode chaining and follow-up offers, the grader's `SUMMARY` line, and the
  three-paper rotation promise. Five modes remain: mock exam, key, grading, coaching, lab prep.
- Sample exam (`examples/mock-exam-1`) and the eval suite removed.
- Practice exams saved on request now live in `exams/`, outside the skill package.

## 1.2.0 — 2026-10-16

- **Full syllabus by default.** A mock exam is always a full 18-22 task paper across all ten RHEL 9
  objective categories unless the user names topics, and a topic-focused paper says so. Each paper
  also rotates in at least four less common objectives (chrony client, SSH keys, links, scp, SELinux
  mode, archive formats, local RPMs, Containerfile/skopeo), so three papers cover every checkable objective.
- **Retry packs give nothing away:** no per-task "targets" labels, no method hints, and no check
  commands when there is no grader file.
- **Eval suite** (`plugins/rhcsa-mock-exam/evals/`): 6 light chat cases plus one full-exam case, runnable
  with `claude plugin eval`.
- **`tools/check_mock_output.py`**: 28 deterministic rules for a generated exam, covering syllabus
  coverage, task count, no answers in the paper, the grader build and `bash -n`.

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
