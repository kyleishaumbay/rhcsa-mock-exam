#!/bin/bash
# Answer-key solution for node1 (tasks 4-7, 9-21). Validation run only.
set -euxo pipefail

# precondition (exam setup block): image archive for the container task
mkdir -p /opt/images
podman save -o /opt/images/ubi9-minimal.tar registry.access.redhat.com/ubi9/ubi-minimal
chmod 755 /opt/images; chmod 644 /opt/images/ubi9-minimal.tar

# 4 - users
useradd -u 2001 -M -d /home/users/linda linda
useradd -u 2002 -M -d /home/users/anna anna
useradd appuser
echo 'appuser:redhat' | chpasswd

# 5 - GPT partition, VG with 16 MiB extents, LV of 30 extents, ext4 by UUID
parted -s /dev/sdb mklabel gpt mkpart lvmpart 1MiB 2049MiB set 1 lvm on
udevadm settle
pvcreate /dev/sdb1
vgcreate -s 16M vgweb /dev/sdb1
lvcreate -n lvweb -l 30 vgweb
mkfs.ext4 -q /dev/vgweb/lvweb
mkdir -p /webfiles
echo "UUID=$(blkid -s UUID -o value /dev/vgweb/lvweb)  /webfiles  ext4  defaults  0 0" >> /etc/fstab

# 6 - persistent NFS mount
mkdir -p /mnt/nfsdata
echo 'node2:/srv/nfs/data  /mnt/nfsdata  nfs  defaults,_netdev  0 0' >> /etc/fstab
systemctl daemon-reload
mount -a
findmnt --verify

# 7 - persistent journal
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' > /etc/systemd/journald.conf.d/persist.conf
systemctl restart systemd-journald

# 9 - name resolution for the vhost on node2
echo '192.168.100.11  sales.example.com  sales' >> /etc/hosts
curl -s http://sales.example.com/

# 10 - autofs indirect map
echo '/shares  /etc/auto.shares' > /etc/auto.master.d/shares.autofs
echo 'data  -rw  node2:/srv/nfs/data' > /etc/auto.shares
systemctl enable --now autofs
systemctl restart autofs
ls /shares/data/hosts

# 11 - Apache document root /webfiles
sed -i 's#^DocumentRoot "/var/www/html"#DocumentRoot "/webfiles"#' /etc/httpd/conf/httpd.conf
cat > /etc/httpd/conf.d/webfiles.conf <<'EOF'
<Directory "/webfiles">
    Require all granted
    AllowOverride None
</Directory>
EOF
echo 'hello world' > /webfiles/index.html
semanage fcontext -a -t httpd_sys_content_t '/webfiles(/.*)?'
restorecon -Rv /webfiles

# 12 - extend lvweb and its file system (online)
lvextend -r -L 688M /dev/vgweb/lvweb

# 13 - vsftpd
dnf install -y vsftpd
systemctl enable --now vsftpd

# 14 - autofs wildcard home directories
echo '/home/users  /etc/auto.users' > /etc/auto.master.d/users.autofs
echo '*  -rw  node2:/srv/nfs/users/&' > /etc/auto.users
systemctl restart autofs

# 15 - Apache on 8090 (SELinux port label + firewall)
sed -i 's/^Listen 80$/Listen 8090/' /etc/httpd/conf/httpd.conf
semanage port -a -t http_port_t -p tcp 8090
firewall-cmd --permanent --add-port=8090/tcp
httpd -t
systemctl enable --now httpd
systemctl restart httpd
curl -s http://127.0.0.1:8090/

# 16 - firewall services
firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --remove-service=cockpit
firewall-cmd --reload

# 17 - extra swap on LVM
lvcreate -n lvswap -L 512M vgweb
mkswap /dev/vgweb/lvswap
echo "UUID=$(blkid -s UUID -o value /dev/vgweb/lvswap)  none  swap  defaults  0 0" >> /etc/fstab
swapon -a
swapon --show

# 18 - httpd drop-in
mkdir -p /etc/systemd/system/httpd.service.d
cat > /etc/systemd/system/httpd.service.d/override.conf <<'EOF'
[Unit]
Wants=vsftpd.service

[Service]
Restart=on-failure
RestartSec=10s
EOF
systemctl daemon-reload

# 19 - daily 23:00 job as root
( crontab -l -u root 2>/dev/null || true; echo '0 23 * * * /usr/bin/df -h /webfiles >> /var/log/webfiles-usage.log' ) | crontab -u root -

# 20 - rootless container as a systemd user service (exam: do this over 'ssh appuser@localhost')
loginctl enable-linger appuser
sleep 3
runuser -l appuser -c '
set -eux
export XDG_RUNTIME_DIR=/run/user/$(id -u)
mkdir -p ~/ticker-data ~/.config/systemd/user
podman load -i /opt/images/ubi9-minimal.tar
podman run -d --name ticker -v /home/appuser/ticker-data:/data:Z registry.access.redhat.com/ubi9/ubi-minimal sleep infinity
cd ~/.config/systemd/user
podman generate systemd --name ticker --files --new
podman stop ticker; podman rm ticker
systemctl --user daemon-reload
systemctl --user enable --now container-ticker.service
podman ps
'

# 21 - default target
systemctl set-default multi-user.target
echo SOLVE-NODE1-DONE
