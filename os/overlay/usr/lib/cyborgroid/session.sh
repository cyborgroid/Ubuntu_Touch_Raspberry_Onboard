#!/usr/bin/env bash
# Runs the session for the current form-factor mode and swaps it when
# cyborgroid-core reports a change: Ubuntu Touch's Lomiri on the touchscreen, the
# standard Ubuntu desktop when a monitor is connected. If Lomiri will not stay up
# it falls back to the Ubuntu desktop, so the device never ends on a blank screen.
set -u

export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

GRID_UNIT_PX=14
# shellcheck source=/dev/null
[ -r /etc/cyborgroid/session.conf ] && . /etc/cyborgroid/session.conf

LOMIRI_MIN_UPTIME=30
POLL_SECS=2
# Set by dm-lomiri-session for the user manager; they would break GNOME apps.
SESSION_ENV="QT_QPA_PLATFORM QT_IM_MODULE GTK_IM_MODULE MALIIT_FORCE_DBUS_CONNECTION UITK_ICON_THEME
  ALARM_BACKEND SDL_VIDEODRIVER QT_WAYLAND_DISABLE_WINDOWDECORATION QT_ACCESSIBILITY
  QT_AUTO_SCREEN_SCALE_FACTOR GTK_CSD GRID_UNIT_PX QT_WAYLAND_FORCE_DPI LOMIRI_RUNNING_IN_VM
  UBUNTU_PLATFORM_API_BACKEND WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP"
lomiri_broken=0

current_mode() { cyborgroid-core query mode 2>/dev/null || echo mobile; }

start_ubuntu() {
  XDG_CURRENT_DESKTOP=ubuntu:GNOME XDG_SESSION_DESKTOP=ubuntu GNOME_SHELL_SESSION_MODE=ubuntu \
    gnome-session --session=ubuntu &
  pid=$!
}

start_touch() {
  # The entry point from lomiri.desktop. It runs Lomiri as a systemd user service
  # and exits when that service does.
  GRID_UNIT_PX=$GRID_UNIT_PX XDG_CURRENT_DESKTOP=Lomiri XDG_SESSION_DESKTOP=lomiri dm-lomiri-session &
  pid=$!
}

stop_user_session() {
  systemctl --user stop lomiri.service graphical-session.target 2>/dev/null
  local name assignments=()
  # shellcheck disable=SC2086
  for name in $SESSION_ENV; do assignments+=("$name="); done
  dbus-update-activation-environment --systemd "${assignments[@]}" 2>/dev/null
  # shellcheck disable=SC2086
  systemctl --user unset-environment $SESSION_ENV 2>/dev/null
}

while :; do
  mode=$(current_mode)
  started=$SECONDS
  if [ "$mode" = mobile ] && [ "$lomiri_broken" = 0 ]; then
    running=touch
    start_touch
  else
    running=ubuntu
    start_ubuntu
  fi
  echo "session: starting $running (mode $mode)"

  changed=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$POLL_SECS"
    if [ "$(current_mode)" != "$mode" ]; then
      echo "session: mode changed, restarting"
      changed=1
      kill -TERM "$pid" 2>/dev/null
      break
    fi
  done
  wait "$pid" 2>/dev/null
  uptime=$((SECONDS - started))
  stop_user_session

  if [ "$changed" = 0 ] && [ "$running" = touch ] && [ "$uptime" -lt "$LOMIRI_MIN_UPTIME" ]; then
    echo "session: Lomiri exited after ${uptime}s, falling back to the Ubuntu desktop"
    lomiri_broken=1
  fi
  sleep 2
done
