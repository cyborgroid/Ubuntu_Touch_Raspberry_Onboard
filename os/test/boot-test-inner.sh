#!/usr/bin/env bash
# Container half of boot-test.sh.
set -euo pipefail

WORK=$(mktemp -d)
MNT=$(mktemp -d)
loops=()
cleanup() {
  set +e
  umount -R "$MNT" 2>/dev/null
  for l in "${loops[@]:-}"; do [ -n "$l" ] && losetup -d "$l"; done
  pkill qemu-system 2>/dev/null
}
trap cleanup EXIT

part() { sfdisk -J "$1" | python3 -c "import json,sys; p=json.load(sys.stdin)['partitiontable']['partitions'][$2-1]; print(p['start']*512, p['size']*512)"; }

echo "==> making a disposable copy"
cp --sparse=always /image.img "$WORK/disk.img"
read -r BOOT_OFF BOOT_SIZE < <(part "$WORK/disk.img" 1)
read -r ROOT_OFF ROOT_SIZE < <(part "$WORK/disk.img" 2)

BOOT_LOOP=$(losetup --find --show --offset "$BOOT_OFF" --sizelimit "$BOOT_SIZE" "$WORK/disk.img"); loops+=("$BOOT_LOOP")
ROOT_LOOP=$(losetup --find --show --offset "$ROOT_OFF" --sizelimit "$ROOT_SIZE" "$WORK/disk.img"); loops+=("$ROOT_LOOP")
mount "$ROOT_LOOP" "$MNT"
mount -o ro "$BOOT_LOOP" "$MNT/boot/firmware"
cp "$MNT/boot/firmware/vmlinuz" "$WORK/vmlinuz"
cp "$MNT/boot/firmware/initrd.img" "$WORK/initrd.img"
umount "$MNT/boot/firmware"

# Test-only probe, in the disposable copy: reports over the serial port, because
# the shipped image deliberately has no login that the test could use.
cp /test/boot-probe.sh "$MNT/usr/local/sbin/boot-probe.sh"
chmod +x "$MNT/usr/local/sbin/boot-probe.sh"
cat > "$MNT/etc/systemd/system/boot-probe.service" <<'UNIT'
[Unit]
Description=Boot test probe
After=cyborgroid-session.service
[Service]
Type=oneshot
StandardOutput=file:/dev/ttyAMA0
StandardError=file:/dev/ttyAMA0
ExecStart=/usr/local/sbin/boot-probe.sh
[Install]
WantedBy=graphical.target
UNIT
ln -sf /etc/systemd/system/boot-probe.service "$MNT/etc/systemd/system/graphical.target.wants/boot-probe.service"
umount "$MNT"
for l in "${loops[@]}"; do losetup -d "$l"; done; loops=()

# Room for firstboot.sh to grow into, as on a real SD card.
truncate -s +3G "$WORK/disk.img"

echo "==> booting (kernel $(file -b "$WORK/vmlinuz" 2>/dev/null | cut -c1-40))"
qemu-system-aarch64 -M virt -cpu max -smp 8 -m 4096 -accel tcg,thread=multi \
  -kernel "$WORK/vmlinuz" -initrd "$WORK/initrd.img" \
  -append "root=LABEL=writable rootfstype=ext4 rootwait console=ttyAMA0 systemd.show_status=1" \
  -drive "file=$WORK/disk.img,format=raw,if=none,id=d0" -device virtio-blk-pci,drive=d0 \
  -device virtio-gpu-pci,xres=800,yres=480 -device qemu-xhci -device usb-tablet \
  -nic user,model=virtio-net-pci -display none -monitor none \
  -qmp "unix:$WORK/qmp.sock,server,nowait" -serial "file:/out/serial.log" &
QEMU=$!

python3 /test/qmp-watch.py "$WORK/qmp.sock" /out/serial.log /out "${BOOT_TIMEOUT:-1500}"
status=$?
kill "$QEMU" 2>/dev/null || true
exit "$status"
