# Simplicity Editor

A vim-style text editor built entirely in RPN for Simplicity OS.

## Launching

```forth
> 0 editor              ( new empty buffer )
> "myfile" editor       ( open existing file or create new )
```

## Modes

The editor has three modes, shown in the status bar at the bottom:

### Normal Mode
Default mode for navigation and commands.

| Key | Action |
|-----|--------|
| `h` or Left | Move cursor left |
| `j` or Down | Move cursor down |
| `k` or Up | Move cursor up |
| `l` or Right | Move cursor right |
| `i` | Enter Insert mode |
| `:` | Enter Command mode |

### Insert Mode
Type text directly. Status bar shows "Insert".

| Key | Action |
|-----|--------|
| Any printable | Insert character at cursor |
| Backspace | Delete character before cursor |
| Enter | Insert newline |
| Ctrl+C or ESC | Return to Normal mode |

### Command Mode
Enter commands after the `:` prompt.

| Command | Action |
|---------|--------|
| `:w filename` | Save buffer to file |
| `:w` | Save to current filename |
| `:q` | Quit editor (no save) |
| `:wq` or `:wq filename` | Save and quit |

## Screen Layout

```
+------------------------------------------------------------------+
| Text content area (24 lines x 80 columns)                        |
|                                                                  |
|                                                                  |
|                                                                  |
+------------------------------------------------------------------+
| Normal                                          filename         |
+------------------------------------------------------------------+
```

- **Status bar** shows current mode (Normal/Insert/Command)
- **Filename** appears after save or when loading existing file

## File System

Files are stored in a simple filesystem:
- **Directory sector**: 250 (16 entries, 32 bytes each)
- **File data**: Sectors 300+ (4 sectors per file = 2048 bytes max)
- **Filename**: Up to 15 characters

### Directory Entry Format
```
Bytes 0-15:  Filename (null-terminated)
Bytes 16-17: Starting sector (little-endian)
Bytes 18-31: Reserved
```

## Examples

### Create and Save New File
```forth
> 0 editor
( Editor opens with empty buffer )
( Press 'i' to enter Insert mode )
( Type some text )
( Press Ctrl+C to return to Normal )
( Type ':w myfile' and Enter to save )
( Type ':q' and Enter to quit )
```

### Edit Existing File
```forth
> "myfile" editor
( File content loaded into buffer )
( Make changes )
( ':wq' to save and quit )
```

### Quick Session
```forth
> 0 editor        ( open editor )
i                 ( insert mode )
Hello World       ( type text )
Ctrl+C            ( normal mode )
:wq hello         ( save as 'hello' and quit )
```

## Technical Details

### Implementation

The editor is implemented in `apps/editor.forth` using:
- **Variables**: cursor position, mode, buffers
- **Direct screen writes**: `screen-char` for rendering
- **Disk I/O**: `disk-read` and `disk-write` for files
- **Keyboard input**: `key` for blocking input

### Memory Layout
- **Text buffer**: 2048 bytes (80x24 + padding)
- **Command buffer**: 80 bytes
- **Directory buffer**: 512 bytes

### Key Words Used
```forth
screen-char ( char attr x y -- )   Draw character
screen-set  ( x y -- )             Position cursor
disk-read   ( sector addr -- )     Read sector
disk-write  ( addr sector -- )     Write sector
key         ( -- char )            Get keypress
allot       ( n -- addr )          Allocate memory
```

## Limitations

- Maximum file size: 2048 bytes (4 sectors)
- Maximum filename: 15 characters
- Maximum files: 16
- No line wrapping (80 columns fixed)
- No undo/redo
- No search/replace

## Source Code

See `apps/editor.forth` for the complete implementation.

Key sections:
- Lines 1-13: Variables
- Lines 15-50: Screen drawing
- Lines 50-200: File system operations
- Lines 200-400: Keyboard handling
- Lines 400+: Main editor loop
