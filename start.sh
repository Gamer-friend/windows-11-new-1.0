#!/bin/bash

# Set variables for low-resource mode (4-cores max)
ISO_FILE="win11.iso"
VM_DISK="win11.qcow2"
RAM_MB=2048  # 2GB RAM to fit 4-core limits
CPUS=2  # 2 CPUs (edit to 4 if needed)
DISK_SIZE=20G  # Small VM disk to save space

# Function to fetch latest ISO URL dynamically
fetch_iso_url() {
    local iso_page="https://www.microsoft.com/en-us/software-download/windows11"
    echo "Fetching latest Windows 11 ISO URL from Microsoft..."
    local iso_url=$(curl -s "$iso_page" | grep -oP 'https://software-download\.microsoft\.com/download/pr/[A-Za-z0-9_/]+\.iso' | head -1)
    if [ -z "$iso_url" ]; then
        echo "Dynamic fetch failed—using fallback URL (English 64-bit, ~7GB)."
        iso_url="https://software-download.microsoft.com/download/pr/Win11_English_x64v2.iso"  # Update this if your version differs; check via browser
    fi
    echo "Using ISO URL: $iso_url"
    echo "$iso_url"
}

# Get the ISO URL
ISO_URL=$(fetch_iso_url)

# Pre-download cleanup to free space (critical for 32GB Codespaces)
echo "Freeing up disk space before download..."
sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /tmp/* ~/.cache/* || true
docker system prune -f || true  # If Docker is running
df -h  # Show current space (for monitoring)

# Check available space (need at least 10GB free for safety)
AVAILABLE_GB=$(df /workspace | tail -1 | awk '{print int($4/1024/1024/1024)}')
if [ "$AVAILABLE_GB" -lt 10 ]; then
    echo "Warning: Less than 10GB free—download may fail. Restart Codespace or upgrade storage."
fi

# Download the ISO (7.2GB, with resume and retries)
echo "Starting auto-download of Windows 11 ISO (~7.2GB, may take 20-60 mins)..."
wget --continue --tries=3 --timeout=30 -O "$ISO_FILE" "$ISO_URL"

# Verify download (rough size check for 7GB+ file)
FILE_SIZE_GB=$(stat -c%s "$ISO_FILE" 2>/dev/null | awk '{print int($1/1024/1024/1024)}' || echo 0)
if [ "$FILE_SIZE_GB" -lt 7 ]; then
    echo "Download incomplete (only $FILE_SIZE_GB GB). Retrying once..."
    rm -f "$ISO_FILE"
    wget --continue --tries=3 --timeout=30 -O "$ISO_FILE" "$ISO_URL"
    FILE_SIZE_GB=$(stat -c%s "$ISO_FILE" 2>/dev/null | awk '{print int($1/1024/1024/1024)}' || echo 0)
    if [ "$FILE_SIZE_GB" -lt 7 ]; then
        echo "Failed to download full ISO. Check connection or try manual download from Microsoft site."
        exit 1
    fi
fi
echo "ISO downloaded successfully: $(ls -lh "$ISO_FILE")"

# Post-download cleanup (optional: keep ISO for reuse, or rm if space tight)
# rm -f "$ISO_FILE"  # Uncomment to delete after VM setup (but needed for install)

# Create minimal VM disk
echo "Creating VM disk ($DISK_SIZE)..."
qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE"

# Start QEMU Windows 11 VM
echo "Launching Windows 11 VM (low-resource mode)..."
qemu-system-x86_64 \
    -m "$RAM_MB" \
    -smp "$CPUS" \
    -cpu host \
    -enable-kvm \
    -drive file="$VM_DISK",format=qcow2 \
    -cdrom "$ISO_FILE" \
    -netdev user,id=net0,hostfwd=tcp::8080-:80 \
    -device e1000,netdev=net0 \
    -vga std \
    -display gtk \
    -usb -device usb-tablet

echo "VM started! Install Windows: Skip internet, use offline account. Port 8080 forwarded for access."
df -h  # Final space check
