# Simplicity OS - Changelog

## [0.2.0] - 2025-11-26 - Stage 1 Complete

### Added - Working Forth Interpreter!
- NEXT inner interpreter loop (core of Forth execution model)
- Forth words implemented: LIT DUP DROP SWAP + * . BYE
- Stack-based execution working correctly
- Test program executes: `2 3 + . 5 7 * .` outputs "5 35"

### Technical Details
- 32-bit protected mode Forth interpreter
- Data stack at 0x80000, return stack at 0x70000
- ESI = instruction pointer, ESP = data stack, EBP = return stack
- Direct threaded code model (addresses of machine code)
- 377 bytes of stage2 code

### What Works
- Forth interpreter loop executes correctly ✓
- LIT pushes literals to stack ✓
- Arithmetic operations (+ *) work ✓
- Stack manipulation (DUP DROP SWAP) functional ✓
- DOT prints numbers in decimal ✓
- Clean halt with BYE ✓

### Next Steps - Stage 2
1. Add more Forth words: - / ROT OVER
2. Add 64-bit long mode support
3. Implement keyboard input
4. Build interactive REPL

---

## [0.1.0] - 2025-11-26 - Stage 0 Complete

### Added
- Project structure (boot/, kernel/, drivers/, stdlib/, tools/, docs/)
- CLAUDE.md with project directives and DEVICE-SET naming convention
- PLAN.md with 4-stage implementation roadmap
- Makefile with build, run, debug, test targets
- Git hooks (pre-commit, post-commit)
- README.md and CHANGELOG.md
- Boot sector (boot/boot.asm) - loads stage2 from disk ✓
- Stage2 loader (boot/stage2.asm) - enters 32-bit protected mode ✓
  - Enables A20 line
  - Loads GDT
  - Switches to 32-bit protected mode
  - VGA text output working
  - Test arithmetic: 2+3=5, 5*7=35 displayed correctly
- Makefile with build/run/test/clean targets ✓
- Git repository initialized ✓

### What Works
- Boots successfully in QEMU ✓
- Boot sector loads stage2 (63 sectors) ✓
- Stage2 enters protected mode ✓
- Screen clears and displays messages ✓
- Arithmetic calculations work ✓
- System halts cleanly ✓

### Known Limitations
- 32-bit protected mode only (not 64-bit long mode yet)
- No keyboard input
- No disk I/O after boot
- No interrupts enabled
- Arithmetic hardcoded (not interactive Forth REPL)

### Next Steps - Stage 1
1. Add 64-bit long mode support
2. Implement proper Forth interpreter (NEXT/DOCOL)
3. Add keyboard input for interactive REPL
4. Build core Forth words: DUP DROP SWAP + - * /
