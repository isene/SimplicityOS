#!/usr/bin/env python3
"""Install a Forth app into the Simplicity disk image."""

import sys
import struct

SECTOR_SIZE = 512
FS_HEADER_SECTOR = 2
FS_FIRST_ENTRY_SECTOR = 3
FS_FIRST_DATA_SECTOR = 100
FS_ENTRY_SIZE = 32
FS_MAGIC = b'SFILES\x00\x00'

def read_sector(img, sector):
    img.seek(sector * SECTOR_SIZE)
    return img.read(SECTOR_SIZE)

def write_sector(img, sector, data):
    data = data.ljust(SECTOR_SIZE, b'\x00')[:SECTOR_SIZE]
    img.seek(sector * SECTOR_SIZE)
    img.write(data)

def install_app(image_path, name, content):
    with open(image_path, 'r+b') as img:
        # Read or initialize header
        header = bytearray(read_sector(img, FS_HEADER_SECTOR))

        if header[:8] != FS_MAGIC:
            # Initialize file system
            print(f"Initializing file system...")
            header = bytearray(SECTOR_SIZE)
            header[:8] = FS_MAGIC
            struct.pack_into('<Q', header, 8, 0)   # entry_count = 0
            struct.pack_into('<Q', header, 16, FS_FIRST_DATA_SECTOR)  # next_free
            write_sector(img, FS_HEADER_SECTOR, header)
            # Clear entry sector
            write_sector(img, FS_FIRST_ENTRY_SECTOR, b'\x00' * SECTOR_SIZE)

        entry_count = struct.unpack_from('<Q', header, 8)[0]
        next_free = struct.unpack_from('<Q', header, 16)[0]

        # Check if file already exists
        entries = bytearray(read_sector(img, FS_FIRST_ENTRY_SECTOR))
        for i in range(entry_count):
            offset = i * FS_ENTRY_SIZE
            existing_name = entries[offset:offset+16].rstrip(b'\x00').decode('ascii', errors='ignore')
            if existing_name == name:
                # Update existing file
                start_sector = struct.unpack_from('<Q', entries, offset + 16)[0]
                print(f"Updating existing file '{name}' at sector {start_sector}")
                next_free = start_sector
                break
        else:
            # New file
            print(f"Creating new file '{name}' at sector {next_free}")
            offset = entry_count * FS_ENTRY_SIZE

            # Write entry
            name_bytes = name.encode('ascii')[:16].ljust(16, b'\x00')
            entries[offset:offset+16] = name_bytes
            struct.pack_into('<Q', entries, offset + 16, next_free)  # start_sector

            # Calculate sectors needed
            sectors_needed = (len(content) + SECTOR_SIZE - 1) // SECTOR_SIZE
            sectors_needed = max(sectors_needed, 1)

            struct.pack_into('<I', entries, offset + 24, sectors_needed)  # size
            struct.pack_into('<I', entries, offset + 28, 0)  # flags = source

            write_sector(img, FS_FIRST_ENTRY_SECTOR, entries)

            # Update header
            entry_count += 1
            struct.pack_into('<Q', header, 8, entry_count)
            struct.pack_into('<Q', header, 16, next_free + sectors_needed)
            write_sector(img, FS_HEADER_SECTOR, header)

        # Write file content
        content_bytes = content.encode('ascii') if isinstance(content, str) else content
        sectors_needed = (len(content_bytes) + SECTOR_SIZE - 1) // SECTOR_SIZE
        sectors_needed = max(sectors_needed, 1)

        for i in range(sectors_needed):
            start = i * SECTOR_SIZE
            end = start + SECTOR_SIZE
            sector_data = content_bytes[start:end].ljust(SECTOR_SIZE, b'\x00')
            write_sector(img, next_free + i, sector_data)
            print(f"  Wrote sector {next_free + i}")

        print(f"Installed '{name}' ({len(content_bytes)} bytes, {sectors_needed} sectors)")

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <image> <name> <file>")
        sys.exit(1)

    image_path = sys.argv[1]
    name = sys.argv[2]
    file_path = sys.argv[3]

    with open(file_path, 'r') as f:
        content = f.read()

    install_app(image_path, name, content)
