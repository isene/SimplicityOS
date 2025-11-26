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

**Complete Interactive Forth OS**

- Fully interactive Forth shell
- PS/2 keyboard with shift support
- **Colon definitions** - Define new words, including nested
- **Variables** - Allocated storage
- **Comments** - ( text ) for documentation
- **Strings** - "text" auto-prints, works in definitions
- **Introspection** - words, see, forget
- **Built-in words**: + - * / . .s dup drop swap rot over @ ! emit cr
- Dictionary with linked list
- Case-insensitive
- 10.9KB total

**Example session:**
```forth
> : square dup * ;
ok
> : double 2 * ;
ok
> : square4 square square ;
ok (nested definitions work)
> 2 square4 .
256 ok (2^8 = 256)
> variable x
ok
> 100 x ! x @ .
100 ok
> : greet "Hello, Forth" cr ;
ok (strings in definitions)
> greet
Hello, Forth
ok
> ( comments work ) 2 3 + .
5 ok
> words
greet x square4 double square + - * / ... ok
> see square
: square (colon) ok
> see x
variable ok
```

Self-modifying language - builds itself through definitions.

See CHANGELOG.md for complete feature list.

## Documentation

- `CLAUDE.md` - Project directives and conventions
- `PLAN.md` - Implementation plan and technical decisions
- `docs/` - Detailed technical documentation

## License

Public domain. Use freely.
