#!/usr/bin/env bash
# Runs inside the booted test VM; every line goes to the serial log. The markers
# drive os/test/qmp-watch.py, which takes the screenshots and sends the input.
export LC_ALL=C.UTF-8
USER_NAME=tester
EXT_SCHEMAS=/usr/share/gnome-shell/extensions/cyborgroid-touch@cyborgroid/schemas
sec() { echo; echo "##### $*"; }
tap() { echo "@@TAP $1 $2"; sleep "${3:-3}"; }
keys() { echo "@@KEYS $*"; sleep 2; }
shot() { echo "@@SHOT $1"; sleep 8; }
wait_for() { # process seconds
  local i
  for ((i = 0; i < $2; i += 5)); do
    pgrep -x "$1" >/dev/null && { echo "$1 running after ${i}s"; return 0; }
    sleep 5
  done
  echo "$1 NOT running after $2s"
  return 1
}
sec "probe started"

if ! id "$USER_NAME" >/dev/null 2>&1; then
  # A freshly flashed card: no account yet, so Ubuntu's first-run setup should be up.
  wait_for gnome-shell 900
  sleep 150
  sec "first run"
  systemctl is-active gdm cyborgroid-core cyborgroid-killswitch
  ps -eo user,comm | grep -E 'gnome-initial|gnome-shell|gdm' | sort -u
  shot firstrun
  echo "@@DONE"
  exit 0
fi

uid=$(id -u "$USER_NAME")
as_user() {
  timeout 60 runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" WAYLAND_DISPLAY=wayland-0 "$@"
}
set_mode() { as_user gsettings --schemadir "$EXT_SCHEMAS" set org.gnome.shell.extensions.cyborgroid-touch mode-override "$1"; }

wait_for gnome-shell 900
until as_user gnome-extensions info cyborgroid-touch@cyborgroid >/dev/null 2>&1; do sleep 5; done
sleep 120
# Ubuntu's own welcome window, which any new account sees once. It would cover the home
# screen and take the taps meant for it.
pkill -f gnome-initial-setup; sleep 10

sec "system"
systemctl is-system-running
systemctl --no-pager --failed
for u in gdm cyborgroid-seed cyborgroid-killswitch cyborgroid-core wg-quick@wg0; do
  printf '%-24s active=%s enabled=%s\n' "$u" "$(systemctl is-active "$u")" "$(systemctl is-enabled "$u" 2>/dev/null)"
done
loginctl list-sessions --no-pager | cut -c1-70
free -h | sed -n 2p | sed 's/^Mem:/RAM:/'

sec "extension"
as_user gnome-extensions info cyborgroid-touch@cyborgroid | grep -E 'State|Enabled'
as_user gsettings get org.gnome.shell enabled-extensions
as_user gsettings get org.gnome.desktop.input-sources sources
as_user gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled
journalctl _UID="$uid" --no-pager | grep -iE 'JS ERROR|cyborgroid' | tail -8 | cut -c1-170

sec "permissions"
stat -c '%U:%G %a %n' / /etc /usr /usr/lib/cyborgroid/wireguard-killswitch.sh /usr/bin/cyborgroid-core /opt/cyborgroid/shell/cyborgroid-shell
for path in /etc /usr/lib/cyborgroid/wireguard-killswitch.sh /usr/share/gnome-shell/extensions/cyborgroid-touch@cyborgroid/extension.js; do
  if runuser -u "$USER_NAME" -- test -w "$path"; then echo "WRITABLE by user: $path"; else echo "not writable by user: $path"; fi
done
runuser -u "$USER_NAME" -- sudo -n true 2>&1 | head -1

sec "core engine and network"
runuser -u "$USER_NAME" -- cyborgroid-core query status | cut -c1-260
ip -br addr | cut -c1-70
if timeout 25 bash -c '</dev/tcp/archive.ubuntu.com/80' 2>/dev/null; then echo "egress: ok"; else echo "egress: blocked"; fi
ls -la /etc/wireguard/ /boot/firmware/cyborgroid/ 2>&1 | cut -c1-70
systemctl is-active cyborgroid-killswitch wg-quick@wg0
iptables -S | head -12
ip6tables -S | sed -n 1,3p

sec "home screen"
shot home

sec "tap tiles"
close_app() { keys alt-f4; sleep "${1:-6}"; }
open_tile() { # name x y seconds
  tap "$2" "$3" "$4"
  echo "$1: $(ps -eo comm --sort=-start_time | head -4 | tr '\n' ' ')"
  shot "tap-$1"
}
open_tile notes 174 92 30
tap 457 51 6                 # the window's close button
shot back-home
open_tile phone 68 92 40; close_app
open_tile files 296 199 25; close_app
open_tile documents 411 199 20; close_app
open_tile network 296 305 40; close_app
open_tile settings 411 305 30; close_app
open_tile video 68 305 30; close_app
open_tile token 296 412 25; close_app
open_tile browser 182 199 150; close_app 15
open_tile all-apps 411 412 8; keys esc; sleep 5
shot home-again

sec "Korean: typed with a hardware key, then on the on-screen keyboard"
tap 174 92 30                # notes
tap 240 200 5
keys meta_l-spc
sleep 6
shot osk-korean
journalctl _UID="$uid" --no-pager -n 300 | grep -iE 'ibus|hangul' | tail -5 | cut -c1-150
pgrep -a ibus-engine | cut -c1-70
for key in g k s r m f; do keys "$key"; done
keys spc
shot typed-hardware
tap 209 529; tap 336 529; tap 84 529   # on-screen keys for ㅎ ㅏ ㄴ
tap 147 485; tap 313 573; tap 167 529  # and ㄱ ㅡ ㄹ
shot typed-onscreen
keys meta_l-spc
pkill -f gnome-text-editor; sleep 5

sec "monitor connected: plain Ubuntu, apps still open"
runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" WAYLAND_DISPLAY=wayland-0 gnome-calculator >/dev/null 2>&1 &
sleep 30
set_mode desktop
sleep 25
as_user gsettings get org.gnome.desktop.interface color-scheme
pgrep -x gnome-calculato >/dev/null && echo "app survived the switch" || echo "app did NOT survive"
shot ubuntu-desktop

sec "monitor removed: touch again"
set_mode auto
sleep 25
pgrep -x gnome-calculato >/dev/null && echo "app survived the switch back" || echo "app did NOT survive"
pkill -x gnome-calculato; sleep 5
shot touch-again

sec "fingerprint button locks the screen, as standard Ubuntu"
tap 240 573 12
as_user gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.GetActive
shot locked

sec "errors"
journalctl -b -p err --no-pager -n 12 | cut -c1-160
ls /var/crash/ 2>/dev/null
for crash in /var/crash/*.crash; do [ -f "$crash" ] && grep -aE '^(ExecutablePath|Signal):' "$crash"; done
echo "@@DONE"
