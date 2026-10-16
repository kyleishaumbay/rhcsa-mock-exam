---
type: llm
weight: 1
---

The response grades the attempt the way the rhcsa-mock-exam skill's grading mode requires:

1. It covers only the attempted tasks (2, 3, 4, 6, 8, 9, 13, 14, 16, 18). It does not give feedback on tasks 1 or 5, which were not attempted.
2. It marks 2, 3, 6 and 16 as passed, and 4, 8, 9, 13, 14 and 18 as failed.
3. It names the recurring pattern: services started but not enabled (tasks 8 and 13), and says task 9 failed because of task 8 on node2 rather than a node1 mistake.
4. The fixes are correct: change linda's and anna's home directories with `usermod -d` (without creating local homes); add the missing `/` before `&` in the autofs map (`node2:/srv/nfs/users/&`); `systemctl enable` for httpd on node2 and vsftpd on node1; a drop-in (e.g. `systemctl edit httpd`) with `Restart=on-failure` (or always) and `RestartSec=10s`, not an edit of the vendor unit file.
5. It gives no partial credit, and does not claim unverified requirements passed.
6. It ends by offering a retry pack for the misses and/or recording the attempt.

Score 1 only if all six hold.
