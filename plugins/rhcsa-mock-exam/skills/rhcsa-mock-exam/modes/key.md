# Mode B — answer key for a practice test the user supplies

The user brings a test: a book's practice exam (Sander van Vugt, Ghori),
a repo lab, a forum task list. Produce the key.

- Read every task first. Do not assume the source is correct.
- Per task: restate it in one line, then commands, verification, and the
  persistence check — using `cheatsheet.md` so commands are consistent
  across keys.
- **Flag bad tasks rather than answering them straight.** Specifically:
  dated material (`ntpd` for `chronyd`, `ifcfg-` files for `nmcli`
  keyfiles, `iptables` for firewalld, `yum` for `dnf`, Stratis or VDO),
  tasks off the RHEL 9 objectives, tasks ambiguous enough that two
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
  tasks. Build a grader for it (`modes/grade.md`) only if asked.
