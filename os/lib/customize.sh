#!/usr/bin/env bash
# Runs in the privileged builder container. Takes the official image, customizes
# it through loop mounts of its partitions, and shrinks the result.
#   customize.sh <base.img.xz> <output.img> <core binary> <shell publish dir>
set -euo pipefail

BASE=$1 OUT=$2 CORE=$3 SHELL_DIR=$4
HERE=$(dirname "$(readlink -f "$0")")
OS_DIR=$(dirname "$HERE")
EXTRA_SIZE=9G
MNT=$(mktemp -d)
loops=()
qemu_registered_here=0
QEMU_ENTRY=/proc/sys/fs/binfmt_misc/qemu-aarch64

cleanup() {
  set +e
  umount -R "$MNT" 2>/dev/null
  for l in "${loops[@]:-}"; do [ -n "$l" ] && losetup -d "$l"; done
  # binfmt_misc is global to the host, so leave it as it was found.
  [ "$qemu_registered_here" = 1 ] && echo -1 > "$QEMU_ENTRY"
}
trap cleanup EXIT

attach() { # image offset size -> loop device
  local dev
  dev=$(losetup --find --show --offset "$2" --sizelimit "$3" "$1")
  loops+=("$dev")
  echo "$dev"
}

part_field() { # image partnum field(start|size) -> bytes
  sfdisk -J "$1" | python3 -c "import json,sys; p=json.load(sys.stdin)['partitiontable']['partitions'][$2-1]; print(p['$3']*512)"
}

echo "==> registering arm64 emulation"
mountpoint -q /proc/sys/fs/binfmt_misc || mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
if [ ! -e "$QEMU_ENTRY" ]; then
  QEMU_BIN=$(command -v qemu-aarch64-static || command -v qemu-aarch64)
  echo ":qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:$QEMU_BIN:OCF" > /proc/sys/fs/binfmt_misc/register
  qemu_registered_here=1
fi

echo "==> unpacking base image"
xz -dc -T0 "$BASE" > "$OUT"
truncate -s "+$EXTRA_SIZE" "$OUT"
echo ', +' | sfdisk --no-reread --no-tell-kernel -N 2 "$OUT"

ROOT_START=$(part_field "$OUT" 2 start)
ROOT_SIZE=$(part_field "$OUT" 2 size)
BOOT_START=$(part_field "$OUT" 1 start)
BOOT_SIZE=$(part_field "$OUT" 1 size)

ROOT_LOOP=$(attach "$OUT" "$ROOT_START" "$ROOT_SIZE")
BOOT_LOOP=$(attach "$OUT" "$BOOT_START" "$BOOT_SIZE")
e2fsck -fy "$ROOT_LOOP" || [ $? -le 1 ]
resize2fs "$ROOT_LOOP"
mount "$ROOT_LOOP" "$MNT"
mount "$BOOT_LOOP" "$MNT/boot/firmware"
for fs in proc sys dev dev/pts; do mount --rbind "/$fs" "$MNT/$fs"; done

echo "==> copying payload"
cp -a "$OS_DIR/overlay/." "$MNT/"
install -m 755 "$CORE" "$MNT/usr/bin/cyborgroid-core"
mkdir -p "$MNT/opt/cyborgroid/shell"
cp -a "$SHELL_DIR/." "$MNT/opt/cyborgroid/shell/"
ln -sf /opt/cyborgroid/shell/cyborgroid-shell "$MNT/usr/bin/cyborgroid-shell"
mkdir -p "$MNT/tmp/cyborgroid"
cp "$OS_DIR/packages.list" "$MNT/tmp/cyborgroid/"
cp "$HERE/chroot-setup.sh" "$MNT/tmp/cyborgroid/"
cat "$OS_DIR/boot-config.txt" >> "$MNT/boot/firmware/config.txt"
mkdir -p "$MNT/boot/firmware/cyborgroid"

# DNS for apt inside the chroot; the image's own resolv.conf link is restored after.
RESOLV_LINK=$(readlink "$MNT/etc/resolv.conf" || true)
rm -f "$MNT/etc/resolv.conf"
cp /etc/resolv.conf "$MNT/etc/resolv.conf"

echo "==> installing packages (slow: this is emulated arm64)"
chroot "$MNT" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash /tmp/cyborgroid/chroot-setup.sh

rm -f "$MNT/etc/resolv.conf"
[ -n "$RESOLV_LINK" ] && ln -s "$RESOLV_LINK" "$MNT/etc/resolv.conf"

echo "==> shrinking"
umount -R "$MNT"
e2fsck -fy "$ROOT_LOOP" || [ $? -le 1 ]
resize2fs -M "$ROOT_LOOP"
BLOCKS=$(dumpe2fs -h "$ROOT_LOOP" 2>/dev/null | awk '/^Block count:/ {print $3}')
BLOCK_SIZE=$(dumpe2fs -h "$ROOT_LOOP" 2>/dev/null | awk '/^Block size:/ {print $3}')
for l in "${loops[@]}"; do losetup -d "$l"; done
loops=()
NEW_ROOT_SECTORS=$((BLOCKS * BLOCK_SIZE / 512))
echo ", $NEW_ROOT_SECTORS" | sfdisk --no-reread --no-tell-kernel -N 2 "$OUT"
truncate -s $((ROOT_START + NEW_ROOT_SECTORS * 512)) "$OUT"

echo "==> done: $(du -h "$OUT" | cut -f1) $OUT"
