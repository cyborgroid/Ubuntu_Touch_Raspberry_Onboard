#!/usr/bin/env bash
# Boots a throwaway copy of the image under QEMU and reports what came up.
#
#   os/test/boot-test.sh build/cyborgroid-pi5-YYYYMMDD.img
#
# QEMU has no Pi 5 model, so this uses its generic `virt` board. It exercises the
# whole userland (systemd units, first boot, core daemon, compositor, home screen)
# but NOT the Pi firmware, the DSI panel or the Wi-Fi chip.
set -euo pipefail

IMG=$(readlink -f "$1")
ROOT=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
OUT=$ROOT/build/boot-test
mkdir -p "$OUT"

docker run --rm --privileged --name cyborgroid-boot-test \
  -v "$ROOT/os/test:/test:ro" -v "$IMG:/image.img:ro" -v "$OUT:/out" ubuntu:26.04 \
  bash -euc '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends qemu-system-arm qemu-utils ipxe-qemu \
      python3 fdisk mount xz-utils >/dev/null
    /test/boot-test-inner.sh
  '
