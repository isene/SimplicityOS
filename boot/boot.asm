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

    ; Load stage2 from disk (two reads to handle >32KB)
    ; Stage2 starts at sector 2 (sector 1 is boot sector)
    ; Floppy geometry: 18 sectors/track, 2 heads, 80 cylinders

    ; First read: 62 sectors starting at sector 2 (head 0, cyl 0)
    ; This gets us through sector 63 (end of tracks 0-3 on head 0)
    mov ah, 0x02        ; BIOS read sectors
    mov al, 17          ; Read remaining sectors on track 0 (2-18)
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start at sector 2
    mov dh, 0           ; Head 0
    mov dl, 0           ; Drive 0 (floppy)
    mov bx, 0x7E00      ; Load stage2 right after boot sector
    int 0x13            ; BIOS disk interrupt
    jc disk_error

    ; Second read: head 1, cylinder 0 (18 sectors)
    mov ah, 0x02
    mov al, 18
    mov ch, 0           ; Cylinder 0
    mov cl, 1           ; Sector 1
    mov dh, 1           ; Head 1
    mov dl, 0
    mov bx, 0x7E00 + (17*512)
    int 0x13
    jc disk_error

    ; Third read: head 0, cylinder 1 (18 sectors)
    mov ah, 0x02
    mov al, 18
    mov ch, 1           ; Cylinder 1
    mov cl, 1
    mov dh, 0           ; Head 0
    mov dl, 0
    mov bx, 0x7E00 + (35*512)
    int 0x13
    jc disk_error

    ; Fourth read: head 1, cylinder 1 (18 sectors)
    mov ah, 0x02
    mov al, 18
    mov ch, 1           ; Cylinder 1
    mov cl, 1
    mov dh, 1           ; Head 1
    mov dl, 0
    mov bx, 0x7E00 + (53*512)
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

; Pad to 510 bytes and add boot signature
times 510-($-$$) db 0
dw 0xAA55           ; Boot signature (must be at bytes 510-511)
