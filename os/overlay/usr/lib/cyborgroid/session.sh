#!/usr/bin/env bash
# Runs the compositor for the current form-factor mode and swaps it when
# cyborgroid-core reports a change. Mobile is sway with the Avalonia home screen;
# desktop is the Lomiri session, falling back to sway if Lomiri will not stay up.
set -u

export XDG_CURRENT_DESKTOP=sway
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
export PATH=/usr/local/bin:/usr/bin:/bin

CONFIG_DIR=/usr/share/cyborgroid/sway
LOMIRI_MIN_UPTIME=15
POLL_SECS=2
lomiri_broken=0

current_mode() { cyborgroid-core query mode 2>/dev/null || echo mobile; }

start_compositor() {
  case "$1" in
    desktop)
      if [ "$lomiri_broken" = 0 ] && command -v lomiri-session >/dev/null; then
        XDG_CURRENT_DESKTOP=Lomiri lomiri-session &
      else
        sway --config "$CONFIG_DIR/desktop.conf" &
      fi
      ;;
    *) sway --config "$CONFIG_DIR/mobile.conf" & ;;
  esac
  pid=$!
}

while :; do
  mode=$(current_mode)
  started=$SECONDS
  echo "session: starting $mode"
  start_compositor "$mode"
  changed=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$POLL_SECS"
    if [ "$(current_mode)" != "$mode" ]; then
      echo "session: mode changed, restarting compositor"
      changed=1
      kill -TERM "$pid" 2>/dev/null
      break
    fi
  done
  wait "$pid" 2>/dev/null
  if [ "$changed" = 0 ] && [ "$mode" = desktop ] && [ $((SECONDS - started)) -lt "$LOMIRI_MIN_UPTIME" ]; then
    echo "session: desktop session exited early, falling back to sway"
    lomiri_broken=1
  fi
  sleep 1
done
