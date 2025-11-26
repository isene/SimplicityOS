# Simplicity OS - Changelog

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
