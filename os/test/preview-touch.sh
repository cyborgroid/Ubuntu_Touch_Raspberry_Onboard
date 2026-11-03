#!/usr/bin/env bash
# Starts the real GNOME Shell of the target release, with no display and no Raspberry
# Pi, loads the touch extension, and saves screenshots to build/preview/.
#
#   os/test/preview-touch.sh [WIDTHxHEIGHT]
#
# The container boots systemd, because GNOME Shell needs logind and a system bus.
set -euo pipefail

ROOT=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
OUT=$ROOT/build/preview
NAME=cyborgroid-preview
mkdir -p "$OUT"
docker build -q -t cyborgroid-gnome-preview -f "$ROOT/os/test/preview.Dockerfile" "$ROOT/os/test" >/dev/null
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --rm --name "$NAME" --privileged --cgroupns=host -e container=docker \
  -v "$ROOT/os/overlay/usr/share/gnome-shell/extensions/cyborgroid-touch@cyborgroid:/ext:ro" \
  -v "$ROOT/os/overlay/usr/share/backgrounds/cyborgroid-touch.png:/usr/share/backgrounds/cyborgroid-touch.png:ro" \
  -v "$ROOT/os/test:/test:ro" -v "$OUT:/out" cyborgroid-gnome-preview /sbin/init >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
docker exec "$NAME" bash -c 'until systemctl is-system-running 2>/dev/null | grep -qE "running|degraded"; do sleep 1; done'
docker exec -e HOME=/tmp/home -e SIZE="${1:-480x640}" -e OWNER="$(id -u):$(id -g)" "$NAME" /test/preview-inner.sh
echo "==> $OUT"
