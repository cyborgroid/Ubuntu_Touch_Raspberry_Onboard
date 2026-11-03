#!/usr/bin/env bash
# Runs inside the arm64 root filesystem under qemu-user.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8

# Keep maintainer scripts from starting services in the build chroot.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

apt-get update
# Deliberately no dist-upgrade: the kernel and firmware stay as shipped in the
# official image, whose boot chain is the part that has been tested on a Pi 5.
grep -vE '^[[:space:]]*(#|$)' /tmp/cyborgroid/packages.list \
  | xargs apt-get install -y --no-install-recommends

# cloud-init and snapd are server provisioning; firstboot.sh replaces the former.
apt-get purge -y cloud-init snapd
apt-get autoremove -y
rm -rf /var/lib/snapd /etc/cloud /var/lib/cloud /etc/netplan/50-cloud-init.yaml

groupadd --system cyborgroid
for group in netdev bluetooth plugdev; do groupadd --force --system "$group"; done
useradd --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin \
  --gid cyborgroid cyborgroid-core
# Password stays locked until firstboot.sh sets a per-device one.
useradd --create-home --shell /bin/bash \
  --groups cyborgroid,sudo,video,render,input,audio,netdev,plugdev,bluetooth cyborg
passwd --lock cyborg

chmod 600 /etc/netplan/*.yaml
chmod +x /usr/lib/cyborgroid/*.sh /usr/bin/cyborgroid-core

systemctl set-default graphical.target
systemctl enable cyborgroid-firstboot.service cyborgroid-killswitch.service \
  cyborgroid-core.service cyborgroid-session.service NetworkManager.service wg-quick@wg0.service
systemctl disable ssh.service ssh.socket systemd-networkd-wait-online.service getty@tty1.service || true

# The image must not carry identity shared by every device flashed from it.
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
echo cyborgroid > /etc/hostname
sed -i '/127.0.1.1/d' /etc/hosts
echo '127.0.1.1 cyborgroid' >> /etc/hosts

apt-get clean
rm -rf /var/lib/apt/lists/* /var/log/apt/* /var/log/dpkg.log /tmp/cyborgroid
rm -f /usr/sbin/policy-rc.d
