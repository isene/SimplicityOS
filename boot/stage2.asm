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

LIT:
    lodsq
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
    pop rbx
    pop rax
    ret

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
    pop rcx
    pop rbx
    pop rax
    ret

; Test program: Just string, then numbers
test_program:
    dq LIT, str_result
    dq QUOTE        ; prints "Test"
    dq LIT, 2
    dq LIT, 3
    dq PLUS
    dq DOT
    dq BYE

str_result: db 'Test', 0

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
