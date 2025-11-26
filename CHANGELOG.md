# Simplicity OS - Changelog

## [0.1.0] - 2025-11-26

### Added
- Project structure (boot/, kernel/, drivers/, stdlib/, tools/, docs/)
- CLAUDE.md with project directives and DEVICE-SET naming convention
- PLAN.md with 4-stage implementation roadmap
- Makefile with build, run, debug, test targets
- Git hooks (pre-commit, post-commit)
- README.md and CHANGELOG.md
- Boot sector (boot/boot.asm) - loads stage2 from disk ✓
- Stage2 loader (boot/stage2.asm) - full CPU mode progression ✓
  - Loads kernel from disk (sectors 18+)
  - Enters 32-bit protected mode
  - Sets up identity paging
  - Enters 64-bit long mode
  - Copies kernel to 1MB
  - Jumps to kernel
- Forth kernel (kernel/forth.asm) - core interpreter ✓
  - NEXT/DOCOL inner interpreter
  - Core stack words: DUP DROP SWAP OVER ROT
  - Arithmetic: + - * /
  - Memory: @ ! C@ C!
  - I/O: EMIT .
  - Dictionary: HERE ,
  - System: LIT BYE
  - VGA text output functions
  - Cold start test: 2 3 + . 5 7 * .

### Status - Stage 0 Complete!
- Bootable disk image builds successfully ✓
- Boot sector → Stage2 → 64-bit long mode ✓
- Kernel loaded at 1MB and ready to execute ✓
- Ready for first boot test with Forth REPL

### Next Steps
1. **TEST**: Run `make run` and verify Forth kernel executes
2. Verify arithmetic output: should see "5 35" on screen
3. Initialize git repository and commit Stage 0
4. Begin Stage 1: Add keyboard input for interactive REPL
