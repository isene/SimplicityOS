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

**Stage 3 Complete!** ✓ - INTERACTIVE FORTH REPL!

- **Fully interactive Forth shell** - Type code and watch it execute! ✓
- PS/2 keyboard input with shift support ✓
- Complete REPL: Read-Eval-Print-Loop ✓
- Forth parser and executor ✓
- Working words: + - * / . dup drop swap
- Type: `2 3 + .` → prints "7 ok"
- 2903 bytes total (under 3KB!)

See CHANGELOG.md for complete feature list.

## Documentation

- `CLAUDE.md` - Project directives and conventions
- `PLAN.md` - Implementation plan and technical decisions
- `docs/` - Detailed technical documentation

## License

Public domain. Use freely.
