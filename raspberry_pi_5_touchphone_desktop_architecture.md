# 📱 Raspberry Pi 5 Touchphone Desktop & Data Engine

An open architecture specification for a mobile-desktop hybrid device built on Raspberry Pi 5. This project turns a single-board computer into an independent **Touchphone Desktop**, featuring hardware-integrated VPN protection, cell network connectivity, and a background engine that mints data tokens based on network traffic usage.

---

## 📸 1. Hardware Concept & Components

### 1.1 Core Hardware
* **Main Unit:** Raspberry Pi 5 (Broadcom BCM2712 SoC, RP1 I/O Controller)
* **Display:** 4" to 7" DSI Touchscreen / Portable HDMI Touch Monitor
* **Cellular & Phone Connectivity:** SIM7600 or EC25 LTE/5G HAT (with SIM Card Slot & Antenna extensions)
* **Enclosure:** Flirc Aluminum Passive-Cooling Case or Custom 3D Printed Wi-Fi/Router Style Case (with SMA antenna mounts)

### 1.2 Form Factor Modes
* **Mobile Mode:** High-portability touch-based smartphone running on LTE/Wi-Fi.
* **Desktop Mode:** Instant convergence to a desktop computer when plugged into an external monitor, keyboard, and mouse.

---

## 🔒 2. Privacy & Network Infrastructure

* **Borderless Communication (WireGuard Hardware Integration):**
  * WireGuard / OpenVPN kernel-level tunneling configured directly at boot.
  * System-wide Kill-Switch: Immediate network termination if the VPN tunnel breaks to prevent IP exposure.
* **Independent Ecosystem:**
  * Complete detachment from big-tech accounts (Google, Apple, Microsoft) and centralized data collection.
  * User-owned OS environment operating on local storage.

---

## 🏗️ 3. Software Architecture: C# & Rust Dual-Core

```
+-----------------------------------------------------------+
|                   C# (.NET / Avalonia UI)                 |
|  - Touch-Optimized Mobile UI                              |
|  - Desktop Convergence UI                                 |
|  - Real-Time Token Wallet & Data Usage Dashboard          |
+-----------------------------------------------------------+
                             |
             IPC (Unix Domain Socket / gRPC)
                             |
+-----------------------------------------------------------+
|                    Rust Core Engine                       |
|  - Linux Low-level Traffic Sniffing (/sys/class/net)      |
|  - Real-Time Data-to-Token Minting Engine                 |
|  - AT Command Driver for LTE/SIM Control                  |
|  - System Health & VPN Status Monitoring                  |
+-----------------------------------------------------------+
```

---

## ⚙️ 4. Data-to-Token Minting Engine (Rust Proof of Concept)

Below is the core Rust daemon that continuously tracks system network traffic (`wwan0` or `eth0`) and mints data tokens dynamically:

```rust
use std::fs;
use std::thread;
use std::time::Duration;

fn get_interface_bytes(interface: &str) -> Result<u64, Box<dyn std::error::Error>> {
    let path = format!("/sys/class/net/{}/statistics/rx_bytes", interface);
    let data = fs::read_to_string(path)?;
    let bytes: u64 = data.trim().parse()?;
    Ok(bytes)
}

fn main() {
    let interface = "wwan0"; // Target LTE/Mobile Data Interface
    let mut last_bytes = get_interface_bytes(interface).unwrap_or(0);
    let mut accumulated_tokens: f64 = 0.0;

    println!("Starting Traffic-to-Token Engine on {}...", interface);

    loop {
        thread::sleep(Duration::from_secs(5));
        
        match get_interface_bytes(interface) {
            Ok(current_bytes) => {
                if current_bytes > last_bytes {
                    let diff = current_bytes - last_bytes;
                    // Minting Formula: 0.01 Token per 1 MB (1,048,576 bytes)
                    let earned_tokens = (diff as f64 / 1_048_576.0) * 0.01;
                    accumulated_tokens += earned_tokens;
                    
                    println!("Traffic detected: {} bytes | Minted Tokens: {:.4} (Total: {:.4})", 
                             diff, earned_tokens, accumulated_tokens);
                }
                last_bytes = current_bytes;
            }
            Err(e) => eprintln!("Failed to read interface stats: {}", e),
        }
    }
}
```

---

## 🚀 5. Getting Started & Roadmap

1. **Phase 1: Assembly** — Mount RPi 5 into aluminum/3D printed enclosure; attach DSI touchscreen and LTE HAT with SIM card.
2. **Phase 2: OS & Kernel** — Flash Ubuntu Touch or customized Ubuntu Desktop; configure WireGuard VPN autostart.
3. **Phase 3: Engine Build** — Compile `rust-core` daemon to measure data throughput and issue local token ledgers.
4. **Phase 4: Dashboard** — Launch C# Avalonia UI desktop application connected to the Rust engine for real-time status display.