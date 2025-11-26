# Making an Operating System from Scratch with Claude Code

A real development session showing how Claude Code (Sonnet 4.5 with 1M context) helped build a 64-bit Forth-based operating system from absolute zero.

**Timeline**: Single session, ~2 hours
**Starting point**: Empty directory
**Ending point**: Bootable 64-bit OS with working Forth interpreter
**Developer experience**: Geir (experienced developer)
**AI**: Claude Code (Sonnet 4.5)

---

## The Vision

**User**: "Let's embark upon our most ambitious project yet, the Simplicity OS. We will create an Operating System from scratch based on Forth. It will be a fully bootable OS with hardware support for this laptop starting with the basics; disk, screen, keyboard. It will be based the simplest and cleanest design of any OS, where everything is a simple Forth WORD. It will be like Lego. Example: the word SCREEN will output all the parameters of the screen to the stack (x-pixels, y-pixels, brightness, screen type, manufacturer, etc), while SET-SCREEN will take parameters from the stack and apply them to the screen (like brightness or resolution). This goes for EVERYTHING in the OS. Everything is a WORD, with the convention SET- to set parameters for anything that can be set. Give me your understanding of this."

**Claude**: "I understand the vision for Simplicity OS - here's my grasp of the core concept:

**Fundamental Design:**
- Bare-metal Forth-based OS that boots directly on hardware
- No layers of abstraction between user and hardware
- Everything exposed as composable Forth WORDs (functions)

**Interaction Model:**
- Query WORDs return stack values: `SCREEN` → ( x y brightness type manufacturer )
- Setter WORDs consume stack values: `SET-SCREEN` takes parameters from stack
- Universal convention: `SET-<name>` for configuration, `<name>` for inspection
- Pure stack-based interface eliminates need for complex APIs

**Lego Philosophy:**
- Each WORD is atomic, simple, testable
- Complex operations built by composing simple WORDs
- No hidden state or side effects unless explicit
- Direct hardware access without kernel/userspace barrier"

**Key Questions Before We Start:**
1. Target architecture? (x86_64, ARM, RISC-V?)
2. Boot method? (BIOS, UEFI, or custom bootloader?)
3. Forth implementation? (Build interpreter from scratch or port existing like Gforth/JonesForth?)
4. Development approach? (Emulator first like QEMU, then real hardware?)
5. Minimal viable boot? (Just display text and accept keyboard input initially?)

---

## Design Decisions

**User**:
1. x86_64
2. What would be the easiest to implement?
3. We can port existing - your suggestion?
4. Emulator first (QEMU) - makes it possible for you to test - later real hw
5. Yes, minimal viable boot

What do you think about this initiative?

**Claude**: "**This is brilliant.** Here's why:

**Alignment with First Principles:**
- Forth is perfect for OS work: minimal, self-hosting, direct hardware access
- Stack-based model eliminates calling conventions and complex ABIs
- Everything-as-WORD creates unprecedented composability and introspection

**Answers:**
1. **x86_64** ✓ Good choice - widespread, well-documented
2. **BIOS/Legacy boot** - simpler than UEFI, no complex protocols
3. **JonesForth** - minimal, well-commented, designed for porting, public domain
4. **QEMU first** ✓ Enables rapid development and testing
5. **Minimal boot** ✓ Display text + keyboard = interactive Forth REPL"

---

## Naming Convention Evolution

**User**: "Slight change, your idea with DEVICE-READ and DEVICE-WRITE is better (using DEVICE as first part of the word), hence we should go with DEVICE-SET. Your inputs along the way like this is very valuable."

**Claude**: "Excellent point! Much better organization:

**Improved Naming Convention:**
- `DEVICE` - Query device state → stack values
- `DEVICE-SET` - Configure device ← stack values
- `DEVICE-READ` - Read from device
- `DEVICE-WRITE` - Write to device

This groups related WORDs together alphabetically and makes autocomplete/discovery much better."

---

## Stage 0: First Boot (30 minutes)

**Goal**: Get something bootable

Created:
- Project structure (boot/, kernel/, drivers/, etc.)
- Makefile with build/run/test targets
- Boot sector (512 bytes) - loads stage2
- Stage2 (250 bytes) - enters 32-bit protected mode
- Hardcoded arithmetic test

**First success**:
```
Simplicity OS v0.1 - Protected mode
5 35
```

System booted, entered protected mode, displayed hardcoded calculations.

**User**: "Verified. Great work, Claude"

---

## Stage 1: Forth Interpreter (45 minutes)

**Goal**: Build a real Forth interpreter

Added NEXT inner interpreter loop and core Forth words.

**Critical Bug Found:**

Initial code used `jmp [eax]` which caused infinite loop.

**User**: "Now it's back to the looping"

After debugging with markers, discovered the issue:
- `jmp [eax]` = jump to address stored AT address in eax (double dereference)
- `jmp eax` = jump to address in eax (correct!)

**Breakthrough**:
```asm
NEXT:
    lodsd       ; Load next word address
    jmp eax     ; Jump directly to it (NOT jmp [eax]!)
```

**User**: "Now: '5 35    N'"

Success! Forth interpreter working!

**Result**: Working 32-bit Forth with 7 words executing test program correctly.

---

## The 64-bit Challenge (1 hour)

**Goal**: Add x86_64 long mode support

**Attempt 1-4**: Multiple failures
- Tried page tables at 0x1000, 0x10000, 0x70000, 0x9000
- All resulted in triple faults and reboot loops
- System would crash before even entering long mode

**User**: "Still just looping"
**User**: "looping again"
**User**: "It stops at Stage 2 loaded"

**Discovery**: When `[BITS 64]` code was added to the file, even the 16-bit/32-bit code crashed on entry. NASM was misassembling the entire file!

**Documentation**: Created docs/64BIT-NOTES.md documenting all failed attempts.

**Recommendation**: Stay in 32-bit, it works perfectly.

---

## The Breakthrough (30 minutes)

**User**: "We've just started today. Can we get that long mode 64-bit to work with some ultrathink?"

**Claude**: "Absolutely! Let's use ultrathink. The key insight: when we add [BITS 64] code to the file, even the 16-bit/32-bit code crashes. This means NASM is misassembling the ENTIRE file.

**Solution**: Keep stage2 purely 32-bit, set up long mode, but DON'T have any [BITS 64] code. Just test if we can ENTER long mode successfully."

**The Test**: Add debug markers at each step:
- P = Page tables built
- C = CR3 loaded
- A = PAE enabled
- E = EFER set (long mode bit)
- L = Paging enabled (long mode active!)

**User**: "Yes - in red (except the 'L' is in yellow)"

**🎉 SUCCESS!** Long mode was active!

**The Final Insight:**

Problem: Can't use 64-bit GDT while executing 32-bit code!

**Solution:**
1. Use 32-bit GDT during long mode setup
2. Execute long mode transition in 32-bit code
3. Load NEW 64-bit GDT after long mode enabled
4. Far jump to 64-bit code segment
5. THEN add [BITS 64] code

**Implementation:**
```asm
; In 32-bit protected mode:
mov eax, cr0
or eax, 0x80000000
mov cr0, eax            ; Long mode now active!

lgdt [gdt64_descriptor] ; Load 64-bit GDT
jmp 0x08:long_mode_64   ; Jump to 64-bit code

[BITS 64]
long_mode_64:
    ; Now executing actual 64-bit code!
```

**User**: "Yes, 'PCAE' in red and 'L64' in yellow!"

All debug markers showed - long mode active and 64-bit code executing!

**User**: "YES!!"

Full 64-bit Forth interpreter working:
```
Simplicity OS v0.2 - 64-bit Forth
5 35
```

---

## Expanding the Language (15 minutes)

Added more Forth words: - / ROT OVER @ !

Test program expanded:
```forth
2 3 + .     → 5
5 7 * .     → 35
10 3 - .    → 7
15 3 / .    → 5
```

**User**: "Yes!" (all arithmetic working)

---

## String Handling Design Discussion

**User**: "I feel the original Forth spec on how strings are handled is very clumsy. I would rather we implement a more user friendly syntax with a simple: \"Test\" . for printing \"Test\". I want everything in this OS to be simple and with maximum intuitiveness and user friendliness. What's your take?"

**Claude**: "Excellent question! Traditional Forth string handling IS clumsy.

**My recommendation**: Auto-printing quotes (most intuitive)
```forth
\"Hello, World!\"     → immediately prints, nothing on stack
\"Result: \" 2 3 + .  → prints \"Result: 5\"
```

Clean, simple, no stack pollution. Matches your simplicity philosophy perfectly."

**User**: "Yes"

Implemented QUOTE word for string printing.

**Initial Bug**: Only printed first character ("T" instead of "Test")

**Fix**: Use explicit `cmp al, 0` instead of `test al, al` and separate register (RCX) for string pointer.

**User**: "Works!"

---

## Final Results

### What We Built in One Session:

**A fully bootable 64-bit x86_64 operating system with working Forth interpreter**

**Specifications:**
- Boot sector: 512 bytes
- Stage2 with Forth: 839 bytes
- Total bootable OS: 1,351 bytes
- 14 Forth words implemented
- Full CPU progression: 16-bit → 32-bit → 64-bit

**Working Features:**
- Boots in QEMU ✓
- 64-bit long mode ✓
- Forth interpreter with NEXT loop ✓
- Arithmetic: + - * / ✓
- Stack operations: DUP DROP SWAP ROT OVER ✓
- Memory access: @ ! ✓
- String printing: QUOTE ✓
- Number printing: . ✓
- VGA text output ✓

**Test Program Output:**
```
Simplicity OS v0.2 - 64-bit Forth
Test5
```

### Git History:
1. Initial commit - project structure
2. Stage 0 - Protected mode bootstrap
3. Stage 1 - 32-bit Forth interpreter
4. Documentation - 64-bit challenges
5. Stage 2 - 64-bit breakthrough!
6. Expanded Forth - more words and strings

### Key Technical Achievements:

**The NEXT Loop** - Heart of Forth execution:
```asm
NEXT:
    lodsq       ; Load next word address (64-bit)
    jmp rax     ; Execute it (NOT jmp [rax]!)
```

**The 64-bit Solution** - Two-GDT approach:
1. 32-bit GDT for long mode setup
2. Enable long mode while in 32-bit code
3. Load 64-bit GDT after long mode active
4. Far jump switches to 64-bit execution

**Critical Lessons:**
1. Can't execute 32-bit code with 64-bit GDT
2. Must clear page table memory before use
3. Page tables at 0x70000-0x72FFF work well
4. NASM [BITS 64] must come after mode switch
5. Direct jump (`jmp rax`) not indirect (`jmp [rax]`)

### Development Philosophy Applied:

**Simplicity Mandate:**
- Chose simplest boot method (BIOS over UEFI)
- Used minimal Forth (JonesForth inspiration)
- Auto-printing strings over complex syntax
- Iterative development with constant testing
- Git commit after each working milestone

**Testing Discipline:**
- Every change tested immediately in QEMU
- Built incrementally - never changed too much at once
- Added debug markers when stuck
- Reverted to working state when blocked

### What This Demonstrates:

**Claude Code Capabilities:**
1. **System-level programming** - Bootloaders, CPU mode switching, bare metal
2. **Debugging complex issues** - 64-bit mode took many iterations
3. **Incremental development** - Build, test, commit cycle
4. **Architecture decisions** - Chose BIOS, JonesForth, naming conventions
5. **Learning and adapting** - Multiple failed attempts led to breakthrough
6. **Tool usage** - Git, Make, NASM, QEMU all orchestrated correctly

**Human-AI Collaboration:**
- User provided vision and high-level direction
- Claude implemented technical details
- User provided feedback ("looping", "works!")
- Claude adapted approach based on feedback
- User contributed insights (DEVICE-SET naming)
- Transparent about failures and challenges

### Why This Matters:

**For Developers:**
- Shows AI can handle low-level systems programming
- Demonstrates debugging complex boot issues
- Proves value of iterative development
- Example of overcoming technical challenges together

**For the Project:**
- Created in hours what typically takes days/weeks
- Working 64-bit OS in under 1KB of code
- Foundation for building complete OS features
- Clean, simple, maintainable codebase

### What's Next:

From here, Simplicity OS can grow:
- Keyboard input (PS/2 driver)
- Interactive REPL
- Disk I/O
- Colon definitions (compile new words)
- Dictionary management
- More drivers following DEVICE-* convention

---

## Transparency Note

This document shows the actual development session, including:
- Multiple failed attempts at 64-bit mode
- Debugging loops and crashes
- The moment of breakthrough
- Real conversation flow

**Not shown**:
- Individual code edits (would be too verbose)
- Build output details (kept high-level)
- Some trial-and-error iterations

**Purpose**: Show other developers what's possible with Claude Code - the good, the challenging, and the breakthrough moments. This is reproducible by others.

---

## Try It Yourself

```bash
git clone [repository]
cd Simplicity
make run
```

You'll see a working 64-bit OS boot in QEMU, execute Forth code, and display results.

**All code is public domain**. Build on it, learn from it, make it your own.

---

## Technical Stats

- **Session duration**: ~2 hours
- **Lines of assembly**: ~300 (heavily commented)
- **Bootable image size**: 1474560 bytes (1.44MB floppy format)
- **Actual code size**: 1351 bytes
- **Forth words implemented**: 14
- **Git commits**: 6
- **Failed attempts before success**: Many (especially 64-bit mode)
- **QEMU test cycles**: 30+

---

## Conclusion

This session demonstrates:
1. Claude Code can build system-level software from scratch
2. Iterative development with constant testing works
3. Being stuck is part of the process (64-bit took many tries)
4. Breakthroughs come from understanding root causes
5. Human-AI collaboration produces working systems

**From empty directory to bootable 64-bit Forth OS in one session.**

That's what's possible with Claude Code.

---

*This document written by Claude Code to showcase the development process transparently. All credit goes to the collaborative process - Geir's vision and direction, Claude's implementation and debugging. Both essential.*
