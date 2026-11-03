//! Device state read from sysfs and procfs: form-factor mode, battery, VPN.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Mobile,
    Desktop,
}

#[derive(Debug, Clone, Serialize)]
pub struct Battery {
    pub percent: u8,
    pub charging: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct Vpn {
    pub interface_up: bool,
    /// Seconds since the last handshake. None if there has never been one or
    /// `wg` could not be queried.
    pub handshake_age_secs: Option<u64>,
    pub connected: bool,
    pub killswitch: bool,
}

/// WireGuard re-handshakes every 2 minutes on an active tunnel; 180 s is the
/// point at which it gives up on the current session.
const HANDSHAKE_FRESH_SECS: u64 = 180;

fn read_trim(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_owned())
}

pub fn rx_bytes(sys_root: &Path, interface: &str) -> Result<u64, String> {
    let path = sys_root.join("class/net").join(interface).join("statistics/rx_bytes");
    let text = fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?;
    text.trim().parse().map_err(|e| format!("{}: {e}", path.display()))
}

pub fn external_display_connected(sys_root: &Path) -> bool {
    let Ok(entries) = fs::read_dir(sys_root.join("class/drm")) else { return false };
    entries.flatten().any(|e| {
        e.file_name().to_string_lossy().contains("-HDMI-")
            && read_trim(&e.path().join("status")).as_deref() == Some("connected")
    })
}

/// Parses `/proc/bus/input/devices`. Only a USB or Bluetooth device with letter
/// keys counts: the power button, CEC remotes and mouse receivers also register
/// a `kbd` handler but must not flip the device to desktop mode.
pub fn has_external_keyboard(devices: &str) -> bool {
    devices.split("\n\n").any(|block| {
        let external = block
            .lines()
            .next()
            .is_some_and(|l| l.contains("Bus=0003") || l.contains("Bus=0005"));
        let has_letters = block.lines().find_map(|l| l.strip_prefix("B: KEY=")).is_some_and(|k| {
            // The bitmap is hex words, most significant first, 64 bits each.
            // Words are little-endian in bit order, so word 0 is the last one.
            let word0 = k.split_whitespace().last().and_then(|w| u64::from_str_radix(w, 16).ok());
            word0.is_some_and(|w| [16, 30, 44].iter().all(|bit| w & (1 << bit) != 0))
        });
        external && has_letters
    })
}

pub fn detect_mode(sys_root: &Path, proc_root: &Path) -> Mode {
    let devices = fs::read_to_string(proc_root.join("bus/input/devices")).unwrap_or_default();
    if external_display_connected(sys_root) && has_external_keyboard(&devices) {
        Mode::Desktop
    } else {
        Mode::Mobile
    }
}

/// None when there is no fuel gauge, which is the case on a bare Pi 5. The UI
/// must then say so rather than show an invented percentage.
pub fn battery(sys_root: &Path) -> Option<Battery> {
    let entries = fs::read_dir(sys_root.join("class/power_supply")).ok()?;
    entries.flatten().find_map(|e| {
        let p = e.path();
        if read_trim(&p.join("type")).as_deref() != Some("Battery") {
            return None;
        }
        let percent = read_trim(&p.join("capacity"))?.parse::<u8>().ok()?.min(100);
        let status = read_trim(&p.join("status")).unwrap_or_default();
        Some(Battery { percent, charging: status == "Charging" || status == "Full" })
    })
}

/// Parses `wg show <if> latest-handshakes`: `<pubkey>\t<unix-seconds>` per peer,
/// with 0 meaning never. Returns the newest handshake's age.
pub fn parse_handshake_age(output: &str, now_secs: u64) -> Option<u64> {
    output
        .lines()
        .filter_map(|l| l.split_whitespace().nth(1)?.parse::<u64>().ok())
        .filter(|&t| t > 0)
        .max()
        .map(|t| now_secs.saturating_sub(t))
}

pub fn vpn(sys_root: &Path, wg_interface: &str, killswitch_marker: &Path) -> Vpn {
    let interface_up = sys_root.join("class/net").join(wg_interface).exists();
    let handshake_age_secs = interface_up.then(|| {
        let out = Command::new("timeout")
            .args(["5", "wg", "show", wg_interface, "latest-handshakes"])
            .output()
            .ok()?;
        let now = SystemTime::now().duration_since(UNIX_EPOCH).ok()?.as_secs();
        parse_handshake_age(&String::from_utf8_lossy(&out.stdout), now)
    }).flatten();
    Vpn {
        interface_up,
        handshake_age_secs,
        connected: handshake_age_secs.is_some_and(|a| a < HANDSHAKE_FRESH_SECS),
        killswitch: killswitch_marker.exists(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Real-shaped entries: a USB keyboard, a USB mouse receiver and the Pi 5
    // power button, the last two of which also expose the kbd handler.
    const KEYBOARD: &str = "\
I: Bus=0003 Vendor=046d Product=c31c Version=0110
N: Name=\"Logitech USB Keyboard\"
H: Handlers=sysrq kbd event0 leds
B: EV=120013
B: KEY=1000000000007 ff9f207ac14057ff febeffdfffefffff fffffffffffffffe
";
    const MOUSE: &str = "\
I: Bus=0003 Vendor=046d Product=c52b Version=0111
N: Name=\"Logitech Receiver\"
H: Handlers=sysrq kbd mouse0 event1
B: KEY=ffff0000 0 0 0 0
";
    const POWER: &str = "\
I: Bus=0019 Vendor=0001 Product=0001 Version=0100
N: Name=\"pwr_button\"
H: Handlers=kbd event2
B: KEY=fffffffffffffffe
";

    #[test]
    fn only_a_real_external_keyboard_counts() {
        assert!(has_external_keyboard(KEYBOARD));
        assert!(!has_external_keyboard(MOUSE));
        assert!(!has_external_keyboard(POWER));
        assert!(has_external_keyboard(&format!("{POWER}\n{MOUSE}\n{KEYBOARD}")));
        assert!(!has_external_keyboard(&format!("{POWER}\n{MOUSE}")));
    }

    #[test]
    fn handshake_age_uses_newest_peer_and_ignores_never() {
        assert_eq!(parse_handshake_age("k1\t0\nk2\t900\nk3\t950\n", 1000), Some(50));
        assert_eq!(parse_handshake_age("k1\t0\n", 1000), None);
        assert_eq!(parse_handshake_age("", 1000), None);
    }

    fn fake_tree(name: &str) -> std::path::PathBuf {
        let root = std::env::temp_dir().join(format!("cyb-sys-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        root
    }

    #[test]
    fn mode_needs_both_display_and_keyboard() {
        let root = fake_tree("mode");
        let hdmi = root.join("class/drm/card1-HDMI-A-1");
        fs::create_dir_all(&hdmi).unwrap();
        fs::create_dir_all(root.join("bus/input")).unwrap();
        fs::write(root.join("bus/input/devices"), KEYBOARD).unwrap();

        fs::write(hdmi.join("status"), "disconnected\n").unwrap();
        assert_eq!(detect_mode(&root, &root), Mode::Mobile);

        fs::write(hdmi.join("status"), "connected\n").unwrap();
        assert_eq!(detect_mode(&root, &root), Mode::Desktop);

        fs::write(root.join("bus/input/devices"), POWER).unwrap();
        assert_eq!(detect_mode(&root, &root), Mode::Mobile);
        fs::remove_dir_all(&root).unwrap();
    }

    #[test]
    fn battery_is_absent_without_a_gauge() {
        let root = fake_tree("bat");
        assert!(battery(&root).is_none());
        let ac = root.join("class/power_supply/rpi-usb");
        fs::create_dir_all(&ac).unwrap();
        fs::write(ac.join("type"), "USB\n").unwrap();
        assert!(battery(&root).is_none());

        let bat = root.join("class/power_supply/BAT0");
        fs::create_dir_all(&bat).unwrap();
        fs::write(bat.join("type"), "Battery\n").unwrap();
        fs::write(bat.join("capacity"), "78\n").unwrap();
        fs::write(bat.join("status"), "Charging\n").unwrap();
        let b = battery(&root).unwrap();
        assert_eq!((b.percent, b.charging), (78, true));
        fs::remove_dir_all(&root).unwrap();
    }
}
