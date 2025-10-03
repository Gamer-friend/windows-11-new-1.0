#!/bin/bash

# Set variables for low-resource mode
ISO_URL="https://www.microsoft.com/en-us/software-download/windows11"  # User must provide direct ISO link; replace with actual download URL after manual fetch
ISO_FILE="win11.iso"
VM_DISK="win11.qcow2"
RAM_MB=2048  # 2GB RAM for 4-core limit
CPUS=2  # Start with 2 CPUs, scalable to 4
DISK_SIZE=20G  # Small disk to avoid space issues

echo "Downloading Windows 11 ISO (this may take time on low storage)..."
# Note: In practice, provide the ISO via GitHub release or external link to avoid direct download in Codespace
wget -O $ISO_FILE $ISO_URL || echo "Manual ISO download needed: Place win11.iso in /workspace"

echo "Creating minimal VM disk..."
qemu-img create -f qcow2 $VM_DISK $DISK_SIZE

echo "Starting QEMU Windows 11 VM..."
qemu-system-x86_64 \
    -m $RAM_MB \
    -smp $CPUS \
    -cpu host \
    -enable-kvm \
    -drive file=$VM_DISK,format=qcow2 \
    -cdrom $ISO_FILE \
    -netdev user,id=net0,hostfwd=tcp::8080-:80 \
    -device e1000,netdev=net0 \
    -vga std \
    -display gtk \
    -usb -device usb-tablet

echo "VM started. Access via forwarded port 8080 if needed."
