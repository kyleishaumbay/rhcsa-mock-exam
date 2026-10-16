---
type: llm
weight: 1
---

The coaching answer is correct and complete:

1. SELinux port label: `semanage port -a -t http_port_t -p tcp 8888` (or `-m` if already defined).
2. Apache config: a `Listen 8888` line, then restart httpd, which is also enabled at boot.
3. Firewall: `firewall-cmd --permanent --add-port=8888/tcp` and `firewall-cmd --reload`.
4. Proof: e.g. `semanage port -l | grep 8888` (or `-l -C`), `ss -tlnp | grep 8888`, `curl localhost:8888`, and `firewall-cmd --list-ports`.
5. It warns not to disable SELinux / `setenforce 0`, and names missing one of the three parts as the trap.

Score 1 only if all five hold.
