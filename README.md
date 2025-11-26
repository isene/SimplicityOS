# Simplicity OS

Bare-metal x86_64 operating system built on Forth principles.

## Philosophy

Everything is a WORD. Hardware is directly composable via stack-based interface.

## Quick Start

```bash
# Build the OS
make

# Run in QEMU
make run

# Debug with GDB
make debug
```

## Requirements

- NASM (assembler)
- QEMU (emulator)
- GCC/LD (linker)
- Make

## Project Structure

```
/boot      - Bootloader and early initialization
/kernel    - Forth kernel core
/drivers   - Hardware drivers as Forth WORDs
/stdlib    - Standard Forth word library
/tools     - Build and development utilities
/docs      - Technical documentation
```

## Current Status

**Stage 1 Complete!** ✓

- Working Forth interpreter in 32-bit protected mode
- NEXT inner interpreter loop
- 7 Forth words: LIT DUP DROP SWAP + * . BYE
- Executes test program: 2 3 + . 5 7 * .
- Output: "5 35"
- 377 bytes of stage2 code

See CHANGELOG.md for details.

## Documentation

- `CLAUDE.md` - Project directives and conventions
- `PLAN.md` - Implementation plan and technical decisions
- `docs/` - Detailed technical documentation

## License

Public domain. Use freely.
