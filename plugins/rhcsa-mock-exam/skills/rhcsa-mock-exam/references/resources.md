# Resources — vetted September 2026, for the RHEL 9 version

Say which version each resource targets. Never recommend dump sites or
"real exam question" collections. Because Red Hat's live page is now
RHEL 10, most new material is RHEL 10 — filter it (drop Flatpak, keep
containers).

## Official (always first)

| Resource | Why |
|---|---|
| Certification Exam Objectives by Version PDF (training-lms.redhat.com) | Confirms the RHEL 9 version is still bookable and when it retires. Check before booking. |
| Red Hat EX200 page | Current policies. Its objective list is now RHEL 10 — don't study from it for a RHEL 9 sitting. |
| RHEL 9 documentation — docs.redhat.com | Authoritative procedures: root password recovery, storage, "Building, running, and managing containers". |
| Red Hat Developer subscription (no cost) — developers.redhat.com | RHEL 9 DVD ISO for the lab. |
| Red Hat Learning Community — learn.redhat.com | Instructor answers on quirks, e.g. the RHEL 9 rd.break console= thread. |
| RHLS labs (`lab start` / `lab grade`), if available | Candidates report these grade most like the real exam. |

## Books

| Book | Notes |
|---|---|
| Sander van Vugt — Red Hat RHCSA 9 Cert Guide: EX200 | The user's current guide. A candidate: "practise Sander's final exam at the end of his course until you can do tasks by heart." |
| Asghar Ghori — RHCSA Red Hat Enterprise Linux 9, 3rd ed. | Lab-heavy, four sample exams; candidates call its labs harder than Sander's — good second source. Publisher's errata page lists book corrections. |

## Practice repos and simulators

| Repo | Use for | Caution |
|---|---|---|
| github.com/aggressiveHiker/rhcsa9 (exam_prep) | RHEL 9 exam-prep tasks; a candidate said it covered every topic. | — |
| github.com/TroggoMan/rhcsa-simulator | Grader-driven simulator with a RHEL 9 mode that includes containers. | Work in progress; dispute results that fail correct work. |
| github.com/tucker-st/rhcsa-ex200 | Reboot-tested objective labs incl. a containers lab; read-only autograde scripts. | Written for RHEL 10 — skip anything Flatpak. |
| github.com/jconwell3115/RHCSA_RHEL_10 | Best model of the real two-node layout with seeded preconditions. | RHEL 10 — reuse the structure, drop Flatpak tasks, add containers. |
| github.com/labex-labs/rhcsa-certification-exam-practice-exercises | Challenge-style exercises including Podman autostart. | Freemium platform. |
| github.com/ive663/RHCSA | Exam-strategy notes, task collection. | Old; links out to a repo named "dumps" — ignore that one. |

## Video

- Sander van Vugt's RHCSA video courses on O'Reilly (the user has two links).
- Dextutor (YouTube) — recommended by a passing candidate.

## Treat with caution

- RHEL 10 guides and videos presented as "RHCSA" without a version: they
  omit containers and add Flatpak.
- CertForged.com and similar one-line forum plugs — unvetted.
- Anything with "dumps", "real questions", "actual exam" in the name.
- RHEL 8 material for storage (Stratis, VDO) — not on the RHEL 9 list.
