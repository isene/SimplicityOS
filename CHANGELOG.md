# Simplicity OS - Changelog

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
