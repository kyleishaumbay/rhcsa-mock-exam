---
type: llm
weight: 1
---

The answer is correct for RHEL 9:

1. The primary method is `rd.break` at the GRUB menu (edit the kernel line with `e`, remove `rhgb quiet` / `console=` arguments if needed), then `mount -o remount,rw /sysroot`, `chroot /sysroot`, `passwd root`, `touch /.autorelabel`, exit twice.
2. It gives `init=/bin/bash` as a fallback, where the root fs is at `/` (remount `/` rw), NOT `/sysroot`.
3. It insists on the SELinux relabel (`touch /.autorelabel`, or `restorecon` on `/etc/shadow` in the fallback).
4. It is laid out as ordered steps that can be followed at the console.

Score 1 only if all four hold. Extra correct detail (verification steps, common mistakes) is fine.
