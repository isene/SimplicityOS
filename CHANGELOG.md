# Simplicity OS - Changelog

## [0.13.0] - 2026-08-17 - Invaders: Glide Controls

- The ship now glides: tap left or right to start moving, tap the
  opposite direction to stop, tap it again to reverse. It parks at
  the walls
- Holding a key is never needed, so autorepeat cannot queue stale
  input on any display stack; repeats of the current direction are
  no-ops. This ends the key-buffering saga for good
- The launcher's xset autorepeat guard from 0.12.7 is removed; it
  did not work on all display stacks and glide makes it pointless

## [0.12.7] - 2026-08-17 - Fix Key Buffering at the Source

- The stuck ship is gone for real. Fresh keys queue BEHIND stale
  autorepeat in the terminal-to-QEMU pipe, so no game logic can see
  them earlier; the only fix is stopping the backlog from forming
- The launcher (tools/run-simplicity) now slows X autorepeat to
  20 per second while QEMU runs and restores it on exit. That rate
  stays under the ~55 per second QEMU curses input path, so the
  queue is always empty: holding moves smoothly, releasing stops
  the ship within one cell, taps always respond
- Invaders drops the 8-cell hop budget from 0.12.3-0.12.6; with no
  backlog the plain drain-and-rate-cap movement is correct
- If you run make run directly, slow autorepeat yourself:
  xset r rate 500 20 (restore with xset r rate 660 25)

## [0.12.6] - 2026-08-17 - Invaders: Hops Survive Stale Floods

- A long held key queues seconds of stale repeats upstream in the
  terminal and QEMU; they drain at ~55 per second. QEMU curses also
  stalls 200-400ms mid-flood, and those false gaps re-armed the hop
  for stale keys: the ship wandered and fresh taps were eaten
- Re-arming now needs 8 ticks of true quiet (~450ms). A flood of
  300 stale arrows moves the ship exactly one 8-cell hop; control
  returns right after the backlog drains

## [0.12.5] - 2026-08-17 - Kernel: Atomic Keyboard Wait

- 0.12.4 made the keyboard flakey: a byte landing between the
  status poll and the HLT fired its interrupt at once, and the CPU
  then slept on data with no second edge coming. Input degraded to
  timer-paced draining and QEMU's queue overflowed, dropping keys
- wait_key now closes the window with CLI before the poll; a byte
  arriving there stays a pending interrupt that wakes the HLT
  immediately. Interrupts remain on everywhere else, so ticks keep
  counting during games

## [0.12.4] - 2026-08-17 - Kernel: Interrupts Always On

- The tick counter froze during busy loops: interrupts were only
  enabled inside the HLT windows of wait_key, waittick and beep.
  That left the invaders ship permanently stuck after its first
  8-cell hop, since hop re-arming compares tick timestamps
- Interrupts are now the resting state: enabled after boot and
  after exception recovery; the HLT windows no longer disable them.
  The handlers only count ticks and acknowledge, and the keyboard
  stays polled, so nothing else changes
- `ticks` is now correct everywhere, not only at the prompt

## [0.12.3] - 2026-08-17 - Invaders: Bounded Movement Hops

- A held movement key moves the ship at most 8 cells, then stops
  until the key is released for a quarter second and pressed again.
  Taps still move exactly 1 cell
- Reason: the terminal delivers no key releases, so a held key and
  a buffered backlog of repeats look identical to the game. Only a
  bounded hop guarantees the ship stops where intended
- Verified: a 1.2s hold at 50 repeats per second moves 8 cells and
  stops at release with zero drift

## [0.12.2] - 2026-08-17 - Invaders: No More Key Buffering

- Holding a movement key no longer carries the ship past the
  release point. The loop drains every pending key each pass,
  collapses movement into one intent, and applies it at a capped
  rate (about 20 cells per second)
- Measured under QEMU curses: a burst of 20 buffered arrows moved
  the ship 8 cells and stopped; a held key stops within 1 cell of
  release; a tap moves exactly 1 cell

## [0.12.1] - 2026-08-17 - Snake Arrow Keys

- Snake accepts arrows under QEMU's curses display, where they
  arrive as ANSI ESC [ A/B/C/D characters instead of scancodes.
  Same handling as invaders

## [0.12.0] - 2026-08-17 - Snake, and a Clean Boot

- New app: snake (contributed). Growing snake, food, score line,
  speedup on eating, 180-degree turn prevention, RNG seeded from
  keypress timing. h/j/k/l or arrows steer, q quits
- Boot is quiet again. xrpn's calculator dispatch referenced words
  defined later in the file; define resolves at compile time, so
  those entries compiled empty (typing time, date, tone and friends
  did nothing). All words now defined before xstep uses them
- Invaders comments are single-line; ( ) comments end at the line,
  and the spill-over lines printed as unknown words at boot

## [0.11.0] - 2026-08-17 - Invaders: Shields and Concurrent Bombs

Closer to the 1978 original:

- Up to 3 alien bombs in the air at once; firing continues while
  the formation marches and descends
- Every third bomb aims at the ship, the rest round-robin the
  columns; fire rate rises as aliens thin out
- Four shields that bombs and the player bullet erode one cell per
  hit; aliens wipe shield cells as they march through them
- Shield state lives in video memory itself, read back with c@
  (new helper cell@); no shadow buffers
- A hit on the ship clears all bombs and grants a short grace

## [0.10.0] - 2026-08-17 - Full XRPN Coverage and the Ultimate Alarm Clock

All 274 XRPN commands traversed: 154 implemented, the rest skipped
for a named reason. See docs/XRPN-COVERAGE.md.

### Kernel
- Timer interrupt: IRQ0 counts ticks; `ticks` reads the count,
  `waittick` halts the CPU until the next tick (idle loops now
  sleep instead of spin)
- `beep` ( hz ticks -- ) plays the PC speaker via PIT channel 2
- `rtc` ( -- s m h ) and `rtcd` ( -- d mo y ) read the CMOS clock,
  BCD and binary modes
- `fatan2` ( y x -- angle ) full-quadrant arctangent

### XRPN
- New: pi, rand, sign, tenx, expx1, ln1x, root, %ch, d-r, r-d,
  p-r, r-p, grad, x<> for y/z/t/l/NN, flag ops (sf, cf, fs?, fc?,
  fs?c, fc?c, invf, x<>f, stoflag, rclflag), all 18 conditionals,
  st+ st- st* st/, sreg, correct, ashf, posa, anum, arcli, hr,
  hms, hms+, hms-, time, date, dow, tone, tonexy, beep, aviewc,
  pse, getkey, getkeyx, view, cld, adv, pra, prregs, prflags
- Interactive conditionals answer YES or NO
- Statistics registers relocatable with sreg
- Verified with three real HP-41 programs: Lambert W, Luhn
  checksum, color luminosity

### Apps
- `uac`: native port of the Ultimate Alarm Clock. Live clock,
  set alarm at HH.MM, alarm in 8h or 30m, snooze, audible time
  beeps, rings until answered. Idles on waittick at ~18 wakeups
  per second, CPU halted between ticks

## [0.9.1] - 2026-08-16 - Screen Scrolling and the XRPN Dashboard

- The screen scrolls: output past the last line shifts everything
  up one line instead of vanishing into invisible video memory.
  One scroll check in emit_char/newline covers every print path
- New kernel word color! ( attr -- ) sets the print color;
  print_string and print_number inherit it
- xrpn is now a fixed dashboard at the top of the screen: T/Z/Y in
  cyan, X in yellow, LASTX in magenta, Alpha in green, a separator,
  the input line below, messages under that. The full stack is
  visible after every keystroke

## [0.9.0] - 2026-08-16 - Roadmap Complete: Resilience and the XRPN REPL

The roadmap closes: every open kernel defect fixed, XRPN finished
with an interactive calculator.

### Kernel resilience
- IDT with all 32 exception vectors: a CPU exception prints
  "(exception N at RIP)" and recovers to a clean REPL instead of
  triple-fault rebooting
- Heap grows on demand: the page-fault handler maps 2MB pages up
  to a 64MB ceiling (verified with a write at 19MB)
- free is real: heap objects go to a first-fit free list that
  allocate_object reuses (freed array reallocates at the same
  address)
- HLT idle: PIC remapped, keyboard IRQ wakes wait_key; QEMU idle
  CPU at the prompt drops from 100% to 0.0%
- Stack guards are app-aware via stack_floor (52 sites)
- str= returns -1 like every other predicate
- New kernel word read-line ( -- str ): echoed, editable line input
  for interactive apps

### XRPN complete
- Type xrpn for an interactive HP-41 calculator: numbers lift into
  X, FOCAL commands dispatch by name, sto NN / rcl NN / fix N take
  arguments, q or off quits, X shown after every line
- Alpha register: aset, aview, cla, aleng
- Indirect addressing (sto ind / rcl ind), isg, statistics
  (splus, sminus, mean, sdev, cls in registers 11-16)
- EEX float literals: 1.5e10 and 2.5e-3 parse everywhere
- Translator maps all the new commands
- Not done: HP-41 RAW import (no test files; would be unverified)

## [0.8.0] - 2026-08-16 - Self-Hosted Programs: eval and runfile

Stage 3 of the XRPN port: write and run programs on the OS itself.

- New kernel word eval ( str -- ): interpret text as source code.
  Accepts a STRING object or an allot'ed buffer of null-terminated
  text. Reentrant with the REPL interpreter
- runfile ( name -- ) in apps/xrpn.forth: finds an editor file,
  reads its 4 sectors, converts newlines to spaces, evals it.
  Write hp-word programs in the editor, save with :w name, run
  with "name" runfile
- mkdemo shows programmatic file creation: builds a program file
  from a string and saves it through the editor's directory
- Verified in QEMU: mkdemo + rftest round-trips a program through
  the disk and prints sqrt(9) via the HP stack; "3 4 + ." eval
  prints 7
- Caveat: use ( ) comments in runnable files; a backslash comment
  swallows the rest of the file (it becomes one line)

## [0.7.0] - 2026-08-16 - XRPN: HP-41 Layer

Stage 2 of the XRPN port: FOCAL programs run on Simplicity OS.

- apps/xrpn.forth: the HP-41 machine model as words. Stack lift
  (xn enter rdn rup xy clx clst lastx), binary and unary math with
  LASTX, 100 float registers (sto/rcl/st+/st-/st*/st- as hp-words),
  flags, dse loops, twelve x-comparisons, prx/prst display
- tools/xrpn2forth: translates .xrpn FOCAL programs to apps at
  build time. Numbers become stack-lift entries, skip-next
  conditionals become if/then, dse + gto self becomes begin/until,
  xeq/gto become calls; labels become words emitted callee-first
- apps/demo.xrpn: dse factorial (10! verified: 3628800), arithmetic
  and skip-conditional checks
- xrpn and demo load at boot after the apps they depend on
- Not covered (see ROADMAP): alpha ops, indirect addressing, isg,
  statistics, EEX, label fall-through, mid-block rtn

## [0.6.0] - 2026-08-16 - Floating Point

First step of the XRPN port: the kernel speaks floats.

- 23 x87 float words: s>f f>s f+ f- f* f/ f< f> f= fneg fabs fsqrt
  fsin fcos ftan fatan fln flog fexp fpow fpi fix f.
- Doubles are raw IEEE-754 bits in ordinary stack cells; f-words
  interpret them, f. prints with FIX-style decimals (default 4)
- Float literals parse at the REPL and in definitions (3.14, -0.5);
  negative literals in define bodies compile as abs value + fneg to
  stay clear of the bit-63 literal tagging
- FPU initialized at kernel entry; works on BIOS and UEFI paths
- Regression probes ft1-ft8 in apps/test.forth
- Verified in QEMU: sqrt(2)=1.4142, e=2.7183, sin(pi/2)=1.0000,
  2^10=1024, truncation, comparisons, FIX 0/2/4 display

## [0.5.0] - 2026-08-16 - Real Hardware Boot, Architectural Fixes

### Real hardware
- stage2 loads sectors 200-447 into a RAM disk at 0x28000 via INT 13h,
  so apps load without ATA PIO (USB/AHCI/NVMe machines). The UEFI
  loader fills the same RAM disk from an embedded copy.
- One disk layer (disk_read_direct/disk_write_direct) with RAM-disk
  routing, an ATA presence probe at boot, and bounded waits: a
  machine with no ATA drive can no longer hang in a status loop.
  Writes go through to ATA when present, so QEMU persistence stays.
- Boot sector forces 80x25 text mode; stage2 checks CPUID for long
  mode (halts with a message on 32-bit CPUs) and enables A20 via
  BIOS before the fast gate.
- README documents the two real-hardware routes (make install for
  BIOS/USB, BOOTX64.EFI on a FAT32 stick for UEFI).

### Architectural fixes (all ten remaining review findings)
- Dictionary out of its overflowed 8KB in-image buffer to 256KB at
  2MB, with a bounds check. Heap at 0x260000, capped: exhaustion
  returns "(out of memory)" instead of walking into unmapped pages.
  App buffer out of the heap. Compile buffer 8x larger at 0x240000.
- Object classification is now "inside the live heap": printing or
  probing large and negative integers can no longer dereference them.
- The 14 empty-stack push special cases removed (key?, key-*,
  varcount, type-new, ...): values are no longer silently lost.
- execute routes colon words through the one true interpreter and
  rejects non-references with an error string instead of executing
  data as machine code.
- Negative literals in define bodies compile correctly (63-bit
  two's complement tagging). REPL array literals are usable data:
  [ 1 2 3 ] 1 at returns 2.
- Unbalanced then/else/until/repeat/again are ignored with a balance
  counter instead of corrupting via the return stack.
- app-exit resets interpreter modes; an editor session can no longer
  leave the REPL silently compiling (the "prints nothing" bug).
- Buffer overruns closed: definition names, save_def_source, compile
  emits, words tables (now 512 entries / 8KB text), array collection.
- Command history clamps to its 10 retained entries.
- Regression words live in apps/test.forth (cfnest, cfif, cfbad,
  negtest).

## [0.4.0] - 2026-08-16 - UEFI Boot, Kernel Hardening, Space Invaders

### UEFI Boot
- New `boot/uefi.asm`: hand-built PE32+ EFI application, no toolchain
  beyond NASM. Embeds kernel.bin and an 8x16 font, calls
  ExitBootServices, programs VGA text mode 3 by direct register access
  (Bochs-VBE disable, CRTC/sequencer/graphics/attribute tables, font
  upload to plane 2, EGA DAC palette), builds identity-mapped page
  tables and the kernel GDT, jumps to 0x10000.
- The kernel binary is unchanged between BIOS and UEFI boot.
- `make run-uefi` boots via OVMF; the ESP is served from build/esp
  with QEMU's FAT passthrough (no image tools needed). Apps still
  load from the IDE disk image.

### Kernel fixes
- Binary ops (+ - * / mod = <> < > <= >= and or xor) now guard
  against stack underflow instead of corrupting kernel variables.
- Division and modulo: signed (idiv), divide-by-zero returns 0
  instead of triple-faulting, INT_MIN/-1 overflow guarded.
- disk-read/disk-write no longer leak one stack cell per call
  (editor saves used to overflow the stack).
- at/put validate array type and bounds; errors push
  "(bad array index)" instead of corrupting memory.
- @ ! c@ c! reject addresses beyond the mapped 4MB.
- type-name read the wrong stack slot; named types now register.
- edit no longer clobbers TOS.
- screen-scroll: negative or zero n no longer wipes memory.
- PgDn no longer acts as backspace at the REPL.
- Boot-time screen clears used wrong rep counts (kernel 4x, stage2 2x).
- Disk layout de-conflicted: apps own sectors 200-399 (pack-apps.sh
  now enforces this and the 32-entry directory), saved definitions
  moved from sector 250 to 400, editor directory from 250 to 450,
  editor files from 300 to 460. Previously `save`, the editor, and
  packed apps overwrote each other.
- Makefile: image depends on apps and packer; kernel size checked
  against the sector-200 limit at build time.

### Space Invaders rewritten
- 18 aliens (3 rows x 6), per-row glyphs, colors and scores
  (30/20/10), computed from a bit mask with loops instead of 36
  copy-pasted per-alien words (file shrank while gaining features).
- Alien bombs with round-robin source column, 3 lives, ship explosion,
  wide ship (/^\), HUD with score/lives/level, wave-clear celebration,
  game over screen. Speed scales with survivors and level.
- Arrow keys work alongside h/l; space fires alongside x.

### Cleanup
- Fixed core.forth 2swap and within (both returned wrong results).
- Corrected WORDS.md: key? returns keycode-or-0, put is
  ( value array index -- ), variables are {name} not [name],
  data arrays via array/put (no { 1 2 3 } literal), not is logical,
  info takes a name string.
- Removed dead files: kernel/forth.asm, boot/stage2 (stale binary),
  boot/stage2-full.asm, apps/hello.fth, apps/ed.fth, apps/catalog.
- Known remaining defects documented in docs/ROADMAP.md.

## [0.17] - 2025-11-28 - Built-in Editor

### New Feature - Mini Vim-like Editor
Type `ed` to launch a full-screen text editor demonstrating all OS primitives.

**Controls:**
- Normal mode: `h`/`j`/`k`/`l` or arrow keys to move cursor
- `i` to enter insert mode
- `q` to quit and return to REPL
- Insert mode: type text, `ESC` returns to normal mode

**Features:**
- 80x24 editing area with status bar
- Mode indicator (NORMAL/INSERT) with help
- Backspace and Enter support
- App isolation preserves REPL stack

**Implementation:**
- Uses app-enter/exit for stack isolation
- Direct VGA memory manipulation for display
- PS/2 keyboard with special key handling
- ~300 lines of assembly

This demonstrates the OS is capable of running real applications!

---

## [0.16] - 2025-11-28 - App Stack Isolation

### New Feature - App Context Switching
Apps can now run with their own isolated stack, preserving the REPL's stack state.

**New Words:**
- `app-enter` ( -- ) - Save current stack, start fresh app stack
- `app-exit` ( -- ) - Restore saved stack, return to REPL
- `app-stack` ( -- addr ) - Push current stack base address
- `app-depth` ( -- n ) - Push current stack depth

**Example - Isolated App:**
```forth
> 1 2 3 .s
<3> 1 2 3 ok (main stack has 3 items)

> app-enter
ok (save main stack, start fresh app stack)
> .s
<0> ok (app stack is empty)

> 100 200 +
ok (app does its work)
> .s
<1> 300 ok (app has its own stack)

> app-exit
ok (restore main stack)
> .s
<3> 1 2 3 ok (main stack preserved!)
```

**Use Cases:**
- Building standalone apps (editors, games)
- Running untrusted code without affecting REPL state
- Testing words without polluting the stack

This completes the foundation for building a vim-like editor!

---

## [0.15] - 2025-11-28 - Control Flow & Comparison

### New Feature - Full Control Flow
Complete set of comparison and control flow words for writing real programs.

**Comparison Words:**
- `=` ( a b -- flag ) - Equal
- `<` ( a b -- flag ) - Less than
- `>` ( a b -- flag ) - Greater than
- `<>` ( a b -- flag ) - Not equal
- `<=` ( a b -- flag ) - Less or equal
- `>=` ( a b -- flag ) - Greater or equal
- `0=` ( n -- flag ) - Zero equal
- `mod` ( a b -- a%b ) - Modulo

**Logic Words:**
- `and` ( a b -- a&b ) - Bitwise AND
- `or` ( a b -- a|b ) - Bitwise OR
- `xor` ( a b -- a^b ) - Bitwise XOR
- `not` ( flag -- flag' ) - Logical NOT

**Control Flow (compile-time, IMMEDIATE):**
- `if` ... `then` - Conditional
- `if` ... `else` ... `then` - Conditional with alternative
- `begin` ... `until` - Loop until TOS is true
- `begin` ... `while` ... `repeat` - Loop while TOS is true
- `begin` ... `again` - Infinite loop

**Examples:**
```forth
: abs ( n -- |n| )
  dup 0 < if 0 swap - then ;

: countdown ( n -- )
  begin dup . 1 - dup 0= until drop ;

: factorial ( n -- n! )
  1 swap begin dup 1 > while
    swap over * swap 1 -
  repeat drop ;
```

**Implementation:**
- BRANCH: Unconditional jump (offset in next cell)
- ZBRANCH: Branch if zero (offset in next cell)
- Control flow uses return stack for compile-time bookkeeping

---

## [0.14] - 2025-11-28 - Keyboard Enhancements

### New Feature - Advanced Keyboard Input
Support for special keys and non-blocking input for interactive applications.

**New Words:**
- `key?` ( -- key|0 ) - Non-blocking key check, returns 0 if no key
- `key-escape` ( -- 256 ) - Escape key constant
- `key-up` ( -- 257 ) - Up arrow constant
- `key-down` ( -- 258 ) - Down arrow constant
- `key-left` ( -- 259 ) - Left arrow constant
- `key-right` ( -- 260 ) - Right arrow constant

**Special Keys Supported:**
- Arrow keys (up, down, left, right)
- Escape key
- Home, End, Page Up, Page Down, Delete
- Ctrl+letter combinations (Ctrl+A = 1, Ctrl+Z = 26)

**Example - Simple Key Handler:**
```forth
: handle-key
  key?
  dup 0 = if drop exit then
  dup key-escape = if "Escape!" . drop exit then
  dup key-up = if "Up!" . drop exit then
  emit
;
```

---

## [0.13] - 2025-11-28 - Screen Primitives

### New Feature - VGA Screen Control
Foundation for building text-mode applications like editors.

**New Words:**
- `screen-get` ( -- array ) - Returns [width height cursor_x cursor_y]
- `screen-set` ( x y -- ) - Move cursor to position
- `screen-char` ( char color x y -- ) - Put character at position with color
- `screen-clear` ( color -- ) - Clear screen with color attribute
- `screen-scroll` ( n -- ) - Scroll screen up n lines

**Color Attributes:**
```
Bits 0-3: Foreground (0=black, 1=blue, 2=green, ..., 15=white)
Bits 4-6: Background
Bit 7: Blink

Common: 0x0F=white-on-black, 0x1F=white-on-blue, 0x4F=white-on-red
```

**Examples:**
```forth
( Clear screen blue )
0x1F screen-clear

( Draw red X at position 40,12 )
88 0x4F 40 12 screen-char

( Move cursor to top-left )
0 0 screen-set

( Scroll up 5 lines )
5 screen-scroll
```

**Goal:** These primitives enable building a vim-like editor entirely in Forth.

---

## [0.12] - 2025-11-28 - User-Defined Types

### New Feature - Type Lego System
Build custom types from primitive pieces. Create your own data structures with named types.

**New Words:**
- `type-new` ( -- type_tag ) - Allocate a new type tag (4, 5, 6...)
- `type-name` ( str type_tag -- ) - Associate a name with a type
- `type-set` ( obj new_type -- obj ) - Change an object's type tag
- `type-name?` ( type_tag -- str|0 ) - Get name STRING for a type

**Example - Creating a Point Type:**
```forth
type-new                    ( -- 4 ) allocate type 4
"point" 4 type-name         ( ) name it "point"
: point { swap , , } 4 type-set ;  ( x y -- point )
10 20 point .               ( ) prints [point: 10 20 ]
```

**Design Philosophy:**
- Minimal primitives, maximum flexibility
- User types are arrays with different type tags
- No special syntax needed - pure Forth composition
- `.` automatically displays type names
- Supports up to 256 user-defined types

### Technical Implementation
- Type registry at type_registry (256 entries)
- next_type_tag tracks allocation
- Types 0-3 reserved (INT, STRING, REF, ARRAY)
- User types start at TYPE_USER_BASE (4)
- Enhanced word_dot with user type display

### Enhanced Array Display
- `.` now prints array contents: `[ 1 2 3 ]`
- Nested objects shown as type indicators
- User types show `[typename: data...]`

---

## [0.11] - 2025-11-27 - Critical Stack Fix

### Bug Fix - Return Stack Memory Conflict
Fixed critical bug where return stack overwrote page tables.

**The Problem:**
- Return stack was initialized at 0x70000
- Page tables (PML4, PDPT, PD) also live at 0x70000-0x72FFF
- Array literals use return stack to save position
- Deep operations corrupted page tables → crashes

**The Fix:**
- Moved return stack from 0x70000 to 0x90000
- Safe distance from page tables and other structures

### Stack Convention Refinement
- Clarified TOS register model
- R15 = forth_stack + 8*depth (points past top)
- R14 = Top of Stack (cached)
- First push doesn't write to memory
- Subsequent pushes: `mov [r15-8], r14` then `add r15, 8`

---

## [0.10] - 2025-11-27 - Arrays and Type Introspection

### New Features - Generic Nested Data Types

**Array Literals:**
```forth
{ 1 2 3 }           → creates ARRAY with 3 integers
{ "a" "b" }         → array of strings
{ { 1 2 } { 3 4 } } → nested arrays (fully supported)
```

**Type Introspection:**
```forth
{ 1 2 3 } type .    → 3 (TYPE_ARRAY)
"hello" type .      → 1 (TYPE_STRING)
42 type .           → 0 (TYPE_INT)
```

**Length Query:**
```forth
{ 1 2 3 } len .     → 3
"hello" len .       → 5
```

**Enhanced .s Display:**
```forth
1 2 { 3 4 } .s      → <3> 1 2 [ARRAY:2] ok
"hi" 42 .s          → <2> [STRING:2] 42 ok
```

### Type System Extended
- TYPE_ARRAY = 3 added to type tags
- Arrays store count + elements as objects
- Full nesting: arrays in variables, variables in arrays
- Type-aware `.s` shows `[TYPE:size]` for objects

### Technical Implementation
- Array literal uses return stack for position tracking
- `{` saves current stack depth to return stack
- `}` calculates item count, allocates, copies
- Object structure: [type:8][count:8][elem0:8][elem1:8]...

---

## [0.9.0] - 2025-11-27 - Pure Object Architecture

**Note**: v1.0.0 reserved for complete OS with vim-like editor and real applications.

### Paradigm Shift - Everything Is Data
Complete architectural refactor to pure data-oriented model.

**Core Principle: ONLY `.` PRINTS**
- All operations push data to stack
- No side-effect output anywhere
- `.` is the single point of rendering
- Detects type and displays appropriately

### Pure RPN Consistency
- Meta-operations use tick: `~square ?` not `see square`
- Fully RPN: data then operation, always
- Tick (~) gets references without executing
- `?` operates on references to show type

### Object Model Implementation
- Type-tagged objects with headers
- Dynamic heap allocation (starts at 2MB)
- No fixed-size buffers
- Scalable to petabytes

**Object Structure:**
```
[8 bytes: type tag]
[8 bytes: size]
[N bytes: data]
```

**Type Tags:**
- 0: Immediate integer (< 0x100000, no header)
- 1: STRING object
- 2: Code reference
- 3+: Future (arrays, images, apps)

### Examples
```forth
"Test"          → pushes STRING, no output
.               → prints "Test"
~square ?       → pushes STRING "(colon)"
.               → prints "(colon)"
2 3 + .         → 5 ok (immediate integers)
```

### Technical Changes
- Heap allocator (bump allocator at 2MB+)
- create_string_from_cstr helper
- Type-aware . operator
- word_inspect creates STRING objects
- Memory mapped to 4MB (expandable)

### Architectural Guardrails Added
- Documented in CLAUDE.md
- Strict rules for future development
- Pure data model enforced
- Scalability requirements defined

---

## [0.5.0] - 2025-11-26 - Stage 4 Complete - Colon Definitions

### Major Feature - Define New Words Interactively
Implemented full colon definition support with linked list dictionary.

### Features Added
- **Colon definitions** - Create new Forth words with `: name ... ;`
- **Dictionary system** - Linked list of user-defined words
- **DOCOL execution** - Proper execution of defined words
- **Compilation mode** - Collect words during definition
- **Immediate words** - Semicolon executes even in compile mode
- **Multi-word definitions** - Define words using other defined words
- **Literal support** - Numbers in definitions work correctly

### Working Examples
```forth
> : square dup * ;
ok
> : double 2 * ;
ok
> : triple 3 * ;
ok
> 2 triple double square .
144 ok (2×3×2, then squared = 144)
> : quad double double ;
ok (defining using other definitions)
```

### Technical Implementation
- Stage2 size: 10303 bytes (split into boot/ and kernel/)
- Dictionary: 4KB space with proper linked list
- dict_latest: Points to most recent entry
- dict_here: Points to next free space
- Search: Backwards from latest, following links
- Entry structure: Link(8) + Length(1) + Name(N) + CodePtr(8) + Body + EXIT

### Architecture Refactoring
- Separated bootloader and kernel using %include
- boot/stage2.asm: 109 lines - Bootloader only
- kernel/simplicity.asm: 1400+ lines - Complete OS
- Clean separation of concerns

### Critical Fixes
1. **Register preservation**: Use R8 for entry start, not RAX
2. **Immediate semicolon**: ; executes in compile mode
3. **LIT handling**: Proper literal execution in definitions
4. **Linked list**: Proper prev-pointer chain
5. **DOCOL compatibility**: Works with REPL function call model
6. **RSI preservation**: Save/restore parse position during execution

### What Works
- Define unlimited new words
- Words with literals (numbers)
- Words calling other defined words
- Chain multiple operations
- Dictionary persists across sessions
- Newest definitions shadow older ones

---

## [0.4.0] - 2025-11-26 - Stage 3 Complete - Interactive Forth REPL

### Major Achievement - Fully Interactive Forth!
You can now TYPE Forth code and watch it EXECUTE in real-time!

### Features Added
- **PS/2 keyboard driver** - Full keyboard input working ✓
- **Scancode to ASCII conversion** - All letters, numbers, special chars ✓
- **Shift key support** - Uppercase and symbols ✓
- **Hardware cursor tracking** - Cursor follows typing ✓
- **Backspace** - Line editing works ✓
- **Interactive REPL loop** - Read-Eval-Print-Loop ✓
- **Forth parser** - Tokenizes input into words ✓
- **Number parser** - Converts strings to integers ✓
- **Word lookup** - Finds and executes Forth words ✓
- **Separate Forth stack** - R15 register, prevents corruption ✓

### Working Interactive Commands
Type these at the prompt (case-insensitive):
```forth
> 2 3 + .
7 ok
> 1 2 3 .s
<3> 1 2 3 ok
> dup drop swap
ok
> 5 dup * .
25 ok (5 squared)
> 65 emit
A ok
> rot over
ok (stack manipulation)
> cr
ok (newline)
```

**All Forth words available:**
- Numbers: Push any integer
- Arithmetic: + - * /
- Stack: dup drop swap rot over .s
- I/O: . (print number) emit (print char) cr (newline)
- Case-insensitive: DUP = dup = Dup

### Technical Implementation
- Stage2 size: 3271 bytes (was 751 bytes in Stage 2)
- Complete OS with bootloader + kernel + REPL: 3.2KB
- R15 = Forth data stack pointer (separate from machine RSP)
- Forth stack: 64 cells (512 bytes), persists across lines
- Scancode table: Complete QWERTY layout (fixed third row offset!)
- Special chars: + - * / . , < > ! @ # $ % ^ & ( ) = _
- Shift support: Uppercase letters + shifted symbols
- Case-insensitive word matching
- Hardware cursor: Tracks typing via VGA controller ports

### Critical Fixes
1. **Stack corruption fix**: Use R15 for Forth stack, RSP for machine calls
2. **Scancode table**: Fixed third row offset (was shifted by one)
3. **Shift handling**: Track shift state, convert to uppercase/symbols
4. **Hardware cursor**: Update VGA cursor after every character
5. **Key release filter**: Ignore scancode bit 7 (releases)

### What Works
- Type Forth expressions interactively ✓
- Arithmetic executes correctly ✓
- Stack manipulation works ✓
- Error handling (? for unknown words) ✓
- Multi-line sessions ✓
- All from a bootable 3KB OS!

### Next Steps - Stage 4
1. Add .S to display stack contents
2. Add colon definitions (: SQUARE DUP * ;)
3. Add more words (ROT OVER @ ! CR EMIT)
4. Build proper dictionary system
5. Add disk I/O to save/load code

---

## [0.3.0] - 2025-11-26 - Stage 2 Complete - 64-BIT BREAKTHROUGH!

### Major Achievement - 64-bit Long Mode Working!
After extensive debugging, successfully implemented 64-bit long mode!

### The Breakthrough
**Key insight**: Keep 32-bit GDT during long mode setup, then load 64-bit GDT after.
- Use 32-bit code segment to execute long mode transition
- Clear page table memory BEFORE setting entries (critical!)
- Page tables at 0x70000-0x72FFF work perfectly
- Load new 64-bit GDT after long mode active
- Far jump to 64-bit code segment

### Features
- Full CPU mode progression: 16-bit → 32-bit → 64-bit ✓
- 64-bit Forth interpreter with NEXT loop ✓
- 7 Forth words in 64-bit: LIT DUP DROP SWAP + * . BYE ✓
- Test program executes: 2 3 + . 5 7 * . outputs "5 35" ✓
- All using 64-bit registers (RAX, RBX, RSP, etc.) ✓

### Technical Implementation
- Stage2: 751 bytes (16-bit + 32-bit + 64-bit code)
- Page tables: Identity map first 2MB
- Two GDTs: 32-bit for setup, 64-bit for execution
- 64-bit NEXT uses lodsq (load qword) and jmp rax
- Stack values are 8 bytes (qword) not 4 bytes
- Program data uses dq (define qword) not dd

### What Works in 64-bit
- Long mode activated successfully ✓
- 64-bit code execution ✓
- 64-bit Forth interpreter NEXT loop ✓
- 64-bit arithmetic operations ✓
- 64-bit stack manipulation ✓
- VGA text output from 64-bit code ✓
- Number printing in 64-bit ✓

### Critical Lessons Learned
1. Can't use 64-bit GDT while executing 32-bit code
2. Must clear page table memory (rep stosd at 0x70000)
3. Page table location 0x70000-0x72FFF is safe
4. Need separate GDTs for 32-bit setup vs 64-bit execution
5. [BITS 64] code works when placed after long mode transition

### Next Steps - Stage 3
1. Add more Forth words: - / ROT OVER @ !
2. Implement keyboard input (PS/2 driver)
3. Build interactive REPL
4. Add DOCOL for colon definitions

---

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
