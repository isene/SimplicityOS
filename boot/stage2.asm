; Simplicity OS - Stage 2 Loader
; Test: Enter 64-bit long mode without [BITS 64] code

[BITS 16]
[ORG 0x7E00]

stage2_start:
    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Load GDT
    lgdt [gdt_descriptor]

    ; Enter protected mode
    cli
    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp 0x08:prot_mode

[BITS 32]
prot_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Clear screen
    mov edi, 0xB8000
    mov ecx, 80*25
    mov eax, 0x0F200F20
    rep stosd

    ; Print message
    mov edi, 0xB8000
    mov esi, msg
    mov ah, 0x0A
.loop:
    lodsb
    test al, al
    jz .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:

    ; CRITICAL: Clear page table memory first!
    mov edi, 0x70000
    xor eax, eax
    mov ecx, 3072        ; 12KB for 3 pages
    rep stosd

    ; Build page tables at 0x70000
    mov dword [0x70000], 0x71003    ; PML4[0] -> PDPT at 0x71000
    mov dword [0x71000], 0x72003    ; PDPT[0] -> PD at 0x72000
    mov dword [0x72000], 0x000083   ; PD[0] -> 2MB page

    ; Debug: Print progress markers
    mov byte [0xB8000 + 160], 'P'   ; Page tables built
    mov byte [0xB8000 + 161], 0x0C

    ; Set CR3
    mov eax, 0x70000
    mov cr3, eax

    mov byte [0xB8000 + 162], 'C'   ; CR3 set
    mov byte [0xB8000 + 163], 0x0C

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    mov byte [0xB8000 + 164], 'A'   ; PAE enabled
    mov byte [0xB8000 + 165], 0x0C

    ; Enable long mode in EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    mov byte [0xB8000 + 166], 'E'   ; EFER set
    mov byte [0xB8000 + 167], 0x0C

    ; Enable paging (activates long mode!)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; If we get here, long mode is ACTIVE!
    mov byte [0xB8000 + 168], 'L'   ; Long mode!
    mov byte [0xB8000 + 169], 0x0E

    ; Load 64-bit GDT
    lgdt [gdt64_descriptor]

    ; Far jump to 64-bit code segment
    jmp 0x08:long_mode_64

    ; Should never get here
    hlt

[BITS 64]
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
    mov rbp, 0x70000        ; Return stack
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

; Wait for keypress and return ASCII in RAX
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

    ; Ignore other key releases (bit 7 set)
    test al, 0x80
    jnz .wait

    ; Convert scancode to ASCII
    call scancode_to_ascii

    ; If zero (unmapped key), wait for another
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

; Convert scancode in AL to ASCII in RAX
scancode_to_ascii:
    push rbx
    movzx rbx, al           ; Zero-extend AL to RBX

    ; Backspace (scancode 0x0E)
    cmp rbx, 0x0E
    jne .check_numbers
    mov rax, 8              ; ASCII backspace
    jmp .done

.check_numbers:
    ; Numbers 1-9,0 (scancodes 0x02-0x0B)
    cmp rbx, 0x02
    jl .letters
    cmp rbx, 0x0B
    jg .check_special

    ; Check if shift pressed
    cmp byte [shift_state], 0
    je .numbers_no_shift

    ; Shifted number keys: !@#$%^&*()
    sub rbx, 0x02
    lea rax, [shift_numbers]
    add rax, rbx
    movzx rax, byte [rax]
    jmp .done

.numbers_no_shift:
    ; Numbers 1-9,0
    sub rbx, 0x02
    cmp rbx, 9
    jne .digit
    mov rax, '0'            ; Scancode 0x0B = '0'
    jmp .done
.digit:
    add rbx, '1'
    mov rax, rbx
    jmp .done

.check_special:
    ; Minus/underscore (scancode 0x0C)
    cmp rbx, 0x0C
    jne .check_equals
    mov rax, '-'
    cmp byte [shift_state], 0
    je .done
    mov rax, '_'
    jmp .done

.check_equals:
    ; Equals/plus (scancode 0x0D)
    cmp rbx, 0x0D
    jne .check_period
    mov rax, '='
    cmp byte [shift_state], 0
    je .done
    mov rax, '+'
    jmp .done

.check_period:
    ; Period (scancode 0x34)
    cmp rbx, 0x34
    jne .check_comma
    mov rax, '.'
    cmp byte [shift_state], 0
    je .done
    mov rax, '>'
    jmp .done

.check_comma:
    ; Comma (scancode 0x33)
    cmp rbx, 0x33
    jne .check_slash
    mov rax, ','
    cmp byte [shift_state], 0
    je .done
    mov rax, '<'
    jmp .done

.check_slash:
    ; Slash (scancode 0x35)
    cmp rbx, 0x35
    jne .letters
    mov rax, '/'
    cmp byte [shift_state], 0
    je .done
    mov rax, '?'
    jmp .done

.letters:
    ; Letter scancodes (0x10-0x19 = QWERTYUIOP, etc)
    ; Simple mapping for common keys
    mov rax, 0

    ; Space (scancode 0x39)
    cmp bl, 0x39
    jne .check_enter
    mov rax, ' '
    jmp .done

.check_enter:
    ; Enter (scancode 0x1C)
    cmp bl, 0x1C
    jne .check_letters
    mov rax, 10             ; Newline
    jmp .done

.check_letters:
    ; Q-P (0x10-0x1C)
    lea rax, [scancode_table]
    cmp bl, 0x50
    jge .done
    add rax, rbx
    movzx rax, byte [rax]

    ; If shift pressed, convert to uppercase
    test rax, rax
    jz .done
    cmp byte [shift_state], 0
    je .done

    ; Convert a-z to A-Z
    cmp al, 'a'
    jl .done
    cmp al, 'z'
    jg .done
    sub al, 32              ; 'a' - 'A' = 32

.done:
    pop rbx
    ret

; Scancode to ASCII table
scancode_table:
    times 0x10 db 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'  ; 0x10-0x19
    db 0, 0, 0, 0                                         ; 0x1A-0x1D
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'      ; 0x1E-0x26
    db 0, 0, 0, 0, 0                                      ; 0x27-0x2B (5 zeros!)
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm'                ; 0x2C-0x32
    times 0x20 db 0

; Shifted number row: 1-9,0 → !@#$%^&*()
shift_numbers:
    db '!', '@', '#', '$', '%', '^', '&', '*', '(', ')'

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

; REPL program: Jump to assembly REPL
test_program:
    dq REPL

; Interactive REPL in assembly
REPL:
    ; Print banner
    mov rax, str_banner
    call print_string
    call newline

.main_loop:
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

    ; Parse and execute the line
    mov rsi, input_buffer   ; RSI = parse pointer
    mov r15, forth_stack    ; R15 = Forth data stack pointer

.parse_loop:
    ; Skip leading spaces
    call skip_spaces
    cmp byte [rsi], 0
    je .line_done

    ; Get word
    call parse_word         ; Returns word in RDI, length in RCX

    ; Check if number
    call is_number
    test rax, rax
    jnz .push_number

    ; Check if known word
    call lookup_word
    test rax, rax
    jz .unknown_word

    ; Execute word
    call rax
    jmp .parse_loop

.push_number:
    call parse_number       ; Converts word to number in RAX
    mov [r15], rax          ; Push to Forth stack
    add r15, 8
    jmp .parse_loop

.unknown_word:
    ; Print error
    mov rax, str_unknown
    call print_string
    jmp .line_done

.line_done:
    mov rax, str_ok
    call print_string
    call newline

    jmp .main_loop

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

; Lookup word, return address in RAX (0 if not found)
lookup_word:
    push rbx
    push rcx
    push rdi
    push rsi

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

    jmp .not_found

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

.check_multi:
    ; Check multi-char words
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
    jne .not_found
    cmp byte [rdi], 's'
    jne .not_found
    cmp byte [rdi+1], 'w'
    jne .not_found
    cmp byte [rdi+2], 'a'
    jne .not_found
    cmp byte [rdi+3], 'p'
    jne .not_found
    mov rax, word_swap
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
    sub r15, 8
    mov rax, [r15]          ; Pop
    sub r15, 8
    add [r15], rax          ; Add to TOS
    add r15, 8
    ret

word_minus:
    sub r15, 8
    mov rax, [r15]          ; Pop
    sub r15, 8
    sub [r15], rax          ; Subtract from TOS
    add r15, 8
    ret

word_mult:
    sub r15, 8
    mov rax, [r15]          ; Pop
    sub r15, 8
    mov rbx, [r15]          ; Pop
    imul rax, rbx
    mov [r15], rax          ; Push
    add r15, 8
    ret

word_div:
    sub r15, 8
    mov rbx, [r15]          ; Pop divisor
    sub r15, 8
    mov rax, [r15]          ; Pop dividend
    xor rdx, rdx
    div rbx
    mov [r15], rax          ; Push quotient
    add r15, 8
    ret

word_dot:
    sub r15, 8
    mov rax, [r15]          ; Pop
    call print_number
    mov rbx, [cursor]
    mov byte [rbx], ' '
    mov byte [rbx+1], 0x0F
    add rbx, 2
    mov [cursor], rbx
    call update_hw_cursor
    ret

word_dup:
    mov rax, [r15-8]        ; Get TOS
    mov [r15], rax          ; Push copy
    add r15, 8
    ret

word_drop:
    sub r15, 8              ; Just decrement stack pointer
    ret

word_swap:
    mov rax, [r15-8]        ; Get TOS
    mov rbx, [r15-16]       ; Get second
    mov [r15-8], rbx        ; Swap
    mov [r15-16], rax
    ret

str_banner: db 'Simplicity Forth REPL v0.3', 0
str_prompt: db '> ', 0
str_ok: db ' ok', 0
str_unknown: db ' ?', 0

input_buffer: times 80 db 0
shift_state: db 0
forth_stack: times 64 dq 0      ; Forth data stack (64 cells)

cursor: dq 0xB8000 + 160

; GDT - 32-bit for now (we'll stay in compatibility mode)
align 8
gdt_start:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 11001111b        ; 32-bit (D=1, L=0)
    db 0

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; 64-bit GDT
align 8
gdt64_start:
    dq 0                ; Null descriptor

gdt64_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 10101111b        ; G=1, L=1 (64-bit), D=0
    db 0

gdt64_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

msg: db 'Simplicity OS - Long mode test', 0
msg64: db 'Simplicity OS v0.2 - 64-bit Forth', 0
