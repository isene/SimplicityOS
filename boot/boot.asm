; Simplicity OS - Boot Sector
; This is the first code that executes when BIOS loads our OS
; BIOS loads this 512-byte sector to 0x7C00 and jumps to it

[BITS 16]           ; Real mode (16-bit)
[ORG 0x7C00]        ; BIOS loads us here

start:
    ; Set up segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack grows down from boot sector

    ; Print boot message
    mov si, msg_boot
    call print_string

    ; Load stage2 from disk
    ; Stage2 starts at sector 2 (sector 1 is boot sector)
    mov ah, 0x02        ; BIOS read sectors
    mov al, 63          ; Read 63 sectors (max for single BIOS call)
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start at sector 2
    mov dh, 0           ; Head 0
    mov bx, 0x7E00      ; Load stage2 right after boot sector
    int 0x13            ; BIOS disk interrupt

    jc disk_error       ; Jump if carry flag set (error)

    ; Print success message
    mov si, msg_loaded
    call print_string

    ; Jump to stage2
    jmp 0x7E00

disk_error:
    mov si, msg_error
    call print_string
    hlt                 ; Halt CPU

; Print null-terminated string
; Input: SI = pointer to string
print_string:
    pusha
.loop:
    lodsb               ; Load byte from SI into AL, increment SI
    test al, al         ; Check if zero (end of string)
    jz .done
    mov ah, 0x0E        ; BIOS teletype output
    int 0x10            ; BIOS video interrupt
    jmp .loop
.done:
    popa
    ret

; Messages
msg_boot:    db 'Simplicity OS booting...', 13, 10, 0
msg_loaded:  db 'Stage2 loaded', 13, 10, 0
msg_error:   db 'Disk read error!', 13, 10, 0

; Pad to 510 bytes and add boot signature
times 510-($-$$) db 0
dw 0xAA55           ; Boot signature (must be at bytes 510-511)
