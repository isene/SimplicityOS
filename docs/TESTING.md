# Simplicity OS - Testing Guide

## Quick Start

```bash
make clean && make   # Build (always use clean for app changes)
make run             # Run in QEMU (user runs this in their terminal)
```

Press `q` in editor to exit, or Ctrl+Alt+2 then `quit` in QEMU monitor.

## Build Commands

```bash
make          # Build disk image
make run      # Run in QEMU with GUI
make clean    # Remove build artifacts (REQUIRED before rebuild if apps changed)
```

**IMPORTANT**: The Makefile doesn't detect changes to `apps/*.forth` files. Always run `make clean && make` when modifying editor.forth or other apps.

## Manual Testing (Recommended)

For full functionality, test manually with `make run`:

### Test REPL
```
> 2 3 + .
5 ok
> "hello" .
'hello' ok
```

### Test Editor with Filename
```
> "myfile" editor
```
- Press `i` to enter insert mode
- Type some text
- Press `Escape` to return to normal mode
- Press `s` to save
- Press `q` to quit
- Run `"myfile" editor` again - text should load

### Test Editor without Filename
```
> 0 editor
```
Opens editor with empty buffer, no file association.

### Test Command Mode (:w filename)
```
> 0 editor
```
1. Press `:` to enter command mode (status bar shows `:`)
2. Type `w myfile` and press Enter - saves as "myfile"
3. Press `:` again, type `q` and Enter - quit
4. Run `"myfile" editor` to reopen the file

**Supported commands:**
- `:w` - save current file
- `:w filename` - save as filename (creates file if new)
- `:q` - quit
- `:wq` - save and quit
- `Escape` - cancel command mode

## Automated Testing with VNC (Claude Code Sessions)

When Claude Code needs to test, use VNC:

```bash
# Start QEMU with VNC (display :1 = port 5901)
qemu-system-x86_64 -drive file=build/simplicity.img,format=raw,cache=none -vnc :1 -daemonize

# Verify running
pgrep -a qemu

# Capture screenshot
vncdotool -s :1 capture /tmp/screen.png

# Type and capture
vncdotool -s :1 type 'hello' key enter pause 1 capture /tmp/result.png

# Kill when done
pkill -9 qemu
```

### CRITICAL: VNC Keyboard Mapping Bug

**vncdotool converts double quotes (`"`) to single quotes (`'`).**

This means string literals don't work via VNC automation:
```bash
# BROKEN - quotes are mangled:
printf '%s' '"test" editor' | vncdotool -s :1 typefile /dev/stdin
# System sees: 'test' editor  (tries to look up 'test' as word, fails)

# WORKS - numbers pass correctly:
vncdotool -s :1 type '999 editor' key enter
```

**Workaround**: Test with numbers instead of strings, or have user test strings manually.

### VNC Test Examples

```bash
# Test editor with number argument (verifies argument passing)
vncdotool -s :1 type '123 editor' key enter pause 2 capture /tmp/test.png

# Exit editor
vncdotool -s :1 key q pause 1

# Run hello app
vncdotool -s :1 type 'hello' key enter pause 1 capture /tmp/hello.png
```

## Debug Markers in Editor

When debugging, editor.forth may have markers that appear on screen:

| Position | Char | Meaning |
|----------|------|---------|
| (3, 0)   | A/a  | Argument was/wasn't non-zero at editor start |
| (5, 0)   | F/f  | {filename} is/isn't non-zero after clear-editor |
| (10-12, 0) | 123 | editor-start function reached |
| (0, 1)   | Y/Z  | try-load found/didn't find filename |

Remove debug code before committing.

## Disk Persistence

QEMU must use `cache=none` for disk writes to persist:
```bash
qemu-system-x86_64 -drive file=build/simplicity.img,format=raw,cache=none ...
```

Without this, file saves appear to work but data is lost on restart.

## File System Layout

| Sector | Contents |
|--------|----------|
| 200 | App directory (app names + start sectors) |
| 201+ | App code (editor, hello, etc.) |
| 250 | File directory (16 entries, 32 bytes each) |
| 300+ | File data (4 sectors = 2KB per file) |

## Troubleshooting

### Editor exits immediately
- Check for stack underflow in editor.forth
- Verify app-enter/app-exit are balanced

### File doesn't load
- Ensure QEMU uses `cache=none`
- Check file was saved (press 's' before 'q')
- Verify filename matches exactly

### Build doesn't include changes
- Run `make clean && make` (app changes need clean rebuild)

### VNC typing not working
- Check QEMU is running: `pgrep -a qemu`
- Check VNC port: `ss -tln | grep 5901`
- Try restarting QEMU

### Strings don't work via VNC
- This is a vncdotool keyboard mapping bug
- Use numbers for automated testing
- Test strings manually with `make run`

## Architecture Notes

- Stack: R14 = TOS (cached), R15 = stack pointer
- Variables: Stored in named_vars array (BSS section)
- Heap: Starts at 0x200000 (2MB), grows upward
- VGA: Text mode at 0xB8000, 80x25 characters
