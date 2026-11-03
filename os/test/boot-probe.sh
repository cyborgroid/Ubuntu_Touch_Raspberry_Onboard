#!/usr/bin/env bash
# Runs inside the booted test VM; every line goes to the serial log. The markers
# drive os/test/qmp-watch.py, which takes the screenshots.
export LC_ALL=C.UTF-8
sec() { echo; echo "##### $*"; }
sec "probe started"

uid=$(id -u cyborg)
as_cyborg() {
  timeout 60 sudo -u cyborg env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@"
}
session_log() { journalctl _UID="$uid" --no-pager | grep -E 'session: ' | tail -"$1"; }
wait_for() { # process-name max-seconds
  local i
  for ((i = 0; i < $2; i += 5)); do
    pgrep -u cyborg -x "$1" >/dev/null && { echo "$1 running after ${i}s"; return 0; }
    sleep 5
  done
  echo "$1 NOT running after $2s"
  return 1
}

wait_for lomiri 900
sleep 60

sec "system state"
systemctl is-system-running
systemctl --no-pager --failed
sec "cyborgroid units"
for u in cyborgroid-firstboot cyborgroid-killswitch cyborgroid-core cyborgroid-session wg-quick@wg0 ssh gdm3 cloud-init; do
  printf '%-26s active=%s enabled=%s\n' "$u" "$(systemctl is-active "$u")" "$(systemctl is-enabled "$u" 2>/dev/null)"
done
sec "first boot"
df -h / | tail -1
ls -la /home/cyborg/initial-password.txt
test -s /home/cyborg/initial-password.txt && echo "password file non-empty"
passwd --status cyborg
ls /etc/ssh/ssh_host_ed25519_key
wc -c /etc/machine-id
sec "ownership (the auto-login user must not be able to change the system)"
stat -c '%U:%G %a %n' / /etc /usr /etc/sudoers.d /usr/lib/cyborgroid/firstboot.sh /usr/lib/cyborgroid/wireguard-killswitch.sh \
  /etc/systemd/system/cyborgroid-firstboot.service /usr/bin/cyborgroid-core /opt/cyborgroid/shell/cyborgroid-shell
echo "system files owned by cyborg: $(find /etc /usr /opt -xdev -user cyborg 2>/dev/null | wc -l)"
for path in /etc /usr/lib/cyborgroid/firstboot.sh /etc/systemd/system; do
  if sudo -u cyborg test -w "$path"; then echo "WRITABLE by cyborg: $path"; else echo "not writable by cyborg: $path"; fi
done
sudo -u cyborg sudo -n true 2>&1 | head -1
sec "core engine"
ls -la /run/cyborgroid/
sudo -u cyborg cyborgroid-core query mode
sudo -u cyborg cyborgroid-core query status | cut -c1-400
systemctl show cyborgroid-core -p User -p NRestarts -p CapabilityBoundingSet --no-pager
sec "network"
ip -br addr
nmcli -t -f DEVICE,TYPE,STATE device status
if timeout 25 bash -c '</dev/tcp/archive.ubuntu.com/80' 2>/dev/null; then echo "egress: ok"; else echo "egress: blocked"; fi
sec "kill-switch"
ls -la /etc/wireguard/ /boot/firmware/cyborgroid/
systemctl --no-pager --lines=4 status cyborgroid-killswitch wg-quick@wg0 | cut -c1-120
wg show 2>&1 | grep -v 'private key' | cut -c1-80
iptables -S | head -30
ip6tables -S | head -6

sec "touch mode: Ubuntu Touch (Lomiri)"
session_log 6
ps -eo user,comm | grep -iE 'lomiri|maliit|gnome-shell|mir' | sort -u
as_cyborg systemctl --user --no-pager --lines=15 status lomiri.service 2>&1 | cut -c1-170
as_cyborg systemctl --user show-environment | grep -E '^(GRID_UNIT_PX|XDG_CURRENT_DESKTOP|WAYLAND_DISPLAY)='
echo "@@SHOT touch"; sleep 8

sec "open apps inside Lomiri"
as_cyborg lomiri-app-launch cyborgroid; echo "launch cyborgroid rc=$?"
sleep 75
pgrep -a -u cyborg -f /opt/cyborgroid/shell/cyborgroid-shell | cut -c1-120
journalctl _UID="$uid" --no-pager -n 400 | grep -iE 'cyborgroid-shell|avalonia' | tail -12 | cut -c1-190
echo "@@SHOT dashboard"; sleep 8
as_cyborg lomiri-app-launch lomiri-calculator-app; echo "launch calculator rc=$?"
sleep 75
pgrep -a -u cyborg -f calculator | cut -c1-100
echo "@@SHOT app"; sleep 8

sec "monitor connected: standard Ubuntu desktop (forced, the VM has no HDMI)"
sudo -u cyborg cyborgroid-core set-mode desktop
wait_for gnome-shell 420
sleep 90
session_log 6
ps -eo user,comm | grep -iE 'lomiri|gnome-shell|gnome-session' | sort -u
journalctl _UID="$uid" --no-pager -n 600 | grep -E 'gnome-shell|gnome-session' | grep -iE 'error|fail|fatal' | tail -10 | cut -c1-190
echo "@@SHOT ubuntu-desktop"; sleep 8

sec "monitor removed: back to Ubuntu Touch"
sudo -u cyborg cyborgroid-core set-mode mobile
sleep 15
wait_for lomiri 420
sleep 60
session_log 6
ps -eo user,comm | grep -iE 'lomiri|gnome-shell' | sort -u
echo "cyborgroid shell processes: $(pgrep -c -u cyborg -f /opt/cyborgroid/shell/cyborgroid-shell)"
journalctl -b -p err --no-pager -n 15 | cut -c1-170
echo "@@SHOT touch-again"; sleep 8
echo "@@DONE"
