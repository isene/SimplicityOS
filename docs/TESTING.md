# Simplicity OS - Testing Guide

## Quick Test

```bash
make run
```

Press `Esc` then `2` to exit QEMU.

## Expected Output

You should see:

1. BIOS boot messages
2. "Simplicity OS booting..."
3. "Stage2 loaded"
4. Screen clears
5. "Prot" (green) - protected mode active
6. "Long mode active!" (yellow) - 64-bit mode
7. Forth kernel messages and arithmetic results

## What the Test Does

The cold start code in `kernel/forth.asm` executes:

```forth
2 3 + .    ( pushes 2, pushes 3, adds, prints → "5 " )
5 7 * .    ( pushes 5, pushes 7, multiplies, prints → "35 " )
BYE        ( halts system )
```

Expected screen output after kernel starts:
```
Simplicity OS v0.1
Forth kernel ready

5 35
```

System then halts.

## Build Commands

```bash
make          # Build disk image
make run      # Run in QEMU
make debug    # Run with GDB stub
make test     # Automated boot test
make clean    # Remove build artifacts
```

## Debugging

If system triple-faults or reboots:
- Check boot sector signature (0xAA55 at offset 510)
- Verify stage2 GDT setup
- Confirm paging tables identity-map 0-2MB
- Ensure kernel at correct offset in disk image

If arithmetic is wrong:
- Check stack pointer initialization
- Verify NEXT implementation
- Inspect word definitions in kernel/forth.asm

## QEMU Options

```bash
# Headless test
qemu-system-x86_64 -drive format=raw,file=simplicity.img -nographic

# With GUI
qemu-system-x86_64 -drive format=raw,file=simplicity.img

# Debug mode
qemu-system-x86_64 -drive format=raw,file=simplicity.img -s -S
# Then: gdb -ex 'target remote localhost:1234'
```

## Current Limitations

- No keyboard input yet (Stage 1)
- No disk I/O after boot (Stage 3)
- No graphics mode (Stage 4)
- Single-tasking only
- No interrupts enabled

## Next Stage

Stage 1 will add keyboard input for interactive Forth REPL.
