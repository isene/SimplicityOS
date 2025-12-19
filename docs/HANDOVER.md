# Editor Debug Session Handover

## Current Status (2025-12-19)

### What Works
- Editor launches with `0 editor`
- Insert mode (i), text entry, cursor movement
- Status line shows "Normal"/"Insert" correctly
- Command mode triggered by `:` key
- `:w myfile` no longer freezes (after unrolling find-file loop)
- `:q` quits editor

### What's Broken
1. **File not loading**: `"myfile" editor` shows empty screen even after saving
2. **Debug markers visible**: "XSC" appears on screen during save (leftover debug code in save-file and create-file)

## Root Cause Found: begin/while/repeat Bug

There is a **critical bug in the kernel's begin/while/repeat loop construct** when the loop body contains more than minimal code.

### Evidence
- Empty loop `0 begin dup 16 < while 1 + repeat drop` works (shows 0-15)
- Adding ANY code like `dup drop` or `0 drop` causes freeze after 1-2 iterations
- Position of extra code matters (before vs after `1 +`)
- This affects find-file, and likely other loops with complex bodies

### Workaround Applied
`find-file` was rewritten to use **loop unrolling** instead of begin/while/repeat:
```forth
"find-one" [ ... check single entry ... ] define
"find-file" [
  read-dir
  0 {file-sector} !
  0 {find-i} ! find-one
  1 {find-i} ! find-one
  ... (16 times total)
  {file-sector} @
] define
```

## Files Modified

### apps/editor.forth
Main editor application. Key sections:

#### Variables (lines 1-13)
```forth
0 {editor-x} !        ( cursor X position )
0 {editor-y} !        ( cursor Y position )
0 {editor-mode} !     ( 0=normal, 1=insert, 2=command )
0 {text-buffer} !     ( 1920 bytes for 80x24 screen )
0 {filename} !        ( pointer to filename string object )
0 {dir-buffer} !      ( 512 bytes for directory sector )
0 {file-sector} !     ( sector number of current file )
0 {cmd-buffer} !      ( 80 bytes for command line input )
0 {cmd-pos} !         ( cursor position in command buffer )
0 {str-ptr} !         ( temp for make-string-from-cmd )
0 {src-ptr} !         ( temp for string copy )
0 {dst-ptr} !         ( temp for string copy )
0 {copy-len} !        ( temp for string length )
```

#### Key Words

**Buffer/Screen:**
- `init-buffer` - Allocates and clears 1920-byte text buffer
- `init-dir-buffer` - Allocates 512-byte directory buffer
- `init-cmd-buffer` - Allocates 80-byte command buffer
- `draw-char-at` ( x y -- ) - Draw character from buffer at screen position
- `move-cursor` - Position cursor at {editor-x}, {editor-y}
- `redraw-all` - Redraw all 24 lines

**File System:**
- `read-dir` - Read sector 250 into dir-buffer
- `write-dir` - Write dir-buffer to sector 250
- `entry-addr` ( n -- addr ) - Calculate address of entry n (n*32 + dir-buffer)
- `entry-name` ( n -- addr ) - Same as entry-addr (name is at offset 0)
- `entry-sector` ( n -- addr ) - entry-addr + 16 (sector stored at offset 16-17)
- `get-entry-sector` ( n -- sector ) - Read 16-bit sector from entry
- `set-entry-sector` ( sector n -- ) - Write sector to entry
- `name-match` ( n -- flag ) - Compare entry n name with {filename}
- `find-one` - Check single entry {find-i} for match
- `find-file` - Search all 16 entries, set {file-sector} if found
- `create-file` - Create new entry, returns sector
- `next-free-sector` - Find next available sector (300+)
- `save-file` - Write text-buffer to file's 4 sectors
- `load-file` - Read 4 sectors into text-buffer

**Command Mode:**
- `enter-command` - Set mode 2, show `:` prompt
- `exit-command` - Set mode 0, redraw status line
- `cmd-add-char` ( char -- ) - Add char to command buffer
- `cmd-backspace` - Remove last char from command buffer
- `make-string-from-cmd` ( -- addr ) - Create string object from cmd buffer (skips first 2 chars: command + space)
- `exec-cmd-w` - Handle :w [filename]
- `exec-cmd-q` - Handle :q (returns 0 to exit)
- `exec-cmd-wq` - Handle :wq
- `exec-command` - Parse and dispatch command
- `handle-command` ( key -- flag ) - Process key in command mode

**Status Line:**
- `status-color` ( -- attr ) - Returns green for insert, white for normal/command
- `clear-status` - Fill line 24 with spaces
- `draw-normal` - Write "Normal" at line 24
- `draw-insert` - Write "Insert" at line 24
- `draw-mode` - Call draw-normal or draw-insert based on mode
- `draw-filename` - Show filename on status line
- `status-line` - Full status line redraw

**Main Loop:**
- `handle-normal` ( key -- flag ) - Process key in normal mode
- `handle-insert` ( key -- flag ) - Process key in insert mode
- `dispatch-mode` ( key -- flag ) - Route to correct handler
- `editor-loop` - Main loop: key dispatch-mode 0 = until
- `try-load` - Load file if {filename} is set and file exists
- `editor-start` - Initialize and run editor
- `editor` ( filename -- ) - Entry point

## String Object Format

Strings are objects with this structure:
- Bytes 0-7: Type (1 for string)
- Bytes 8-15: Length
- Bytes 16+: Characters (null-terminated)

`make-string-from-cmd` creates this format from command buffer.

## Directory Entry Format (32 bytes each)

- Bytes 0-15: Filename (null-terminated)
- Bytes 16-17: Sector number (little-endian 16-bit)
- Bytes 18-31: Reserved

Directory is at sector 250. Files start at sector 300+, using 4 sectors each.

## Debug Code to Remove

### In save-file (around line 156):
```forth
88 7 0 1 screen-char    ( 'X' at 0,1 )
83 7 1 1 screen-char    ( 'S' at 1,1 )
78 7 1 1 screen-char    ( 'N' at 1,1 - overwrites S )
```

### In create-file (around line 140):
```forth
67 7 2 1 screen-char    ( 'C' at 2,1 )
```

## Next Steps

1. **Remove debug markers** from save-file and create-file
2. **Debug file loading** - `try-load` calls find-file, but file may not be loading:
   - Check if find-file returns correct sector
   - Check if load-file reads correct sectors
   - Verify text-buffer contains data after load
3. **Investigate kernel loop bug** - The begin/while/repeat bug should be reported/fixed in the kernel

## VNC Testing Note

vncdotool has keyboard mapping issues:
- `"` (double quote) is converted to `'` (single quote)
- This breaks string literals when testing via VNC
- Manual testing with `make run` is required for string-based tests

## Key Kernel Words Used

- `screen-char` ( char attr x y -- ) - Draw character
- `screen-set` ( x y -- ) - Position cursor
- `screen-clear` ( attr -- ) - Clear screen with attribute
- `disk-read` ( sector addr -- ) - Read 512 bytes from sector to addr
- `disk-write` ( addr sector -- ) - Write 512 bytes from addr to sector
- `key` ( -- scancode ) - Wait for and return keypress
- `key-escape`, `key-left`, `key-right`, `key-up`, `key-down` - Key constants
- `allot` ( n -- addr ) - Allocate n bytes from heap
- `c@` ( addr -- byte ) - Read byte
- `c!` ( byte addr -- ) - Write byte
- `@` ( addr -- value ) - Read cell (8 bytes)
- `!` ( value addr -- ) - Write cell (8 bytes)
- `app-enter` / `app-exit` - Application lifecycle hooks
