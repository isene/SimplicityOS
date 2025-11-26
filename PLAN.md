# Simplicity OS - Implementation Plan

## Overview
Build minimal bootable Forth OS for x86_64 in stages.
Each stage produces bootable, testable system.

## Stage 0: Bootstrap (Current)
**Goal:** Project structure and build system

**Tasks:**
- [✓] Project directives (CLAUDE.md)
- [✓] Git hooks (pre-commit, post-commit)
- [ ] Directory structure
- [ ] Makefile for building and QEMU testing
- [ ] Initial git repository

**Deliverable:** Build system that produces bootable image

---

## Stage 1: Minimal Boot
**Goal:** Boot to Forth prompt with VGA text output

### 1.1 Bootloader (boot/boot.asm)
- BIOS boot sector (512 bytes)
- Load Stage 2 from disk
- Switch to protected mode (32-bit)
- Jump to Stage 2

### 1.2 Stage 2 Loader (boot/stage2.asm)
- Enable A20 line
- Set up GDT (Global Descriptor Table)
- Switch to long mode (64-bit)
- Set up initial stack
- Jump to kernel

### 1.3 Minimal Forth Kernel (kernel/forth.asm)
Based on JonesForth, adapted for bare metal:
- Inner interpreter (NEXT, DOCOL, EXIT)
- Dictionary structure (header, code, data)
- Core words: DUP DROP SWAP OVER ROT + - * / @ ! , HERE ALLOT
- Text output via VGA buffer (0xB8000)
- Basic REPL (read-eval-print loop)

### 1.4 VGA Text Driver (drivers/vga.asm)
WORDs implemented:
- `VGA` - Get VGA state ( -- cols rows cursor-x cursor-y )
- `VGA-SET` - Set cursor ( x y -- )
- `VGA-WRITE` - Write char ( char -- )
- `VGA-CLEAR` - Clear screen ( -- )

**Test Criteria:**
- Boots in QEMU
- Shows "Simplicity OS v0.1" message
- Accepts keyboard input
- Echo typed characters
- Execute basic Forth: `2 3 + .` shows "5"

**Estimated Lines of Code:** ~800 lines assembly

---

## Stage 2: Keyboard Input
**Goal:** Full interactive Forth REPL

### 2.1 Keyboard Driver (drivers/keyboard.asm)
- PS/2 keyboard via port 0x60
- Scancode to ASCII conversion
- Handle special keys (Enter, Backspace, Shift)

WORDs implemented:
- `KEYBOARD-READ` - Read scancode ( -- scancode )
- `KEYBOARD-KEY` - Wait for key, return ASCII ( -- char )

### 2.2 Enhanced REPL
- Line editing (backspace, cursor)
- Command history (simple)
- Word completion (optional)

**Test Criteria:**
- Type multi-line Forth definitions
- Define and execute custom words
- Use backspace to edit
- Execute: `: SQUARE DUP * ; 5 SQUARE .` shows "25"

**Estimated Lines of Code:** ~400 lines assembly

---

## Stage 3: Disk I/O
**Goal:** Load and save Forth programs from disk

### 3.1 Disk Driver (drivers/disk.asm)
- BIOS INT 13h for initial implementation
- Later: IDE/AHCI for real hardware

WORDs implemented:
- `DISK` - Get disk info ( -- sectors heads cylinders )
- `DISK-READ` - Read sector ( sector -- addr )
- `DISK-WRITE` - Write sector ( addr sector -- )

### 3.2 Simple Filesystem
- Raw sector addressing initially
- Block-based storage (1KB blocks)
- Later: Simple directory structure

WORDs implemented:
- `BLOCK` - Load block to buffer ( block# -- addr )
- `SAVE-BLOCK` - Save buffer to block ( addr block# -- )
- `LIST` - Display block contents ( block# -- )

**Test Criteria:**
- Save Forth definition to disk
- Reboot and load definition
- Execute loaded definition successfully

**Estimated Lines of Code:** ~600 lines assembly

---

## Stage 4: Graphics
**Goal:** Framebuffer graphics support

### 4.1 Framebuffer Driver (drivers/screen.asm)
- VESA BIOS Extensions (VBE)
- Linear framebuffer access
- Multiple resolutions

WORDs implemented:
- `SCREEN` - Get screen info ( -- width height bpp pitch addr )
- `SCREEN-SET` - Set video mode ( mode# -- )
- `PIXEL` - Set pixel ( x y color -- )
- `LINE` - Draw line ( x1 y1 x2 y2 color -- )
- `RECT` - Draw rectangle ( x y w h color -- )

**Test Criteria:**
- Switch to graphics mode
- Draw pixels, lines, rectangles
- Implement simple bitmap font
- Render text in graphics mode

**Estimated Lines of Code:** ~800 lines assembly

---

## Future Stages (Beyond MVP)

### Stage 5: Memory Management
- Page tables and virtual memory
- Memory allocator (simple bump allocator)
- WORDs: `ALLOC` `FREE` `MEMORY`

### Stage 6: Multitasking
- Cooperative multitasking
- Task switching
- WORDs: `TASK` `YIELD` `SLEEP`

### Stage 7: Hardware Expansion
- PCI bus enumeration
- USB support
- Network card (RTL8139 or similar)
- Sound (PC speaker, then AC97/HDA)

---

## Build System Architecture

### Makefile targets:
```
make          - Build bootable image (simplicity.img)
make run      - Run in QEMU
make debug    - Run in QEMU with GDB stub
make clean    - Remove build artifacts
make install  - Write to USB drive (for real hardware)
```

### Build process:
1. Assemble boot/boot.asm → boot.bin (512 bytes)
2. Assemble boot/stage2.asm → stage2.bin
3. Assemble kernel/*.asm → kernel.bin
4. Concatenate: boot.bin + stage2.bin + kernel.bin → simplicity.img
5. Pad to disk image size (1.44MB floppy or larger)

---

## Technical Decisions

### Why JonesForth?
- Public domain, well-documented
- Minimal implementation (~1000 lines)
- Designed for porting
- Educational code with excellent comments

### Why BIOS boot?
- Simpler than UEFI (no complex protocols)
- Works in QEMU and real hardware
- Good learning path for OS development
- Can add UEFI later if needed

### Why VGA text mode first?
- Simplest video output (direct memory write)
- No mode switching required
- Works everywhere
- Good for debugging

### Why assembly first, Forth later?
- Need bootstrap code in assembly
- Once Forth interpreter running, write drivers in Forth
- Gradual transition: asm → Forth primitives → Forth drivers

---

## Development Approach

### Phase 1: Assembly Bootstrap
- Get bootloader working
- Port JonesForth core to bare metal
- Implement VGA text output
- Basic REPL working

### Phase 2: Forth Expansion
- Write new drivers in Forth where possible
- Keep performance-critical code in assembly
- Build standard library in Forth

### Phase 3: Self-Hosting
- Forth compiler written in Forth
- Can redefine core words
- OS modifiable at runtime

---

## Testing Strategy

### QEMU Testing
- Fast iteration
- Easy debugging
- Snapshot/restore for testing

### Real Hardware Testing
- Test on actual laptop periodically
- Identify hardware-specific issues
- Validate performance

### Regression Testing
- Keep bootable images of each stage
- Verify old functionality after changes
- Document breaking changes

---

## Success Metrics

### Stage 1 Success:
- Boot to Forth prompt in < 1 second
- Execute basic Forth arithmetic
- Define and call custom words

### Stage 2 Success:
- Type and execute multi-line definitions
- Edit lines with backspace
- No crashes from malformed input

### Stage 3 Success:
- Save 100 lines of Forth code
- Reboot and load it back
- Execute without errors

### Stage 4 Success:
- Display graphics at 1024x768
- Draw smooth lines and shapes
- Render readable text

---

## Next Immediate Steps

1. Create directory structure
2. Write Makefile
3. Implement boot sector (16 lines, loads stage2)
4. Implement stage2 (switches to long mode)
5. Port JonesForth inner interpreter
6. Add VGA text output
7. Test in QEMU

**First milestone:** "Hello from Simplicity!" on screen via QEMU
