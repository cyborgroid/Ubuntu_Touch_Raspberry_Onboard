# Sourced inside the running session of preview-inner.sh; has evalshell and shot.
SCHEMAS="$HOME/.local/share/gnome-shell/extensions/cyborgroid-touch@cyborgroid/schemas"
UUID=cyborgroid-touch@cyborgroid

# Eval runs with the shell's own modules loaded through a dynamic import. "probe" lines
# land in shell.log. M is the Main module, X the extension's instance.
shell_do() {
  evalshell "import('resource:///org/gnome/shell/ui/main.js').then(M => { const X = M.extensionManager.lookup('$UUID').stateObj; const probe = t => console.log('PROBE ' + t); $1 }).catch(e => console.log('PROBE error ' + e))" >/dev/null
  sleep 1
}

# Real touch input through Clutter, so it hits whatever is on screen.
TOUCH="const C = imports.gi.Clutter; const d = C.get_default_backend().get_default_seat().create_virtual_device(C.InputDeviceType.TOUCHSCREEN_DEVICE); const t = imports.gi.GLib.get_monotonic_time();"
tap() {
  shell_do "$TOUCH d.notify_touch_down(t, 0, $1, $2); d.notify_touch_up(t + 40000, 0);"
}
swipe() { # x1 y1 x2 y2
  shell_do "$TOUCH d.notify_touch_down(t, 0, $1, $2); for (let i = 1; i <= 12; i++) d.notify_touch_motion(t + i * 20000, 0, $1 + ($3 - $1) * i / 12, $2 + ($4 - $2) * i / 12); d.notify_touch_up(t + 280000, 0);"
}

shell_do "probe('state ' + M.extensionManager.lookup('$UUID').state + ' touch ' + X._touch + ' overview ' + M.overview.visible + ' monitors ' + global.backend.get_monitor_manager().get_monitors().map(m => m.get_connector()).join(','))"
# The notice about running as root belongs to this test setup only.
shell_do "M.messageTray.getSources().forEach(s => s.destroy()); M.messageTray.bannerBlocked = true; X._home.setBattery(78, true);"
sleep 2
shot home

# The notes tile in the first row: opens the app.
tap 174 90
sleep 8
shell_do "probe('after tap: ' + global.get_window_actors().map(a => a.meta_window.get_wm_class() + ' ' + a.meta_window.get_frame_rect().width + 'x' + a.meta_window.get_frame_rect().height).join(', '))"
shot app
pkill -f gnome-text-editor; sleep 3

shell_do "M.overview.showApps();"
sleep 3
shot all-apps
shell_do "M.overview.hide();"
sleep 2

# From the left edge, as on Ubuntu Touch: reveals the launcher.
swipe 1 300 140 300
sleep 2
shot launcher
sleep 3

# From the right edge: the spread of open apps.
gnome-calculator >/dev/null 2>&1 &
sleep 6
swipe 478 300 300 300
sleep 3
shell_do "probe('right edge: overview ' + M.overview.visible);"
shot spread
shell_do "M.overview.hide();"
pkill -f gnome-calculator; sleep 3

# From the top edge: quick settings.
swipe 240 1 240 200
sleep 2
shell_do "probe('top edge: quick settings ' + M.panel.statusArea.quickSettings.menu.isOpen);"
shot quick-settings
shell_do "M.panel.statusArea.quickSettings.menu.close();"
sleep 2

# The on-screen keyboard, with the Korean input source: the keys for 한글 (g k s r m f).
ibus-daemon -d -r
sleep 4
gnome-text-editor >/dev/null 2>&1 &
sleep 8
evalshell "import('resource:///org/gnome/shell/ui/status/keyboard.js').then(K => { const m = K.getInputSourceManager(); console.log('PROBE sources ' + Object.values(m.inputSources).map(i => i.type + ':' + i.id).join(',')); m.inputSources[1].activate(true); }).catch(e => console.log('PROBE error ' + e))" >/dev/null
sleep 4
tap 240 200
sleep 5
shell_do "const k = M.keyboard._keyboard; probe('keyboard visible ' + k?.visible + ' at ' + k?.get_transformed_position() + ' size ' + k?.get_transformed_size());"
shot keyboard-korean
source /test/preview-keys.sh 2>/dev/null
sleep 2
shot typed-korean
pkill -f gnome-text-editor; sleep 3

gsettings --schemadir "$SCHEMAS" set org.gnome.shell.extensions.cyborgroid-touch mode-override desktop
sleep 4
shell_do "probe('desktop mode: touch ' + X._touch + ' style ' + M.layoutManager.uiGroup.has_style_class_name('cyborgroid-touch'))"
gsettings get org.gnome.desktop.interface color-scheme
shot desktop

gsettings --schemadir "$SCHEMAS" set org.gnome.shell.extensions.cyborgroid-touch mode-override touch
sleep 4
shell_do "X._home.setBattery(78, true); probe('back to touch: touch ' + X._touch);"
sleep 2
shot touch-again
