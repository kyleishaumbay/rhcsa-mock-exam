# Practice lab that behaves like the exam

Mode A papers assume this lab unless the user says otherwise. When a user
asks how to set up practice, give them this — trimmed to what they lack.

## Topology

| Host | Role | Disks |
|---|---|---|
| `utility.lab.example.com` | Plays the classroom server: HTTP repo (BaseOS/AppStream), NFS exports for autofs, NTP source, container registry | one |
| `node1.lab.example.com` | Exam system 1 — reachable, network pre-configured | one + one spare 10 GB |
| `node2.lab.example.com` | Exam system 2 — starts locked out, network unconfigured | one + two spare 5 GB |

One subnet, e.g. 192.168.122.0/24 (libvirt default) with static addresses.
Two cores and 2 GB RAM per node is enough; utility can be smaller.

Single-VM fallback: node1 plays both roles, utility's services run on the
host or on node1 itself. Say so in the paper's preamble.

## Getting RHEL 9

- A no-cost Red Hat Developer subscription gives the RHEL 9 DVD ISO. Use
  the DVD, not the boot ISO: the boot ISO lacks the BaseOS/AppStream trees
  needed for the local repo.
- Rocky or Alma 9 work for most drills, but repo IDs, subscription tooling
  and container image names differ. Do the final mocks on RHEL 9.

## utility host

```bash
# repo from the DVD
mount -o loop,ro rhel-9.x-x86_64-dvd.iso /mnt
dnf install -y httpd nfs-utils chrony
mkdir -p /var/www/html/rhel9 && cp -a /mnt/BaseOS /mnt/AppStream /var/www/html/rhel9/
restorecon -Rv /var/www/html
systemctl enable --now httpd
firewall-cmd --permanent --add-service={http,nfs,mountd,rpc-bind,ntp} && firewall-cmd --reload

# NFS exports for NFS and autofs tasks
mkdir -p /exports/share /exports/home/{user1,user2} /exports/docs
echo '/exports *(rw,sync,no_root_squash)' > /etc/exports.d/lab.exports
exportfs -rav && systemctl enable --now nfs-server

# NTP source for time-client tasks
echo 'allow 192.168.122.0/24' >> /etc/chrony.conf && echo 'local stratum 8' >> /etc/chrony.conf
systemctl enable --now chronyd && systemctl restart chronyd
```

Nodes then use `baseurl=http://utility.lab.example.com/rhel9/BaseOS` (and
`/AppStream`), `server utility.lab.example.com iburst`, and
`utility.lab.example.com:/exports/...`.

## Container registry practice

The exam supplies a registry and credentials. Practise the same way:

- **With internet:** pull from `registry.access.redhat.com` (UBI images, no
  login) or `registry.redhat.io` (needs a Red Hat login) — e.g.
  `registry.access.redhat.com/ubi9/httpd-24`.
- **Offline, exam-like:** run a registry on utility and push images to it.

  ```bash
  # utility, while it still has internet
  dnf install -y container-tools
  podman run -d --name registry --restart=always -p 5000:5000 docker.io/library/registry:2
  firewall-cmd --permanent --add-port=5000/tcp && firewall-cmd --reload
  podman pull registry.access.redhat.com/ubi9/httpd-24
  podman tag registry.access.redhat.com/ubi9/httpd-24 utility.lab.example.com:5000/rhel9/httpd-24
  podman push --tls-verify=false utility.lab.example.com:5000/rhel9/httpd-24
  ```

  On each node, allow the plain-HTTP registry in a drop-in —
  `/etc/containers/registries.conf.d/lab.conf`:

  ```
  [[registry]]
  location = "utility.lab.example.com:5000"
  insecure = true
  ```

  `--restart=always` only survives a utility reboot if its container is also
  run from a systemd unit; for a practice box, re-run it after reboots.
- Seed a named user on node1 for rootless tasks (or make creating it a task)
  and never do container tasks as root unless the paper says so.
- **No registry at all?** Seed an image archive in the preamble on a node
  that already has the image: `podman save -o /opt/images/<name>.tar <image>`
  (mode 644). The task then has the user run `podman load -i` on it.

## Seed the preconditions (before starting the clock)

Snapshot everything first, then on **node2**:

```bash
echo "root:$(openssl rand -hex 12)" | chpasswd          # locked out
nmcli -g NAME con show | while read c; do nmcli con delete "$c"; done   # no network
systemctl set-default graphical.target 2>/dev/null || true               # wrong target (if GUI installed)
```

On **node1**: leave one spare disk untouched; optionally a stale repo file
pointing nowhere, so repo configuration is a real task.

Keep exam VMs dedicated to mock exams. Other practice tools installed on
the same VM can interfere: one simulator installs a service that strips
/etc/fstab entries at every boot and shutdown, which silently fails every
storage task. A clone of a node that carries such a tool is not a clean
node.

Reset between attempts by reverting snapshots
(`virsh snapshot-revert <vm> clean` or the VirtualBox equivalent), never by
undoing work by hand.

## Grading run

1. Reboot both nodes.
2. Copy the grader to each node (`scp`), run it as root on each.
3. Paste both outputs back for Mode C grading.
