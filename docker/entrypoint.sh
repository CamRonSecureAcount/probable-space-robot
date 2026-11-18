#!/usr/bin/env bash
set -euo pipefail

readonly MINT_VERSION=22.3
readonly ISO_NAME="linuxmint-${MINT_VERSION}-cinnamon-64bit.iso"
readonly ISO_PATH="/data/${ISO_NAME}"
readonly CHECKSUMS_URL="https://pub.linuxmint.io/stable/${MINT_VERSION}/sha256sum.txt"
readonly ISO_URL="https://pub.linuxmint.io/stable/${MINT_VERSION}/${ISO_NAME}"
readonly DISK_PATH=/data/linuxmint.qcow2

mkdir -p /data

if [[ ! -f "$ISO_PATH" ]]; then
    echo "Downloading Linux Mint ${MINT_VERSION} Cinnamon ISO (about 3 GB)..."
    curl --fail --location --retry 3 --output "${ISO_PATH}.part" "$ISO_URL"
    mv "${ISO_PATH}.part" "$ISO_PATH"
fi

curl --fail --location --retry 3 --output /tmp/sha256sum.txt "$CHECKSUMS_URL"
expected_checksum="$(awk -v iso="$ISO_NAME" '$2 == "*" iso { print $1 }' /tmp/sha256sum.txt)"
if [[ -z "$expected_checksum" ]]; then
    echo "Could not find ${ISO_NAME} in the Linux Mint checksum file." >&2
    exit 1
fi
if ! printf '%s  %s\n' "$expected_checksum" "$ISO_PATH" | sha256sum --check --status; then
    echo "Linux Mint ISO checksum verification failed: ${ISO_PATH}" >&2
    exit 1
fi

if [[ ! -e "$DISK_PATH" ]]; then
    qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
fi

qemu_acceleration=(-accel tcg -cpu max)
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    qemu_acceleration=(-accel kvm -cpu host)
    echo "Starting Linux Mint with KVM hardware acceleration."
else
    echo "KVM is unavailable; using slower software emulation." >&2
fi

qemu-system-x86_64 \
    -machine q35 \
    "${qemu_acceleration[@]}" \
    -m "$MEMORY_MB" \
    -smp "$CPUS" \
    -vga std \
    -display none \
    -vnc 127.0.0.1:0 \
    -drive "file=${DISK_PATH},if=virtio,format=qcow2" \
    -cdrom "$ISO_PATH" \
    -boot order=cd \
    -nic user,model=virtio-net-pci \
    -rtc base=utc \
    &
qemu_pid=$!

websockify --web=/usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 &
websockify_pid=$!

cleanup() {
    kill "$qemu_pid" "$websockify_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
    wait "$websockify_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if wait -n "$qemu_pid" "$websockify_pid"; then
    exit 0
else
    exit $?
fi
