# Mode F — track progress across attempts

For "how am I doing", "am I ready", "show my progress", and after every
grading (Mode C) to record the attempt.

## Where results live

- **Claude Code:** `~/.rhcsa-mock/progress.csv`. Create it (and the folder)
  the first time, after asking once. Header:
  `date,paper,scope,score,graded,failed,objectives`
- **claude.ai** has no lasting files. Give the user the row to keep (one
  line), and ask them to paste their saved rows when they want a trend.

## Recording an attempt

Take the grader's last line, which has this shape:

    SUMMARY|2026-10-16|RHCSA9 Mock Exam 1|all nodes|211/300|graded=21|failed=4,9|OPS=100,STOR=67,...

and append one CSV row: `date,paper,scope,score,graded,"failed","objectives"`.
For `score` and `graded` keep the numbers only; quote the two
comma-separated fields. If only part of the paper was attempted, record the
graded tasks the user attempted, and add `(partial: tasks …)` to `paper`.
Confirm in one line ("Recorded: Mock 1, 211/300"). Without a SUMMARY line
(the user pasted commands, or an older grader), don't record a score; say
why.

## Reporting

Read the file, never memory. Keep it short:

1. A table of the last five attempts: date, paper, score, pass (≥ 210).
2. Per objective: first vs latest percentage, with ↑ ↓ or =.
3. The three weakest objectives, and any task number that failed in two or
   more attempts.
4. One recommendation: a retry pack on the weakest (`modes/drill.md`) while
   any objective is under 70%; a fresh full paper once two attempts in a row
   score ≥ 210. Say plainly that this is a readiness signal, not a
   prediction.

Never invent or estimate past results. If the file is missing or empty,
say so.
