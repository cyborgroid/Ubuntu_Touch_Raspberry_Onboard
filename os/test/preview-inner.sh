#!/usr/bin/env bash
# Container half of preview-touch.sh. Runs as root because GNOME 50's image loader
# sandboxes itself with user namespaces, which Ubuntu's AppArmor policy on the host
# denies to an ordinary user in a container. A real session has no such problem.
set -uo pipefail

UUID=cyborgroid-touch@cyborgroid
HOME_DIR=/root
RUN_DIR=/run/user/0
mkdir -p "$RUN_DIR" "$HOME_DIR/.local/share/gnome-shell/extensions" "$HOME_DIR/Desktop"
chmod 700 "$RUN_DIR"
rm -rf "$HOME_DIR/.local/share/gnome-shell/extensions/$UUID"
cp -r /ext "$HOME_DIR/.local/share/gnome-shell/extensions/$UUID"
glib-compile-schemas "$HOME_DIR/.local/share/gnome-shell/extensions/$UUID/schemas"

cat > /tmp/session.sh <<SESSION
#!/usr/bin/env bash
set -uo pipefail
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.shell enabled-extensions "['$UUID']"
gsettings set org.gnome.desktop.input-sources sources "[('xkb','us'),('ibus','hangul')]"
XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=ubuntu:GNOME XDG_SESSION_DESKTOP=ubuntu GNOME_SHELL_SESSION_MODE=ubuntu \
  gnome-shell --mode=ubuntu --headless --wayland --unsafe-mode --virtual-monitor $SIZE >/out/shell.log 2>&1 &
shell=\$!
for _ in \$(seq 1 60); do
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "1+1" >/dev/null 2>&1 && break
  sleep 1
done
sleep 6
evalshell() { gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "\$1"; }
shot() { gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot --method org.gnome.Shell.Screenshot.Screenshot false false "/out/\$1.png" >/dev/null; }
export -f evalshell shot
source /test/preview-steps.sh
kill \$shell
SESSION
chmod +x /tmp/session.sh
env HOME="$HOME_DIR" XDG_RUNTIME_DIR="$RUN_DIR" LANG=C.UTF-8 LC_ALL=C.UTF-8 dbus-run-session -- /tmp/session.sh
chown -R "$OWNER" /out
chown -R "$OWNER" /out
