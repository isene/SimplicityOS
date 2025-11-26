# Simplicity OS - Project Directives

## Vision
Bare-metal x86_64 operating system built on Forth principles.
Everything is a WORD. Hardware is directly composable.

## Core Philosophy
1. **Everything is a WORD** - No APIs, no system calls, just Forth
2. **Stack-based interface** - Query returns values, -SET consumes values
3. **Direct hardware access** - No abstraction layers
4. **Lego composability** - Complex from simple, always
5. **Introspectable** - See and modify everything at runtime

## Design Constraints
- BIOS boot (simpler than UEFI)
- x86_64 protected mode → long mode
- JonesForth-based kernel (minimal, portable)
- QEMU primary test platform
- Real hardware secondary target

## Naming Conventions
- `DEVICE` - Query device state, returns stack values
- `DEVICE-SET` - Configure device, consumes stack values
- `DEVICE-READ` - Read from device
- `DEVICE-WRITE` - Write to device

**Examples:**
```
SCREEN          ( -- x y brightness type manufacturer )
SCREEN-SET      ( x y brightness -- )
DISK-READ       ( sector -- addr len )
DISK-WRITE      ( addr len sector -- )
KEYBOARD-READ   ( -- scancode )
```

## Development Workflow
1. Write assembly/Forth in `src/`
2. Build with `make`
3. Test in QEMU: `make run`
4. Verify functionality works
5. Commit with clear message
6. Push to GitHub

## Testing Protocol
- Every feature tested in QEMU before commit
- Boot test: Does it boot and show prompt?
- Functionality test: Does new WORD work as specified?
- Integration test: Do existing WORDs still work?
- Manual verification required before marking complete

## Code Standards
- Assembly: NASM syntax, well-commented
- Forth: Lowercase words, stack effects in comments
- Comments: Explain WHY, not WHAT
- Keep WORDs small (< 20 lines typically)
- One feature per commit

## Directory Structure
```
/boot      - Bootloader and early initialization
/kernel    - Forth kernel core
/drivers   - Hardware drivers as Forth WORDs
/stdlib    - Standard Forth word library
/tools     - Build and development utilities
/docs      - Technical documentation
```

## Hardware Support Priority
1. **Stage 1**: VGA text mode, keyboard input
2. **Stage 2**: Disk I/O (IDE/AHCI)
3. **Stage 3**: Framebuffer graphics
4. **Stage 4**: Network, USB, etc.

## Debugging
- QEMU with `-d int,cpu_reset` for debugging
- Use INT3 breakpoints in assembly
- Print stack state frequently during development
- Keep GDB ready for low-level debugging

## Security Model
- No privilege separation initially
- All code runs in ring 0
- Trust through simplicity and transparency
- Evolve security model as system matures

## Remember
- Simplest solution always wins
- Working code beats perfect design
- Test before commit, always
- Document as you build, not after
