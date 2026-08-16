; Simplicity OS - Stage 2 Loader (Minimal)
; Only handles: Real mode -> Protected mode -> Long mode
; Jumps to kernel at 0x10000

[BITS 16]
[ORG 0x7E00]

stage2_start:
    ; Save boot drive (DL preserved from boot sector's INT 13h calls)
    mov [boot_drive2], dl

    ; Require a 64-bit CPU before touching long-mode machinery
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb no_long_mode
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29           ; LM bit
    jz no_long_mode

    ; Load RAM disk: sectors 200-447 to 0x28000 so apps work without
    ; ATA PIO (real hardware booted from USB/AHCI). 32-sector chunks
    ; at 16KB-aligned addresses avoid 64KB DMA boundary crossings.
.rd_loop:
    mov ax, [rd_remaining]
    test ax, ax
    jz .rd_done
    cmp ax, 32
    jbe .rd_have
    mov ax, 32
.rd_have:
    mov [rd_dap_cnt], ax
    push ax
    mov ah, 0x42
    mov dl, [boot_drive2]
    mov si, rd_dap
    int 0x13
    pop ax
    jc .rd_done                 ; On error: boot continues, apps absent
    sub [rd_remaining], ax
    add word [rd_dap_lba], ax
    shl ax, 5                   ; 32 paragraphs per sector
    add [rd_dap_seg], ax
    jmp .rd_loop
.rd_done:

    ; Enable A20: BIOS service first, fast gate as fallback
    mov ax, 0x2401
    int 0x15
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

    ; Clear screen (2000 cells = 1000 dwords)
    mov edi, 0xB8000
    mov ecx, 1000
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
    mov dword [0x72000], 0x000083   ; PD[0] -> first 2MB page
    mov dword [0x72008], 0x200083   ; PD[1] -> second 2MB page (2-4MB)

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

    ; Far jump to 64-bit kernel at 0x10000
    jmp 0x08:0x10000

    ; Should never get here
    hlt

; ============================================================
; GDT - Must be in first 32KB so 16-bit code can reference it
; ============================================================

; GDT - 32-bit protected mode
align 8
gdt_start:
    dq 0                ; Null descriptor

gdt_code:
    dw 0xFFFF           ; Limit low
    dw 0                ; Base low
    db 0                ; Base mid
    db 10011010b        ; Access: present, ring 0, code, readable
    db 11001111b        ; Flags: 4K granularity, 32-bit (D=1, L=0)
    db 0                ; Base high

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b        ; Access: present, ring 0, data, writable
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

msg: db 'Stage2: Transitioning to 64-bit...', 0

; ============================================================
; Real-mode helpers and data
; ============================================================
[BITS 16]
no_long_mode:
    mov si, msg_no64
.nl_print:
    lodsb
    test al, al
    jz .nl_halt
    mov ah, 0x0E
    int 0x10
    jmp .nl_print
.nl_halt:
    hlt
    jmp .nl_halt

msg_no64: db '64-bit CPU required', 13, 10, 0
boot_drive2: db 0

; Disk Address Packet for the RAM-disk load (updated in place)
align 4
rd_dap:
    db 16, 0
rd_dap_cnt: dw 0                ; Sectors this transfer
rd_dap_off: dw 0                ; Offset (always 0)
rd_dap_seg: dw 0x2800           ; Segment (0x2800:0 = 0x28000)
rd_dap_lba: dq 200              ; Current LBA
rd_remaining: dw 248            ; Sectors left to load

; Pad to sector multiple (image layout gives stage2 up to 33KB)
times 1024-($-$$) db 0
