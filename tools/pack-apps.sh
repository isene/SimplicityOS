#!/bin/bash
# pack-apps.sh - Pack Forth apps into disk image
#
# Disk Layout:
#   Sector 0: Boot sector
#   Sectors 1-65: Stage2 (padded to 33280 bytes)
#   Sectors 66+: Kernel
#   Sector 200: App directory (32 entries max)
#   Sectors 201+: App data
#
# Directory Entry Format (16 bytes each, 32 entries per sector):
#   [name: 12 bytes, null-padded]
#   [start_sector: 2 bytes, little-endian]
#   [length_sectors: 2 bytes, little-endian]

set -e

IMAGE="$1"
APPS_DIR="$2"

if [ -z "$IMAGE" ] || [ -z "$APPS_DIR" ]; then
    echo "Usage: $0 <image> <apps_dir>"
    exit 1
fi

# Constants
DIR_SECTOR=200
DIR_OFFSET=$((DIR_SECTOR * 512))
DATA_START_SECTOR=201

# Create directory sector (512 bytes of zeros initially)
dd if=/dev/zero of=/tmp/app_dir.bin bs=512 count=1 2>/dev/null

current_sector=$DATA_START_SECTOR
entry_offset=0

# Process each .forth file
for app in "$APPS_DIR"/*.forth; do
    [ -f "$app" ] || continue

    name=$(basename "$app" .forth)
    size=$(stat -c%s "$app")
    sectors=$(( (size + 511) / 512 ))

    echo "  Packing: $name ($size bytes, $sectors sectors at sector $current_sector)"

    # Write directory entry (16 bytes)
    # Name (12 bytes, null-padded)
    printf "%-12s" "$name" | head -c 12 | dd of=/tmp/app_dir.bin bs=1 seek=$entry_offset conv=notrunc 2>/dev/null

    # Start sector (2 bytes, little-endian)
    printf "\\x$(printf '%02x' $((current_sector & 0xFF)))\\x$(printf '%02x' $(((current_sector >> 8) & 0xFF)))" | \
        dd of=/tmp/app_dir.bin bs=1 seek=$((entry_offset + 12)) conv=notrunc 2>/dev/null

    # Length in sectors (2 bytes, little-endian)
    printf "\\x$(printf '%02x' $((sectors & 0xFF)))\\x$(printf '%02x' $(((sectors >> 8) & 0xFF)))" | \
        dd of=/tmp/app_dir.bin bs=1 seek=$((entry_offset + 14)) conv=notrunc 2>/dev/null

    # Write app data to image (padded to sector boundary)
    app_offset=$((current_sector * 512))
    dd if="$app" of="$IMAGE" bs=1 seek=$app_offset conv=notrunc 2>/dev/null

    # Pad to sector boundary
    remainder=$((size % 512))
    if [ $remainder -ne 0 ]; then
        padding=$((512 - remainder))
        dd if=/dev/zero of="$IMAGE" bs=1 seek=$((app_offset + size)) count=$padding conv=notrunc 2>/dev/null
    fi

    current_sector=$((current_sector + sectors))
    entry_offset=$((entry_offset + 16))
done

# Write directory to image
dd if=/tmp/app_dir.bin of="$IMAGE" bs=512 seek=$DIR_SECTOR conv=notrunc 2>/dev/null

rm -f /tmp/app_dir.bin
echo "  Apps packed (directory at sector $DIR_SECTOR)"
