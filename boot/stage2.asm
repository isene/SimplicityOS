; Simplicity OS - Stage 2 Loader
; Switch to protected mode → long mode → jump to kernel

[BITS 16]
[ORG 0x7E00]

stage2_start:
    ; Setup segments
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; Load kernel from disk to 0x10000 temporarily
    mov ah, 0x02
    mov al, 127         ; Read ~64KB
    mov ch, 0
    mov cl, 18          ; After boot(1) + stage2(16) = sector 18
    mov dh, 0
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    int 0x13
    ; Don't check errors for now

    ; Reset ES
    xor ax, ax
    mov es, ax

    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Load GDT
    lgdt [gdt_descriptor]

    ; Enter protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Far jump to reload CS
    jmp 0x08:prot_mode

[BITS 32]
prot_mode:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Print protected mode message
    mov edi, 0xB8000
    mov esi, msg_prot
    mov ah, 0x0A        ; Green
    call print32

    ; Copy kernel from 0x10000 to 0x100000
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, 17408      ; 69632 / 4
    rep movsd

    ; Setup page tables for long mode
    call setup_paging

    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Load PML4
    mov eax, pml4_table
    mov cr3, eax

    ; Enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable paging (activates long mode)
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Jump to 64-bit code
    jmp 0x08:long_mode

[BITS 64]
long_mode:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Clear screen
    mov rdi, 0xB8000
    mov rcx, 80*25
    mov rax, 0x0F200F20
    rep stosq

    ; Print long mode message
    mov rdi, 0xB8000
    mov rsi, msg_long
    mov ah, 0x0E        ; Yellow
    call print64

    ; Jump to kernel at 1MB
    ; Kernel was placed there by our disk image layout
    mov rax, 0x100000
    jmp rax

; Print in 32-bit protected mode
[BITS 32]
print32:
    push eax
.loop:
    lodsb
    test al, al
    jz .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    pop eax
    ret

; Setup identity paging
setup_paging:
    ; Clear page tables
    mov edi, pml4_table
    mov ecx, 4096 * 3 / 4
    xor eax, eax
    rep stosd

    ; PML4[0] → PDPT
    mov eax, pdp_table
    or eax, 3
    mov [pml4_table], eax

    ; PDPT[0] → PD
    mov eax, pd_table
    or eax, 3
    mov [pdp_table], eax

    ; Identity map first 2MB (covers 0-2MB including kernel at 1MB)
    mov eax, 0x83       ; Present, writable, 2MB page
    mov [pd_table], eax

    ret

; Print in 64-bit long mode
[BITS 64]
print64:
    push rax
.loop:
    lodsb
    test al, al
    jz .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:
    pop rax
    ret

; GDT
align 8
gdt_start:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 10101111b        ; 64-bit flag
    db 0

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 10101111b
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; Messages
msg_prot: db 'Prot ', 0
msg_long: db 'Long mode active!', 0

; Page tables
align 4096
pml4_table:
    times 512 dq 0

align 4096
pdp_table:
    times 512 dq 0

align 4096
pd_table:
    times 512 dq 0
