# Resources — vetted October 2026, RHEL 9 only

Every resource here targets the RHEL 9 version of EX200. Never recommend
dump sites or "real exam question" collections. Recommend only material
that says RHEL 9 and includes containers.

## Official (always first)

| Resource | Why |
|---|---|
| Certification Exam Objectives by Version PDF (learn.redhat.com / training-lms.redhat.com, login needed) | Confirms the RHEL 9 version (EX200V9K) is still bookable. Also check the version shown on the booking page. |
| RHEL 9 documentation — docs.redhat.com/en/documentation/red_hat_enterprise_linux/9 | Authoritative procedures. Guides that map to the objectives: "Building, running, and managing containers", "Configuring basic system settings", "Configuring and managing logical volumes", "Managing file systems", "Configuring and managing networking", "Using SELinux", "Configuring firewalls and packet filters". Skip the Stratis and VDO chapters. |
| Red Hat Developer subscription (no cost) — developers.redhat.com/products/rhel/download | RHEL 9 DVD ISOs (9.0–9.8) for the lab. |
| Red Hat Learning Community — learn.redhat.com | Instructor answers on quirks, e.g. the RHEL 9 rd.break console= thread. |
| RHLS labs (`lab start` / `lab grade`), if available | Candidates report these grade most like the real exam. |

## Books

| Book | Notes |
|---|---|
| Sander van Vugt — Red Hat RHCSA 9 Cert Guide: EX200 (ISBN 9780138096311) | Two extra practice tests on the companion site. A candidate: "practise Sander's final exam at the end of his course until you can do tasks by heart." |
| Asghar Ghori — RHCSA Red Hat Enterprise Linux 9, 3rd ed. | 74 labs, four sample exams; candidates call its labs harder than Sander's — good second source. Buy the RHEL 9 edition specifically. Publisher's errata page lists corrections. |

## Practice repos and labs

| Repo | Use for | Caution |
|---|---|---|
| github.com/sandervanvugt/rhcsa9 | 30- and 45-minute mini exams with bash grading scripts, a Containerfile for container practice. | Loose class files; best used alongside his course. |
| github.com/aggressiveHiker/rhcsa9 | Two-server lab setup and practice tasks covering every RHEL 9 objective. | Skip its VDO task and Stratis notes (RHEL 8 material). |
| github.com/RedHatRanger/rhcsa9vagrant | One `vagrant up` builds a multi-node VirtualBox lab (node1, node2). | Rocky 9.6, not RHEL; no tasks or grader. Sit final mocks on RHEL. |
| github.com/labex-labs/rhcsa-certification-exam-practice-exercises | 58 challenge-style exercises incl. 7 podman/skopeo labs ending in systemd autostart. | Links to hosted labs (account needed); doesn't state its version — use only the exercises that match the RHEL 9 objectives. |

## Video

- Sander van Vugt — RHCSA (RHEL 9) Complete Course with Exam Labs, O'Reilly
  (oreilly.com/videos/rhcsa-rhel-9/9780135397237/): ~19 h, the strongest
  RHCSA 9 video course. Needs a subscription.
- Dextutor (youtube.com/@dextutor) — "RHCSA Complete Course" (2025),
  includes podman containers; recommended by a passing candidate.

## Treat with caution

- Guides, videos and simulators sold as "RHCSA" without saying RHEL 9:
  check the version and that containers are covered before using them.
- Simulators or repos built from an "exam answers" PDF — dump-derived.
- Aggregator repos that link out to dumps (e.g. github.com/ive663/RHCSA).
- CertForged.com and similar one-line forum plugs — unvetted.
- Anything with "dumps", "real questions", "actual exam" in the name.
- RHEL 8 material for storage (Stratis, VDO) — not on the RHEL 9 list.
