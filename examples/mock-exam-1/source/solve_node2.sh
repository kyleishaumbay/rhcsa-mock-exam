#!/bin/bash
# Answer-key solution for node2 (tasks 1, 2, 3, 8). Validation run only.
set -euxo pipefail

# 1 - LVM for the NFS export area
vgcreate -s 8M vgnfs /dev/sdb
lvcreate -n lvexport -l 128 vgnfs
mkfs.xfs /dev/vgnfs/lvexport
mkdir -p /srv/nfs
echo "UUID=$(blkid -s UUID -o value /dev/vgnfs/lvexport)  /srv/nfs  xfs  defaults  0 0" >> /etc/fstab
systemctl daemon-reload
mount -a
findmnt --verify

# 2 - NFS server
mkdir -p /srv/nfs/data /srv/nfs/users/linda /srv/nfs/users/anna
cp /etc/hosts /srv/nfs/data/
chown 2001 /srv/nfs/users/linda
chown 2002 /srv/nfs/users/anna
chmod 700 /srv/nfs/users/linda /srv/nfs/users/anna
cat > /etc/exports.d/srv.exports <<'EOF'
/srv/nfs/data   192.168.100.0/24(rw)
/srv/nfs/users  192.168.100.0/24(rw)
EOF
systemctl enable --now nfs-server
exportfs -rav

# 3 - firewall for NFS clients
firewall-cmd --permanent --add-service={nfs,mountd,rpc-bind}
firewall-cmd --reload

# 8 - Apache name-based virtual host
mkdir -p /www/docs/sales
echo 'Welcome to the sales server' > /www/docs/sales/index.html
cat > /etc/httpd/conf.d/sales.example.com.conf <<'EOF'
<Directory /www/docs>
    Require all granted
    AllowOverride None
</Directory>

<VirtualHost *:80>
    ServerName sales.example.com
    DocumentRoot /www/docs/sales
</VirtualHost>
EOF
semanage fcontext -a -t httpd_sys_content_t '/www(/.*)?'
restorecon -Rv /www
httpd -t
systemctl enable --now httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
curl -s -H 'Host: sales.example.com' http://127.0.0.1/
