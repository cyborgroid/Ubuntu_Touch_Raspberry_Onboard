#!/usr/bin/env bash
# Imports settings the owner left on the FAT boot partition, which any computer can
# write to, and removes them from there because FAT has no permissions.
set -uo pipefail

SEED=/boot/firmware/cyborgroid
mkdir -p "$SEED"
mountpoint -q /boot/firmware || mount /boot/firmware 2>/dev/null

if [ -f "$SEED/wg0.conf" ]; then
  install -D -m 600 "$SEED/wg0.conf" /etc/wireguard/wg0.conf && rm -f "$SEED/wg0.conf"
fi
for conn in "$SEED"/*.nmconnection; do
  [ -f "$conn" ] || continue
  install -D -m 600 "$conn" "/etc/NetworkManager/system-connections/$(basename "$conn")" && rm -f "$conn"
done
exit 0
