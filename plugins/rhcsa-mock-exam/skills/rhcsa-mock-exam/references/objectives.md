# EX200 objectives

**Target: RHEL 9.** Wording below is Red Hat's RHEL 9 list (68 objectives,
as published from February 2023 and reproduced in Ghori's RHEL 9 guide).
The "Certification Exam Objectives by Version" PDF
(training-lms.redhat.com) has the RHEL 9 version's booking dates. The code
in brackets is the grader category (`scripts/grader_lib.sh`).

The rule every task and check is built on: "As with all Red Hat
performance-based exams, configurations must persist after reboot without
intervention."

## RHEL 9 (default)

**Understand and use essential tools [TOOLS]**
- Access a shell prompt and issue commands with correct syntax
- Use input-output redirection (>, >>, |, 2>, etc)
- Use grep and regular expressions to analyze text
- Access remote systems using ssh
- Log in and switch users in multi-user targets
- Archive, compress, unpack, and uncompress files using tar, star, gzip, and bzip2
- Create and edit text files
- Create, delete, copy, and move files and directories
- Create hard and soft links
- List, set, and change standard ugo/rwx permissions
- Locate, read, and use system documentation including man, info, and files in /usr/share/doc

**Create simple shell scripts [SH]**
- Conditionally execute code (use of: if, test, [], etc.)
- Use Looping constructs (for, etc.) to process file, command line input
- Process script inputs ($1, $2, etc.)
- Processing output of shell commands within a script

**Operate running systems [OPS]**
- Boot, reboot, and shut down a system normally
- Boot systems into different targets manually
- Interrupt the boot process in order to gain access to a system
- Identify CPU/memory intensive processes and kill processes
- Adjust process scheduling
- Manage tuning profiles
- Locate and interpret system log files and journals
- Preserve system journals
- Start, stop, and check the status of network services
- Securely transfer files between systems

**Configure local storage [STOR]**
- List, create, and delete partitions on MBR and GPT disks
- Create and remove physical volumes
- Assign physical volumes to volume groups
- Create and delete logical volumes
- Configure systems to mount file systems at boot by Universally Unique ID (UUID) or label
- Add new partitions and logical volumes, and swap to a system non-destructively

**Create and configure file systems [FS]**
- Create, mount, unmount, and use vfat, ext4, and xfs file systems
- Mount and unmount network file systems using NFS
- Configure autofs
- Extend existing logical volumes
- Create and configure set-GID directories for collaboration
- Diagnose and correct file permission problems

**Deploy, configure, and maintain systems [DEP]**
- Schedule tasks using at and cron
- Start and stop services and configure services to start automatically at boot
- Configure systems to boot into a specific target automatically
- Configure time service clients
- Install and update software packages from Red Hat Network, a remote repository, or from the local file system
- Modify the system bootloader

**Manage basic networking [NET]**
- Configure IPv4 and IPv6 addresses
- Configure hostname resolution
- Configure network services to start automatically at boot
- Restrict network access using firewall-cmd/firewall

**Manage users and groups [USR]**
- Create, delete, and modify local user accounts
- Change passwords and adjust password aging for local user accounts
- Create, delete, and modify local groups and group memberships
- Configure superuser access

**Manage security [SEC]**
- Configure firewall settings using firewall-cmd/firewalld
- Manage default file permissions
- Configure key-based authentication for SSH
- Set enforcing and permissive modes for SELinux
- List and identify SELinux file and process context
- Restore default file contexts
- Manage SELinux port labels
- Use Boolean settings to modify system SELinux settings
- Diagnose and address routine SELinux policy violations

**Manage containers [CON]**
- Find and retrieve container images from a remote registry
- Inspect container images
- Perform container management using commands such as podman and skopeo
- Build a container from a Containerfile
- Perform basic container management such as running, starting, stopping, and listing running containers
- Run a service inside a container
- Configure a container to start automatically as a systemd service
- Attach persistent storage to a container

### RHEL 9 notes for task writing

- Repository access and package installs are **DEP** tasks.
- systemd timers are not named ("at and cron"). A timer task is fair only as
  an alternative the key mentions; never make a timer the only correct
  answer on a RHEL 9 paper.
- Ghori's RHEL 9 guide lists 68 objectives; if the user's copy of Red Hat's
  RHEL 9 objectives differs, theirs wins.

## Not on the exam

Stratis and VDO are not RHEL 9 objectives; anything teaching them is RHEL 8
material.
