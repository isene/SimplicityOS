; Simplicity OS - 64-bit Forth Kernel
; Loaded at 0x10000 by stage2 after mode transitions
; Contains: REPL, all assembly primitives, and Forth interpreter

[BITS 64]
[ORG 0x10000]

long_mode_64:
    ; Setup 64-bit segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Clear screen in 64-bit mode
    mov rdi, 0xB8000
    mov rcx, 2000
    mov rax, 0x0F200F20
    rep stosq

    ; Print message
    mov rdi, 0xB8000
    mov rsi, msg64
    mov ah, 0x0A
.loop:
    lodsb
    test al, al
    jz .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:

    ; Initialize Forth (64-bit)
    mov rsp, 0x80000        ; Data stack
    mov rbp, 0x90000        ; Return stack (away from page tables at 0x70000)
    mov rsi, test_program   ; Instruction pointer
    jmp NEXT

; NEXT - Forth inner interpreter (64-bit)
NEXT:
    lodsq                   ; Load qword
    jmp rax

; Core Forth words (64-bit)

DUP:
    mov rax, [rsp]
    push rax
    jmp NEXT

DROP:
    add rsp, 8
    jmp NEXT

SWAP:
    pop rax
    pop rbx
    push rax
    push rbx
    jmp NEXT

PLUS:
    pop rax
    add [rsp], rax
    jmp NEXT

MULT:
    pop rax
    pop rbx
    imul rax, rbx
    push rax
    jmp NEXT

MINUS:
    pop rax
    sub [rsp], rax
    jmp NEXT

DIV:
    xor rdx, rdx
    pop rbx             ; divisor
    pop rax             ; dividend
    div rbx
    push rax            ; quotient
    jmp NEXT

ROT:
    pop rax             ; c
    pop rbx             ; b
    pop rcx             ; a
    push rbx            ; b
    push rax            ; c
    push rcx            ; a
    jmp NEXT

OVER:
    mov rax, [rsp+8]
    push rax
    jmp NEXT

FETCH:
    pop rax
    mov rax, [rax]
    push rax
    jmp NEXT

STORE:
    pop rax             ; address
    pop rbx             ; value
    mov [rax], rbx
    jmp NEXT

DOT:
    pop rax
    call print_number
    mov rbx, [cursor]
    mov byte [rbx], ' '
    mov byte [rbx+1], 0x0F
    add rbx, 2
    mov [cursor], rbx
    jmp NEXT

QUOTE:
    pop rax             ; Get string address
    call print_string
    jmp NEXT

EMIT:
    pop rax             ; Get character
    call emit_char
    jmp NEXT

CR:
    ; Move cursor to next line
    mov rbx, [cursor]
    sub rbx, 0xB8000    ; Get offset from start
    shr rbx, 1          ; Divide by 2 (char+attr)
    mov rax, rbx
    xor rdx, rdx
    mov rcx, 80
    div rcx             ; RAX = row, RDX = col
    inc rax             ; Next row
    xor rdx, rdx
    mul rcx             ; RAX = row * 80
    shl rax, 1          ; Multiply by 2
    add rax, 0xB8000
    mov [cursor], rax
    jmp NEXT

LIT:
    lodsq
    push rax
    jmp NEXT

BRANCH:
    ; Unconditional branch - offset in next cell
    lodsq                   ; Get offset
    add rsi, rax            ; Add to instruction pointer
    jmp NEXT

ZBRANCH:
    ; Branch if TOS is zero - offset in next cell
    ; Uses R14/R15 stack model: R14 = TOS, R15 = stack pointer
    lodsq                   ; Get offset into RAX
    mov rbx, r14            ; Save TOS for test
    ; Pop TOS using R14/R15 convention
    sub r15, 8
    cmp r15, forth_stack
    jl .zbranch_empty_prim  ; Use jl not jle - R15==forth_stack means valid element at [R15]
    mov r14, [r15]          ; After sub, old second-on-stack is at [r15]
    jmp .zbranch_test_prim
.zbranch_empty_prim:
    mov r15, forth_stack
    xor r14, r14
.zbranch_test_prim:
    test rbx, rbx
    jz .do_branch
    jmp NEXT                ; Non-zero, don't branch
.do_branch:
    add rsi, rax            ; Zero, take branch
    jmp NEXT

KEY:
    ; Wait for keypress and return ASCII character
    call wait_key
    push rax
    jmp NEXT

BYE:
    cli
    hlt
    jmp $

; Print number in RAX (64-bit)
print_number:
    push rax
    push rbx
    push rcx
    push rdx

    mov rbx, 10
    xor rcx, rcx

    test rax, rax
    jnz .conv
    mov al, '0'
    call emit_char
    jmp .done

.conv:
    xor rdx, rdx
    div rbx
    push rdx
    inc rcx
    test rax, rax
    jnz .conv

.print:
    pop rax
    add al, '0'
    call emit_char
    loop .print

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

emit_char:
    push rax
    push rbx
    mov rbx, [cursor]
    mov [rbx], al
    mov byte [rbx+1], 0x0E
    add rbx, 2
    mov [cursor], rbx
    call update_hw_cursor
    pop rbx
    pop rax
    ret

; Update hardware VGA cursor to match software cursor
update_hw_cursor:
    push rax
    push rbx
    push rdx

    ; Calculate cursor position
    mov rax, [cursor]
    sub rax, 0xB8000
    shr rax, 1              ; Divide by 2 (char+attr)

    ; Send cursor position to VGA controller
    ; High byte
    mov rbx, rax
    shr rbx, 8
    mov al, 0x0E            ; Cursor high register
    mov dx, 0x3D4
    out dx, al
    mov al, bl
    mov dx, 0x3D5
    out dx, al

    ; Low byte
    mov rax, [cursor]
    sub rax, 0xB8000
    shr rax, 1
    mov rbx, rax
    mov al, 0x0F            ; Cursor low register
    mov dx, 0x3D4
    out dx, al
    mov al, bl
    mov dx, 0x3D5
    out dx, al

    pop rdx
    pop rbx
    pop rax
    ret

; Wait for keypress and return key code in RAX
; Returns: ASCII for normal keys, or special codes (KEY_UP, KEY_DOWN, etc.)
wait_key:
    push rbx
.wait:
    ; Check if key available (port 0x64, bit 0)
    in al, 0x64
    test al, 1
    jz .wait

    ; Read scancode from port 0x60
    in al, 0x60

    ; Check for shift keys
    cmp al, 0x2A            ; Left shift press
    je .shift_press
    cmp al, 0x36            ; Right shift press
    je .shift_press
    cmp al, 0xAA            ; Left shift release
    je .shift_release
    cmp al, 0xB6            ; Right shift release
    je .shift_release

    ; Check for ctrl key
    cmp al, 0x1D            ; Ctrl press
    je .ctrl_press
    cmp al, 0x9D            ; Ctrl release
    je .ctrl_release

    ; Ignore other key releases (bit 7 set)
    test al, 0x80
    jnz .wait

    ; Check for special keys (arrow keys, escape, etc.)
    cmp al, 0x01            ; Escape
    je .key_escape
    cmp al, 0x48            ; Up arrow
    je .key_up
    cmp al, 0x50            ; Down arrow
    je .key_down
    cmp al, 0x4B            ; Left arrow
    je .key_left
    cmp al, 0x4D            ; Right arrow
    je .key_right
    cmp al, 0x47            ; Home
    je .key_home
    cmp al, 0x4F            ; End
    je .key_end
    cmp al, 0x49            ; Page Up
    je .key_pgup
    cmp al, 0x51            ; Page Down
    je .key_pgdn
    cmp al, 0x53            ; Delete
    je .key_delete

    ; Convert scancode to ASCII
    call scancode_to_ascii

    ; Apply ctrl modifier (Ctrl+A = 1, Ctrl+B = 2, etc.)
    cmp byte [ctrl_state], 0
    je .no_ctrl
    cmp rax, 'a'
    jl .no_ctrl
    cmp rax, 'z'
    jg .no_ctrl
    sub rax, 96             ; 'a' -> 1, 'b' -> 2, etc.
.no_ctrl:

    ; If zero (unmapped key), ignore it
    test rax, rax
    jz .wait

    pop rbx
    ret

.shift_press:
    mov byte [shift_state], 1
    jmp .wait

.shift_release:
    mov byte [shift_state], 0
    jmp .wait

.ctrl_press:
    mov byte [ctrl_state], 1
    jmp .wait

.ctrl_release:
    mov byte [ctrl_state], 0
    jmp .wait

.key_escape:
    mov rax, KEY_ESCAPE
    pop rbx
    ret

.key_up:
    mov rax, KEY_UP
    pop rbx
    ret

.key_down:
    mov rax, KEY_DOWN
    pop rbx
    ret

.key_left:
    mov rax, KEY_LEFT
    pop rbx
    ret

.key_right:
    mov rax, KEY_RIGHT
    pop rbx
    ret

.key_home:
    mov rax, KEY_HOME
    pop rbx
    ret

.key_end:
    mov rax, KEY_END
    pop rbx
    ret

.key_pgup:
    mov rax, KEY_PGUP
    pop rbx
    ret

.key_pgdn:
    mov rax, KEY_PGDN
    pop rbx
    ret

.key_delete:
    mov rax, KEY_DELETE
    pop rbx
    ret

; Check if key available without blocking
; Returns: key code in RAX, or 0 if no key
check_key:
    push rbx

    ; Check if key available
    in al, 0x64
    test al, 1
    jz .no_key

    ; Read scancode
    in al, 0x60

    ; Handle shift/ctrl state changes
    cmp al, 0x2A
    je .ck_shift_press
    cmp al, 0x36
    je .ck_shift_press
    cmp al, 0xAA
    je .ck_shift_release
    cmp al, 0xB6
    je .ck_shift_release
    cmp al, 0x1D
    je .ck_ctrl_press
    cmp al, 0x9D
    je .ck_ctrl_release

    ; Ignore releases
    test al, 0x80
    jnz .no_key

    ; Check special keys
    cmp al, 0x01
    je .ck_escape
    cmp al, 0x48
    je .ck_up
    cmp al, 0x50
    je .ck_down
    cmp al, 0x4B
    je .ck_left
    cmp al, 0x4D
    je .ck_right
    cmp al, 0x47
    je .ck_home
    cmp al, 0x4F
    je .ck_end
    cmp al, 0x49
    je .ck_pgup
    cmp al, 0x51
    je .ck_pgdn
    cmp al, 0x53
    je .ck_delete

    ; Normal key
    call scancode_to_ascii

    ; Apply ctrl
    cmp byte [ctrl_state], 0
    je .ck_done
    cmp rax, 'a'
    jl .ck_done
    cmp rax, 'z'
    jg .ck_done
    sub rax, 96

.ck_done:
    pop rbx
    ret

.no_key:
    xor rax, rax
    pop rbx
    ret

.ck_shift_press:
    mov byte [shift_state], 1
    jmp .no_key
.ck_shift_release:
    mov byte [shift_state], 0
    jmp .no_key
.ck_ctrl_press:
    mov byte [ctrl_state], 1
    jmp .no_key
.ck_ctrl_release:
    mov byte [ctrl_state], 0
    jmp .no_key

.ck_escape:
    mov rax, KEY_ESCAPE
    jmp .ck_done
.ck_up:
    mov rax, KEY_UP
    jmp .ck_done
.ck_down:
    mov rax, KEY_DOWN
    jmp .ck_done
.ck_left:
    mov rax, KEY_LEFT
    jmp .ck_done
.ck_right:
    mov rax, KEY_RIGHT
    jmp .ck_done
.ck_home:
    mov rax, KEY_HOME
    jmp .ck_done
.ck_end:
    mov rax, KEY_END
    jmp .ck_done
.ck_pgup:
    mov rax, KEY_PGUP
    jmp .ck_done
.ck_pgdn:
    mov rax, KEY_PGDN
    jmp .ck_done
.ck_delete:
    mov rax, KEY_DELETE
    jmp .ck_done

; Special key codes (above ASCII range)
KEY_ESCAPE equ 256
KEY_UP     equ 257
KEY_DOWN   equ 258
KEY_LEFT   equ 259
KEY_RIGHT  equ 260
KEY_HOME   equ 261
KEY_END    equ 262
KEY_PGUP   equ 263
KEY_PGDN   equ 264
KEY_DELETE equ 265

; Convert scancode to ASCII using direct table lookup
; Why: Faster than jump chain, cleaner code
scancode_to_ascii:
    push rbx
    movzx rbx, al           ; Scancode as index

    ; Select table based on shift state
    cmp byte [shift_state], 0
    je .use_normal

    ; Shifted - use shift table
    movzx rax, byte [scancode_shift_table + rbx]
    pop rbx
    ret

.use_normal:
    ; Normal - use normal table
    movzx rax, byte [scancode_normal_table + rbx]
    pop rbx
    ret

; Optimized scancode tables - Direct 256-byte lookup (no jumps)
; Why: Faster and cleaner than jump chain

scancode_normal_table:
    times 0x02 db 0
    db '1','2','3','4','5','6','7','8','9','0'          ; 0x02-0x0B
    db '-','=', 8, 0                                     ; 0x0C-0x0F (minus, equals, backspace, tab)
    db 'q','w','e','r','t','y','u','i','o','p'          ; 0x10-0x19
    db '[',']', 10, 0                                    ; 0x1A-0x1D (brackets, enter, ctrl)
    db 'a','s','d','f','g','h','j','k','l'              ; 0x1E-0x26
    db ';', 39, 96, 0, 0                                 ; 0x27-0x2B (semicolon, apostrophe, backtick, lshift, backslash)
    db 'z','x','c','v','b','n','m'                      ; 0x2C-0x32
    db ',','.','/', 0, 0, 0                              ; 0x33-0x38
    db ' ', 0, 0, 0, 0, 0, 0                            ; 0x39-0x3F (space + unmapped)
    db 0, 0, 0, 0, 0, 0, 0, 0, 0                         ; 0x40-0x48
    db 0, 0, 0, 0, 0, 0, 0                               ; 0x49-0x4F
    times 0xB0 db 0                                      ; Rest - will add Norwegian when we find scancodes

scancode_shift_table:
    times 0x02 db 0
    db '!','@','#','$','%','^','&','*','(',')'          ; 0x02-0x0B (shifted numbers)
    db '_','+', 8, 0                                     ; 0x0C-0x0F
    db 'Q','W','E','R','T','Y','U','I','O','P'          ; 0x10-0x19 (uppercase)
    db '{','}', 10, 0                                    ; 0x1A-0x1D
    db 'A','S','D','F','G','H','J','K','L'              ; 0x1E-0x26 (uppercase)
    db ':', 34, 126, 0, 0                                ; 0x27-0x2B (colon, quote, tilde)
    db 'Z','X','C','V','B','N','M'                      ; 0x2C-0x32 (uppercase)
    db '<','>','?', 0, 0, 0                              ; 0x33-0x38
    db ' '                                               ; 0x39
    times 0xC7 db 0

; Print null-terminated string from RAX
print_string:
    push rax
    push rbx
    push rcx
    mov rbx, [cursor]
    mov rcx, rax        ; Use RCX for string pointer
.loop:
    mov al, [rcx]
    cmp al, 0           ; Explicit zero comparison
    je .done
    mov [rbx], al
    mov byte [rbx+1], 0x0E
    add rbx, 2
    inc rcx
    jmp .loop
.done:
    mov [cursor], rbx
    call update_hw_cursor
    pop rcx
    pop rbx
    pop rax
    ret

; Print null-terminated string in gray
print_string_gray:
    push rax
    push rbx
    push rcx
    mov rbx, [cursor]
    mov rcx, rax
.loop:
    mov al, [rcx]
    cmp al, 0
    je .done
    mov [rbx], al
    mov byte [rbx+1], 0x03      ; Dark cyan
    add rbx, 2
    inc rcx
    jmp .loop
.done:
    mov [cursor], rbx
    call update_hw_cursor
    pop rcx
    pop rbx
    pop rax
    ret

; REPL program: Jump to assembly REPL
test_program:
    dq REPL

; Interactive REPL in assembly
REPL:
    ; Print banner
    mov rax, str_banner
    call print_string
    call newline

    ; Initialize stacks
    ; R15 points one past last item, R14 holds TOS
    mov r15, forth_stack    ; Data stack base
    mov r14, 0              ; Top of stack (TOS) - empty initially
    mov rbp, 0x90000        ; Return stack (away from page tables at 0x70000) (grows down)

    ; Load embedded apps (defines editor, invaders words)
    call load_apps

.main_loop:
    ; Debug: print compile_mode at start of loop
    push rax
    mov rsi, debug_compile_mode_msg
    call serial_print
    movzx rax, byte [compile_mode]
    call serial_print_hex
    mov al, 10
    call serial_putchar
    pop rax

    ; Print prompt
    mov rax, str_prompt
    call print_string

    ; Read line into buffer
    mov rdi, input_buffer
    xor rcx, rcx            ; Character count

.read_char:
    call wait_key           ; Get character in RAX

    cmp al, 10              ; Enter?
    je .execute_line

    cmp al, 8               ; Backspace?
    je .backspace

    ; Regular character - echo and store
    call emit_char
    mov [rdi], al
    inc rdi
    inc rcx
    cmp rcx, 79             ; Max line length
    jl .read_char
    jmp .execute_line

.backspace:
    test rcx, rcx
    jz .read_char           ; Nothing to delete
    dec rdi
    dec rcx
    ; Move cursor back, print space, move back again
    mov rbx, [cursor]
    sub rbx, 2              ; Move back one char
    mov byte [rbx], ' '     ; Erase with space
    mov byte [rbx+1], 0x0F
    mov [cursor], rbx       ; Update cursor
    call update_hw_cursor
    jmp .read_char

.execute_line:
    ; Null-terminate input
    mov byte [rdi], 0

    call newline

    ; Use interpret_line - no code duplication!
    mov rsi, input_buffer
    call interpret_line
    jmp .line_done

.line_done:
    mov rax, str_ok
    call print_string_gray
    call newline

    jmp .main_loop

; Create STRING object from C string (RSI = null-terminated string)
; Returns object address in RAX
create_string_from_cstr:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Count string length
    mov rdi, rsi
    xor rcx, rcx
.count:
    cmp byte [rdi], 0
    je .counted
    inc rdi
    inc rcx
    jmp .count
.counted:

    ; Allocate object
    push rcx
    push rsi
    add rcx, 17             ; Header + null
    call allocate_object
    pop rsi
    pop rcx

    ; Fill header
    mov qword [rax], TYPE_STRING
    mov [rax+8], rcx

    ; Copy string
    lea rdi, [rax+16]
.copy:
    mov bl, [rsi]
    mov [rdi], bl
    test bl, bl
    jz .done
    inc rsi
    inc rdi
    jmp .copy
.done:

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Get or create named variable (RDI=name, RCX=length)
; Returns address of value slot in RAX
get_or_create_named_var:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Search existing variables
    mov rsi, named_vars
    mov rax, [named_var_count]
    shl rax, 4              ; Each entry is 16 bytes
    add rax, named_vars     ; End marker

.search_loop:
    cmp rsi, rax
    jge .not_found

    ; Get name STRING from this slot
    mov rbx, [rsi]
    test rbx, rbx
    jz .not_found

    ; Compare names (simplified - just compare first char for now)
    ; TODO: Full string comparison
    lea rbx, [rbx+16]       ; String data
    mov r8b, [rbx]
    mov r9b, [rdi]
    cmp r8b, r9b
    je .found               ; Found it (simplified match)

    add rsi, 16             ; Next entry
    jmp .search_loop

.not_found:
    ; Create new entry
    mov rsi, [named_var_count]
    shl rsi, 4
    add rsi, named_vars

    ; Create name STRING
    push rsi
    push rdi
    push rcx
    mov rax, rdi
    push rax
    mov rsi, rax
    call create_string_from_cstr
    pop rcx
    pop rcx
    pop rdi
    pop rsi

    ; Store name STRING
    mov [rsi], rax

    ; Initialize value to 0
    mov qword [rsi+8], 0

    ; Increment count
    inc qword [named_var_count]

.found:
    ; Return address of value slot
    lea rax, [rsi+8]

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Allocate object (RCX = total size in bytes)
; Returns address in RAX
allocate_object:
    push rbx
    push rcx

    ; Get current heap position
    mov rax, [heap_ptr]

    ; Align to 16 bytes
    add rax, 15
    and rax, ~15

    ; Update heap pointer
    add rcx, rax
    mov [heap_ptr], rcx

    pop rcx
    pop rbx
    ret

; DOCOL - Marker for colon-defined words (not executable code)
; Why: Distinguishes user definitions from built-in words
; Code field contains DOCOL, followed by definition body
; Execution handled by .dict_word in REPL, not by calling this
DOCOL:
    ; Get address of this call (return address on stack)
    pop rsi                 ; Return address = start of definition body

    ; Execute each word until EXIT
.exec_loop:
    lodsq                   ; Load next word address
    cmp rax, EXIT
    je .done

    ; Check if it's LIT
    cmp rax, LIT
    jne .not_lit
    lodsq                   ; Get literal value
    mov [r15], r14          ; Save old TOS to memory
    add r15, 8
    mov r14, rax            ; New value becomes TOS
    jmp .exec_loop

.not_lit:
    ; Check for BRANCH (unconditional jump)
    cmp rax, BRANCH
    jne .not_branch
    lodsq                   ; Get offset
    add rsi, rax            ; Jump
    jmp .exec_loop

.not_branch:
    ; Check for ZBRANCH (branch if zero)
    cmp rax, ZBRANCH
    jne .do_call
    lodsq                   ; Get offset
    mov rbx, r14            ; Get TOS
    ; Pop TOS using R14/R15 convention
    sub r15, 8
    cmp r15, forth_stack
    jl .zbranch_empty_docol ; Use jl not jle - R15==forth_stack means valid element at [R15]
    mov r14, [r15]          ; After sub, old second-on-stack is at [r15]
    jmp .zbranch_test
.zbranch_empty_docol:
    mov r15, forth_stack
    xor r14, r14
.zbranch_test:
    test rbx, rbx
    jnz .exec_loop          ; Non-zero, don't branch
    add rsi, rax            ; Zero, take branch
    jmp .exec_loop

.do_call:
    ; Call the word
    call rax
    jmp .exec_loop

.done:
    ret

; EXIT - Just a marker, not executed
EXIT:
    ret

; Create dictionary entry for new word
create_dict_entry:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    mov rdi, [dict_here]
    mov r8, rdi             ; Save entry start in R8 (not RAX!)

    ; Store link to previous entry
    mov rbx, [dict_latest]
    mov [rdi], rbx
    add rdi, 8

    ; Store name length
    mov rsi, new_word_name
    xor rcx, rcx
.count:
    cmp byte [rsi + rcx], 0
    je .name_done
    inc rcx
    jmp .count
.name_done:
    mov [rdi], cl
    inc rdi

    ; Store name
    mov rsi, new_word_name
    rep movsb

    ; Align to 8 bytes
    mov rax, rdi
    and rax, 7
    test rax, rax
    jz .aligned
    add rdi, 8
    and rdi, ~7
.aligned:

    ; Store code pointer (DOCOL)
    mov qword [rdi], DOCOL
    add rdi, 8

    ; Copy compiled code from compile_buffer
    mov rsi, compile_buffer
    mov rcx, [compile_ptr]
    sub rcx, compile_buffer
    shr rcx, 3              ; Divide by 8 (qwords)
    rep movsq

    ; Store EXIT at end
    mov qword [rdi], EXIT
    add rdi, 8

    ; Update dict_here (next free space)
    mov [dict_here], rdi

    ; Update dict_latest (this entry's start - saved in R8)
    mov [dict_latest], r8

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; Helper: Print newline
newline:
    push rax
    mov rbx, [cursor]
    sub rbx, 0xB8000
    shr rbx, 1
    mov rax, rbx
    xor rdx, rdx
    mov rcx, 80
    div rcx
    inc rax
    xor rdx, rdx
    mul rcx
    shl rax, 1
    add rax, 0xB8000
    mov [cursor], rax
    call update_hw_cursor
    pop rax
    ret

; Skip spaces in buffer pointed by RSI
skip_spaces:
    push rax
.loop:
    mov al, [rsi]
    cmp al, ' '
    jne .done
    inc rsi
    jmp .loop
.done:
    pop rax
    ret

; Parse word from RSI, return start in RDI, length in RCX, advance RSI
parse_word:
    push rax
    mov rdi, rsi            ; Start of word
    xor rcx, rcx            ; Length
.loop:
    mov al, [rsi]
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    inc rsi
    inc rcx
    jmp .loop
.done:
    pop rax
    ret

; Check if word is a number (all digits), returns 1 in RAX if yes
is_number:
    push rbx
    push rcx
    push rdi

    test rcx, rcx
    jz .not_number

    mov rbx, rdi
.check_loop:
    mov al, [rbx]
    cmp al, '0'
    jl .not_number
    cmp al, '9'
    jg .not_number
    inc rbx
    dec rcx
    jnz .check_loop

    mov rax, 1
    jmp .done

.not_number:
    xor rax, rax

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

; Parse number from word (RDI, RCX) into RAX
parse_number:
    push rbx
    push rcx
    push rdi

    xor rax, rax            ; Result
    mov rbx, 10             ; Base

.loop:
    movzx r8, byte [rdi]
    sub r8, '0'
    imul rax, rbx
    add rax, r8
    inc rdi
    dec rcx
    jnz .loop

    pop rdi
    pop rcx
    pop rbx
    ret

; Search dictionary for word (RDI=name, RCX=length)
; Returns code address in RAX, or 0 if not found
search_dictionary:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Start at latest entry
    mov rsi, [dict_latest]
    test rsi, rsi
    jz .not_found           ; Empty dictionary (dict_latest = 0)

.search_loop:
    ; RSI points to start of entry (link field)

    ; Save link for later
    mov r8, [rsi]           ; R8 = link to previous entry

    ; Skip link pointer
    add rsi, 8

    ; Check name length
    movzx rbx, byte [rsi]
    inc rsi
    cmp rbx, rcx
    jne .next_entry

    ; Compare names character by character
    push rsi
    push rdi
    push rcx
.cmp_loop:
    mov al, [rdi]
    mov bl, [rsi]
    cmp al, bl
    jne .name_mismatch
    inc rdi
    inc rsi
    dec rcx
    jnz .cmp_loop

    ; Match! RSI now points right after name
    pop rcx
    pop rdi
    pop rsi

    ; Skip name bytes
    add rsi, rcx

    ; Align to 8 bytes to find code pointer
    mov rax, rsi
    and rax, 7
    test rax, rax
    jz .already_aligned
    add rsi, 8
    and rsi, ~7
.already_aligned:

    ; Return address of code field
    mov rax, rsi
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

.name_mismatch:
    pop rcx
    pop rdi
    pop rsi

.next_entry:
    ; Follow link to previous entry
    mov rsi, r8             ; R8 has the link we saved earlier
    test rsi, rsi
    jz .not_found           ; No more entries (link = 0)
    jmp .search_loop

.not_found:
    xor rax, rax
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Lookup word, return address in RAX (0 if not found)
lookup_word:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Convert word to lowercase for case-insensitive matching
    push rdi
    push rcx
    mov rbx, rdi
.lower_loop:
    mov al, [rbx]
    cmp al, 'A'
    jl .next_char
    cmp al, 'Z'
    jg .next_char
    add byte [rbx], 32      ; Convert to lowercase
.next_char:
    inc rbx
    dec rcx
    jnz .lower_loop
    pop rcx
    pop rdi

    ; Search dictionary first
    call search_dictionary
    test rax, rax
    jz .not_in_dict

    ; Found in dictionary - return it
    jmp .done

.not_in_dict:

    ; Check single-char operators first
    cmp rcx, 1
    jne .check_multi

    mov al, [rdi]
    cmp al, '+'
    je .found_plus
    cmp al, '-'
    je .found_minus
    cmp al, '*'
    je .found_mult
    cmp al, '/'
    je .found_div
    cmp al, '.'
    je .found_dot
    cmp al, ':'
    je .found_colon
    cmp al, ';'
    je .found_semi
    cmp al, '@'
    je .found_fetch
    cmp al, '!'
    je .found_store
    cmp al, '?'
    je .found_inspect
    cmp al, '='
    je .found_eq
    cmp al, '<'
    je .found_lt
    cmp al, '>'
    je .found_gt

    jmp .check_multi

.found_plus:
    mov rax, word_plus
    jmp .done
.found_minus:
    mov rax, word_minus
    jmp .done
.found_mult:
    mov rax, word_mult
    jmp .done
.found_div:
    mov rax, word_div
    jmp .done
.found_dot:
    mov rax, word_dot
    jmp .done
.found_colon:
    mov rax, word_colon
    jmp .done
.found_semi:
    mov rax, word_semi
    jmp .done_immediate    ; ';' is IMMEDIATE - must execute during compile mode
.found_fetch:
    mov rax, word_fetch
    jmp .done
.found_store:
    mov rax, word_store
    jmp .done
.found_inspect:
    mov rax, word_inspect
    jmp .done
.found_eq:
    mov rax, word_eq
    jmp .done
.found_lt:
    mov rax, word_lt
    jmp .done
.found_gt:
    mov rax, word_gt
    jmp .done

.check_multi:
    ; Check multi-char words
    ; .S (stack display)
    cmp rcx, 2
    jne .try_dup
    cmp byte [rdi], '.'
    jne .try_dup
    cmp byte [rdi+1], 's'
    jne .try_dup
    mov rax, word_dots
    jmp .done

.try_dup:
    ; DUP
    cmp rcx, 3
    jne .try_drop
    cmp byte [rdi], 'd'
    jne .try_drop
    cmp byte [rdi+1], 'u'
    jne .try_drop
    cmp byte [rdi+2], 'p'
    jne .try_drop
    mov rax, word_dup
    jmp .done

.try_drop:
    cmp rcx, 4
    jne .try_swap
    cmp byte [rdi], 'd'
    jne .try_swap
    cmp byte [rdi+1], 'r'
    jne .try_swap
    cmp byte [rdi+2], 'o'
    jne .try_swap
    cmp byte [rdi+3], 'p'
    jne .try_swap
    mov rax, word_drop
    jmp .done

.try_swap:
    cmp rcx, 4
    jne .try_over
    cmp byte [rdi], 's'
    jne .try_over
    cmp byte [rdi+1], 'w'
    jne .try_over
    cmp byte [rdi+2], 'a'
    jne .try_over
    cmp byte [rdi+3], 'p'
    jne .try_over
    mov rax, word_swap
    jmp .done

.try_over:
    cmp rcx, 4
    jne .try_emit
    cmp byte [rdi], 'o'
    jne .try_emit
    cmp byte [rdi+1], 'v'
    jne .try_emit
    cmp byte [rdi+2], 'e'
    jne .try_emit
    cmp byte [rdi+3], 'r'
    jne .try_emit
    mov rax, word_over
    jmp .done

.try_emit:
    cmp rcx, 4
    jne .try_rot
    cmp byte [rdi], 'e'
    jne .try_rot
    cmp byte [rdi+1], 'm'
    jne .try_rot
    cmp byte [rdi+2], 'i'
    jne .try_rot
    cmp byte [rdi+3], 't'
    jne .try_rot
    mov rax, word_emit
    jmp .done

.try_rot:
    cmp rcx, 3
    jne .try_cr
    cmp byte [rdi], 'r'
    jne .try_cr
    cmp byte [rdi+1], 'o'
    jne .try_cr
    cmp byte [rdi+2], 't'
    jne .try_cr
    mov rax, word_rot
    jmp .done

.try_cr:
    cmp rcx, 2
    jne .try_exit
    cmp byte [rdi], 'c'
    jne .try_exit
    cmp byte [rdi+1], 'r'
    jne .try_exit
    mov rax, word_cr
    jmp .done

.try_exit:
    cmp rcx, 4
    jne .try_words
    cmp byte [rdi], 'e'
    jne .try_words
    cmp byte [rdi+1], 'x'
    jne .try_words
    cmp byte [rdi+2], 'i'
    jne .try_words
    cmp byte [rdi+3], 't'
    jne .try_words
    mov rax, word_exit
    jmp .done

.try_words:
    cmp rcx, 5
    jne .try_forget
    cmp byte [rdi], 'w'
    jne .try_forget
    cmp byte [rdi+1], 'o'
    jne .try_forget
    cmp byte [rdi+2], 'r'
    jne .try_forget
    cmp byte [rdi+3], 'd'
    jne .try_forget
    cmp byte [rdi+4], 's'
    jne .try_forget
    mov rax, word_words
    jmp .done

.try_forget:
    cmp rcx, 6
    jne .try_execute
    cmp byte [rdi], 'f'
    jne .try_execute
    cmp byte [rdi+1], 'o'
    jne .try_execute
    cmp byte [rdi+2], 'r'
    jne .try_execute
    cmp byte [rdi+3], 'g'
    jne .try_execute
    cmp byte [rdi+4], 'e'
    jne .try_execute
    cmp byte [rdi+5], 't'
    jne .try_execute
    mov rax, word_forget
    jmp .done

.try_execute:
    cmp rcx, 7
    jne .try_array
    cmp byte [rdi], 'e'
    jne .try_see
    cmp byte [rdi+1], 'x'
    jne .try_see
    cmp byte [rdi+2], 'e'
    jne .try_see
    cmp byte [rdi+3], 'c'
    jne .try_see
    cmp byte [rdi+4], 'u'
    jne .try_see
    cmp byte [rdi+5], 't'
    jne .try_see
    cmp byte [rdi+6], 'e'
    jne .try_array
    mov rax, word_execute
    jmp .done

.try_array:
    cmp rcx, 5
    jne .try_at
    cmp byte [rdi], 'a'
    jne .try_at
    cmp byte [rdi+1], 'r'
    jne .try_at
    cmp byte [rdi+2], 'r'
    jne .try_at
    cmp byte [rdi+3], 'a'
    jne .try_at
    cmp byte [rdi+4], 'y'
    jne .try_at
    mov rax, word_array
    jmp .done

.try_at:
    cmp rcx, 2
    jne .try_put
    cmp byte [rdi], 'a'
    jne .try_put
    cmp byte [rdi+1], 't'
    jne .try_put
    mov rax, word_at
    jmp .done

.try_put:
    cmp rcx, 3
    jne .try_free
    cmp byte [rdi], 'p'
    jne .try_free
    cmp byte [rdi+1], 'u'
    jne .try_free
    cmp byte [rdi+2], 't'
    jne .try_free
    mov rax, word_put
    jmp .done

.try_free:
    cmp rcx, 4
    jne .try_screen_get
    cmp byte [rdi], 'f'
    jne .try_see
    cmp byte [rdi+1], 'r'
    jne .try_see
    cmp byte [rdi+2], 'e'
    jne .try_see
    cmp byte [rdi+3], 'e'
    jne .try_screen_get
    mov rax, word_free
    jmp .done

.try_screen_get:
    ; Check if word starts with "screen-" (7 chars)
    cmp rcx, 10
    jl .try_see              ; Too short to be screen-*
    cmp byte [rdi], 's'
    jne .try_see
    cmp byte [rdi+1], 'c'
    jne .try_see
    cmp byte [rdi+2], 'r'
    jne .try_see
    cmp byte [rdi+3], 'e'
    jne .try_see
    cmp byte [rdi+4], 'e'
    jne .try_see
    cmp byte [rdi+5], 'n'
    jne .try_see
    cmp byte [rdi+6], '-'
    jne .try_see

    ; Has screen- prefix, check which variant
    cmp rcx, 10
    je .check_screen_get_set
    cmp rcx, 11
    je .check_screen_char
    cmp rcx, 12
    je .check_screen_clear
    cmp rcx, 13
    je .check_screen_scroll
    jmp .try_see             ; Unknown screen-* length

.check_screen_get_set:
    ; Could be screen-get or screen-set (both 10 chars)
    cmp byte [rdi+7], 'g'
    je .is_screen_get
    cmp byte [rdi+7], 's'
    jne .try_see
    cmp byte [rdi+8], 'e'
    jne .try_see
    cmp byte [rdi+9], 't'
    jne .try_see
    mov rax, word_screen_set
    jmp .done

.is_screen_get:
    cmp byte [rdi+8], 'e'
    jne .try_see
    cmp byte [rdi+9], 't'
    jne .try_see
    mov rax, word_screen_get
    jmp .done

.check_screen_char:
    ; screen-char (11 chars)
    cmp byte [rdi+7], 'c'
    jne .try_see
    cmp byte [rdi+8], 'h'
    jne .try_see
    cmp byte [rdi+9], 'a'
    jne .try_see
    cmp byte [rdi+10], 'r'
    jne .try_see
    mov rax, word_screen_char
    jmp .done

.check_screen_clear:
    ; screen-clear (12 chars)
    cmp byte [rdi+7], 'c'
    jne .try_see
    cmp byte [rdi+8], 'l'
    jne .try_see
    cmp byte [rdi+9], 'e'
    jne .try_see
    cmp byte [rdi+10], 'a'
    jne .try_see
    cmp byte [rdi+11], 'r'
    jne .try_see
    mov rax, word_screen_clear
    jmp .done

.check_screen_scroll:
    ; screen-scroll (13 chars)
    cmp byte [rdi+7], 's'
    jne .try_see
    cmp byte [rdi+8], 'c'
    jne .try_see
    cmp byte [rdi+9], 'r'
    jne .try_see
    cmp byte [rdi+10], 'o'
    jne .try_see
    cmp byte [rdi+11], 'l'
    jne .try_see
    cmp byte [rdi+12], 'l'
    jne .try_see
    mov rax, word_screen_scroll
    jmp .done

.try_see:
    cmp rcx, 3
    jne .try_len
    cmp byte [rdi], 's'
    jne .try_len
    cmp byte [rdi+1], 'e'
    jne .try_len
    cmp byte [rdi+2], 'e'
    jne .try_len
    mov rax, word_see
    jmp .done

.try_len:
    cmp rcx, 3
    jne .try_type
    cmp byte [rdi], 'l'
    jne .try_type
    cmp byte [rdi+1], 'e'
    jne .try_type
    cmp byte [rdi+2], 'n'
    jne .try_type
    mov rax, word_len
    jmp .done

.try_type:
    cmp rcx, 4
    jne .try_type_new
    cmp byte [rdi], 't'
    jne .try_type_new
    cmp byte [rdi+1], 'y'
    jne .try_type_new
    cmp byte [rdi+2], 'p'
    jne .try_type_new
    cmp byte [rdi+3], 'e'
    jne .try_type_new
    mov rax, word_type
    jmp .done

.try_type_new:
    ; type-new (8 chars)
    cmp rcx, 8
    jne .try_type_name
    cmp byte [rdi], 't'
    jne .try_type_name
    cmp byte [rdi+1], 'y'
    jne .try_type_name
    cmp byte [rdi+2], 'p'
    jne .try_type_name
    cmp byte [rdi+3], 'e'
    jne .try_type_name
    cmp byte [rdi+4], '-'
    jne .try_type_name
    cmp byte [rdi+5], 'n'
    jne .try_type_name
    cmp byte [rdi+6], 'e'
    jne .try_type_name
    cmp byte [rdi+7], 'w'
    jne .try_type_name
    mov rax, word_type_new
    jmp .done

.try_type_name:
    ; type-name (9 chars)
    cmp rcx, 9
    jne .try_type_set
    cmp byte [rdi], 't'
    jne .try_type_set
    cmp byte [rdi+1], 'y'
    jne .try_type_set
    cmp byte [rdi+2], 'p'
    jne .try_type_set
    cmp byte [rdi+3], 'e'
    jne .try_type_set
    cmp byte [rdi+4], '-'
    jne .try_type_set
    cmp byte [rdi+5], 'n'
    jne .try_type_set
    cmp byte [rdi+6], 'a'
    jne .try_type_set
    cmp byte [rdi+7], 'm'
    jne .try_type_set
    cmp byte [rdi+8], 'e'
    jne .try_type_set
    mov rax, word_type_name
    jmp .done

.try_type_set:
    ; type-set (8 chars)
    cmp rcx, 8
    jne .try_type_name_get
    cmp byte [rdi], 't'
    jne .try_type_name_get
    cmp byte [rdi+1], 'y'
    jne .try_type_name_get
    cmp byte [rdi+2], 'p'
    jne .try_type_name_get
    cmp byte [rdi+3], 'e'
    jne .try_type_name_get
    cmp byte [rdi+4], '-'
    jne .try_type_name_get
    cmp byte [rdi+5], 's'
    jne .try_type_name_get
    cmp byte [rdi+6], 'e'
    jne .try_type_name_get
    cmp byte [rdi+7], 't'
    jne .try_type_name_get
    mov rax, word_type_set
    jmp .done

.try_type_name_get:
    ; type-name? (10 chars)
    cmp rcx, 10
    jne .try_key_check
    cmp byte [rdi], 't'
    jne .try_key_check
    cmp byte [rdi+1], 'y'
    jne .try_key_check
    cmp byte [rdi+2], 'p'
    jne .try_key_check
    cmp byte [rdi+3], 'e'
    jne .try_key_check
    cmp byte [rdi+4], '-'
    jne .try_key_check
    cmp byte [rdi+5], 'n'
    jne .try_key_check
    cmp byte [rdi+6], 'a'
    jne .try_key_check
    cmp byte [rdi+7], 'm'
    jne .try_key_check
    cmp byte [rdi+8], 'e'
    jne .try_key_check
    cmp byte [rdi+9], '?'
    jne .try_key_check
    mov rax, word_type_name_get
    jmp .done

.try_key_check:
    ; key? (4 chars)
    cmp rcx, 4
    jne .try_key_escape
    cmp byte [rdi], 'k'
    jne .try_key_escape
    cmp byte [rdi+1], 'e'
    jne .try_key_escape
    cmp byte [rdi+2], 'y'
    jne .try_key_escape
    cmp byte [rdi+3], '?'
    jne .try_key_escape
    mov rax, word_key_check
    jmp .done

.try_key_escape:
    ; key-escape (10 chars)
    cmp rcx, 10
    jne .try_key_up
    cmp byte [rdi], 'k'
    jne .try_key_up
    cmp byte [rdi+1], 'e'
    jne .try_key_up
    cmp byte [rdi+2], 'y'
    jne .try_key_up
    cmp byte [rdi+3], '-'
    jne .try_key_up
    cmp byte [rdi+4], 'e'
    jne .try_key_up
    cmp byte [rdi+5], 's'
    jne .try_key_up
    cmp byte [rdi+6], 'c'
    jne .try_key_up
    cmp byte [rdi+7], 'a'
    jne .try_key_up
    cmp byte [rdi+8], 'p'
    jne .try_key_up
    cmp byte [rdi+9], 'e'
    jne .try_key_up
    mov rax, word_key_escape
    jmp .done

.try_key_up:
    ; key-up (6 chars)
    cmp rcx, 6
    jne .try_key_down
    cmp byte [rdi], 'k'
    jne .try_key_down
    cmp byte [rdi+1], 'e'
    jne .try_key_down
    cmp byte [rdi+2], 'y'
    jne .try_key_down
    cmp byte [rdi+3], '-'
    jne .try_key_down
    cmp byte [rdi+4], 'u'
    jne .try_key_down
    cmp byte [rdi+5], 'p'
    jne .try_key_down
    mov rax, word_key_up
    jmp .done

.try_key_down:
    ; key-down (8 chars)
    cmp rcx, 8
    jne .try_key_left
    cmp byte [rdi], 'k'
    jne .try_key_left
    cmp byte [rdi+1], 'e'
    jne .try_key_left
    cmp byte [rdi+2], 'y'
    jne .try_key_left
    cmp byte [rdi+3], '-'
    jne .try_key_left
    cmp byte [rdi+4], 'd'
    jne .try_key_left
    cmp byte [rdi+5], 'o'
    jne .try_key_left
    cmp byte [rdi+6], 'w'
    jne .try_key_left
    cmp byte [rdi+7], 'n'
    jne .try_key_left
    mov rax, word_key_down
    jmp .done

.try_key_left:
    ; key-left (8 chars)
    cmp rcx, 8
    jne .try_key_right
    cmp byte [rdi], 'k'
    jne .try_key_right
    cmp byte [rdi+1], 'e'
    jne .try_key_right
    cmp byte [rdi+2], 'y'
    jne .try_key_right
    cmp byte [rdi+3], '-'
    jne .try_key_right
    cmp byte [rdi+4], 'l'
    jne .try_key_right
    cmp byte [rdi+5], 'e'
    jne .try_key_right
    cmp byte [rdi+6], 'f'
    jne .try_key_right
    cmp byte [rdi+7], 't'
    jne .try_key_right
    mov rax, word_key_left
    jmp .done

.try_key_right:
    ; key-right (9 chars)
    cmp rcx, 9
    jne .try_neq
    cmp byte [rdi], 'k'
    jne .try_neq
    cmp byte [rdi+1], 'e'
    jne .try_neq
    cmp byte [rdi+2], 'y'
    jne .try_neq
    cmp byte [rdi+3], '-'
    jne .try_neq
    cmp byte [rdi+4], 'r'
    jne .try_neq
    cmp byte [rdi+5], 'i'
    jne .try_neq
    cmp byte [rdi+6], 'g'
    jne .try_neq
    cmp byte [rdi+7], 'h'
    jne .try_neq
    cmp byte [rdi+8], 't'
    jne .try_neq
    mov rax, word_key_right
    jmp .done

.try_neq:
    ; <> (2 chars)
    cmp rcx, 2
    jne .try_le
    cmp byte [rdi], '<'
    jne .try_le
    cmp byte [rdi+1], '>'
    jne .try_le
    mov rax, word_neq
    jmp .done

.try_le:
    ; <= (2 chars)
    cmp rcx, 2
    jne .try_ge
    cmp byte [rdi], '<'
    jne .try_ge
    cmp byte [rdi+1], '='
    jne .try_ge
    mov rax, word_le
    jmp .done

.try_ge:
    ; >= (2 chars)
    cmp rcx, 2
    jne .try_zeq
    cmp byte [rdi], '>'
    jne .try_zeq
    cmp byte [rdi+1], '='
    jne .try_zeq
    mov rax, word_ge
    jmp .done

.try_zeq:
    ; 0= (2 chars)
    cmp rcx, 2
    jne .try_mod
    cmp byte [rdi], '0'
    jne .try_mod
    cmp byte [rdi+1], '='
    jne .try_mod
    mov rax, word_zeq
    jmp .done

.try_mod:
    ; mod (3 chars)
    cmp rcx, 3
    jne .try_and
    cmp byte [rdi], 'm'
    jne .try_and
    cmp byte [rdi+1], 'o'
    jne .try_and
    cmp byte [rdi+2], 'd'
    jne .try_and
    mov rax, word_mod
    jmp .done

.try_and:
    ; and (3 chars)
    cmp rcx, 3
    jne .try_or
    cmp byte [rdi], 'a'
    jne .try_or
    cmp byte [rdi+1], 'n'
    jne .try_or
    cmp byte [rdi+2], 'd'
    jne .try_or
    mov rax, word_and
    jmp .done

.try_or:
    ; or (2 chars)
    cmp rcx, 2
    jne .try_xor
    cmp byte [rdi], 'o'
    jne .try_xor
    cmp byte [rdi+1], 'r'
    jne .try_xor
    mov rax, word_or
    jmp .done

.try_xor:
    ; xor (3 chars)
    cmp rcx, 3
    jne .try_not
    cmp byte [rdi], 'x'
    jne .try_not
    cmp byte [rdi+1], 'o'
    jne .try_not
    cmp byte [rdi+2], 'r'
    jne .try_not
    mov rax, word_xor
    jmp .done

.try_not:
    ; not (3 chars)
    cmp rcx, 3
    jne .try_if
    cmp byte [rdi], 'n'
    jne .try_if
    cmp byte [rdi+1], 'o'
    jne .try_if
    cmp byte [rdi+2], 't'
    jne .try_if
    mov rax, word_not
    jmp .done

.try_if:
    ; if (2 chars) - IMMEDIATE
    cmp rcx, 2
    jne .try_then
    cmp byte [rdi], 'i'
    jne .try_then
    cmp byte [rdi+1], 'f'
    jne .try_then
    mov rax, word_if
    jmp .done_immediate

.try_then:
    ; then (4 chars) - IMMEDIATE
    cmp rcx, 4
    jne .try_else
    cmp byte [rdi], 't'
    jne .try_else
    cmp byte [rdi+1], 'h'
    jne .try_else
    cmp byte [rdi+2], 'e'
    jne .try_else
    cmp byte [rdi+3], 'n'
    jne .try_else
    mov rax, word_then
    jmp .done_immediate

.try_else:
    ; else (4 chars) - IMMEDIATE
    cmp rcx, 4
    jne .try_begin
    cmp byte [rdi], 'e'
    jne .try_begin
    cmp byte [rdi+1], 'l'
    jne .try_begin
    cmp byte [rdi+2], 's'
    jne .try_begin
    cmp byte [rdi+3], 'e'
    jne .try_begin
    mov rax, word_else
    jmp .done_immediate

.try_begin:
    ; begin (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_until
    cmp byte [rdi], 'b'
    jne .try_until
    cmp byte [rdi+1], 'e'
    jne .try_until
    cmp byte [rdi+2], 'g'
    jne .try_until
    cmp byte [rdi+3], 'i'
    jne .try_until
    cmp byte [rdi+4], 'n'
    jne .try_until
    mov rax, word_begin
    jmp .done_immediate

.try_until:
    ; until (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_while
    cmp byte [rdi], 'u'
    jne .try_while
    cmp byte [rdi+1], 'n'
    jne .try_while
    cmp byte [rdi+2], 't'
    jne .try_while
    cmp byte [rdi+3], 'i'
    jne .try_while
    cmp byte [rdi+4], 'l'
    jne .try_while
    mov rax, word_until
    jmp .done_immediate

.try_while:
    ; while (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_repeat
    cmp byte [rdi], 'w'
    jne .try_repeat
    cmp byte [rdi+1], 'h'
    jne .try_repeat
    cmp byte [rdi+2], 'i'
    jne .try_repeat
    cmp byte [rdi+3], 'l'
    jne .try_repeat
    cmp byte [rdi+4], 'e'
    jne .try_repeat
    mov rax, word_while
    jmp .done_immediate

.try_repeat:
    ; repeat (6 chars) - IMMEDIATE
    cmp rcx, 6
    jne .try_again
    cmp byte [rdi], 'r'
    jne .try_again
    cmp byte [rdi+1], 'e'
    jne .try_again
    cmp byte [rdi+2], 'p'
    jne .try_again
    cmp byte [rdi+3], 'e'
    jne .try_again
    cmp byte [rdi+4], 'a'
    jne .try_again
    cmp byte [rdi+5], 't'
    jne .try_again
    mov rax, word_repeat
    jmp .done_immediate

.try_again:
    ; again (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_app_enter
    cmp byte [rdi], 'a'
    jne .try_app_enter
    cmp byte [rdi+1], 'g'
    jne .try_app_enter
    cmp byte [rdi+2], 'a'
    jne .try_app_enter
    cmp byte [rdi+3], 'i'
    jne .try_app_enter
    cmp byte [rdi+4], 'n'
    jne .try_app_enter
    mov rax, word_again
    jmp .done_immediate

.try_app_enter:
    ; app-enter (9 chars)
    cmp rcx, 9
    jne .try_app_exit
    cmp byte [rdi], 'a'
    jne .try_app_exit
    cmp byte [rdi+1], 'p'
    jne .try_app_exit
    cmp byte [rdi+2], 'p'
    jne .try_app_exit
    cmp byte [rdi+3], '-'
    jne .try_app_exit
    cmp byte [rdi+4], 'e'
    jne .try_app_exit
    cmp byte [rdi+5], 'n'
    jne .try_app_exit
    cmp byte [rdi+6], 't'
    jne .try_app_exit
    cmp byte [rdi+7], 'e'
    jne .try_app_exit
    cmp byte [rdi+8], 'r'
    jne .try_app_exit
    mov rax, word_app_enter
    jmp .done

.try_app_exit:
    ; app-exit (8 chars)
    cmp rcx, 8
    jne .try_app_stack
    cmp byte [rdi], 'a'
    jne .try_app_stack
    cmp byte [rdi+1], 'p'
    jne .try_app_stack
    cmp byte [rdi+2], 'p'
    jne .try_app_stack
    cmp byte [rdi+3], '-'
    jne .try_app_stack
    cmp byte [rdi+4], 'e'
    jne .try_app_stack
    cmp byte [rdi+5], 'x'
    jne .try_app_stack
    cmp byte [rdi+6], 'i'
    jne .try_app_stack
    cmp byte [rdi+7], 't'
    jne .try_app_stack
    mov rax, word_app_exit
    jmp .done

.try_app_stack:
    ; app-stack (9 chars)
    cmp rcx, 9
    jne .try_app_depth
    cmp byte [rdi], 'a'
    jne .try_app_depth
    cmp byte [rdi+1], 'p'
    jne .try_app_depth
    cmp byte [rdi+2], 'p'
    jne .try_app_depth
    cmp byte [rdi+3], '-'
    jne .try_app_depth
    cmp byte [rdi+4], 's'
    jne .try_app_depth
    cmp byte [rdi+5], 't'
    jne .try_app_depth
    cmp byte [rdi+6], 'a'
    jne .try_app_depth
    cmp byte [rdi+7], 'c'
    jne .try_app_depth
    cmp byte [rdi+8], 'k'
    jne .try_app_depth
    mov rax, word_app_stack
    jmp .done

.try_app_depth:
    ; app-depth (9 chars)
    cmp rcx, 9
    jne .try_disk_read
    cmp byte [rdi], 'a'
    jne .try_disk_read
    cmp byte [rdi+1], 'p'
    jne .try_disk_read
    cmp byte [rdi+2], 'p'
    jne .try_disk_read
    cmp byte [rdi+3], '-'
    jne .try_disk_read
    cmp byte [rdi+4], 'd'
    jne .try_disk_read
    cmp byte [rdi+5], 'e'
    jne .try_disk_read
    cmp byte [rdi+6], 'p'
    jne .try_disk_read
    cmp byte [rdi+7], 't'
    jne .try_disk_read
    cmp byte [rdi+8], 'h'
    jne .try_disk_read
    mov rax, word_app_depth
    jmp .done

.try_disk_read:
    ; disk-read (9 chars) - read sector from disk
    cmp rcx, 9
    jne .try_disk_write
    cmp byte [rdi], 'd'
    jne .try_disk_write
    cmp byte [rdi+1], 'i'
    jne .try_disk_write
    cmp byte [rdi+2], 's'
    jne .try_disk_write
    cmp byte [rdi+3], 'k'
    jne .try_disk_write
    cmp byte [rdi+4], '-'
    jne .try_disk_write
    cmp byte [rdi+5], 'r'
    jne .try_disk_write
    cmp byte [rdi+6], 'e'
    jne .try_disk_write
    cmp byte [rdi+7], 'a'
    jne .try_disk_write
    cmp byte [rdi+8], 'd'
    jne .try_disk_write
    mov rax, word_disk_read
    jmp .done

.try_disk_write:
    ; disk-write (10 chars) - write sector to disk
    cmp rcx, 10
    jne .try_ed
    cmp byte [rdi], 'd'
    jne .try_ed
    cmp byte [rdi+1], 'i'
    jne .try_ed
    cmp byte [rdi+2], 's'
    jne .try_ed
    cmp byte [rdi+3], 'k'
    jne .try_ed
    cmp byte [rdi+4], '-'
    jne .try_ed
    cmp byte [rdi+5], 'w'
    jne .try_ed
    cmp byte [rdi+6], 'r'
    jne .try_ed
    cmp byte [rdi+7], 'i'
    jne .try_ed
    cmp byte [rdi+8], 't'
    jne .try_ed
    cmp byte [rdi+9], 'e'
    jne .try_load
    mov rax, word_disk_write
    jmp .done

.try_load:
    ; load (4 chars) - load and run Forth app from disk
    cmp rcx, 4
    jne .try_ed
    cmp byte [rdi], 'l'
    jne .try_ed
    cmp byte [rdi+1], 'o'
    jne .try_ed
    cmp byte [rdi+2], 'a'
    jne .try_ed
    cmp byte [rdi+3], 'd'
    jne .try_ed
    mov rax, word_load
    jmp .done

.try_ed:
    ; ed (2 chars) - mini editor
    cmp rcx, 2
    jne .not_found
    cmp byte [rdi], 'e'
    jne .not_found
    cmp byte [rdi+1], 'd'
    jne .not_found
    mov rax, word_ed
    jmp .done

.done_immediate:
    ; Mark as immediate by setting high bit (bit 63)
    bts rax, 63
    jmp .done

.not_found:
    xor rax, rax

.done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Word implementations for REPL (using R15 as Forth stack)
word_plus:
    ; Add: pop second, add to TOS (in R14)
    sub r15, 8
    add r14, [r15]
    ret

word_minus:
    ; Subtract: second - TOS, result in TOS
    sub r15, 8
    mov rax, [r15]
    sub rax, r14
    mov r14, rax
    ret

word_mult:
    ; Multiply: second * TOS
    sub r15, 8
    imul r14, [r15]
    ret

word_div:
    ; Divide: second / TOS
    sub r15, 8
    mov rax, [r15]          ; Dividend (second)
    mov rbx, r14            ; Divisor (TOS)
    xor rdx, rdx
    div rbx
    mov r14, rax            ; Quotient becomes TOS
    ret

word_mod:
    ; Modulo: second mod TOS
    sub r15, 8
    mov rax, [r15]          ; Dividend (second)
    mov rbx, r14            ; Divisor (TOS)
    xor rdx, rdx
    div rbx
    mov r14, rdx            ; Remainder becomes TOS
    ret

word_eq:
    ; Equal: second = TOS -> flag ( a b -- flag )
    sub r15, 8
    mov rax, [r15]
    cmp rax, r14
    je .eq_true
    xor r14, r14            ; 0 = false
    ret
.eq_true:
    mov r14, -1             ; -1 = true (all bits set)
    ret

word_neq:
    ; Not equal: second <> TOS -> flag
    sub r15, 8
    mov rax, [r15]
    cmp rax, r14
    jne .neq_true
    xor r14, r14
    ret
.neq_true:
    mov r14, -1
    ret

word_lt:
    ; Less than: second < TOS -> flag
    sub r15, 8
    mov rax, [r15]
    cmp rax, r14
    jl .lt_true
    xor r14, r14
    ret
.lt_true:
    mov r14, -1
    ret

word_gt:
    ; Greater than: second > TOS -> flag
    sub r15, 8
    mov rax, [r15]
    cmp rax, r14
    jg .gt_true
    xor r14, r14
    ret
.gt_true:
    mov r14, -1
    ret

word_le:
    ; Less or equal: second <= TOS -> flag
    sub r15, 8
    mov rax, [r15]
    cmp rax, r14
    jle .le_true
    xor r14, r14
    ret
.le_true:
    mov r14, -1
    ret

word_ge:
    ; Greater or equal: second >= TOS -> flag
    sub r15, 8
    mov rax, [r15]
    cmp rax, r14
    jge .ge_true
    xor r14, r14
    ret
.ge_true:
    mov r14, -1
    ret

word_zeq:
    ; Zero equal: TOS = 0 -> flag ( n -- flag )
    test r14, r14
    jz .zeq_true
    xor r14, r14
    ret
.zeq_true:
    mov r14, -1
    ret

word_and:
    ; Bitwise AND ( a b -- a&b )
    sub r15, 8
    and r14, [r15]
    ret

word_or:
    ; Bitwise OR ( a b -- a|b )
    sub r15, 8
    or r14, [r15]
    ret

word_xor:
    ; Bitwise XOR ( a b -- a^b )
    sub r15, 8
    xor r14, [r15]
    ret

word_not:
    ; Logical NOT ( flag -- flag' )
    test r14, r14
    jz .not_true
    xor r14, r14
    ret
.not_true:
    mov r14, -1
    ret

word_dot:
    ; Print TOS and load new TOS
    mov rax, r14

    ; Check if immediate integer (< 0x100000)
    cmp rax, 0x100000
    jl .print_immediate

    ; Object - check type
    mov rbx, [rax]          ; Get type tag
    cmp rbx, TYPE_STRING
    je .print_string_obj
    cmp rbx, TYPE_REF
    je .print_ref_obj
    cmp rbx, TYPE_ARRAY
    je .print_array_obj

    ; Check for user-defined type
    cmp rbx, TYPE_USER_BASE
    jge .print_user_obj

    ; Unknown type - print address
    call print_number
    jmp .dot_done

.print_array_obj:
    ; Print array contents: [ elem1 elem2 ... ]
    push rax
    mov al, '['
    call emit_char
    mov al, ' '
    call emit_char
    pop rax

    ; Get count and print elements
    push rax
    mov rcx, [rax+8]        ; Count
    lea rdi, [rax+16]       ; Data start
.print_arr_loop:
    test rcx, rcx
    jz .print_arr_done
    push rcx
    push rdi
    mov rax, [rdi]
    ; Recursively print element (simplified - just number for now)
    cmp rax, 0x100000
    jl .arr_elem_int
    ; Object element - print type tag
    mov rbx, [rax]
    push rax
    mov al, '['
    call emit_char
    mov rax, rbx
    call print_number
    mov al, ']'
    call emit_char
    pop rax
    jmp .arr_elem_done
.arr_elem_int:
    call print_number
.arr_elem_done:
    mov al, ' '
    call emit_char
    pop rdi
    pop rcx
    add rdi, 8
    dec rcx
    jmp .print_arr_loop
.print_arr_done:
    pop rax
    mov al, ']'
    call emit_char
    jmp .dot_done

.print_user_obj:
    ; User type - print [typename: data...]
    push rax
    push rbx
    mov al, '['
    call emit_char

    ; Get type name
    mov rax, rbx
    sub rax, TYPE_USER_BASE
    mov rax, [type_registry + rax*8]
    test rax, rax
    jz .user_no_name

    ; Print type name
    lea rax, [rax+16]       ; String data
    call print_string
    jmp .user_after_name

.user_no_name:
    ; No name - print type number
    pop rbx
    push rbx
    mov rax, rbx
    call print_number

.user_after_name:
    mov al, ':'
    call emit_char
    mov al, ' '
    call emit_char

    ; Print array-like contents (user types are arrays with different tag)
    pop rbx
    pop rax
    push rax
    mov rcx, [rax+8]        ; Count/size
    lea rdi, [rax+16]       ; Data start
.user_print_loop:
    test rcx, rcx
    jz .user_print_done
    push rcx
    push rdi
    mov rax, [rdi]
    cmp rax, 0x100000
    jl .user_elem_int
    mov al, '.'
    call emit_char
    jmp .user_elem_done
.user_elem_int:
    call print_number
.user_elem_done:
    mov al, ' '
    call emit_char
    pop rdi
    pop rcx
    add rdi, 8
    dec rcx
    jmp .user_print_loop
.user_print_done:
    pop rax
    mov al, ']'
    call emit_char
    jmp .dot_done

.print_immediate:
    call print_number
    jmp .dot_done

.print_string_obj:
    ; Print string object data
    lea rax, [rax+16]       ; Skip header to data
    call print_string
    jmp .dot_done

.print_ref_obj:
    ; Print ref as "(code)"
    push rax
    mov rax, str_code_obj
    call print_string
    pop rax
    jmp .dot_done

.dot_done:
    ; Pop: decrement depth, load new TOS from memory
    ; Convention: depth = (R15 - forth_stack) / 8
    ; After pop: depth decreases by 1
    sub r15, 8
    cmp r15, forth_stack
    jle .dot_empty
    ; Still have items - load new TOS from memory
    mov r14, [r15 - 8]      ; mem[depth-2] becomes new TOS
    ret

.dot_empty:
    ; Stack is now empty
    mov r15, forth_stack
    xor r14, r14            ; R14 undefined, set to 0
    ret

str_code_obj: db '(code)', 0

word_dots:
    ; Display stack: <depth> item1 item2 ...
    ; Shows type-aware representation: 42 "str" [arr:3] (ref)
    ; Convention: depth = (R15 - stack_base) / 8
    ; Depth 0: empty, Depth N: TOS in R14, rest in mem[0..N-2]
    ; App-aware: uses app_stack when app_active, else forth_stack
    push rax
    push rbx
    push rcx
    push rdi
    push r8                 ; R8 = stack base

    ; Get correct stack base
    mov r8, forth_stack
    cmp qword [app_active], 0
    je .have_base
    mov r8, app_stack
.have_base:

    ; Calculate depth
    mov rax, r15
    sub rax, r8
    shr rax, 3              ; Depth = (R15 - stack_base) / 8
    mov rcx, rax

    ; Print <depth>
    mov al, '<'
    call emit_char
    mov rax, rcx
    call print_number
    mov al, '>'
    call emit_char

    ; If empty, done
    test rcx, rcx
    jz .done

    mov al, ' '
    call emit_char

    ; Print memory items (depth - 1 items in mem[0..depth-2])
    dec rcx                 ; Memory items = depth - 1
    jz .print_tos           ; If was depth 1, skip to TOS

    ; Items stored at [base+8], [base+16], ..., [R15-8]
    lea rdi, [r8 + 8]       ; Start at base + 8 (first stored item)
.loop:
    mov rax, [rdi]
    call print_value_typed
    mov al, ' '
    call emit_char
    add rdi, 8
    dec rcx
    jnz .loop

.print_tos:
    ; Print TOS (R14)
    mov rax, r14
    call print_value_typed

.done:
    pop r8
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; Print value with type indicator
; RAX = value to print
print_value_typed:
    push rbx

    ; Check if immediate integer (< 0x100000)
    cmp rax, 0x100000
    jl .print_int

    ; Object - check type
    mov rbx, [rax]
    cmp rbx, TYPE_STRING
    je .print_str
    cmp rbx, TYPE_ARRAY
    je .print_arr
    cmp rbx, TYPE_REF
    je .print_ref

    ; Unknown object - print address
    call print_number
    jmp .done

.print_int:
    call print_number
    jmp .done

.print_str:
    ; Print "content" (abbreviated if long)
    push rax
    mov al, '"'
    call emit_char
    pop rax
    push rax
    lea rax, [rax+16]       ; String data
    call print_string_short ; Max 10 chars
    pop rax
    push rax
    mov al, '"'
    call emit_char
    pop rax
    jmp .done

.print_arr:
    ; Print [arr:N]
    push rax
    mov al, '['
    call emit_char
    mov rax, str_arr_tag
    call print_string
    pop rax
    mov rax, [rax+8]        ; Size
    call print_number
    mov al, ']'
    call emit_char
    jmp .done

.print_ref:
    ; Print (ref)
    mov rax, str_ref_tag
    call print_string
    jmp .done

.done:
    pop rbx
    ret

str_arr_tag: db 'arr:', 0
str_ref_tag: db '(ref)', 0

; Print string, max 10 chars (for .s display)
print_string_short:
    push rbx
    push rcx
    mov rbx, rax
    mov rcx, 10             ; Max chars
.loop:
    mov al, [rbx]
    test al, al
    jz .done
    call emit_char
    inc rbx
    dec rcx
    jz .truncated
    jmp .loop
.truncated:
    mov al, '.'
    call emit_char
    call emit_char
    call emit_char
.done:
    pop rcx
    pop rbx
    ret

word_dup:
    ; Duplicate TOS: push R14, R14 unchanged
    mov [r15], r14
    add r15, 8
    ret

word_drop:
    ; Drop TOS: decrement depth, load new TOS from memory
    sub r15, 8
    cmp r15, forth_stack
    jle .drop_empty
    mov r14, [r15 - 8]
    ret
.drop_empty:
    mov r15, forth_stack
    xor r14, r14
    ret

word_swap:
    ; Swap TOS with second: exchange R14 and [R15-8]
    sub r15, 8
    xchg r14, [r15]
    add r15, 8
    ret

word_rot:
    ; Rotate top 3: ( a b c -- b c a )
    sub r15, 8
    mov rax, [r15]          ; b
    sub r15, 8
    mov rbx, [r15]          ; a
    mov [r15], rax          ; b
    add r15, 8
    mov [r15], r14          ; c
    add r15, 8
    mov r14, rbx            ; a becomes TOS
    ret

word_over:
    ; Copy second to TOS: ( a b -- a b a )
    mov [r15], r14          ; Push current TOS
    add r15, 8
    mov r14, [r15-16]       ; Second becomes new TOS
    ret

word_emit:
    ; Emit character from TOS
    mov rax, r14
    ; Also output to serial for debugging
    push rax
    call serial_putchar
    pop rax
    ; Check if newline (10)
    cmp rax, 10
    je .emit_newline
    ; Regular character
    call emit_char
    sub r15, 8
    mov r14, [r15]          ; Load new TOS
    ret
.emit_newline:
    ; Call proper newline function
    call newline
    sub r15, 8
    mov r14, [r15]          ; Load new TOS
    ret

word_cr:
    ; Newline (doesn't consume stack)
    call newline
    ret

word_exit:
    ; Exit SimplicityOS cleanly
    ; Print goodbye message
    push rax
    mov rax, str_goodbye
    call print_string
    call newline
    pop rax

    ; ACPI shutdown for QEMU (port 0x604, value 0x2000)
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax

    ; Fallback: halt loop if shutdown fails
.halt:
    hlt
    jmp .halt

word_fetch:
    ; Fetch: TOS is address, replace with value at address
    ; Validate address (check it's not a small immediate)
    cmp r14, 1000
    jl .fetch_invalid       ; Very small values likely wrong

    mov rax, [r14]
    mov r14, rax
    ret

.fetch_invalid:
    ; Return error STRING
    push rsi
    mov rsi, str_bad_addr
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

word_store:
    ; Store: ( value addr -- ) second=value, TOS=addr
    ; Validate address (basic check)
    cmp r14, 1000
    jl .store_invalid

    mov rax, r14            ; Address
    sub r15, 8
    mov rbx, [r15]          ; Value
    mov [rax], rbx
    sub r15, 8
    mov r14, [r15]          ; New TOS
    ret

.store_invalid:
    ; Return error, clean stack
    sub r15, 8
    sub r15, 8
    push rsi
    mov rsi, str_bad_addr
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

str_bad_addr: db '(bad address)', 0

word_inspect:
    ; ? - Inspect reference from TOS, push STRING description
    mov rax, r14            ; Get TOS reference

    test rax, rax
    jz .push_unknown

    ; Check if dictionary or built-in
    cmp rax, dictionary_space
    jl .push_builtin

    ; Dictionary word - create STRING "(colon)"
    push rsi
    mov rsi, str_colon_ref
    call create_string_from_cstr
    pop rsi
    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

.push_builtin:
    push rsi
    mov rsi, str_builtin_ref
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

.push_unknown:
    push rsi
    mov rsi, str_unknown
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

str_colon_ref: db '(colon)', 0
str_builtin_ref: db '(built-in)', 0

word_execute:
    ; Execute code reference from TOS
    mov rax, r14            ; Get reference from TOS

    ; Load new TOS
    sub r15, 8
    mov r14, [r15]

    ; Validate reference (check for null/invalid)
    test rax, rax
    jz .invalid_ref

    ; Check if dictionary word
    push rbx
    cmp rax, dictionary_space
    jl .exec_builtin

    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rbx
    jne .exec_builtin

    ; Dictionary word - execute definition body
    mov [rbp], rsi
    sub rbp, 8
    add rax, 8              ; Skip to body
    mov rsi, rax

.exec_loop:
    lodsq
    cmp rax, EXIT
    je .exec_end

    cmp rax, LIT
    jne .check_branch
    ; LIT - push next value
    lodsq
    cmp r15, forth_stack
    je .lit_first
    mov [r15-8], r14
    add r15, 8
    mov r14, rax
    jmp .exec_loop
.lit_first:
    mov r14, rax
    add r15, 8
    jmp .exec_loop

.check_branch:
    cmp rax, BRANCH
    jne .check_zbranch
    ; BRANCH - unconditional jump
    lodsq                   ; Get offset
    add rsi, rax
    jmp .exec_loop

.check_zbranch:
    cmp rax, ZBRANCH
    jne .exec_call
    ; ZBRANCH - branch if TOS is zero
    lodsq                   ; Get offset
    mov rbx, r14            ; Get TOS
    ; Pop TOS using R14/R15 convention
    sub r15, 8
    cmp r15, forth_stack
    jl .zbranch_empty       ; Use jl not jle - R15==forth_stack means valid element at [R15]
    mov r14, [r15]          ; After sub, old second-on-stack is at [r15]
    jmp .zbranch_check
.zbranch_empty:
    mov r15, forth_stack
    xor r14, r14
.zbranch_check:
    test rbx, rbx
    jnz .exec_loop          ; Non-zero, don't branch
    add rsi, rax            ; Zero, take branch
    jmp .exec_loop

.exec_call:
    call rax
    jmp .exec_loop

.exec_end:
    add rbp, 8
    mov rsi, [rbp]
    ret

.exec_builtin:
    call rax
    ret

.invalid_ref:
    ; Push error STRING for invalid reference (TOS model)
    push rsi
    mov rsi, str_invalid_ref
    call create_string_from_cstr
    pop rsi
    mov r14, rax            ; Error STRING becomes TOS
    ret

str_invalid_ref: db '(invalid reference)', 0

word_array:
    ; Create ARRAY object ( size -- array )
    mov rax, r14            ; Size from TOS

    ; Allocate: header(16) + size*8 bytes
    push rax
    shl rax, 3              ; size * 8
    add rax, 16
    mov rcx, rax
    call allocate_object
    pop rcx                 ; Restore size

    ; Fill header
    mov qword [rax], TYPE_ARRAY
    mov [rax+8], rcx

    ; Initialize array to zeros
    lea rdi, [rax+16]
    push rax
    mov rax, rcx
.zero_loop:
    mov qword [rdi], 0
    add rdi, 8
    dec rax
    jnz .zero_loop
    pop rax

    ; Push array object to TOS
    mov r14, rax
    ret

word_at:
    ; Array access ( array index -- value ) TOS=index
    mov rbx, r14            ; Index from TOS
    sub r15, 8
    mov rax, [r15]          ; Array from second

    ; Get element: array[index]
    lea rax, [rax + 16 + rbx*8]
    mov r14, [rax]          ; Value becomes TOS
    ret

word_put:
    ; Array store ( value array index -- ) TOS=index
    mov rbx, r14            ; Index from TOS
    sub r15, 8
    mov rcx, [r15]          ; Array from second
    sub r15, 8
    mov rax, [r15]          ; Value from third

    ; Store: array[index] = value
    lea rcx, [rcx + 16 + rbx*8]
    mov [rcx], rax

    ; Load new TOS
    sub r15, 8
    mov r14, [r15]
    ret

word_free:
    ; Free object from TOS (stub - just drops it)
    sub r15, 8
    mov r14, [r15]
    ret

word_len:
    ; LEN - Get length of array or string ( obj -- length )
    mov rax, r14

    ; Check if immediate (no length)
    cmp rax, 0x100000
    jl .len_zero

    ; Get type
    mov rbx, [rax]
    cmp rbx, TYPE_STRING
    je .len_string
    cmp rbx, TYPE_ARRAY
    je .len_array

    ; Unknown type - return 0
.len_zero:
    xor r14, r14
    ret

.len_string:
    ; String length is in header
    mov r14, [rax+8]
    ret

.len_array:
    ; Array length is in header
    mov r14, [rax+8]
    ret

word_type:
    ; TYPE - Get type tag of value ( val -- type )
    ; Returns: 0=INT, 1=STRING, 2=REF, 3=ARRAY, 4+=user
    mov rax, r14

    ; Check if immediate integer
    cmp rax, 0x100000
    jl .type_int

    ; Get type from object header
    mov r14, [rax]
    ret

.type_int:
    xor r14, r14              ; TYPE_INT = 0
    ret

word_type_new:
    ; TYPE-NEW - Allocate a new type tag ( -- type_tag )
    ; Returns next available type tag and increments counter
    push rax

    ; Get current tag
    mov rax, [next_type_tag]

    ; Push to TOS
    cmp r15, forth_stack
    je .tn_first
    mov [r15-8], r14
    add r15, 8
    mov r14, rax
    jmp .tn_done
.tn_first:
    mov r14, rax
    add r15, 8
.tn_done:
    ; Increment for next allocation
    inc qword [next_type_tag]

    pop rax
    ret

word_type_name:
    ; TYPE-NAME - Associate name with type ( str type_tag -- )
    ; str must be a STRING object, type_tag is the type number
    ; Stack before: ... str type_tag (R14=type_tag)
    ; Memory layout: [forth_stack]=str (depth 2, R15=forth_stack+16)
    mov rbx, r14            ; RBX = type_tag

    ; Pop type_tag, get str
    sub r15, 8              ; Pop type_tag (R15 now = forth_stack + 8)
    mov rax, [r15-8]        ; RAX = str at [forth_stack + 0]

    ; Validate type_tag >= TYPE_USER_BASE
    cmp rbx, TYPE_USER_BASE
    jl .tn_invalid

    ; Calculate registry index
    sub rbx, TYPE_USER_BASE
    cmp rbx, 256
    jge .tn_invalid

    ; Store name STRING in registry
    lea rcx, [type_registry + rbx*8]
    mov [rcx], rax

    ; Pop str, load new TOS
    sub r15, 8
    cmp r15, forth_stack
    jle .tn_empty
    mov r14, [r15-8]        ; Load new TOS from memory
    ret

.tn_empty:
    mov r15, forth_stack
    xor r14, r14
    ret

.tn_invalid:
    ; Invalid type tag - just clean stack (pop both)
    sub r15, 8              ; Already decremented once, decrement again
    cmp r15, forth_stack
    jle .tn_empty
    mov r14, [r15-8]
    ret

word_type_set:
    ; TYPE-SET - Change object's type tag ( obj new_type -- obj )
    ; Returns same object with modified type
    mov rax, r14            ; new_type from TOS
    mov rbx, [r15-8]        ; obj from second

    ; Validate obj is actually an object (not immediate)
    cmp rbx, 0x100000
    jl .ts_invalid

    ; Set new type in object header
    mov [rbx], rax

    ; Pop type, keep obj as TOS
    sub r15, 8
    mov r14, rbx
    ret

.ts_invalid:
    ; Can't set type on immediate - return obj unchanged
    sub r15, 8
    mov r14, rbx
    ret

word_type_name_get:
    ; TYPE-NAME? - Get type name ( type_tag -- str|0 )
    ; Returns STRING name or 0 if unnamed
    mov rax, r14            ; type_tag

    ; Check built-in types first
    cmp rax, TYPE_INT
    je .tng_int
    cmp rax, TYPE_STRING
    je .tng_string
    cmp rax, TYPE_REF
    je .tng_ref
    cmp rax, TYPE_ARRAY
    je .tng_array

    ; User type - look up in registry
    cmp rax, TYPE_USER_BASE
    jl .tng_unknown
    sub rax, TYPE_USER_BASE
    cmp rax, 256
    jge .tng_unknown

    ; Get name from registry
    mov r14, [type_registry + rax*8]
    ret

.tng_int:
    push rsi
    mov rsi, str_type_int
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_string:
    push rsi
    mov rsi, str_type_string
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_ref:
    push rsi
    mov rsi, str_type_ref
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_array:
    push rsi
    mov rsi, str_type_array
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_unknown:
    xor r14, r14            ; Return 0 for unknown
    ret

str_type_int: db 'int', 0
str_type_string: db 'string', 0
str_type_ref: db 'ref', 0
str_type_array: db 'array', 0

word_screen_get:
    ; SCREEN-GET - Query VGA text mode parameters
    ; Returns ARRAY: ( width height cursor_x cursor_y )

    ; Create 4-element array
    push rax
    push rbx
    push rcx

    ; Allocate array
    mov rcx, 48             ; 16 (header) + 4*8 (data)
    call allocate_object

    ; Fill header
    mov qword [rax], TYPE_ARRAY
    mov qword [rax+8], 4    ; 4 elements

    ; Save array address
    mov r8, rax

    ; Get cursor position from VGA cursor variable
    mov rbx, [cursor]       ; Get cursor address
    sub rbx, 0xB8000        ; Offset from VGA start
    shr rbx, 1              ; Convert bytes to char position

    ; Divide by 80 to get row and col
    mov rax, rbx
    xor rdx, rdx
    mov rcx, 80
    div rcx                 ; RAX = row (Y), RDX = col (X)

    ; Store params in array
    mov qword [r8+16], 80   ; [0] Width
    mov qword [r8+24], 25   ; [1] Height
    mov qword [r8+32], rdx  ; [2] Cursor X (col)
    mov qword [r8+40], rax  ; [3] Cursor Y (row)

    ; Restore and push array to TOS
    pop rcx
    pop rbx
    pop rax                 ; Restore RAX

    mov [r15], r14          ; Push old TOS
    add r15, 8
    mov r14, r8             ; Array becomes new TOS
    ret

word_screen_set:
    ; SCREEN-SET - Move cursor to x,y ( x y -- )
    ; TOS = y, second = x
    mov rax, r14            ; RAX = y
    sub r15, 8
    mov rbx, [r15]          ; RBX = x

    ; Calculate VGA offset: (y * 80 + x) * 2 + 0xB8000
    imul rax, 80            ; y * 80
    add rax, rbx            ; + x
    shl rax, 1              ; * 2 (char + attr)
    add rax, 0xB8000

    ; Update cursor
    mov [cursor], rax
    call update_hw_cursor

    ; Pop both, load new TOS
    sub r15, 8
    cmp r15, forth_stack
    jle .ss_empty
    mov r14, [r15]          ; Fixed: was [r15-8]
    ret
.ss_empty:
    mov r15, forth_stack
    xor r14, r14
    ret

word_screen_char:
    ; SCREEN-CHAR - Put char at x,y with color ( char color x y -- )
    ; TOS = y, then x, color, char
    mov rax, r14            ; RAX = y
    sub r15, 8
    mov rbx, [r15]          ; RBX = x
    sub r15, 8
    mov rcx, [r15]          ; RCX = color
    sub r15, 8
    mov rdx, [r15]          ; RDX = char

    ; Calculate VGA offset: (y * 80 + x) * 2 + 0xB8000
    imul rax, 80
    add rax, rbx
    shl rax, 1
    add rax, 0xB8000

    ; Write char and color
    mov [rax], dl           ; Character
    mov [rax+1], cl         ; Color attribute

    ; Pop all four, load new TOS
    sub r15, 8
    cmp r15, forth_stack
    jle .sc_empty
    mov r14, [r15]          ; Fixed: was [r15-8]
    ret
.sc_empty:
    mov r15, forth_stack
    xor r14, r14
    ret

word_screen_clear:
    ; SCREEN-CLEAR - Clear screen with color ( color -- )
    mov rcx, r14            ; Color attribute

    ; Clear all 80x25 characters
    mov rdi, 0xB8000
    mov rax, rcx
    shl rax, 8              ; Color in high byte
    or rax, 0x20            ; Space in low byte
    mov rdx, rax
    shl rdx, 16
    or rax, rdx             ; Two chars at once
    shl rdx, 16
    or rax, rdx
    shl rdx, 16
    or rax, rdx             ; Four chars in RAX

    mov rcx, 500            ; 2000 chars / 4 = 500 qwords
.clear_loop:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .clear_loop

    ; Reset cursor to top-left
    mov qword [cursor], 0xB8000
    call update_hw_cursor

    ; Pop color, load new TOS
    sub r15, 8
    cmp r15, forth_stack
    jle .scl_empty
    mov r14, [r15]          ; Fixed: was [r15-8]
    ret
.scl_empty:
    mov r15, forth_stack
    xor r14, r14
    ret

word_screen_scroll:
    ; SCREEN-SCROLL - Scroll screen up n lines ( n -- )
    mov rcx, r14            ; RCX = lines to scroll

    ; Validate
    cmp rcx, 25
    jge .scroll_clear       ; If >= 25, just clear

    ; Calculate bytes to copy: (25 - n) * 80 * 2
    mov rax, 25
    sub rax, rcx
    imul rax, 160           ; (25-n) * 80 * 2

    ; Source: line n = 0xB8000 + n * 160
    mov rsi, rcx
    imul rsi, 160
    add rsi, 0xB8000

    ; Dest: line 0
    mov rdi, 0xB8000

    ; Copy (rax bytes, but we'll do qwords)
    push rcx
    mov rcx, rax
    shr rcx, 3              ; Bytes to qwords
.copy_loop:
    mov rax, [rsi]
    mov [rdi], rax
    add rsi, 8
    add rdi, 8
    dec rcx
    jnz .copy_loop
    pop rcx

    ; Clear bottom n lines
    ; RDI is now at start of area to clear
    imul rcx, 160           ; Bytes to clear
    shr rcx, 3              ; Qwords
    mov rax, 0x0F200F200F200F20  ; Spaces with white-on-black
.clear_bottom:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .clear_bottom

    jmp .scroll_done

.scroll_clear:
    ; Clear entire screen
    mov rdi, 0xB8000
    mov rcx, 500
    mov rax, 0x0F200F200F200F20
.full_clear:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .full_clear

.scroll_done:
    ; Pop n, load new TOS
    sub r15, 8
    cmp r15, forth_stack
    jle .scr_empty
    mov r14, [r15-8]
    ret
.scr_empty:
    mov r15, forth_stack
    xor r14, r14
    ret

word_key_check:
    ; KEY? - Check if key available, return key or 0 ( -- key|0 )
    call check_key

    ; Push to TOS
    cmp r15, forth_stack
    je .kc_first
    mov [r15-8], r14
    add r15, 8
    mov r14, rax
    ret
.kc_first:
    mov r14, rax
    add r15, 8
    ret

word_key_escape:
    ; KEY-ESCAPE - Push escape key constant ( -- 256 )
    cmp r15, forth_stack
    je .ke_first
    mov [r15-8], r14
    add r15, 8
    mov r14, KEY_ESCAPE
    ret
.ke_first:
    mov r14, KEY_ESCAPE
    add r15, 8
    ret

word_key_up:
    ; KEY-UP - Push up arrow constant ( -- 257 )
    cmp r15, forth_stack
    je .ku_first
    mov [r15-8], r14
    add r15, 8
    mov r14, KEY_UP
    ret
.ku_first:
    mov r14, KEY_UP
    add r15, 8
    ret

word_key_down:
    ; KEY-DOWN - Push down arrow constant ( -- 258 )
    cmp r15, forth_stack
    je .kd_first
    mov [r15-8], r14
    add r15, 8
    mov r14, KEY_DOWN
    ret
.kd_first:
    mov r14, KEY_DOWN
    add r15, 8
    ret

word_key_left:
    ; KEY-LEFT - Push left arrow constant ( -- 259 )
    cmp r15, forth_stack
    je .kl_first
    mov [r15-8], r14
    add r15, 8
    mov r14, KEY_LEFT
    ret
.kl_first:
    mov r14, KEY_LEFT
    add r15, 8
    ret

word_key_right:
    ; KEY-RIGHT - Push right arrow constant ( -- 260 )
    cmp r15, forth_stack
    je .kr_first
    mov [r15-8], r14
    add r15, 8
    mov r14, KEY_RIGHT
    ret
.kr_first:
    mov r14, KEY_RIGHT
    add r15, 8
    ret

; Control flow words - IMMEDIATE (execute during compilation)
; These use the control flow stack (reusing part of return stack)
; compile_ptr points to current compilation position

word_if:
    ; IF - compile ZBRANCH with placeholder, push address for THEN/ELSE
    ; Must be in compile mode
    cmp byte [compile_mode], 0
    je .if_error

    mov rbx, [compile_ptr]
    mov qword [rbx], ZBRANCH    ; Compile ZBRANCH
    add rbx, 8
    ; Push address of placeholder to control stack (using return stack)
    mov [rbp], rbx              ; Save location of offset
    sub rbp, 8
    mov qword [rbx], 0          ; Placeholder offset
    add rbx, 8
    mov [compile_ptr], rbx
    ret
.if_error:
    ret

word_then:
    ; THEN - resolve forward branch from IF or ELSE
    cmp byte [compile_mode], 0
    je .then_error

    ; Pop address from control stack
    add rbp, 8
    mov rbx, [rbp]              ; Address of placeholder
    mov rax, [compile_ptr]
    sub rax, rbx                ; Calculate offset
    sub rax, 8                  ; Adjust for already past placeholder
    mov [rbx], rax              ; Fill in the offset
    ret
.then_error:
    ret

word_else:
    ; ELSE - compile BRANCH, resolve IF's placeholder, push new placeholder
    cmp byte [compile_mode], 0
    je .else_error

    mov rcx, [compile_ptr]
    mov qword [rcx], BRANCH     ; Compile unconditional branch
    add rcx, 8

    ; Pop IF's placeholder, push ELSE's placeholder
    add rbp, 8
    mov rbx, [rbp]              ; IF's placeholder address

    mov [rbp], rcx              ; Push ELSE's placeholder address
    sub rbp, 8

    mov qword [rcx], 0          ; ELSE's placeholder
    add rcx, 8
    mov [compile_ptr], rcx

    ; Resolve IF's branch (to here, after ELSE's branch instruction)
    mov rax, [compile_ptr]
    sub rax, rbx
    sub rax, 8
    mov [rbx], rax
    ret
.else_error:
    ret

word_begin:
    ; BEGIN - mark loop start, push address
    cmp byte [compile_mode], 0
    je .begin_error

    ; Push current compile address to control stack
    mov rax, [compile_ptr]
    mov [rbp], rax
    sub rbp, 8
    ret
.begin_error:
    ret

word_until:
    ; UNTIL - compile ZBRANCH back to BEGIN
    cmp byte [compile_mode], 0
    je .until_error

    ; Pop loop start address
    add rbp, 8
    mov rbx, [rbp]              ; BEGIN address

    mov rcx, [compile_ptr]
    mov qword [rcx], ZBRANCH    ; Compile ZBRANCH
    add rcx, 8

    ; Calculate backward offset (negative)
    mov rax, rbx
    sub rax, rcx
    sub rax, 8                  ; Adjust for offset cell itself
    mov [rcx], rax
    add rcx, 8
    mov [compile_ptr], rcx
    ret
.until_error:
    ret

word_while:
    ; WHILE - like IF but inside a loop, push placeholder
    cmp byte [compile_mode], 0
    je .while_error

    mov rbx, [compile_ptr]
    mov qword [rbx], ZBRANCH
    add rbx, 8
    mov [rbp], rbx              ; Push placeholder address
    sub rbp, 8
    mov qword [rbx], 0          ; Placeholder
    add rbx, 8
    mov [compile_ptr], rbx
    ret
.while_error:
    ret

word_repeat:
    ; REPEAT - compile BRANCH back to BEGIN, resolve WHILE
    cmp byte [compile_mode], 0
    je .repeat_error

    ; Pop WHILE placeholder
    add rbp, 8
    mov rbx, [rbp]              ; WHILE's placeholder

    ; Pop BEGIN address
    add rbp, 8
    mov rdx, [rbp]              ; BEGIN address

    mov rcx, [compile_ptr]
    mov qword [rcx], BRANCH     ; Compile unconditional branch
    add rcx, 8

    ; Calculate backward offset to BEGIN
    mov rax, rdx
    sub rax, rcx
    sub rax, 8
    mov [rcx], rax
    add rcx, 8
    mov [compile_ptr], rcx

    ; Resolve WHILE's branch (to here, after loop)
    mov rax, [compile_ptr]
    sub rax, rbx
    sub rax, 8
    mov [rbx], rax
    ret
.repeat_error:
    ret

word_again:
    ; AGAIN - compile unconditional BRANCH back to BEGIN
    cmp byte [compile_mode], 0
    je .again_error

    ; Pop loop start address
    add rbp, 8
    mov rbx, [rbp]              ; BEGIN address

    mov rcx, [compile_ptr]
    mov qword [rcx], BRANCH     ; Compile BRANCH
    add rcx, 8

    ; Calculate backward offset
    mov rax, rbx
    sub rax, rcx
    sub rax, 8
    mov [rcx], rax
    add rcx, 8
    mov [compile_ptr], rcx
    ret
.again_error:
    ret

; App stack isolation words
; Allow apps to run with their own isolated stack context

word_app_enter:
    ; APP-ENTER - Save current stack, start fresh app stack ( -- )
    ; Saves R14 (TOS), R15 (stack ptr) to app_saved_*
    ; Sets up fresh stack at app_stack for the app to use

    ; Save current stack state
    mov [app_saved_tos], r14
    mov [app_saved_sp], r15
    mov qword [app_active], 1

    ; Set up fresh app stack
    mov r15, app_stack
    xor r14, r14                ; Empty TOS
    ret

word_app_exit:
    ; APP-EXIT - Restore saved stack, return to REPL ( -- )
    ; Restores R14, R15 from saved state

    ; Check if we're in an app
    cmp qword [app_active], 0
    je .not_in_app

    ; Restore saved stack state
    mov r14, [app_saved_tos]
    mov r15, [app_saved_sp]
    mov qword [app_active], 0
    ret

.not_in_app:
    ; Not in app - push error string
    push rsi
    mov rsi, str_not_in_app
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

word_app_stack:
    ; APP-STACK - Push current stack base address ( -- addr )
    ; Returns app_stack if in app, forth_stack otherwise

    mov rax, forth_stack
    cmp qword [app_active], 0
    je .use_main
    mov rax, app_stack
.use_main:
    ; Push to TOS
    cmp r15, forth_stack
    je .as_first
    mov [r15-8], r14
    add r15, 8
    mov r14, rax
    ret
.as_first:
    mov r14, rax
    add r15, 8
    ret

word_app_depth:
    ; APP-DEPTH - Push current stack depth ( -- n )
    ; Calculate: (R15 - stack_base) / 8

    mov rax, forth_stack
    cmp qword [app_active], 0
    je .use_main_depth
    mov rax, app_stack
.use_main_depth:
    mov rbx, r15
    sub rbx, rax
    shr rbx, 3                  ; Divide by 8

    ; Push to TOS
    cmp r15, forth_stack
    je .ad_first
    cmp r15, app_stack
    je .ad_first
    mov [r15-8], r14
    add r15, 8
    mov r14, rbx
    ret
.ad_first:
    mov r14, rbx
    add r15, 8
    ret

str_not_in_app: db '(not in app)', 0

; ============================================================
; DISK I/O - IDE PIO mode disk access
; ============================================================
; disk-read ( sector addr -- ) - Read 512 bytes from sector to address
; disk-write ( addr sector -- ) - Write 512 bytes from address to sector
; Uses primary IDE controller at ports 0x1F0-0x1F7
; ============================================================

; IDE port definitions
IDE_DATA        equ 0x1F0
IDE_SECTOR_CNT  equ 0x1F2
IDE_LBA_LOW     equ 0x1F3
IDE_LBA_MID     equ 0x1F4
IDE_LBA_HIGH    equ 0x1F5
IDE_DRIVE_HEAD  equ 0x1F6
IDE_STATUS      equ 0x1F7
IDE_COMMAND     equ 0x1F7

IDE_CMD_READ    equ 0x20
IDE_CMD_WRITE   equ 0x30

; word_disk_read - Read 512 bytes from disk sector
; Stack: ( sector addr -- )
word_disk_read:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Get addr from TOS (r14), sector from second (stack)
    mov rdi, r14            ; addr
    sub r15, 8
    mov rax, [r15]          ; sector
    mov r14, [r15-8]        ; new TOS (or garbage if stack empty)

    ; Wait for drive ready
    mov dx, IDE_STATUS
.dr_wait_ready:
    in al, dx
    test al, 0x80           ; BSY bit
    jnz .dr_wait_ready

    ; Set up LBA addressing
    mov dx, IDE_SECTOR_CNT
    mov al, 1               ; Read 1 sector
    out dx, al

    mov dx, IDE_LBA_LOW
    mov ecx, eax            ; Save sector number
    out dx, al              ; LBA bits 0-7

    mov dx, IDE_LBA_MID
    mov al, ah
    out dx, al              ; LBA bits 8-15

    mov dx, IDE_LBA_HIGH
    shr ecx, 16
    mov al, cl
    out dx, al              ; LBA bits 16-23

    mov dx, IDE_DRIVE_HEAD
    mov al, 0xE0            ; LBA mode, master drive
    or al, ch               ; LBA bits 24-27 (in low nibble)
    and al, 0xEF            ; Ensure only bits 0-3 used
    out dx, al

    ; Send read command
    mov dx, IDE_COMMAND
    mov al, IDE_CMD_READ
    out dx, al

    ; Wait for data ready
    mov dx, IDE_STATUS
.dr_wait_drq:
    in al, dx
    test al, 0x01           ; ERR bit
    jnz .dr_error
    test al, 0x08           ; DRQ bit
    jz .dr_wait_drq

    ; Read 256 words (512 bytes)
    mov dx, IDE_DATA
    mov rcx, 256
.dr_read_loop:
    in ax, dx
    stosw                   ; Store word, advance rdi
    dec rcx
    jnz .dr_read_loop

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

.dr_error:
    ; On error, fill with zeros
    xor eax, eax
    mov rcx, 256
    rep stosw
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; word_disk_write - Write 512 bytes to disk sector
; Stack: ( addr sector -- )
word_disk_write:
    push rbx
    push rcx
    push rdx
    push rsi

    ; Get sector from TOS (r14), addr from second (stack)
    mov rax, r14            ; sector
    sub r15, 8
    mov rsi, [r15]          ; addr
    mov r14, [r15-8]        ; new TOS (or garbage if stack empty)

    ; Wait for drive ready
    mov dx, IDE_STATUS
.dw_wait_ready:
    in al, dx
    test al, 0x80           ; BSY bit
    jnz .dw_wait_ready

    mov ecx, eax            ; Save sector number

    ; Set up LBA addressing
    mov dx, IDE_SECTOR_CNT
    mov al, 1               ; Write 1 sector
    out dx, al

    mov dx, IDE_LBA_LOW
    mov eax, ecx
    out dx, al              ; LBA bits 0-7

    mov dx, IDE_LBA_MID
    mov al, ah
    out dx, al              ; LBA bits 8-15

    mov dx, IDE_LBA_HIGH
    shr eax, 16
    out dx, al              ; LBA bits 16-23

    mov dx, IDE_DRIVE_HEAD
    mov al, 0xE0            ; LBA mode, master drive
    shr eax, 8
    and al, 0x0F            ; LBA bits 24-27
    or al, 0xE0
    out dx, al

    ; Send write command
    mov dx, IDE_COMMAND
    mov al, IDE_CMD_WRITE
    out dx, al

    ; Wait for drive ready to accept data
    mov dx, IDE_STATUS
.dw_wait_drq:
    in al, dx
    test al, 0x01           ; ERR bit
    jnz .dw_error
    test al, 0x08           ; DRQ bit
    jz .dw_wait_drq

    ; Write 256 words (512 bytes)
    mov dx, IDE_DATA
    mov rcx, 256
.dw_write_loop:
    lodsw                   ; Load word from rsi, advance rsi
    out dx, ax
    dec rcx
    jnz .dw_write_loop

    ; Flush cache
    mov dx, IDE_COMMAND
    mov al, 0xE7            ; CACHE FLUSH command
    out dx, al

    ; Wait for completion
    mov dx, IDE_STATUS
.dw_wait_flush:
    in al, dx
    test al, 0x80           ; BSY bit
    jnz .dw_wait_flush

    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

.dw_error:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================
; LOAD - Load and run Forth app from disk
; Stack: ( name-string -- )
; Reads app directory from sector 200, finds app, loads and runs
; ============================================================
; Directory entry format (16 bytes):
;   [name: 12 bytes null-padded]
;   [start_sector: 2 bytes LE]
;   [length_sectors: 2 bytes LE]
; ============================================================

APP_DIR_SECTOR  equ 200
APP_BUFFER_ADDR equ 0x300000    ; 3MB - buffer for loading apps

word_load:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13

    ; Get app name string from TOS
    mov r12, r14                ; r12 = STRING object address
    sub r15, 8
    mov r14, [r15-8]            ; Pop, get new TOS

    ; Validate it's a string object
    mov rax, [r12]              ; Get type header
    cmp al, TYPE_STRING
    jne .load_error

    ; Get string data pointer (skip 16-byte header)
    lea r13, [r12 + 16]         ; r13 = pointer to name chars

    ; Read app directory sector (200) into load buffer
    mov rax, APP_DIR_SECTOR
    mov rdi, APP_BUFFER_ADDR
    call read_sector_to_addr

    ; Search directory for matching app name
    mov rbx, APP_BUFFER_ADDR    ; rbx = current directory entry
    mov rcx, 32                 ; max 32 entries per sector

.search_loop:
    ; Check if entry is empty (first byte = 0)
    cmp byte [rbx], 0
    je .not_found

    ; Compare name (up to 12 chars)
    push rcx
    mov rsi, r13                ; App name we're looking for
    mov rdi, rbx                ; Directory entry name
    mov rcx, 12
.cmp_name:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, 0                   ; End of search name?
    je .name_match_check
    cmp al, ah
    jne .next_entry
    inc rsi
    inc rdi
    dec rcx
    jnz .cmp_name
    jmp .name_match_check

.name_match_check:
    ; If we got here, names match (or search name ended)
    ; Check that entry name also ends or matches
    cmp ah, 0
    je .found
    cmp ah, ' '                 ; Space padding also OK
    je .found

.next_entry:
    pop rcx
    add rbx, 16                 ; Next entry
    dec rcx
    jnz .search_loop

.not_found:
    ; Print error
    mov rax, str_app_not_found
    call print_string
    jmp .load_done

.found:
    pop rcx                     ; Clean up saved rcx

    ; Get start sector and length from entry
    movzx rax, word [rbx + 12]  ; Start sector
    movzx rcx, word [rbx + 14]  ; Length in sectors

    ; Load app sectors into buffer
    mov rdi, APP_BUFFER_ADDR
.load_sectors:
    push rcx
    push rdi
    push rax
    call read_sector_to_addr
    pop rax
    pop rdi
    pop rcx
    inc rax                     ; Next sector
    add rdi, 512                ; Advance buffer
    dec rcx
    jnz .load_sectors

    ; Null-terminate the loaded code
    mov byte [rdi], 0

    ; Print loading message
    mov rax, str_loading_app
    call print_string
    mov rax, r13                ; App name (null-terminated)
    call print_string
    call newline

    ; Interpret the loaded Forth source
    mov rsi, APP_BUFFER_ADDR
    call interpret_forth_buffer

.load_done:
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

.load_error:
    mov rax, str_load_error
    call print_string
    jmp .load_done

; Helper: Read sector to address
; Input: RAX = sector, RDI = destination address
read_sector_to_addr:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Save sector number BEFORE status reads corrupt AL
    mov rbx, rax

    ; Wait for drive ready
    mov dx, IDE_STATUS
.rsta_wait:
    in al, dx
    test al, 0x80
    jnz .rsta_wait
    test al, 0x40
    jz .rsta_wait

    ; Set up LBA (sector number is in RBX)
    mov dx, IDE_SECTOR_CNT
    mov al, 1
    out dx, al

    mov dx, IDE_LBA_LOW
    mov rax, rbx
    out dx, al

    mov dx, IDE_LBA_MID
    mov al, ah
    out dx, al

    mov dx, IDE_LBA_HIGH
    shr rax, 16
    out dx, al

    mov dx, IDE_DRIVE_HEAD
    shr rax, 8
    and al, 0x0F
    or al, 0xE0
    out dx, al

    ; Send read command
    mov dx, IDE_COMMAND
    mov al, IDE_CMD_READ
    out dx, al

    ; Wait for data ready
    mov dx, IDE_STATUS
.rsta_wait_data:
    in al, dx
    test al, 0x80
    jnz .rsta_wait_data
    test al, 0x08
    jz .rsta_wait_data

    ; Read 256 words
    pop rdi
    push rdi
    mov dx, IDE_DATA
    mov rcx, 256
.rsta_read_loop:
    in ax, dx
    stosw
    dec rcx
    jnz .rsta_read_loop

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

str_app_not_found: db 'App not found', 13, 10, 0
str_loading_app: db 'Loading app: ', 0
str_sector200_debug: db 'Sector200: ', 0
str_load_error: db 'Error: expected string', 13, 10, 0

; ============================================================
; ED - Mini text editor (vim-like)
; Demonstrates: app isolation, screen control, keyboard input,
;               control flow, and the pure data model
; ============================================================
; Controls:
;   Normal mode: h/j/k/l = move, i = insert, q = quit
;   Insert mode: type text, ESC = back to normal
; ============================================================

word_ed:
    ; Enter app context
    mov [app_saved_tos], r14
    mov [app_saved_sp], r15
    mov qword [app_active], 1
    mov r15, app_stack
    xor r14, r14

    ; Initialize editor state
    xor rax, rax
    mov [ed_cursor_x], rax
    mov [ed_cursor_y], rax
    mov byte [ed_mode], 0       ; 0 = normal, 1 = insert

    ; Clear buffer
    mov rdi, ed_buffer
    mov rcx, 2000
    mov al, ' '
    rep stosb

    ; Clear screen (black background)
    mov rdi, 0xB8000
    mov rcx, 2000
    mov rax, 0x0720072007200720  ; White on black spaces
    rep stosq

    ; Draw status line (line 24)
    call ed_draw_status

    ; Position cursor at 0,0
    mov qword [cursor], 0xB8000
    call update_hw_cursor

.main_loop:
    ; Wait for key
    call wait_key

    ; Check mode
    cmp byte [ed_mode], 0
    jne .insert_mode

    ; Normal mode key handling
    cmp al, 'q'
    je .quit
    cmp al, 'i'
    je .enter_insert
    cmp al, 'h'
    je .move_left
    cmp al, 'j'
    je .move_down
    cmp al, 'k'
    je .move_up
    cmp al, 'l'
    je .move_right
    cmp rax, KEY_LEFT
    je .move_left
    cmp rax, KEY_DOWN
    je .move_down
    cmp rax, KEY_UP
    je .move_up
    cmp rax, KEY_RIGHT
    je .move_right
    jmp .main_loop

.insert_mode:
    ; Insert mode - ESC returns to normal
    cmp rax, KEY_ESCAPE
    je .exit_insert
    cmp al, 27                  ; ESC ASCII
    je .exit_insert

    ; Backspace
    cmp al, 8
    je .backspace

    ; Enter - move to next line
    cmp al, 10
    je .newline

    ; Printable character - insert it
    cmp al, 32
    jl .main_loop               ; Ignore control chars

    ; Put char in buffer and on screen
    call ed_put_char
    jmp .main_loop

.enter_insert:
    mov byte [ed_mode], 1
    call ed_draw_status
    jmp .main_loop

.exit_insert:
    mov byte [ed_mode], 0
    call ed_draw_status
    jmp .main_loop

.move_left:
    cmp qword [ed_cursor_x], 0
    je .main_loop
    dec qword [ed_cursor_x]
    call ed_update_cursor
    jmp .main_loop

.move_right:
    cmp qword [ed_cursor_x], 79
    jge .main_loop
    inc qword [ed_cursor_x]
    call ed_update_cursor
    jmp .main_loop

.move_up:
    cmp qword [ed_cursor_y], 0
    je .main_loop
    dec qword [ed_cursor_y]
    call ed_update_cursor
    jmp .main_loop

.move_down:
    cmp qword [ed_cursor_y], 23
    jge .main_loop
    inc qword [ed_cursor_y]
    call ed_update_cursor
    jmp .main_loop

.backspace:
    cmp qword [ed_cursor_x], 0
    je .main_loop
    dec qword [ed_cursor_x]
    mov al, ' '
    call ed_put_char_no_advance
    call ed_update_cursor
    jmp .main_loop

.newline:
    mov qword [ed_cursor_x], 0
    cmp qword [ed_cursor_y], 23
    jge .main_loop
    inc qword [ed_cursor_y]
    call ed_update_cursor
    jmp .main_loop

.quit:
    ; Restore REPL stack and exit
    mov r14, [app_saved_tos]
    mov r15, [app_saved_sp]
    mov qword [app_active], 0

    ; Clear screen and restore prompt
    mov rdi, 0xB8000
    mov rcx, 2000
    mov rax, 0x0F200F200F200F20
    rep stosq
    mov qword [cursor], 0xB8000
    call update_hw_cursor
    ret

; Put character at cursor, advance cursor
ed_put_char:
    push rax
    push rbx

    ; Calculate screen position
    mov rbx, [ed_cursor_y]
    imul rbx, 80
    add rbx, [ed_cursor_x]
    shl rbx, 1
    add rbx, 0xB8000

    ; Write char
    mov [rbx], al
    mov byte [rbx+1], 0x07      ; White on black

    ; Also store in buffer
    mov rbx, [ed_cursor_y]
    imul rbx, 80
    add rbx, [ed_cursor_x]
    add rbx, ed_buffer
    mov [rbx], al

    ; Advance cursor
    inc qword [ed_cursor_x]
    cmp qword [ed_cursor_x], 80
    jl .no_wrap
    mov qword [ed_cursor_x], 0
    inc qword [ed_cursor_y]
    cmp qword [ed_cursor_y], 24
    jl .no_wrap
    mov qword [ed_cursor_y], 23
.no_wrap:
    call ed_update_cursor

    pop rbx
    pop rax
    ret

; Put character without advancing
ed_put_char_no_advance:
    push rbx

    ; Calculate screen position
    mov rbx, [ed_cursor_y]
    imul rbx, 80
    add rbx, [ed_cursor_x]
    shl rbx, 1
    add rbx, 0xB8000

    ; Write char
    mov [rbx], al
    mov byte [rbx+1], 0x07

    ; Also store in buffer
    mov rbx, [ed_cursor_y]
    imul rbx, 80
    add rbx, [ed_cursor_x]
    add rbx, ed_buffer
    mov [rbx], al

    pop rbx
    ret

; Update hardware cursor position
ed_update_cursor:
    push rax
    push rbx

    mov rax, [ed_cursor_y]
    imul rax, 80
    add rax, [ed_cursor_x]
    shl rax, 1
    add rax, 0xB8000
    mov [cursor], rax
    call update_hw_cursor

    pop rbx
    pop rax
    ret

; Draw status line at bottom (line 24)
ed_draw_status:
    push rax
    push rbx
    push rcx
    push rsi

    ; Calculate line 24 position
    mov rbx, 0xB8000 + (24 * 160)

    ; Clear status line with inverse video
    mov rcx, 80
    mov ax, 0x7020              ; Black on white, space
.clear_status:
    mov [rbx], ax
    add rbx, 2
    dec rcx
    jnz .clear_status

    ; Print mode indicator
    mov rbx, 0xB8000 + (24 * 160)
    cmp byte [ed_mode], 0
    jne .show_insert

    ; Normal mode
    mov rsi, str_normal
    jmp .print_mode

.show_insert:
    mov rsi, str_insert

.print_mode:
    mov ah, 0x70                ; Black on white
.print_loop:
    lodsb
    test al, al
    jz .done
    mov [rbx], ax
    add rbx, 2
    jmp .print_loop

.done:
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

str_normal: db ' NORMAL  h/j/k/l:move  i:insert  q:quit ', 0
str_insert: db ' INSERT  type text  ESC:normal ', 0

; Editor state
ed_cursor_x: dq 0
ed_cursor_y: dq 0
ed_mode: db 0                   ; 0=normal, 1=insert
ed_buffer: times 2000 db ' '    ; 80x25 text buffer

word_words:
    ; Push STRING listing all words
    push rsi
    mov rsi, str_builtins
    call create_string_from_cstr
    pop rsi

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

str_builtins: db '+ - * / mod = < > <> <= >= 0= and or xor not . .s dup drop swap rot over @ ! emit cr : ; ~word ? words execute len type array at put { } type-new type-name type-set type-name? screen-* key? key-* if then else begin until while repeat again app-* disk-read disk-write ed ', 0

word_forget:
    ; Simplified FORGET - just removes latest word
    push rax
    mov rax, [dict_latest]
    test rax, rax
    jz .done

    ; Get link from latest entry (points to previous)
    mov rax, [rax]
    mov [dict_latest], rax

.done:
    pop rax
    ret

word_see:
    ; Show word info - parse name and look it up
    call skip_spaces
    call parse_word
    push rsi
    call lookup_word
    pop rsi

    test rax, rax
    jz .not_found

    ; Check if dictionary word
    cmp rax, dictionary_space
    jl .is_builtin

    ; Print ": name (colon def)"
    push rax
    mov al, ':'
    call emit_char
    mov al, ' '
    call emit_char
    mov rax, new_word_name
    call print_string
    mov al, ' '
    call emit_char
    mov rax, str_colon_type
    call print_string
    pop rax
    ret

.is_builtin:
    push rax
    mov rax, str_builtin_type
    call print_string
    pop rax
    ret

.not_found:
    push rax
    mov rax, str_unknown
    call print_string
    pop rax
    ret

str_colon_type: db '(colon)', 0
str_builtin_type: db '(built-in)', 0

word_colon:
    ; Set mode to get name next
    mov byte [compile_mode], 2

    ; Reset compilation buffer
    mov rax, compile_buffer
    mov [compile_ptr], rax
    ret

word_semi:
    ; End compilation mode
    mov byte [compile_mode], 0

    ; Debug: show what's in compile buffer
    push rax
    push rbx
    push rsi
    mov rsi, debug_semi_buffer_msg
    call serial_print
    mov rax, [compile_ptr]
    sub rax, compile_buffer
    shr rax, 3                  ; Count of qwords
    call serial_print_hex
    mov rsi, debug_semi_name_msg
    call serial_print
    mov rsi, new_word_name
    call serial_print
    mov al, 10
    call serial_putchar
    pop rsi
    pop rbx
    pop rax

    ; Create dictionary entry
    call create_dict_entry
    ret

; =============================================================
; interpret_forth_buffer - Interpret Forth source from memory
; Input: RSI = pointer to null-terminated Forth source
; Preserves: R14, R15, RBP (Forth stacks)
; =============================================================
interpret_forth_buffer:
    push rbx
    push r12
    push r13
    mov r12, rsi                ; Save source pointer

.next_line:
    ; Copy line to input_buffer
    mov rdi, input_buffer
    xor rcx, rcx                ; Line length

.copy_char:
    mov al, [r12]
    cmp al, 0                   ; End of source?
    je .done_copying
    cmp al, 10                  ; Newline?
    je .end_line
    cmp al, 13                  ; CR?
    je .skip_cr
    mov [rdi], al
    inc rdi
    inc r12
    inc rcx
    cmp rcx, 79                 ; Max line length
    jl .copy_char
    jmp .end_line

.skip_cr:
    inc r12
    jmp .copy_char

.end_line:
    inc r12                     ; Skip newline

.done_copying:
    mov byte [rdi], 0           ; Null terminate

    ; Skip empty lines
    test rcx, rcx
    jz .check_more

    ; Debug: print the line being processed
    push rsi
    mov rsi, debug_boot_line_msg
    call serial_print
    mov rsi, input_buffer
    call serial_print
    mov al, 10
    call serial_putchar
    pop rsi

    ; Process the line (reuse REPL's parse logic)
    mov rsi, input_buffer
    call interpret_line

.check_more:
    ; Check if more source
    mov al, [r12]
    test al, al
    jnz .next_line

    pop r13
    pop r12
    pop rbx
    ret

; interpret_line - Interpret tokens from RSI until null
; Reuses existing parse/interpret logic
interpret_line:
    push rbx
    push r13
    mov r13, rsi                ; Save source pointer

.iline_parse_loop:
    mov rsi, r13
    ; Skip spaces
    call skip_spaces
    mov r13, rsi

    cmp byte [rsi], 0
    je .iline_done

    ; Check for comments (backslash or parenthesis)
    cmp byte [rsi], '\'
    je .iline_done              ; Skip rest of line on backslash
    cmp byte [rsi], '('
    je .iline_skip_comment

    ; Check for tick (~) - get reference to next word
    cmp byte [rsi], 126         ; Tilde
    je .iline_handle_tick

    ; Check for quote (") - string literal
    cmp byte [rsi], 34          ; Double quote
    je .iline_handle_string

    ; Check for bracket [name] - named variable access
    cmp byte [rsi], '['
    je .iline_handle_bracket

    ; Check for array literal start {
    cmp byte [rsi], '{'
    je .iline_handle_array_start

    ; Check for array literal end }
    cmp byte [rsi], '}'
    je .iline_handle_array_end

    ; Get word using parse_word
    call parse_word             ; RDI = word start, RCX = length
    mov r13, rsi                ; Update position after parse

    test rcx, rcx
    jz .iline_parse_loop

    ; Check if getting name for definition
    cmp byte [compile_mode], 2
    je .iline_save_name

    ; Check if number
    call is_number
    test rax, rax
    jnz .iline_push_number

    ; Check if known word
    call lookup_word
    test rax, rax
    jz .iline_unknown

    ; Check for immediate flag (bit 63 set by lookup_word)
    ; Immediate words are executed even during compilation
    bt rax, 63
    jnc .iline_not_immediate
    ; It's immediate - clear the flag and execute
    btr rax, 63
    jmp .iline_exec_immediate

.iline_not_immediate:
    ; Execute or compile word
    cmp byte [compile_mode], 0
    jne .iline_compile_word

    ; Check if dictionary word
    push rax
    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rax
    je .iline_dict_word

.iline_exec_immediate:
    ; Execute immediate/built-in word
    call rax
    jmp .iline_parse_loop

.iline_dict_word:
    ; Execute dictionary word using the standard mechanism
    push r13                    ; Save parse position
    add rax, 8                  ; Skip code pointer
    mov rsi, rax
    call exec_definition
    pop r13
    jmp .iline_parse_loop

.iline_compile_word:
    ; Compiling - store word address
    ; Check if dictionary word
    push rax
    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rax
    jne .iline_compile_builtin

    ; Dictionary word - store code field address
    mov rbx, [compile_ptr]
    mov [rbx], rax
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_compile_builtin:
    ; Built-in - store function address
    mov rbx, [compile_ptr]
    mov [rbx], rax
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_push_number:
    ; Parse the actual number value (RDI=word start, RCX=length still valid)
    call parse_number           ; Convert string to number in RAX

    ; Check if compiling
    cmp byte [compile_mode], 0
    jne .iline_compile_number

    ; Push number to stack (interpret mode)
    mov [r15], r14              ; Push old TOS
    add r15, 8
    mov r14, rax                ; New TOS
    jmp .iline_parse_loop

.iline_compile_number:
    ; Compile LIT + number
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_save_name:
    ; Save word name for definition
    push rdi
    push rcx
    mov rsi, rdi
    mov rdi, new_word_name
    rep movsb
    mov byte [rdi], 0
    pop rcx
    pop rdi
    mov byte [compile_mode], 1  ; Switch to compile mode
    jmp .iline_parse_loop

.iline_unknown:
    ; Unknown word - ignore silently
    jmp .iline_parse_loop

.iline_skip_comment:
    ; Skip until )
.iline_skip_to_paren:
    inc r13
    cmp byte [r13], 0
    je .iline_done
    cmp byte [r13], ')'
    jne .iline_skip_to_paren
    inc r13                     ; Skip )
    jmp .iline_parse_loop

.iline_handle_bracket:
    ; Handle [name] variable access
    inc r13                     ; Skip [
    mov rdi, r13
    xor rcx, rcx
.iline_get_varname:
    mov al, [r13]
    cmp al, ']'
    je .iline_got_varname
    cmp al, 0
    je .iline_done
    inc r13
    inc rcx
    jmp .iline_get_varname

.iline_got_varname:
    inc r13                     ; Skip ]
    ; RDI = name start, RCX = length
    call get_or_create_named_var  ; Returns address in RAX

    ; Check if compiling
    cmp byte [compile_mode], 0
    jne .iline_compile_var

    ; Push address to stack
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_compile_var:
    ; Compile LIT + address
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_handle_tick:
    ; Tick (~) - get reference to next word
    inc r13                     ; Skip ~
    mov rsi, r13
    call skip_spaces
    mov r13, rsi
    call parse_word             ; RDI = word, RCX = length
    mov r13, rsi
    call lookup_word
    test rax, rax
    jz .iline_parse_loop        ; Unknown word, skip
    ; Push reference
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_handle_string:
    ; String literal
    inc r13                     ; Skip opening quote
    mov rsi, r13
    ; Count length
    push rsi
    xor rcx, rcx
.iline_count_str:
    mov al, [rsi]
    test al, al
    jz .iline_str_counted
    cmp al, 34                  ; Closing quote?
    je .iline_str_counted
    inc rsi
    inc rcx
    jmp .iline_count_str
.iline_str_counted:
    pop rsi
    ; Allocate STRING object
    push rcx
    add rcx, 17                 ; Header + null
    call allocate_object
    pop rcx
    ; Fill header
    mov qword [rax], TYPE_STRING
    mov [rax+8], rcx
    ; Copy string
    lea rdi, [rax+16]
    mov rbx, r13
.iline_copy_str:
    mov r8b, [rbx]
    test r8b, r8b
    jz .iline_str_done
    inc rbx
    cmp r8b, 34                 ; Closing quote?
    je .iline_str_done
    mov [rdi], r8b
    inc rdi
    jmp .iline_copy_str
.iline_str_done:
    mov byte [rdi], 0
    mov r13, rbx                ; Update position
    ; Check compile mode
    cmp byte [compile_mode], 0
    jne .iline_compile_string
    ; Push to stack
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop
.iline_compile_string:
    ; Compile LIT + string address
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_handle_array_start:
    ; { - Save marker on return stack
    inc r13                     ; Skip {
    mov [rbp], r15
    sub rbp, 8
    jmp .iline_parse_loop

.iline_handle_array_end:
    ; } - Create array from marker
    inc r13                     ; Skip }
    add rbp, 8
    mov rbx, [rbp]              ; Get marker
    ; Count elements
    mov rcx, r15
    sub rcx, rbx
    shr rcx, 3                  ; Divide by 8
    ; Allocate array
    push rcx
    push rbx
    shl rcx, 3
    add rcx, 16                 ; Header
    call allocate_object
    pop rbx
    pop rcx
    ; Fill header
    mov qword [rax], TYPE_ARRAY
    mov [rax+8], rcx
    ; Copy elements
    lea rdi, [rax+16]
    mov rsi, rbx
.iline_copy_arr:
    test rcx, rcx
    jz .iline_arr_done
    movsq
    dec rcx
    jmp .iline_copy_arr
.iline_arr_done:
    mov r15, rbx                ; Reset stack
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_done:
    pop r13
    pop rbx
    ret

; exec_definition - Execute a colon definition
; Input: RSI = pointer to definition body (after DOCOL)
exec_definition:
    push r13
.exec_def_loop:
    lodsq
    cmp rax, EXIT
    je .exec_def_done

    ; Check for LIT
    cmp rax, LIT
    jne .exec_not_lit
    lodsq
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .exec_def_loop

.exec_not_lit:
    ; Check for BRANCH
    cmp rax, BRANCH
    jne .exec_not_branch
    lodsq
    add rsi, rax
    jmp .exec_def_loop

.exec_not_branch:
    ; Check for ZBRANCH
    cmp rax, ZBRANCH
    jne .exec_not_zbranch
    lodsq                       ; Get offset
    test r14, r14               ; Check TOS
    sub r15, 8
    mov r14, [r15]              ; Pop new TOS
    jnz .exec_def_loop          ; If not zero, don't branch
    add rsi, rax                ; Branch
    jmp .exec_def_loop

.exec_not_zbranch:
    ; Check if nested dictionary word
    cmp rax, dictionary_space
    jl .exec_is_builtin
    mov r13, [dict_here]
    cmp rax, r13
    jge .exec_is_builtin
    mov rbx, [rax]
    cmp rbx, DOCOL
    jne .exec_is_builtin

    ; Nested definition - recurse
    push rsi
    add rax, 8
    mov rsi, rax
    call exec_definition
    pop rsi
    jmp .exec_def_loop

.exec_is_builtin:
    push rsi
    call rax
    pop rsi
    jmp .exec_def_loop

.exec_def_done:
    pop r13
    ret

; serial_putchar - Output a character to serial port (for debugging)
; Input: AL = character
serial_putchar:
    push rdx
    push rax
    mov dx, 0x3F8 + 5       ; Line status register
.wait:
    in al, dx
    test al, 0x20           ; Transmit buffer empty?
    jz .wait
    pop rax
    mov dx, 0x3F8           ; Data register
    out dx, al
    pop rdx
    ret

; serial_print_hex - Output 64-bit value as hex to serial port
; Input: RAX = value to print
serial_print_hex:
    push rax
    push rcx
    push rdx
    mov rcx, 16             ; 16 hex digits
.hex_loop:
    rol rax, 4              ; Rotate left 4 bits
    push rax
    and al, 0x0F            ; Get low 4 bits
    add al, '0'
    cmp al, '9'
    jle .not_letter
    add al, 7               ; Convert to A-F
.not_letter:
    call serial_putchar
    pop rax
    dec rcx
    jnz .hex_loop
    pop rdx
    pop rcx
    pop rax
    ret

; serial_print - Output string to serial port
; Input: RSI = null-terminated string
serial_print:
    push rsi
    push rax
.loop:
    lodsb
    test al, al
    jz .done
    call serial_putchar
    jmp .loop
.done:
    pop rax
    pop rsi
    ret

; load_apps - Load apps from disk at boot
; Uses the disk catalog at sector 200 to load Forth apps
load_apps:
    push rbx
    push r12
    push r13

    ; Load editor
    mov rsi, serial_loading_editor
    call serial_print
    mov rsi, app_name_editor
    call load_app_by_cstring

    ; Load invaders
    mov rsi, serial_loading_invaders
    call serial_print
    mov rsi, app_name_invaders
    call load_app_by_cstring

    ; Load hello
    mov rsi, serial_loading_hello
    call serial_print
    mov rsi, app_name_hello
    call load_app_by_cstring

    ; Load test
    mov rsi, serial_loading_test
    call serial_print
    mov rsi, app_name_test
    call load_app_by_cstring

    ; Done
    mov rsi, serial_apps_done
    call serial_print

    pop r13
    pop r12
    pop rbx
    ret

; App names for boot loading
app_name_editor: db 'editor', 0
app_name_invaders: db 'invaders', 0
app_name_hello: db 'hello', 0
app_name_test: db 'test', 0

; load_app_by_cstring - Load app by C string name (for boot time)
; Input: RSI = pointer to null-terminated app name
; Uses disk catalog at sector 200
load_app_by_cstring:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13

    mov r13, rsi                ; r13 = app name

    ; Read app directory sector (200) into load buffer
    mov rax, APP_DIR_SECTOR
    mov rdi, APP_BUFFER_ADDR
    call read_sector_to_addr

    ; DEBUG: Print what we read from sector 200
    push rsi
    mov rsi, str_sector200_debug
    call serial_print
    mov rax, [APP_BUFFER_ADDR]       ; First 8 bytes
    call serial_print_hex
    mov al, ' '
    call serial_putchar
    mov rax, [APP_BUFFER_ADDR + 8]   ; Next 8 bytes
    call serial_print_hex
    mov al, 13
    call serial_putchar
    mov al, 10
    call serial_putchar
    pop rsi

    ; Search directory for matching app name
    mov rbx, APP_BUFFER_ADDR    ; rbx = current directory entry
    mov rcx, 32                 ; max 32 entries per sector

.labc_search_loop:
    ; Check if entry is empty (first byte = 0)
    cmp byte [rbx], 0
    je .labc_not_found

    ; Compare name (up to 12 chars)
    push rcx
    mov rsi, r13                ; App name we're looking for
    mov rdi, rbx                ; Directory entry name
    mov rcx, 12
.labc_cmp_name:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, 0                   ; End of search name?
    je .labc_name_match_check
    cmp al, ah
    jne .labc_next_entry
    inc rsi
    inc rdi
    dec rcx
    jnz .labc_cmp_name
    jmp .labc_name_match_check

.labc_name_match_check:
    ; If we got here, names match (or search name ended)
    cmp ah, 0
    je .labc_found
    cmp ah, ' '                 ; Space padding also OK
    je .labc_found

.labc_next_entry:
    pop rcx
    add rbx, 16                 ; Next entry (16 bytes each)
    dec rcx
    jnz .labc_search_loop

.labc_not_found:
    ; App not found - just print error and continue
    mov rsi, str_app_not_found
    call serial_print
    jmp .labc_done

.labc_found:
    pop rcx                     ; Clean up saved rcx

    ; Get start sector and length from entry
    movzx rax, word [rbx + 12]  ; Start sector
    movzx rcx, word [rbx + 14]  ; Length in sectors

    ; Load app sectors into buffer
    mov rdi, APP_BUFFER_ADDR
.labc_load_sectors:
    push rcx
    push rdi
    push rax
    call read_sector_to_addr
    pop rax
    pop rdi
    pop rcx
    inc rax                     ; Next sector
    add rdi, 512                ; Advance buffer
    dec rcx
    jnz .labc_load_sectors

    ; Null-terminate the loaded code
    mov byte [rdi], 0

    ; Interpret the loaded Forth source
    mov rsi, APP_BUFFER_ADDR
    call interpret_forth_buffer

.labc_done:
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

serial_loading_hello: db 'Loading hello...', 13, 10, 0
serial_loading_editor: db 'Loading editor...', 13, 10, 0
serial_loading_invaders: db 'Loading invaders...', 13, 10, 0
serial_loading_test: db 'Loading test...', 13, 10, 0
serial_apps_done: db 'Apps loaded OK', 13, 10, 0
debug_if_entry: db 'IF rbp=', 0
debug_else_entry: db 'ELSE entry, IF placeholder=', 0
debug_parse_word: db 'parse_word done', 13, 10, 0
debug_lookup_word: db 'lookup: ', 0
debug_lookup_result: db 'result: ', 0
debug_imm_call: db 'IMM addr=', 0
debug_else_done: db 'ELSE done', 13, 10, 0
debug_unknown_word: db 'Unknown: ', 0
debug_semicolon: db 'Created word: ', 0
debug_compile_mode_msg: db '[compile_mode=', 0
debug_boot_line_msg: db 'BOOT: ', 0
debug_semi_buffer_msg: db '; compiled=', 0
debug_semi_name_msg: db ' name=', 0
str_banner: db 'Simplicity Forth REPL v0.3', 0
str_prompt: db '> ', 0
str_ok: db ' ok', 0
str_goodbye: db 'Goodbye!', 0
str_unknown: db ' ?', 0

input_buffer: times 80 db 0
shift_state: db 0
ctrl_state: db 0
forth_stack: times 64 dq 0      ; Forth data stack (64 cells)

; App stack isolation
app_stack: times 64 dq 0        ; Separate stack for apps (64 cells)
app_saved_tos: dq 0             ; Saved TOS (R14) when entering app
app_saved_sp: dq 0              ; Saved stack pointer (R15) when entering app
app_active: dq 0                ; 1 if inside app context, 0 otherwise

compile_mode: db 0              ; 0 = interpret, 1 = compile
dict_here: dq dictionary_space  ; Next free space in dictionary
dict_latest: dq 0               ; Pointer to most recent entry (0 = empty)
compile_buffer: times 256 dq 0  ; Compilation buffer
compile_ptr: dq compile_buffer  ; Current compilation position
new_word_name: times 32 db 0    ; Name of word being defined
string_pool: times 2048 db 0    ; Temporary string pool
string_here: dq string_pool     ; Next free space

; Object model
heap_start: dq 0x200000         ; Heap starts at 2MB
heap_ptr: dq 0x200000           ; Current heap position

; Type tags
TYPE_INT equ 0
TYPE_STRING equ 1
TYPE_REF equ 2
TYPE_ARRAY equ 3
TYPE_USER_BASE equ 4            ; User types start at 4

; Type registry (for user-defined types)
; Each entry: [name_ptr:8] - pointer to STRING object with type name
; Index = type_tag - TYPE_USER_BASE
type_registry: times 256 dq 0   ; Up to 256 user types
next_type_tag: dq TYPE_USER_BASE ; Next available type tag

; Named variables namespace (simple linear list)
named_vars: times 1024 dq 0     ; 128 variable slots (name_hash, value)
named_var_count: dq 0

cursor: dq 0xB8000 + 160

; Dictionary space (4KB for user-defined words)
dictionary_space: times 4096 db 0

msg64: db 'Simplicity OS v0.2 - 64-bit Forth', 0
