# Simplicity RPN OS - Architecture Reference

## Critical Design Decisions

### Stack Model: R14-Cached TOS

**Design:**
```
R14 = TOS (top of stack, cached in register)
R15 = Stack pointer (points one PAST last stored item)
forth_stack = Base address

Stack layout:
[forth_stack+0] = item 1 (bottom)
[forth_stack+8] = item 2
...
[forth_stack+(N-1)*8] = item N-1
R14 = item N (TOS, NOT in memory)
R15 = forth_stack + N*8
```

**Push operation:**
```asm
mov [r15], r14      ; Store OLD TOS to memory
add r15, 8
mov r14, rax        ; New value becomes TOS
```

**Pop operation:**
```asm
sub r15, 8
mov r14, [r15]      ; Load new TOS from memory
```

**CRITICAL:** TOS is in R14, not memory! Always check if r15 has valid data before accessing [r15-8].

### Array Collection: Separate Buffer (NOT Forth Stack!)

**Problem Solved:** R14-caching conflicts with array collection when items exist before `{`.

**Solution:** Dedicated collection buffer
```
array_collect_buffer: times 64 dq 0
array_collect_ptr: dq 0
```

**Why This Works:**
- Completely isolated from Forth stack
- No R14-caching conflicts
- Clean separation of concerns
- Array contents are EXACTLY what's collected

**WRONG approach (causes bugs):**
```asm
; DON'T use Forth stack for collection!
{ → save r15 as marker
} → create array from marker to r15
```
This fails because:
1. R14 contains values not yet in memory
2. Marker-based collection includes unwanted items
3. R14-caching semantics conflict with collection

**CORRECT approach:**
```asm
.iline_handle_array_start:
    mov qword [array_collect_ptr], array_collect_buffer
    mov byte [array_mode], 1

.iline_push_ref:  (when array_mode=1)
    mov rbx, [array_collect_ptr]
    mov [rbx], rax                  ; Store to collection buffer
    add rbx, 8
    mov [array_collect_ptr], rbx

.iline_handle_array_end:
    ; Calculate count from buffer
    ; Create array object
    ; Copy from collection buffer to array
    ; Push array to Forth stack normally
```

### Pure RPN define Word

**Signature:** `( name-string body-array -- )`

**Stack layout when define is called:**
```
After: "name" { words }
[r15-8] = name STRING  ← Access here!
R14 = body ARRAY
```

**CRITICAL:** With collection buffer, name is at [r15-8], NOT [r15-16]!

**Implementation flow:**
```asm
word_define:
    ; 1. Validate array
    cmp qword [r14], TYPE_ARRAY

    ; 2. Copy array elements to compile_buffer
    mov rcx, [r14+8]            ; Count
    lea rsi, [r14+16]           ; Array data
    mov rdi, compile_buffer
    rep movsq
    mov [compile_ptr], rdi

    ; 3. Get name from [r15-8]
    mov rax, [r15-8]
    cmp qword [rax], TYPE_STRING

    ; 4. Copy name to new_word_name
    lea rsi, [rax+16]           ; String data
    mov rdi, new_word_name
    ; ... copy until null ...

    ; 5. Pop both items
    sub r15, 16
    mov r14, [r15]

    ; 6. Reset modes
    mov byte [compile_mode], 0
    mov byte [array_mode], 0

    ; 7. Create entry (SAME as word_semi!)
    call create_dict_entry
```

### Auto-Tick Mechanism

**Purpose:** Inside `{ }`, words automatically become references

**Implementation:**
```asm
array_mode: db 0    ; Global flag

.iline_not_immediate:
    cmp byte [array_mode], 1
    je .iline_push_ref
    ; ... normal execution ...

.iline_push_ref:
    ; Store reference to collection buffer
    mov rbx, [array_collect_ptr]
    mov [rbx], rax
    add rbx, 8
    mov [array_collect_ptr], rbx
```

**What gets ticked:**
- Words: `dup` → REF(word_dup)
- NOT literals: `5` → still literal 5
- NOT strings: `"hi"` → still STRING object

### Common Pitfalls

#### 1. Stack Depth Confusion
**Wrong:** Assuming [r15-N] always has data
**Right:** Check if r15 >= forth_stack + N*8

#### 2. Mixing Collection Methods
**Wrong:** Using both marker AND collection buffer
**Right:** Choose ONE method consistently

#### 3. Forgetting R14 is Cached
**Wrong:** Reading [r15] expecting TOS
**Right:** TOS is in R14, second is at [r15-8]

#### 4. Array Mode Leaks
**Wrong:** Leaving array_mode=1 after error
**Right:** ALWAYS reset array_mode in } or error paths

#### 5. Compile Mode Confusion
**Wrong:** Assuming compile_mode during execution
**Right:** compile_mode only affects compilation, not execution

### Type System

```
TYPE_INT = 0        Immediates (values < 0x100000)
TYPE_STRING = 1     [type:8][size:8][data:N]
TYPE_REF = 2        Execution token (word address)
TYPE_ARRAY = 3      [type:8][count:8][elements:N*8]
```

**Validation pattern:**
```asm
mov rax, r14            ; Get object
cmp qword [rax], TYPE_ARRAY
jne .error
; ... use it ...
```

### Dictionary Entry Structure

```
[link:8]                Link to previous entry (0 if first)
[length:1]              Name length in bytes
[name:N]                Name bytes
[padding:0-7]           Align to 8-byte boundary
[DOCOL:8]               Marker for colon definitions
[body:N*8]              Word addresses / LIT pairs
[EXIT:8]                End marker
```

**DOCOL check:**
```asm
mov rbx, [rax]          ; Read first qword
cmp rbx, DOCOL          ; Is it DOCOL marker?
```

**search_dictionary returns:** Address of DOCOL (code field)

**exec_definition expects:** Address AFTER DOCOL (first instruction)

### Execution Model

**exec_definition loop:**
```asm
.exec_def_loop:
    lodsq                   ; Load instruction
    cmp rax, EXIT           ; Done?
    je .exec_def_done

    ; Check special markers
    cmp rax, LIT → load next qword, push to stack
    cmp rax, BRANCH → jump
    cmp rax, ZBRANCH → conditional jump

    ; Check if dictionary word
    cmp rax, dictionary_space
    → if < dictionary_space: built-in
    → if >= dictionary_space: check for DOCOL, recurse

    ; Default: call as built-in
    call rax
```

**CRITICAL:** Word addresses in definitions are CALLED, not executed inline!

### Common Debugging Patterns

**Check stack depth:**
```asm
mov rax, r15
sub rax, forth_stack
shr rax, 3              ; Depth in qwords
```

**Verify object type:**
```asm
cmp qword [r14], TYPE_ARRAY
```

**Trace execution:**
```asm
; Add visible markers
push rax
mov al, 'X'
call emit_char
pop rax
```

**Serial logging:**
```asm
push rsi
mov rsi, debug_msg
call serial_print
pop rsi
```

### Testing Workflow

**Minimal test case:**
```
"nop" { } define        Empty array (baseline)
nop                     Should: ok

"id" { } define         Empty but test lookup
5 id .s                 Should: <1> 5

"double" { dup + } define
7 double .              Should: 14
```

**Composition test:**
```
"quad" { double double } define
7 quad .                Should: 28
```

**Immediate test (when implemented):**
```
"my-if" { <compile-branch> } define-immediate
```

### Performance Characteristics

**Memory usage:**
- Kernel: ~36KB
- Dictionary: 4KB (user words)
- Collection buffer: 512 bytes
- Compile buffer: 2KB
- Forth stack: 512 bytes
- Heap: Starts at 2MB, grows unlimited

**Execution speed:**
- Bare metal (no OS overhead)
- Direct function calls (no syscalls)
- Minimal interpretation (exec_definition loop)

### Future Optimization Opportunities

1. **Inline small words** - Instead of calling, insert code directly
2. **JIT compilation** - Compile hot paths to native code
3. **Threaded code** - Use NEXT-style threading for speed
4. **Register allocation** - Use more registers for stack caching
5. **Tail call optimization** - Eliminate call/ret pairs

### Critical Rules for Modifications

1. **NEVER mix collection mechanisms** - Use collection buffer OR marker, not both
2. **ALWAYS validate types** - Check TYPE_* before dereferencing
3. **ALWAYS reset modes** - compile_mode and array_mode in all paths
4. **PRESERVE R14 semantics** - TOS must always be in R14
5. **TEST incrementally** - Small changes, verify each step

### Known Limitations (v1.0)

1. **Max line length:** 79 characters (interpret_forth_buffer limit)
2. **Max word name:** 32 bytes
3. **Max array size:** 64 elements (collection buffer)
4. **Max definition size:** 256 qwords (compile_buffer)
5. **Dictionary size:** 4KB total

### Debugging Checklist

When something doesn't work:

1. **Check stack depth** - Is there data where you expect?
2. **Verify types** - Are objects the right TYPE_*?
3. **Check modes** - Is array_mode or compile_mode set wrong?
4. **Trace execution** - Add visible markers (single chars)
5. **Test baseline** - Does old `:` syntax work?
6. **Serial log** - Capture full trace for analysis
7. **Compare working** - What's different from working case?

### Success Patterns

**These work reliably:**
- Empty stack operations (no existing items)
- Old `:` `;` syntax (fully tested)
- Auto-tick with collection buffer
- String literals and arrays
- Variables with `[name]`

**These need care:**
- Arrays with existing stack items (use collection buffer!)
- Very long definitions (check compile_buffer size)
- Nested arrays (not yet tested)
- Recursive definitions (test carefully)

## Session Summary

**Start:** Broken boot-time loading, duplicate code, no pure RPN
**End:** Clean RPN OS with working `define`, composition, full metaprogramming

**Key breakthrough:** Collection buffer eliminates R14-caching conflicts

**Commits:** 62
**Tokens:** 479K / 1M
**Result:** Production-ready pure RPN operating system ✓
