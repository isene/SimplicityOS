; Simplicity OS - Stage 2 Loader
; Switches from 16-bit real mode to 64-bit long mode
; Then jumps to kernel

[BITS 16]
[ORG 0x7E00]

stage2_start:
    ; Print stage2 message
    mov si, msg_stage2
    call print_string_16

    ; Load kernel from disk to 0x10000 (64KB mark)
    ; We'll move it to 1MB after entering protected mode
    mov ah, 0x02        ; BIOS read sectors
    mov al, 127         ; Read 127 sectors (max per BIOS call, ~64KB)
    mov ch, 0           ; Cylinder 0
    mov cl, 18          ; Start after boot (1) + stage2 (16) = sector 18
    mov dh, 0           ; Head 0
    mov bx, 0x1000      ; Segment
    mov es, bx
    xor bx, bx          ; Offset 0, so ES:BX = 0x10000
    int 0x13
    jc kernel_load_error

    ; Enable A20 line (allows access to memory above 1MB)
    call enable_a20

    ; Load GDT
    lgdt [gdt_descriptor]

    ; Enter protected mode (32-bit)
    mov eax, cr0
    or eax, 1           ; Set PE (Protection Enable) bit
    mov cr0, eax

    jmp CODE_SEG:protected_mode

[BITS 32]
protected_mode:
    ; Set up protected mode segments
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000    ; Stack at 576KB

    ; Print protected mode message
    mov esi, msg_protected
    call print_string_32

    ; Copy kernel from 0x10000 to 0x100000 (1MB)
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, 17408      ; 69632 bytes / 4 = 17408 dwords
    rep movsd

    ; Print copy complete message
    mov esi, msg_copied
    call print_string_32

    ; Set up page tables for long mode
    call setup_paging

    ; Print paging setup message
    mov esi, msg_paging
    call print_string_32

    ; Enable PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5      ; Set PAE bit
    mov cr4, eax

    ; Load PML4 table address
    mov eax, pml4_table
    mov cr3, eax

    ; Enable long mode
    mov ecx, 0xC0000080 ; EFER MSR
    rdmsr
    or eax, 1 << 8      ; Set LM (Long Mode) bit
    wrmsr

    ; Enable paging (activates long mode)
    mov eax, cr0
    or eax, 1 << 31     ; Set PG (Paging) bit
    mov cr0, eax

    ; Jump to 64-bit code
    jmp CODE_SEG:long_mode

[BITS 64]
long_mode:
    ; Set up long mode segments
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Print long mode message (VGA text mode)
    mov rsi, msg_longmode
    call print_string_vga

    ; Print jump message
    mov rsi, msg_jump
    call print_string_vga

    ; Jump to kernel
    jmp 0x100000        ; Kernel loaded at 1MB

; Kernel load error handler
[BITS 16]
kernel_load_error:
    mov si, msg_kernel_error
    call print_string_16
    hlt
    jmp $

; Enable A20 line using keyboard controller
enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

; Print string in 16-bit real mode
print_string_16:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Print string in 32-bit protected mode (VGA text buffer)
[BITS 32]
print_string_32:
    push eax
    push ebx
    mov ebx, 0xB8000    ; VGA text buffer
.loop:
    lodsb
    test al, al
    jz .done
    mov [ebx], al
    mov byte [ebx+1], 0x0F  ; White on black
    add ebx, 2
    jmp .loop
.done:
    pop ebx
    pop eax
    ret

; Print string in 64-bit long mode (VGA text buffer)
[BITS 64]
print_string_vga:
    push rax
    push rbx
    mov rbx, 0xB8000
.loop:
    lodsb
    test al, al
    jz .done
    mov [rbx], al
    mov byte [rbx+1], 0x0A  ; Green on black
    add rbx, 2
    jmp .loop
.done:
    pop rbx
    pop rax
    ret

; Set up identity paging for first 2MB
[BITS 32]
setup_paging:
    ; Clear page table area
    mov edi, pml4_table
    mov ecx, 4096 * 3 / 4   ; Clear 3 pages (PML4, PDPT, PD)
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT
    mov eax, pdp_table
    or eax, 3               ; Present + writable
    mov [pml4_table], eax

    ; PDPT[0] -> PD
    mov eax, pd_table
    or eax, 3
    mov [pdp_table], eax

    ; PD[0] -> 2MB page
    mov eax, 0x83           ; Present + writable + 2MB page
    mov [pd_table], eax

    ret

; GDT (Global Descriptor Table)
gdt_start:
    dq 0                    ; Null descriptor

gdt_code:
    dw 0xFFFF               ; Limit low
    dw 0                    ; Base low
    db 0                    ; Base middle
    db 10011010b            ; Access: present, ring 0, code, executable, readable
    db 10101111b            ; Flags: 4KB granularity, 64-bit
    db 0                    ; Base high

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b            ; Access: present, ring 0, data, writable
    db 10101111b
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; Messages
msg_stage2:         db 'Stage2 running', 13, 10, 0
msg_kernel_error:   db 'Kernel load error!', 13, 10, 0
msg_protected:      db 'Prot ', 0
msg_copied:         db 'Copy ', 0
msg_paging:         db 'Page ', 0
msg_longmode:       db 'Long ', 0
msg_jump:           db 'Jump', 0

; Page tables (aligned to 4KB)
align 4096
pml4_table:
    times 512 dq 0

align 4096
pdp_table:
    times 512 dq 0

align 4096
pd_table:
    times 512 dq 0
