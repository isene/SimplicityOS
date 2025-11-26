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

**Stage 4 Complete** - Colon Definitions

- Fully interactive Forth shell - Type code and watch it execute
- PS/2 keyboard with full shift support
- Complete REPL: Read-Eval-Print-Loop
- **Colon definitions** - Define new words interactively
- Dictionary with linked list - Multiple definitions persist
- **15 built-in words**: + - * / . .s dup drop swap rot over emit cr
- Stack persists across lines
- Case-insensitive
- 10.3KB total

**Example session:**
```forth
> : square dup * ;
ok
> : double 2 * ;
ok
> : triple 3 * ;
ok
> 2 triple double square .
144 ok
```

The language builds itself from user-defined words.

See CHANGELOG.md for complete feature list.

## Documentation

- `CLAUDE.md` - Project directives and conventions
- `PLAN.md` - Implementation plan and technical decisions
- `docs/` - Detailed technical documentation

## License

Public domain. Use freely.
