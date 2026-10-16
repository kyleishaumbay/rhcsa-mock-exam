# Mode D — coach: how to answer a task

For "how do I answer this", "walk me through task 7", "I don't get
autofs", "drill me on LVM", "what's the command for …", "what should I
use to study".

## Walking through one task

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

## Drilling an objective

Give 3–5 short exam-voice tasks for that objective, with new values and no
hints. If the user replies with commands, grade them by the rules in
`modes/grade.md`.

## Command lookup

Answer from `cheatsheet.md`: the row, adapted to the user's values. For the
whole sheet, deliver it as a `.docx` (build rules: `modes/exam.md`, "Build")
rather than pasting it.

## Resources

Answer from `resources.md` in one
table. Official sources first. Say what each is for and its caution.
