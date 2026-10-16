# Mode E — practise where you missed (retry pack)

For "give me more practice on what I got wrong", "drill my weak areas",
or the offer at the end of a grading (Mode C).

## Input

The misses, from the best source available:

1. the grading just done in this conversation: failed tasks, their
   objectives, and the cause found for each;
2. a pasted grader output, or its `SUMMARY|…` line;
3. the progress file (`modes/progress.md`): the weakest objectives across
   the last three attempts.

Never invent misses. With no source, ask for the grader output.

## Build the pack

- **4–8 short tasks**, one or two per missed objective, ordered root cause
  first (a failed user task before the autofs task that needed it).
- **New values every time**: other names, sizes, paths, ports and users than
  the paper used, so the pack tests skill, not memory. Same lab and node
  layout as the paper; no internet; everything checkable after a reboot.
- **Aim at the trap, not just the topic.** If the cause was "started, not
  enabled", every service in the pack must survive the reboot. If it was a
  path typo (`users&`), the check must depend on the exact path working. If
  it was a missing SELinux rule, use a non-default directory again.
- Same exam voice as a paper (`modes/exam.md`): terse, names the node, never
  prescribes the tool.

## Deliver it light

- The tasks **in chat**, as a numbered list: no docx unless asked.
- A **mini grader** as a file: write only its checks and build it with
  `scripts/build_grader.sh` (`PAPER="Retry pack <n>"`), `need` per
  requirement, `requires` where tasks stack.
- **No answers up front, and no hints that give the method away.** Don't
  say which commands, services, files or options a task needs, or how it will
  be checked, and don't label tasks with the miss they target (a label like
  "started but not enabled" is the answer). One intro line ("aimed at your
  misses from <paper>") is enough; map tasks to misses when grading. Give the
  key for a task only after the user has attempted it, or asks.
- Tell them: do the tasks, reboot, run `bash <grader> --all` from node1,
  paste the output. If they asked for no files (so no grader), ask them to
  paste what they ran instead, and don't list check commands: those reveal
  what each task needs.

## After the attempt

Grade it by `modes/grade.md`. An objective is cleared after two clean
passes in a row with different values. Still failing? Give one more task in
a different shape (another service, another map type, another node), then
switch to a coached walk-through (`modes/coach.md`) of that one task.

No lab at hand? Run the drill interactively instead (`modes/coach.md`,
"Drilling an objective"): the user answers with commands, graded as intent.
