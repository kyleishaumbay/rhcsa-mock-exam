# Mode G — prepare the lab (Claude Code on the VM host)

For "get my VMs ready for the exam", "set up the lab", or "grade my VMs for
me". Only possible where Claude has a shell on the machine that runs the
hypervisor. On claude.ai, say so and give `references/lab-setup.md`
instead.

## Safety rules — always

- Look before touching: inventory first, and change nothing a step doesn't need.
- **Ask before changing any VM**: attaching an ISO, adding a disk or NIC,
  powering on or off, or typing into its console.
- **Snapshot powered off** before seeding anything. A live snapshot of a
  desktop VM can hang for an hour.
- **Never delete** a VM, disk or snapshot, and never restore a snapshot over
  a VM the user may have worked in (their attempt is their work) without
  asking.
- Don't use VMs that run other practice tools. One simulator strips
  /etc/fstab at every boot and shutdown, and a clone of such a VM inherits
  it.

## Find the hypervisor

- VirtualBox: `VBoxManage` (from WSL:
  `/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe`).
- libvirt/KVM: `virsh` (`virsh -c qemu:///system`).
- Neither found: stop, and point to `references/lab-setup.md`.

## Steps

1. **Inventory.** VirtualBox: `list vms`, then `showvminfo <vm>
   --machinereadable` for ostype, memory, cpus, `SATA-*` disks, `nic*` /
   `intnet*` / `hostonlyadapter*`, `Forwarding(*)`, snapshots, state.
   libvirt: `dominfo`, `domblklist`, `domiflist`, `snapshot-list`.
2. **Map the nodes.** VMs on the same internal, host-only or bridged network
   can be node1, node2 (and a utility host). Show a table (VM, role, OS,
   disks, network, snapshots) and get the user's yes.
3. **Close gaps, after asking.** A package source (attach the RHEL DVD ISO
   with `storageattach … --type dvddrive --medium <iso>`), spare disks,
   a shared network, an SSH port forward (`modifyvm --natpf1
   "ssh,tcp,127.0.0.1,22NN,,22"`).
4. **Get inside.** Use root (or sudo) over an SSH key. No key: the user runs
   `ssh-copy-id` themselves (password prompt), or, if they agree, Claude
   types into the console (`controlvm <vm> keyboardputstring "…"` +
   `keyboardputscancode 1c 9c`, read back with `screenshotpng`). Check the
   result: capitals can be dropped.
   *WSL2:* Windows-side forwards on 127.0.0.1 are not reachable from Linux,
   so use `/mnt/c/Windows/System32/OpenSSH/ssh.exe`. `ssh-keygen.exe -N '""'`
   called from WSL sets a literal `""` passphrase.
5. **Freshness check, read-only.** Look for leftover VGs, users with UID ≥
   1000, enabled non-default services, extra fstab lines, permanent firewall
   services, exports, autofs maps, the default target, SELinux mode and
   crontabs. Report anything that pre-solves or collides with a task, and
   pick other values (`modes/exam.md` rules) rather than "cleaning" the VM.
6. **Seed and snapshot.** Run only the paper's setup block, shut every node
   down, and take a `mock-<n>-start` snapshot of each.
7. **Prove the paper** (`modes/exam.md`, "Prove the paper"), then restore
   `mock-<n>-start` on every node. Name any check that couldn't be proven.
8. **Hand over** the paper, key and grader, plus: "To start: power on node2,
   then node1. To retake: restore `mock-<n>-start` on every node."

## Grading for the user

After the attempt, offer to grade directly: ask before rebooting, reboot
server nodes first, copy the grader to node1, run `bash <grader> --all`,
and continue with `modes/grade.md` and `modes/progress.md`. Leave the
attempt in place afterwards; restore only if the user asks.
