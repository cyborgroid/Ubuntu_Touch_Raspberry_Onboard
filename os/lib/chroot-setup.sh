#!/usr/bin/env bash
# Runs inside the arm64 root filesystem under qemu-user. This stays a standard Ubuntu:
# first-run setup, login, updates and apps are all as shipped; this only adds to them.
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

groupadd --system cyborgroid
useradd --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin \
  --gid cyborgroid cyborgroid-core

chmod +x /usr/lib/cyborgroid/*.sh /usr/bin/cyborgroid-core
glib-compile-schemas /usr/share/gnome-shell/extensions/cyborgroid-touch@cyborgroid/schemas
glib-compile-schemas /usr/share/glib-2.0/schemas

systemctl enable cyborgroid-seed.service cyborgroid-killswitch.service \
  cyborgroid-core.service wg-quick@wg0.service

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/cyborgroid
rm -f /usr/sbin/policy-rc.d
