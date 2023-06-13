#!/bin/bash

apt update
apt upgrade
apt autoremove

apt -y install samba

mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
cat >> /etc/samba/smb.conf <<EOF
[global]
  workgroup = WORKGROUP
  server string = %h server (Samba, Ubuntu)
  log file = /var/log/samba/log.%m
  max log size = 1000
  logging = file
  panic action = /usr/share/samba/panic-action %d
  server role = standalone server
  obey pam restrictions = yes
  unix password sync = yes
  passwd program = /usr/bin/passwd %u
  passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
  pam password change = yes
  map to guest = bad user
  usershare allow guests = no

[files]
  path = /files
  valid users = files
  browsable = no
  guest ok = no
  writable = yes
  create mask = 0644
EOF

useradd -MUr files
passwd files
smbpasswd -a files

mkdir /files
chown files:files /files

systemctl restart smbd.service nmbd.service
