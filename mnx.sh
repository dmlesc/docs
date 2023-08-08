#!/bin/bash

# visudo
#   dml ALL=(ALL) NOPASSWD: ALL

FIND='ExecStart=\/lib\/systemd\/systemd-networkd-wait-online'
REPLACE='ExecStart=\/lib\/systemd\/systemd-networkd-wait-online --timeout=1'
sed -i 's|$FIND|$REPLACE|' /lib/systemd/system/systemd-networkd-wait-online.service


# DNS
apt -y install bind9

mv /etc/bind/named.conf.options /etc/bind/named.conf.options.bak
cat >> /etc/bind/named.conf.options <<EOF
options {
  directory "/var/cache/bind";

#  forwarders {
#    8.8.8.8;
#    8.8.4.4;
#  };

  forwarders {
    192.168.50.1;
  };

  dnssec-validation auto;
  listen-on-v6 { any; };
};
EOF

mkdir /var/log/named
chown bind:bind /var/log/named

cat >> /etc/bind/named.conf.local <<EOF
logging {
  channel query.log {
    file "/var/log/named/query.log";
    severity debug 3;
  };
  category queries { query.log; };
};
EOF


# DHCP
apt update && apt -y install isc-dhcp-server

mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak

cat >> /etc/dhcp/dhcpd.conf <<EOF
option domain-name "dmlesc.me";
option domain-name-servers 10.0.0.1;
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;

subnet 10.0.0.0 netmask 255.255.255.0 {
  range 10.0.0.10 10.0.0.20;
  option routers 10.0.0.1;
}
EOF

sed -i 's|INTERFACESv4=""|INTERFACESv4="br0"|' /etc/default/isc-dhcp-server
wget -O /usr/local/etc/oui.txt http://standards-oui.ieee.org/oui.txt


# Network Bridge
apt install bridge-utils

cat >> /etc/netplan/00-router-bridges.yaml <<EOF
network:
  bridges:
    br0:
      interfaces: [enp1s0, enp2s0]
      addresses:
       - 10.0.0.1/24
  version: 2
EOF

netplan generate
netplan apply

sed -i 's|DEFAULT_FORWARD_POLICY="DROP"|DEFAULT_FORWARD_POLICY="ACCEPT"|' /etc/default/ufw
sed -i 's|#net\/ipv4\/ip_forward=1|net\/ipv4\/ip_forward=1|' /etc/ufw/sysctl.conf
sed -i '1s|^|*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.0.0.0/24 -o wlo1 -j MASQUERADE\nCOMMIT\n|' /etc/ufw/before.rules

systemctl enable isc-dhcp-server
systemctl restart isc-dhcp-server.service
systemctl restart bind9.service

systemctl enable ufw.service
ufw disable && ufw enable
ufw allow 22
ufw allow from 10.0.0.0/24 to 10.0.0.1 port 53

reboot


# microk8s

snap install microk8s --classic --channel=1.27

microk8s start
microk8s kubectl get all --all-namespaces
microk8s enable dashboard
microk8s kubectl describe secret -n kube-system microk8s-dashboard-token

~/.ssh/config
  Host mnx1
    Hostname mnx1
    LocalForward 10443 10.152.183.45:443
    LocalForward  3000 127.0.0.1:3000 

https://localhost:10443

https://grafana.com/docs/helm-charts/


sudo usermod -a -G microk8s dml
mkdir ~/.kube
chown -R dml ~/.kube
newgrp microk8s

echo 'alias kubectl="microk8s kubectl"' >> ~/.bashrc
echo 'alias helm="microk8s helm"' >> ~/.bashrc
source ~/.bashrc

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
