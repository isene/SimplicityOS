; Simplicity OS - UEFI Loader
; Hand-built PE32+ EFI application. Embeds kernel.bin and an 8x16 font.
; Path: efi_main -> ExitBootServices -> own GDT/page tables -> VGA text
; mode 3 (direct register programming, no BIOS) -> jump to kernel 0x10000.
; The kernel is identical for BIOS and UEFI boot.
;
; Position independent: ImageBase 0, no real relocations, all data
; references RIP-relative. Assemble: nasm -f bin -I build/ -o BOOTX64.EFI

BITS 64
default rel

%define FILE_ALIGN      0x200
%define SECT_ALIGN      0x1000
%define MAP_BUF_SIZE    32768
%define KERNEL_ADDR     0x10000
%define GDT_ADDR        0x60000     ; GDT copied here (kernel-lifetime memory)
%define PML4_ADDR       0x70000     ; page tables, same layout as stage2

; ============================================================
; PE32+ headers
; ============================================================
; DOS stub
    db 'MZ'
    times 0x3C - 2 db 0
    dd pe_header                    ; e_lfanew

pe_header:
    db 'PE', 0, 0
    dw 0x8664                       ; Machine: x86-64
    dw 2                            ; NumberOfSections
    dd 0                            ; TimeDateStamp
    dd 0                            ; PointerToSymbolTable
    dd 0                            ; NumberOfSymbols
    dw opt_end - opt_start          ; SizeOfOptionalHeader
    dw 0x0206                       ; Characteristics: EXEC | LINE_NUMS | DEBUG_STRIPPED

opt_start:
    dw 0x020B                       ; Magic: PE32+
    db 0, 0                         ; Linker version
    dd text_raw_size                ; SizeOfCode
    dd 0                            ; SizeOfInitializedData
    dd 0                            ; SizeOfUninitializedData
    dd 0x1000                       ; AddressOfEntryPoint (efi_main = text start)
    dd 0x1000                       ; BaseOfCode
    dq 0                            ; ImageBase (relocatable, PIC code)
    dd SECT_ALIGN                   ; SectionAlignment
    dd FILE_ALIGN                   ; FileAlignment
    dw 0, 0                         ; OS version
    dw 0, 0                         ; Image version
    dw 0, 0                         ; Subsystem version
    dd 0                            ; Win32 version
    dd image_size                   ; SizeOfImage
    dd FILE_ALIGN                   ; SizeOfHeaders
    dd 0                            ; Checksum
    dw 10                           ; Subsystem: EFI application
    dw 0                            ; DllCharacteristics
    dq 0x10000                      ; Stack reserve
    dq 0x10000                      ; Stack commit
    dq 0x10000                      ; Heap reserve
    dq 0                            ; Heap commit
    dd 0                            ; LoaderFlags
    dd 16                           ; NumberOfRvaAndSizes
    dd 0, 0                         ; Export
    dd 0, 0                         ; Import
    dd 0, 0                         ; Resource
    dd 0, 0                         ; Exception
    dd 0, 0                         ; Certificate
    dd reloc_rva, 12                ; Base relocation (dummy block)
    dd 0, 0                         ; Debug
    dd 0, 0                         ; Architecture
    dd 0, 0                         ; Global ptr
    dd 0, 0                         ; TLS
    dd 0, 0                         ; Load config
    dd 0, 0                         ; Bound import
    dd 0, 0                         ; IAT
    dd 0, 0                         ; Delay import
    dd 0, 0                         ; COM descriptor
    dd 0, 0                         ; Reserved
opt_end:

; Section table
    db '.text', 0, 0, 0
    dd text_raw_size                ; VirtualSize
    dd 0x1000                       ; VirtualAddress
    dd text_raw_size                ; SizeOfRawData
    dd text_file                    ; PointerToRawData
    dd 0, 0
    dw 0, 0
    dd 0xE0000020                   ; CODE | EXEC | READ | WRITE

    db '.reloc', 0, 0
    dd 12                           ; VirtualSize
    dd reloc_rva                    ; VirtualAddress
    dd FILE_ALIGN                   ; SizeOfRawData
    dd reloc_file                   ; PointerToRawData
    dd 0, 0
    dw 0, 0
    dd 0x42000040                   ; INITIALIZED_DATA | DISCARDABLE | READ

    times FILE_ALIGN - ($ - $$) db 0
text_file:

; ============================================================
; Code (RVA 0x1000). Entry: RCX = ImageHandle, RDX = SystemTable
; ============================================================
efi_main:
    sub rsp, 56                     ; shadow space + 5th arg + alignment
    mov [image_handle], rcx
    mov r13, [rdx + 96]             ; SystemTable->BootServices

.get_map:
    mov qword [map_size], MAP_BUF_SIZE
    lea rcx, [map_size]
    lea rdx, [mem_map]
    lea r8,  [map_key]
    lea r9,  [desc_size]
    lea rax, [desc_ver]
    mov [rsp + 32], rax
    mov rax, [r13 + 56]             ; GetMemoryMap
    call rax

    mov rcx, [image_handle]
    mov rdx, [map_key]
    mov rax, [r13 + 232]            ; ExitBootServices
    call rax
    test rax, rax
    jnz .get_map                    ; stale map key: retry (spec-mandated loop)

    cli

    ; Copy GDT to fixed low memory so it outlives this image
    lea rsi, [gdt64]
    mov rdi, GDT_ADDR
    mov rcx, gdt64_end - gdt64
    rep movsb
    mov word  [abs GDT_ADDR + 0x100], gdt64_end - gdt64 - 1
    mov qword [abs GDT_ADDR + 0x102], GDT_ADDR
    lgdt [abs GDT_ADDR + 0x100]

    ; Reload CS = 0x08 via far return, then data segments = 0x10
    lea rax, [.new_cs]
    push 0x08
    push rax
    retfq
.new_cs:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x80000                ; kernel machine-stack region

    ; Page tables: identity map first 1GB with 2MB pages
    ; (superset of stage2's 0-4MB; needed because this loader runs high)
    mov rdi, PML4_ADDR
    xor eax, eax
    mov rcx, 3 * 4096 / 8
    rep stosq
    mov qword [abs PML4_ADDR],          PML4_ADDR + 0x1003  ; PML4[0] -> PDPT
    mov qword [abs PML4_ADDR + 0x1000], PML4_ADDR + 0x2003  ; PDPT[0] -> PD
    mov rdi, PML4_ADDR + 0x2000
    mov rax, 0x83                   ; present | writable | 2MB page
    mov rcx, 512
.fill_pd:
    mov [rdi], rax
    add rax, 0x200000
    add rdi, 8
    dec rcx
    jnz .fill_pd
    mov rax, PML4_ADDR
    mov cr3, rax

    ; Copy embedded kernel to its load address
    lea rsi, [kernel_blob]
    mov rdi, KERNEL_ADDR
    mov rcx, (kernel_end - kernel_blob + 7) / 8
    rep movsq

    ; Copy embedded apps (disk sectors 200-447) to the RAM disk area
    lea rsi, [apps_blob]
    mov rdi, 0x28000
    mov rcx, (apps_end - apps_blob + 7) / 8
    rep movsq

    call vga_text_mode

    mov rax, KERNEL_ADDR
    jmp rax

; ============================================================
; VGA text mode 3 without BIOS: registers, font, palette
; ============================================================
vga_text_mode:
    ; Disable QEMU Bochs-VBE linear framebuffer (set by OVMF video driver)
    mov dx, 0x1CE
    mov ax, 4                       ; VBE_DISPI_INDEX_ENABLE
    out dx, ax
    mov dx, 0x1CF
    xor ax, ax                      ; disabled
    out dx, ax

    ; Miscellaneous output: color, 28MHz, sync polarities for 400 lines
    mov dx, 0x3C2
    mov al, 0x67
    out dx, al

    ; Sequencer: sync reset, program, release
    mov dx, 0x3C4
    mov ax, 0x0100
    out dx, ax
    mov ax, 0x0001                  ; clocking mode: 9-dot chars
    out dx, ax
    mov ax, 0x0302                  ; map mask: planes 0+1
    out dx, ax
    mov ax, 0x0003                  ; char map select: font A=B=0
    out dx, ax
    mov ax, 0x0204                  ; memory mode: odd/even
    out dx, ax
    mov ax, 0x0300                  ; release reset
    out dx, ax

    ; CRTC: unlock regs 0-7, then standard mode 3 table
    mov dx, 0x3D4
    mov ax, 0x0E11
    out dx, ax
    lea rsi, [crtc_regs]
    xor rcx, rcx
.crtc_loop:
    mov al, cl
    mov ah, [rsi + rcx]
    out dx, ax
    inc rcx
    cmp rcx, 25
    jb .crtc_loop

    ; Graphics controller
    mov dx, 0x3CE
    lea rsi, [gfx_regs]
    xor rcx, rcx
.gfx_loop:
    mov al, cl
    mov ah, [rsi + rcx]
    out dx, ax
    inc rcx
    cmp rcx, 9
    jb .gfx_loop

    ; Attribute controller (reset flip-flop first)
    mov dx, 0x3DA
    in al, dx
    lea rsi, [attr_regs]
    xor rcx, rcx
    mov dx, 0x3C0
.attr_loop:
    mov al, cl
    out dx, al
    mov al, [rsi + rcx]
    out dx, al
    inc rcx
    cmp rcx, 21
    jb .attr_loop

    ; Upload font to plane 2 (256 glyphs, 16 bytes each, 32-byte stride)
    mov dx, 0x3C4
    mov ax, 0x0100
    out dx, ax
    mov ax, 0x0402                  ; map mask: plane 2
    out dx, ax
    mov ax, 0x0704                  ; memory mode: sequential
    out dx, ax
    mov ax, 0x0300
    out dx, ax
    mov dx, 0x3CE
    mov ax, 0x0204                  ; read map: plane 2
    out dx, ax
    mov ax, 0x0005                  ; mode: linear
    out dx, ax
    mov ax, 0x0406                  ; misc: map at A0000
    out dx, ax

    lea rsi, [font_blob]
    mov rdi, 0xA0000
    mov rcx, 256
.font_loop:
    push rcx
    mov rcx, 16
    rep movsb
    add rdi, 16                     ; skip to next 32-byte glyph slot
    pop rcx
    dec rcx
    jnz .font_loop

    ; Restore sequencer/graphics for text mode
    mov dx, 0x3C4
    mov ax, 0x0100
    out dx, ax
    mov ax, 0x0302
    out dx, ax
    mov ax, 0x0204
    out dx, ax
    mov ax, 0x0300
    out dx, ax
    mov dx, 0x3CE
    mov ax, 0x0004
    out dx, ax
    mov ax, 0x1005
    out dx, ax
    mov ax, 0x0E06                  ; map at B8000
    out dx, ax

    ; DAC palette: standard EGA colors for indexes 0-63
    mov dx, 0x3C8
    xor al, al
    out dx, al
    mov dx, 0x3C9
    xor rcx, rcx                    ; RCX = palette index
.dac_loop:
    ; R: bit2 primary (0x2A), bit5 secondary (0x15)
    xor al, al
    test cl, 0x04
    jz .dac_r2
    add al, 0x2A
.dac_r2:
    test cl, 0x20
    jz .dac_r_done
    add al, 0x15
.dac_r_done:
    out dx, al
    ; G: bit1 primary, bit4 secondary
    xor al, al
    test cl, 0x02
    jz .dac_g2
    add al, 0x2A
.dac_g2:
    test cl, 0x10
    jz .dac_g_done
    add al, 0x15
.dac_g_done:
    out dx, al
    ; B: bit0 primary, bit3 secondary
    xor al, al
    test cl, 0x01
    jz .dac_b2
    add al, 0x2A
.dac_b2:
    test cl, 0x08
    jz .dac_b_done
    add al, 0x15
.dac_b_done:
    out dx, al
    inc rcx
    cmp rcx, 64
    jb .dac_loop

    ; Re-enable video output
    mov dx, 0x3DA
    in al, dx
    mov dx, 0x3C0
    mov al, 0x20
    out dx, al

    ; Clear text buffer: spaces, light grey on black
    mov rdi, 0xB8000
    mov rcx, 2000
    mov ax, 0x0720
    rep stosw
    ret

; ============================================================
; Data
; ============================================================
crtc_regs: db 0x5F, 0x4F, 0x50, 0x82, 0x55, 0x81, 0xBF, 0x1F
           db 0x00, 0x4F, 0x0D, 0x0E, 0x00, 0x00, 0x00, 0x00
           db 0x9C, 0x8E, 0x8F, 0x28, 0x1F, 0x96, 0xB9, 0xA3
           db 0xFF
gfx_regs:  db 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x0E, 0x00
           db 0xFF
attr_regs: db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x14, 0x07
           db 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F
           db 0x0C, 0x00, 0x0F, 0x08, 0x00

align 8
gdt64:
    dq 0                            ; null
    dq 0x00209A0000000000           ; 0x08: 64-bit code
    dq 0x0000920000000000           ; 0x10: data
gdt64_end:

align 8
image_handle: dq 0
map_size:     dq 0
map_key:      dq 0
desc_size:    dq 0
desc_ver:     dq 0
mem_map:      times MAP_BUF_SIZE db 0

align 8
font_blob:   incbin "font8x16.bin"

align 8
kernel_blob: incbin "kernel.bin"
kernel_end:

align 8
apps_blob:   incbin "apps.img"
apps_end:

    times ((($ - text_file) + FILE_ALIGN - 1) / FILE_ALIGN) * FILE_ALIGN - ($ - text_file) db 0
text_end:

; ============================================================
; .reloc section: one dummy block (two ABSOLUTE entries)
; ============================================================
reloc_file:
    dd 0x1000                       ; page RVA
    dd 12                           ; block size
    dw 0, 0                         ; two no-op entries
    times FILE_ALIGN - 12 db 0

; Header constants
text_raw_size equ text_end - text_file
reloc_rva     equ 0x1000 + ((text_raw_size + SECT_ALIGN - 1) / SECT_ALIGN) * SECT_ALIGN
image_size    equ reloc_rva + SECT_ALIGN
