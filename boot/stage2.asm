; Simplicity OS - Stage 2 Loader with Forth Interpreter
; 32-bit protected mode with working Forth

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

    ; Initialize Forth
    mov esp, 0x80000        ; Data stack
    mov ebp, 0x70000        ; Return stack
    mov esi, test_program   ; Instruction pointer
    jmp NEXT

; NEXT - Forth inner interpreter
NEXT:
    lodsd                   ; Load next word address into EAX
    jmp eax                 ; Jump to the address in EAX

; Core Forth words

; DUP ( n -- n n )
DUP:
    mov eax, [esp]
    push eax
    jmp NEXT

; DROP ( n -- )
DROP:
    add esp, 4
    jmp NEXT

; SWAP ( a b -- b a )
SWAP:
    pop eax
    pop ebx
    push eax
    push ebx
    jmp NEXT

; + ( a b -- sum )
PLUS:
    pop eax
    add [esp], eax
    jmp NEXT

; * ( a b -- product )
MULT:
    pop eax
    pop ebx
    imul eax, ebx
    push eax
    jmp NEXT

; . ( n -- ) Print number
DOT:
    pop eax
    call print_number
    ; Add space after number
    mov ebx, [cursor]
    mov byte [ebx], ' '
    mov byte [ebx+1], 0x0F
    add ebx, 2
    mov [cursor], ebx
    jmp NEXT

; LIT - Push next value
LIT:
    lodsd
    push eax
    jmp NEXT

; EXIT/BYE - Halt
BYE:
    cli
    hlt
    jmp $

; Print number in EAX
print_number:
    push eax
    push ebx
    push ecx
    push edx

    mov ebx, 10
    xor ecx, ecx

    test eax, eax
    jnz .conv
    mov al, '0'
    call emit_char
    jmp .done

.conv:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .conv

.print:
    pop eax
    add al, '0'
    call emit_char
    loop .print

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Emit character in AL
emit_char:
    push eax
    push ebx
    mov ebx, [cursor]
    mov [ebx], al
    mov byte [ebx+1], 0x0E
    add ebx, 2
    mov [cursor], ebx
    pop ebx
    pop eax
    ret

; Test program: 2 3 + . 5 7 * . BYE
test_program:
    dd LIT, 2
    dd LIT, 3
    dd PLUS
    dd DOT
    dd LIT, 5
    dd LIT, 7
    dd MULT
    dd DOT
    dd BYE

; GDT
align 8
gdt_start:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 11001111b
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

cursor: dd 0xB8000 + 160
msg: db 'Simplicity OS v0.1 - Forth interpreter', 0
