# Simplicity OS Development Roadmap

## Current Status
Stage 0 complete - bootable Forth OS with REPL, VGA output, keyboard input.
**Phase 1 COMPLETE** - Apps (editor, invaders) load AND execute correctly!

## Phase 1: Get sForth Programs Running [COMPLETE]
**Goal**: External .forth files load AND execute correctly

### Final Fix (Dec 2025)
**Problem**: Numbers in word definitions weren't being compiled.
`parse_number` was called for ALL unrecognized tokens, not just numbers.

**Solution**: Added digit check before calling parse_number:
```asm
mov al, [rdi]
cmp al, '0'
jb .try_named_var       ; Not a digit
cmp al, '9'
ja .try_named_var       ; Not a digit
call parse_number
```

**Result**: Both editor and invaders now execute without crashing!

### Previous Fixes Applied
1. LIT vs lit_stub mismatch (compile LIT marker, not address)
2. Dictionary space overflow (increased 4KB -> 8KB)
3. Added BRANCH/ZBRANCH handling to both execution loops
4. Number compilation check in interpret_forth_buffer

## Phase 2: File Operations
**Goal**: Read and save programs and files from Forth

### Required Words
- `DISK-READ ( sector -- addr len )` - read sector to memory
- `DISK-WRITE ( addr len sector -- )` - write memory to sector
- `FILE-LOAD ( "filename" -- )` - load and interpret file
- `FILE-SAVE ( addr len "filename" -- )` - save buffer to file

### Implementation Notes
- Catalog at sector 99 maps filenames to sectors
- Current: editor.forth at sector 100, invaders.forth at sector 110
- Need: dynamic file allocation, directory management

## Phase 3: Complete Assembly Word Set
**Goal**: All primitive words in assembly so sForth can build everything else

### Core Words Needed
- Arithmetic: `+ - * / MOD` (done)
- Stack: `DUP DROP SWAP OVER ROT` (done)
- Memory: `@ ! C@ C!` (done)
- Comparison: `= < > 0=` (done)
- Logic: `AND OR XOR NOT` (done)
- Control: `IF THEN ELSE BEGIN UNTIL WHILE REPEAT` (done in compilation)
- I/O: `KEY EMIT .` (done)
- Definition: `: ; IMMEDIATE` (done)

### Words to Add
- `HERE ALLOT ,` - memory allocation
- `CREATE DOES>` - defining words
- `' EXECUTE` - execution tokens
- `>R R> R@` - return stack
- `WORDS` - list dictionary (done)
- `SEE` - decompile word

## Phase 4: Pure sForth Applications
**Goal**: Write all apps in Forth, no assembly

### Planned Apps
1. **Editor** - vim-like text editor (exists, needs fixing)
2. **Invaders** - space invaders game (exists, needs fixing)
3. **Shell** - file manager
4. **Assembler** - inline assembly from Forth
5. **Forth compiler** - self-hosting capability

## Architecture Notes

### Two Execution Paths
1. **REPL** (`.exec_def` at line ~880): Executes words typed interactively
2. **interpret_forth_buffer** (`.ifb_exec_def` at line ~5465): Executes during app loading

Both must handle identically:
- `EXIT` - return from word
- `LIT` - push literal value
- `BRANCH` - unconditional jump
- `ZBRANCH` - conditional jump (if zero)
- Nested dictionary words - save/restore RSI via return stack
- Builtins - direct CALL

### Stack Convention
- R14 = TOS (top of stack, cached in register)
- R15 = stack pointer (points past valid data)
- RBP = return stack pointer (for nested calls)
- RSI = instruction pointer during execution

### Control Flow Compilation
`IF` compiles: `ZBRANCH <offset>`
`ELSE` compiles: `BRANCH <offset>`, patches IF's ZBRANCH
`THEN` patches the forward reference

Offsets are BYTE offsets from current position.
