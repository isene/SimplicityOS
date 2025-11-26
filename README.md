<div align="center">

[![](img/simplicity_logo.svg)](img/simplicity_logo.svg)

# Simplicity OS

[![License](https://img.shields.io/badge/license-Public%20Domain-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-x86__64-green.svg)](https://en.wikipedia.org/wiki/X86-64)
[![Language](https://img.shields.io/badge/language-Assembly-orange.svg)](https://www.nasm.us/)
[![Version](https://img.shields.io/badge/version-0.3.0-brightgreen.svg)](CHANGELOG.md)
[![Size](https://img.shields.io/badge/size-1.3KB-red.svg)](#)

Bare-metal x86_64 operating system built on Forth principles.

**Blog post**: [Building a 64-bit OS from Scratch with Claude Code](https://isene.org/2025/11/SimplicityOS.html)
**Development narrative**: [MakingAnOS.md](MakingAnOS.md) - Complete session transcript

</div>

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

**Stage 2 Complete!** ✓ - 64-BIT BREAKTHROUGH!

- Full 64-bit long mode (x86_64) working!
- CPU progression: 16-bit → 32-bit → 64-bit ✓
- 64-bit Forth interpreter with NEXT loop
- 7 Forth words: LIT DUP DROP SWAP + * . BYE
- Executes test: 2 3 + . 5 7 * .
- Output: "5 35" using 64-bit arithmetic
- 751 bytes of bootable code

See CHANGELOG.md for breakthrough details.

## Documentation

- `CLAUDE.md` - Project directives and conventions
- `PLAN.md` - Implementation plan and technical decisions
- `docs/` - Detailed technical documentation

## License

Public domain. Use freely.
