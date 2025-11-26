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

%include "kernel/simplicity.asm"
