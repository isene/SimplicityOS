; Simplicity OS - Forth Kernel (Minimal Test)

[BITS 64]
[ORG 0x100000]

kernel_start:
    ; Clear screen
    mov rdi, 0xB8000
    mov rcx, 80*25
    mov rax, 0x0F200F20
    rep stosq

    ; Print message
    mov rdi, 0xB8000
    mov rsi, msg
    mov ah, 0x0E        ; Yellow on black
.loop:
    lodsb
    test al, al
    jz .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:

    ; Halt
    cli
    hlt
    jmp $

msg: db 'Kernel OK!', 0
