#!/usr/bin/env bash
# Boots a throwaway copy of the image under QEMU and reports what came up.
#
#   os/test/boot-test.sh build/cyborgroid-pi5-YYYYMMDD.img
#
# FIRSTRUN=1 boots as a fresh card, to see Ubuntu's first-run setup. Otherwise the copy
# gets a test account that logs in by itself. SEED_WG=1 also seeds a WireGuard config.
#
# QEMU has no Pi 5 model, so this uses its generic `virt` board. It exercises the whole
# userland (systemd units, GNOME, the touch extension, Korean input) but NOT the Pi
# firmware, the DSI panel or the Wi-Fi chip.
set -euo pipefail

IMG=$(readlink -f "$1")
ROOT=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
OUT=$ROOT/build/boot-test${SEED_WG:+-seeded}${FIRSTRUN:+-firstrun}
mkdir -p "$OUT"

docker run --rm --privileged --name cyborgroid-boot-test -e SEED_WG="${SEED_WG:-}" -e FIRSTRUN="${FIRSTRUN:-}" \
  -v "$ROOT/os:/os:ro" -v "$IMG:/image.img:ro" -v "$OUT:/out" ubuntu:26.04 \
  bash -euc '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends qemu-system-arm qemu-utils ipxe-qemu \
      python3 fdisk mount xz-utils wireguard-tools >/dev/null
    /os/test/boot-test-inner.sh
  '
