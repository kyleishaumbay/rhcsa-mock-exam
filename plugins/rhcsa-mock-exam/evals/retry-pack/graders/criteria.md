---
type: llm
weight: 1
---

The response is a retry pack, per the skill:

1. It gives roughly 4-8 tasks in exam voice, each naming its node, aimed at the three misses: services that must survive a reboot, an autofs wildcard/indirect map, and users with specific home directories.
2. It uses new names and paths rather than the user's originals (e.g. not linda/anna or /home/users again). Practising the same kind of service, such as a web or FTP server that must survive a reboot, is fine.
3. It does NOT give the solutions up front: no commands that solve a task, and no hints naming the commands, services or files that solve it. Offering answers after an attempt is fine, and so are setup commands that seed the lab before the attempt (creating export directories, for example): those are preconditions, not solutions.
4. It tells the user how the tasks will be checked: after a reboot, with a grader, or by pasting results back.

Score 1 only if all four hold.
