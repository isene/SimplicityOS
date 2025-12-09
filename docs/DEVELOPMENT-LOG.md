# Simplicity OS Development Log

## 2025-12-09: Major Session - Pure RPN Architecture

### Overview
Transitioned from Forth-inspired syntax to pure RPN (Reverse Polish Notation) with postfix-only operations. Eliminated code duplication and fixed numerous bugs in boot-time app loading.

### Completed Work

#### 1. Code Duplication Elimination (564 lines removed)
- **Problem**: REPL had its own parsing logic separate from `interpret_line`
- **Solution**: REPL now calls `interpret_line` directly
- **Impact**: Single code path for all interpretation (boot-time and interactive)
- **Commit**: e0252bc

#### 2. Boot-Time App Loading Fixes
- **Problem**: Apps were auto-executing during boot instead of just defining words
- **Solution**: Removed execution lines from app files
- **Files**: `apps/test.forth`, `apps/hello.forth`
- **Commit**: 3c04b0a

#### 3. Screen Word Lookup Bug
- **Problem**: `screen-char`, `screen-clear`, `screen-scroll` not recognized
- **Root Cause**: Lookup logic was jumping past these checks
- **Solution**: Restructured to check "screen-" prefix first, then dispatch by length
- **Commit**: 68406ae

#### 4. Emit Newline Handling
- **Problem**: Character 10 (newline) rendered as box glyph instead of moving cursor
- **Solution**: Added check in `word_emit` to call `newline` function for ASCII 10
- **Commit**: fecc9fb

#### 5. String Literal Support in interpret_line
- **Problem**: String literals (`"text"`), tick (`~word`), arrays (`{}`") only worked in REPL
- **Root Cause**: `interpret_line` missing these handlers (code duplication)
- **Solution**: Added `.iline_handle_string`, `.iline_handle_tick`, `.iline_handle_array_*`
- **Impact**: Boot-time and REPL now have identical features
- **Commit**: 63396ec

#### 6. Exit Command
- **Problem**: Had to kill terminal to exit QEMU
- **Solution**: Implemented `exit` word using ACPI shutdown (port 0x604)
- **Commit**: 2cc0370, 8e87c6a (fixed lookup chain)

#### 7. Error Handling
- **Problem**: All commands showed "ok" even if undefined
- **Solution**: `interpret_line` now returns 1=success, 0=error in RAX
- **Impact**: Unknown words properly show "?"
- **Commit**: 6a6e248, a58fdf9

#### 8. hello.forth Bug Fix
- **Problem**: Only output newline, not greeting text
- **Root Cause**: Used `type` instead of `.` operator
- **Solution**: Changed to use `.` for printing STRING objects
- **Also**: Split `greet` to multi-line (was 89 chars, exceeded 79 limit)
- **Commits**: cb88be3, b4c8baa

### Pure RPN Implementation (In Progress)

#### Architecture Vision
- **Pure postfix**: No exceptions to RPN, including meta-operations
- **Old**: `: hello "hi" . ;` (prefix colon)
- **New**: `"hello" { "hi" . } define` (pure postfix)

#### Implemented Features

**1. Auto-Tick in Arrays**
- **Feature**: Inside `{ }`, words automatically become references
- **Example**: `{ dup + }` creates `[REF(dup), REF(+)]` not `[7, 7]`
- **Implementation**: `array_mode` flag, checked in `.iline_not_immediate`
- **Status**: ✓ Working

**2. Array Stack Preservation**
- **Problem**: `}` was resetting stack, losing items before `{`
- **Solution**: Reset to marker but don't overwrite existing items
- **Status**: ✓ Fixed (line 5344-5348)

**3. define Word**
- **Signature**: `( name-string body-array -- )`
- **Implementation**: Copies array elements to compile_buffer, calls create_dict_entry
- **Status**: ⚠️ Partially working (creates entry but execution crashes)

#### Current Issues

**define Word Execution Crash**
- **Symptom**: `"double" { dup + } define` succeeds, but calling `double` crashes/reboots OS
- **Working**: `: double dup + ;` works perfectly (old syntax)
- **Debug findings**:
  - Array validation passes ✓
  - Name extraction location unclear (tried [r15-8], [r15-16])
  - Dictionary entry gets created
  - Crash happens when executing the defined word
- **Hypothesis**: Stack layout after `}` not matching expectations
- **Next**: Need to verify exact memory layout and stack positions

### Documentation Created

**1. RPN-GUIDE.md**
- Comprehensive beginner guide
- Explains define vs define-immediate clearly
- Examples of all major features
- Common patterns and mistakes
- **Status**: ✓ Complete

### Files Modified

**Kernel**:
- `kernel/simplicity.asm`: Major refactoring, -564 lines duplicate code

**Apps**:
- `apps/hello.forth`: Fixed to use `.` instead of `type`, split long lines
- `apps/test.forth`: Removed auto-execution

**Documentation**:
- `docs/RPN-GUIDE.md`: New comprehensive guide
- `docs/DEBUG-LOG.md`: Existing (not modified this session)
- `docs/ROADMAP.md`: Existing (not modified this session)

### Technical Details

#### Stack Model
```
R14 = TOS (top of stack, cached in register)
R15 = Stack pointer (points one past last stored item)
forth_stack = Base address

Stack layout for depth N:
[forth_stack+0] = item 1 (bottom)
[forth_stack+8] = item 2
...
[forth_stack+(N-1)*8] = item N-1
R14 = item N (TOS, not in memory)
R15 = forth_stack + N*8
```

#### Array Literal Handling
```asm
.iline_handle_array_start:
    mov [rbp], r15              ; Save marker
    sub rbp, 8
    mov byte [array_mode], 1    ; Enable auto-tick

.iline_handle_array_end:
    mov byte [array_mode], 0    ; Disable auto-tick
    add rbp, 8
    mov rbx, [rbp]              ; Get marker
    ; ... create array ...
    mov r15, rbx                ; Reset to marker
    add r15, 8                  ; One slot for array
    mov r14, rax                ; Array becomes TOS
```

#### Type System
```
TYPE_INT = 0        (immediates < 0x100000)
TYPE_STRING = 1     (with header [type][size][data])
TYPE_REF = 2        (execution token)
TYPE_ARRAY = 3      (with header [type][count][elements])
```

### Known Working Features
✓ Boot from disk
✓ Load apps from disk (sector 200+)
✓ REPL with error handling
✓ String literals
✓ Arrays (general purpose)
✓ Variables with `[name]` syntax
✓ Old-style `:` `;` definitions
✓ Control flow: if/then/else, begin/until/while/repeat
✓ Stack operations: dup, drop, swap, rot, over
✓ Math: +, -, *, /, mod
✓ Comparison: =, <, >, <=, >=
✓ Output: `.`, `emit`, `cr`
✓ Screen control: screen-*, cursor operations
✓ Exit command (clean shutdown)

### Remaining Work for Pure RPN

**1. Fix define Word**
- Debug stack layout issue
- Verify [r15-16] vs [r15-8] for name location
- Test with simpler cases
- Compare compiled output with `:` syntax

**2. Implement define-immediate**
- Similar to define but sets immediate flag
- For creating control flow words

**3. Implement info Word**
- Replace `see` with pure postfix `"word-name" info`
- Show word definition details

**4. Convert All Apps**
- Update editor.forth to pure RPN
- Update invaders.forth to pure RPN
- Update hello.forth (already mostly done)
- Update test.forth (already simple)

**5. Add Missing Words**
- `key` - Read keyboard input
- `ms` - Millisecond delay
- Any others needed by editor/invaders

**6. Remove Old Syntax**
- Remove `:` and `;` words
- Update all references
- Clean up compile_mode usage

**7. Rename Throughout**
- Change "Forth" to "RPN" in:
  - Kernel comments
  - String messages
  - Banner text
  - File names (*.forth → *.rpn?)

### Architecture Maintained

**CRITICAL**: Throughout all changes, the core architecture was preserved:
- ✓ All RPN apps stored on disk (sector 200+)
- ✓ NO RPN code embedded in kernel
- ✓ Only assembly-implemented words in kernel
- ✓ Apps loaded at boot via `interpret_forth_buffer`
- ✓ Single interpreter for all contexts

### Git Commits This Session

1. `3863099` - Add serial output to emit, verify disk apps work
2. `3c04b0a` - Remove auto-execution from boot-time loading
3. `68406ae` - Fix screen word lookup logic
4. `fecc9fb` - Fix emit newline handling
5. `63396ec` - Add string literal/tick/array to interpret_line
6. `e0252bc` - Eliminate REPL code duplication (564 lines)
7. `2cc0370` - Add exit word
8. `8e87c6a` - Fix exit word lookup chain
9. `6a6e248` - Add error handling to interpret_line
10. `a58fdf9` - Fix error handling flag preservation
11. `cb88be3` - Fix hello.forth to use dot operator
12. `b4c8baa` - Fix greet line length
13. `9b04b3e` - Remove debug spam, add RPN-GUIDE.md
14. `a97c8ac` - Implement define with auto-tick arrays
15. `9c368f6` - Fix array end stack preservation
16. `1490655` - Add serial debug for define/exec

### Next Session Priorities

1. **Fix define crash** - Most critical for pure RPN
2. **Test with simpler case** - Try `"nop" { } define` (empty word)
3. **Compare bytecode** - Check if `:` and `define` produce same output
4. **Stack inspection** - Add .s calls at each step to verify layout
5. **Serial logging** - Capture full trace of define + execution

### Performance Notes

- Boot time: ~3 seconds in QEMU
- Kernel size: ~36KB
- Apps packed: ~5KB total
- Dictionary space: 4KB
- Heap starts: 0x200000

### Testing Protocol

**Verified working:**
```
test               → Outputs "HI"
hello              → Outputs "Hello from disk!"
greet              → Outputs two greeting messages
exit               → Cleanly exits QEMU
: t2 "x" . ;       → Old syntax still works
t2                 → Outputs "x"
```

**Not working:**
```
"double" { dup + } define    → Appears to succeed
double                       → Crashes/reboots OS
```

### Build Info

- Build system: Make with NASM
- Boot: 512 bytes (sector 0)
- Stage2: 512 bytes (sector 1)
- Kernel: ~36KB (sector 66)
- Apps: Sector 200+ (packed by tools/pack-apps.sh)

### Memory Map

```
0x00000 - 0x00500   Boot sector
0x00500 - 0x07C00   (unused)
0x07C00 - 0x07E00   Boot sector loaded here initially
0x07E00 - 0x17C00   Stage2 + kernel load area
0x10000 - 0x1XXXX   Kernel code/data
0x1XXXX - 0x20000   Dictionary space (user words)
0x90000             Return stack (grows down)
0x200000+           Heap (objects, strings, arrays)
```
