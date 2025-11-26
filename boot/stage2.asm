; Simplicity OS - Stage 2 Loader
; Minimal working version - Protected mode only

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

    ; Print test calculation: 2 + 3 = 5
    mov eax, 2
    add eax, 3
    add al, '0'
    mov [0xB8000 + 160 + 0], al
    mov byte [0xB8000 + 160 + 1], 0x0E

    ; Print " "
    mov byte [0xB8000 + 160 + 2], ' '
    mov byte [0xB8000 + 160 + 3], 0x0F

    ; Print test: 5 * 7 = 35
    mov eax, 5
    mov ebx, 7
    imul eax, ebx
    ; Print tens digit
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    mov [0xB8000 + 160 + 4], al
    mov byte [0xB8000 + 160 + 5], 0x0E
    ; Print ones digit
    add dl, '0'
    mov [0xB8000 + 160 + 6], dl
    mov byte [0xB8000 + 160 + 7], 0x0E

    ; Halt
    cli
    hlt
    jmp $

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

msg: db 'Simplicity OS v0.1 - Protected mode', 0
