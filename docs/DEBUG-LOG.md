# Simplicity OS Debug Log

## 2025-12-03: App Execution Crash

### Symptoms
- Apps load successfully at boot ("Loading apps...done")
- Typing "editor" in REPL causes immediate crash/reboot
- Same for "invaders"

### Fixes Applied (still crashing)

#### Fix 1: LIT Compilation Mismatch
**Problem**: `interpret_forth_buffer` compiled `lit_stub` (code address) but executor checked for `LIT` (marker constant).
**Solution**: Lines 5383, 5537 changed from:
```asm
lea rcx, [rel lit_stub]
mov [rbx], rcx
```
To:
```asm
mov qword [rbx], LIT
```

#### Fix 2: Dictionary Space Overflow
**Problem**: Dictionary was 4KB, two apps exceeded this.
**Solution**: Line 5131 increased to 8192 bytes.

#### Fix 3: BRANCH/ZBRANCH Handling
**Problem**: Execution loops only handled EXIT, LIT, nested words, builtins.
Control flow words (if/then/else) compile to ZBRANCH/BRANCH which were being called as functions.
**Solution**: Added BRANCH/ZBRANCH handling to both:
- REPL's `.exec_def` (lines 911-940)
- `interpret_forth_buffer`'s `.ifb_exec_def` (lines 5489-5518)

#### Fix 4: Number Compilation in interpret_forth_buffer (SOLVED!)
**Problem**: Numbers in word definitions were not being compiled correctly.
The `parse_number` function was being called for ALL unrecognized tokens
(including words like `white-on-black`), not just actual numbers.

**Root Cause**: After dictionary lookup and named variable check failed,
the code fell through to parse_number without first checking if the token
was actually a number.

**Solution**: Added digit check before calling parse_number (lines 5484-5488):
```asm
    ; Try as a number - first check if it starts with a digit
    mov al, [rdi]
    cmp al, '0'
    jb .try_named_var       ; Not a digit (below '0')
    cmp al, '9'
    ja .try_named_var       ; Not a digit (above '9')

    ; Starts with a digit - parse as number
    call parse_number
    jmp .push_number
```

**Result**: Apps now execute without crashing!
- Editor trace: `S7` shows screen-clear receiving color 7 (white-on-black)
- Invaders trace: Shows proper execution with multiple builtin calls returning

### Debug Technique
Serial output with markers:
- `S` + char = screen-clear with color (e.g., `S7` = color 7)
- `B[addr]R` = Builtin at address, returned
- `D[addr]` = Dictionary word at address
- `.N..}` = Nested word execution
- `ZT` = ZBRANCH with True/Taken condition

### Successful Trace Example
```
> editorD[0A5B].N.N..}.B[A794]S7R...B[A23E]R...
```
Shows editor word executing, calling screen-clear with color 7, all returning properly.
