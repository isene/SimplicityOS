# Editor Session Handover

## Current Status (2025-12-19)

### What Works
- Editor launches with `0 editor` or `"filename" editor`
- Insert mode (i), text entry, cursor movement (hjkl, arrows)
- Command mode (`:`) with `:w filename`, `:q`, `:wq`
- File saving and loading works correctly
- Filename displays in status line after save or on load
- Status line shows "Normal"/"Insert" mode correctly

### Fixed Issues
1. **Buffer overflow** - text-buffer was 1920 bytes but load-file reads 2048 bytes. Fixed by allocating 2048 bytes.
2. **Loop bug workaround** - All begin/while/repeat loops in file operations unrolled to avoid kernel bug.

## Remaining Issue: Kernel begin/while/repeat Bug

There is a **critical bug in the kernel's begin/while/repeat loop construct** when the loop body contains more than minimal code.

### Evidence
- Empty loop `0 begin dup 16 < while 1 + repeat drop` works
- Adding ANY code like `dup drop` causes freeze after 1-2 iterations
- Affects all complex loops in Forth code

### Workaround Applied
All file-related loops rewritten using **loop unrolling**:
```forth
"find-one" [ ... check single entry ... ] define
"find-file" [
  0 {find-i} ! find-one
  1 {find-i} ! find-one
  ... (16 times total)
] define
```

Unrolled loops:
- `find-file` - directory search (16 entries)
- `name-match` - string comparison (16 chars)
- `copy-name-to-entry` - filename copy (16 chars)
- `create-file` - find empty entry (16 entries)
- `next-free-sector` - find max sector (16 entries)
- `make-string-from-cmd` - copy command (16 chars)
- `draw-filename` - display filename (12 chars)

### Next Step: Debug Kernel Loop
The kernel's begin/while/repeat implementation in `kernel/simplicity.asm` needs investigation. Look for:
- Stack corruption during loop iteration
- Incorrect jump target calculation
- Register clobbering in complex loop bodies

## File Structure

### apps/editor.forth
Key sections:

**Variables (lines 1-13):**
- `{editor-x}`, `{editor-y}` - cursor position
- `{editor-mode}` - 0=normal, 1=insert, 2=command
- `{text-buffer}` - 2048 bytes for screen content
- `{filename}` - pointer to filename string
- `{dir-buffer}` - 512 bytes for directory sector
- `{file-sector}` - current file's starting sector
- `{cmd-buffer}` - 80 bytes for command input

**File System (sectors):**
- Sector 250: Directory (16 entries, 32 bytes each)
- Sectors 300+: File data (4 sectors per file = 2048 bytes)

**Directory Entry Format (32 bytes):**
- Bytes 0-15: Filename (null-terminated)
- Bytes 16-17: Starting sector (little-endian 16-bit)
- Bytes 18-31: Reserved

## VNC Testing (for Claude)

```bash
# Start QEMU headless
qemu-system-x86_64 -drive file=build/simplicity.img,format=raw -vnc :1 -daemonize

# Capture screenshot
vncdotool -s localhost:1 capture /tmp/screenshot.png

# Send keys
vncdotool -s localhost:1 type "0 editor" key enter
vncdotool -s localhost:1 key ctrl-c  # Exit insert (Escape doesn't work)

# Stop
pkill -f qemu
```

**Limitation:** Quote `"` is converted to `'` - can't test string literals via VNC.

## Key Kernel Words

- `screen-char` ( char attr x y -- ) - Draw character
- `disk-read` ( sector addr -- ) - Read 512 bytes
- `disk-write` ( addr sector -- ) - Write 512 bytes
- `key` ( -- scancode ) - Wait for keypress
- `allot` ( n -- addr ) - Allocate heap memory
- `c@` / `c!` - Byte read/write
- `@` / `!` - Cell (8-byte) read/write
