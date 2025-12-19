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
3. **Kernel word_drop bug** - Fixed `[r15-8]` to `[r15]` after `sub r15, 8` in word_drop, screen scroll, and app load functions.

## Kernel Loop Bug Fix (2025-12-19)

### Root Cause Found
The kernel had a bug in `word_drop` and several other places where after `sub r15, 8`, the code incorrectly used `mov r14, [r15-8]` instead of `mov r14, [r15]`.

### Stack Model
- R14 = TOS (cached top of stack)
- R15 = pointer to next free slot (one past last stored element)
- After `sub r15, 8`, the old second-on-stack is at `[r15]`, NOT `[r15-8]`

### Affected Functions Fixed
1. `word_drop` (line 3726) - Core drop operation
2. `.scroll_done` (line 4654) - Screen scroll cleanup
3. App loading (line 6341) - Loading apps from disk

### Why Loops Broke
When a loop contained `drop` (directly or implicitly via other operations), `word_drop` would corrupt R14 with garbage from `[r15-8]` instead of the correct value at `[r15]`. This caused:
- Incorrect loop counters
- Garbage comparison values
- Infinite loops or premature exits

### Testing
The fix should allow begin/while/repeat loops with complex bodies (including `dup drop`) to work correctly. Test with:
```forth
0 begin dup 16 < while dup drop 1 + repeat drop .s
```
Expected: Empty stack (loop runs 0-15, drops result)

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
