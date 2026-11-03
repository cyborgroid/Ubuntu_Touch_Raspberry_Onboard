#!/usr/bin/env bash
# Runs inside the booted test VM; every line goes to the serial log. The markers
# drive os/test/qmp-watch.py, which takes the screenshots.
export LC_ALL=C.UTF-8
sec() { echo; echo "##### $*"; }
sec "probe started"

as_cyborg() {
  local uid; uid=$(id -u cyborg)
  timeout 30 sudo -u cyborg env XDG_RUNTIME_DIR="/run/user/$uid" SWAYSOCK="$(ls /run/user/"$uid"/sway-ipc.*.sock 2>/dev/null | head -1)" "$@"
}

# Give the session time to settle; TCG is slow.
for _ in $(seq 1 60); do
  as_cyborg swaymsg -t get_tree 2>/dev/null | grep -q cyborgroid-shell && break
  sleep 5
done
sleep 20

sec "system state"
systemctl is-system-running
systemctl --no-pager --failed
sec "cyborgroid units"
for u in cyborgroid-firstboot cyborgroid-killswitch cyborgroid-core cyborgroid-session wg-quick@wg0 ssh; do
  printf '%-26s active=%s enabled=%s\n' "$u" "$(systemctl is-active "$u")" "$(systemctl is-enabled "$u" 2>/dev/null)"
done
sec "first boot"
df -h / | tail -1
ls -la /home/cyborg/initial-password.txt
test -s /home/cyborg/initial-password.txt && echo "password file non-empty"
passwd --status cyborg
ls /etc/ssh/ssh_host_ed25519_key
wc -c /etc/machine-id
sec "core engine"
ls -la /run/cyborgroid/
sudo -u cyborg cyborgroid-core query mode
sudo -u cyborg cyborgroid-core query status
systemctl show cyborgroid-core -p User -p NRestarts -p CapabilityBoundingSet --no-pager
sec "session journal"
journalctl -u cyborgroid-session --no-pager -n 25
sec "sway windows"
as_cyborg swaymsg -t get_tree | python3 -c '
import json, sys
def walk(n):
    if n.get("pid"):
        print(n.get("app_id"), (n.get("window_properties") or {}).get("class"), "visible=%s" % n.get("visible"), n.get("name"), n["rect"]["width"], n["rect"]["height"])
    for c in n.get("nodes", []) + n.get("floating_nodes", []): walk(c)
walk(json.load(sys.stdin))'
as_cyborg swaymsg -t get_outputs | python3 -c 'import json,sys; [print(o["name"], o["current_mode"]) for o in json.load(sys.stdin)]'
ps -eo user,comm | grep -E 'sway|waybar|wvkbd|cyborgroid' | sort -u
echo "@@SHOT mobile"; sleep 8

sec "launch a Lomiri app from the mobile session"
as_cyborg swaymsg workspace number 2
as_cyborg swaymsg exec -- lomiri-calculator-app
sleep 60
as_cyborg swaymsg -t get_tree | grep -oE '"app_id": "[^"]+"' | sort -u
echo "@@SHOT app"; sleep 8
as_cyborg swaymsg workspace number 1

sec "automatic mode switch to desktop (forced, the VM has no HDMI)"
sudo -u cyborg cyborgroid-core set-mode desktop
sleep 150
ps -eo user,comm | grep -iE 'lomiri|sway|mir' | sort -u
journalctl -u cyborgroid-session --no-pager -n 15
echo "@@SHOT desktop"; sleep 8

sudo -u cyborg cyborgroid-core set-mode mobile
sleep 60
ps -eo user,comm | grep -iE 'lomiri|sway' | sort -u
journalctl -b -p err --no-pager -n 25
echo "@@SHOT mobile-again"; sleep 8
echo "@@DONE"
