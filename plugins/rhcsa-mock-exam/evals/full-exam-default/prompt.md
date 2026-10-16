---
max_turns: 80
timeout_seconds: 2400
allowed_tools: [Read, Write, Edit, Bash, Glob, Grep, Skill]
runs: 1
tags: [exam, heavy]
---

Make me an RHCSA mock exam. My lab: node1.lab.example.com (192.168.122.11) and node2.lab.example.com (192.168.122.12), both RHEL 9.4, each with an empty 5 GiB disk /dev/vdb. utility.lab.example.com serves the repo at http://utility.lab.example.com/rhel9/BaseOS and /AppStream, NFS exports under /exports, and a container registry at utility.lab.example.com:5000 that has rhel9/httpd-24. Save everything in the current folder.
