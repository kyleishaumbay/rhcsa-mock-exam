---
type: llm
weight: 1
---

The response acts as an answer key that checks the source instead of trusting it:

1. Task 1 is flagged as dated: RHEL 9 uses chronyd (`/etc/chrony.conf`, `server classroom.example.com iburst`, enable and restart chronyd), not ntpd. The answer it gives uses chrony.
2. Task 2 is flagged as off the RHEL 9 objectives (Stratis is RHEL 8 material) and is not presented as exam-relevant.
3. Task 3 gets correct commands (`useradd -u 2100 bob`, `chage -M 60 bob` or equivalent) with a verification command such as `chage -l bob`.
4. Task 4 gets a correct find-and-copy (e.g. `find / -user harry -exec cp --parents -a {} /root/harryfiles \;` or equivalent) with a verification step.
5. Each answered task includes how to prove it (a verification command) and, where relevant, how it survives a reboot.

Score 1 only if all five hold.
