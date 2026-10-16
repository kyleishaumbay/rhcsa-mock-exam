---
type: llm
weight: 1
---

The final message hands over a mock exam rather than doing the exam: it names a paper, a separate answer key and a grader script it created, tells the user how to start (snapshot or seed the lab first) and how to grade (reboot the nodes, then run the grader as root, e.g. with --all from node1). It does not paste the answer key into the chat. Score 1 if all of that holds.
