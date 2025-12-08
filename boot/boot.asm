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

    ; Save boot drive (BIOS passes in DL)
    mov [boot_drive], dl

    ; Print boot message
    mov si, msg_boot
    call print_string

    ; Load stage2 + kernel using LBA mode (INT 13h extensions)
    ; First read: sectors 1-127 (127 sectors)
    mov ah, 0x42        ; Extended read
    mov dl, [boot_drive]
    mov si, dap1        ; First Disk Address Packet
    int 0x13
    jc disk_error

    ; Second read: sectors 128-200 (73 more sectors for larger kernels)
    mov ah, 0x42        ; Extended read
    mov dl, [boot_drive]
    mov si, dap2        ; Second Disk Address Packet
    int 0x13
    jc disk_error

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

; Boot drive number (saved from DL)
boot_drive:  db 0

; First Disk Address Packet - Load sectors 1-127 to 0x7E00
dap1:
    db 16           ; Size of packet
    db 0            ; Reserved
    dw 127          ; Sectors to read
    dw 0x7E00       ; Offset (loads to 0x7E00)
    dw 0            ; Segment
    dq 1            ; LBA start (sector 1)

; Second Disk Address Packet - Load sectors 128-200 to continue
; Destination: 0x7E00 + 127*512 = 0x7E00 + 0xFE00 = 0x17C00
dap2:
    db 16           ; Size of packet
    db 0            ; Reserved
    dw 73           ; Sectors to read (128-200 = 73 more sectors)
    dw 0x7C00       ; Offset (low word of 0x17C00)
    dw 0x1000       ; Segment (0x1000:0x7C00 = 0x17C00)
    dq 128          ; LBA start (sector 128)

; Pad to 510 bytes and add boot signature
times 510-($-$$) db 0
dw 0xAA55           ; Boot signature (must be at bytes 510-511)
