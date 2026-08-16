; Simplicity - 64-bit RPN "Lego" OS Kernel
; Loaded at 0x10000 by stage2 after mode transitions
; Contains: REPL, assembly primitives, and RPN interpreter

[BITS 64]
[ORG 0x10000]

; ============================================================
; Physical memory map
;   0x010000 - 0x020000  Kernel image and in-image buffers
;   0x028000 - 0x047000  RAM disk (sectors 200-447, loaded at boot)
;   0x060000             GDT copy (UEFI path)
;   0x070000 - 0x073000  Page tables
;   0x080000             Machine stack (grows down)
;   0x090000             Return stack (grows down)
;   0x100000 - 0x160000  App load buffer
;   0x200000 - 0x240000  Dictionary (user definitions)
;   0x240000 - 0x248000  Compile buffer
;   0x260000 - 0x4000000 Heap (grows on demand via #PF, 64MB cap)
;   0x074000 - 0x075000  IDT
; ============================================================
DICT_SPACE      equ 0x200000
DICT_END        equ 0x240000
HEAP_START      equ 0x260000
HEAP_END        equ 0x400000    ; initially mapped boundary
HEAP_MAX        equ 0x4000000   ; heap ceiling (64MB, mapped on demand)
IDT_ADDR        equ 0x74000     ; 4KB IDT after the page tables
RAMDISK_ADDR    equ 0x28000
RAMDISK_FIRST   equ 200         ; First sector held in the RAM disk
RAMDISK_COUNT   equ 248         ; Sectors 200-447

long_mode_64:
    ; Setup 64-bit segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Initialize x87 FPU (float words use it; exceptions masked)
    fninit

    ; Interrupts: IDT with exception recovery, PIC remap, keyboard IRQ
    call init_interrupts

    ; Clear screen in 64-bit mode (2000 cells = 500 qwords)
    mov rdi, 0xB8000
    mov rcx, 500
    mov rax, 0x0F200F200F200F20
    rep stosq

    ; Print message
    mov rdi, 0xB8000
    mov rsi, msg64
    mov ah, 0x0A
.loop:
    lodsb
    test al, al
    jz .done
    mov [rdi], ax
    add rdi, 2
    jmp .loop
.done:

    ; Initialize RPN interpreter (64-bit)
    mov rsp, 0x80000        ; Data stack
    mov rbp, 0x90000        ; Return stack (away from page tables at 0x70000)
    mov rsi, test_program   ; Instruction pointer
    jmp NEXT

; NEXT - Inner interpreter (64-bit)
NEXT:
    lodsq                   ; Load qword
    jmp rax

; Core words (64-bit)

DUP:
    mov rax, [rsp]
    push rax
    jmp NEXT

DROP:
    add rsp, 8
    jmp NEXT

SWAP:
    pop rax
    pop rbx
    push rax
    push rbx
    jmp NEXT

PLUS:
    pop rax
    add [rsp], rax
    jmp NEXT

MULT:
    pop rax
    pop rbx
    imul rax, rbx
    push rax
    jmp NEXT

MINUS:
    pop rax
    sub [rsp], rax
    jmp NEXT

DIV:
    xor rdx, rdx
    pop rbx             ; divisor
    pop rax             ; dividend
    div rbx
    push rax            ; quotient
    jmp NEXT

ROT:
    pop rax             ; c
    pop rbx             ; b
    pop rcx             ; a
    push rbx            ; b
    push rax            ; c
    push rcx            ; a
    jmp NEXT

OVER:
    mov rax, [rsp+8]
    push rax
    jmp NEXT

FETCH:
    pop rax
    mov rax, [rax]
    push rax
    jmp NEXT

STORE:
    pop rax             ; address
    pop rbx             ; value
    mov [rax], rbx
    jmp NEXT

DOT:
    pop rax
    call print_number
    mov rbx, [cursor]
    mov byte [rbx], ' '
    mov byte [rbx+1], 0x0F
    add rbx, 2
    mov [cursor], rbx
    jmp NEXT

QUOTE:
    pop rax             ; Get string address
    call print_string
    jmp NEXT

EMIT:
    pop rax             ; Get character
    call emit_char
    jmp NEXT

CR:
    ; Move cursor to next line
    mov rbx, [cursor]
    sub rbx, 0xB8000    ; Get offset from start
    shr rbx, 1          ; Divide by 2 (char+attr)
    mov rax, rbx
    xor rdx, rdx
    mov rcx, 80
    div rcx             ; RAX = row, RDX = col
    inc rax             ; Next row
    xor rdx, rdx
    mul rcx             ; RAX = row * 80
    shl rax, 1          ; Multiply by 2
    add rax, 0xB8000
    mov [cursor], rax
    jmp NEXT

LIT:
    ; Push literal to data stack (R14/R15 model)
    lodsq               ; Get literal value from [RSI]
    mov [r15], r14      ; Save old TOS to stack memory
    add r15, 8          ; Advance stack pointer
    mov r14, rax        ; New value becomes TOS
    jmp NEXT

BRANCH:
    ; Unconditional branch - offset in next cell
    lodsq                   ; Get offset
    add rsi, rax            ; Add to instruction pointer
    jmp NEXT

ZBRANCH:
    ; Branch if TOS is zero - offset in next cell
    ; Uses R14/R15 stack model: R14 = TOS, R15 = stack pointer
    lodsq                   ; Get offset into RAX
    mov rbx, r14            ; Save TOS for test
    ; Pop TOS using R14/R15 convention
    sub r15, 8
    cmp r15, [stack_floor]
    jl .zbranch_empty_prim  ; Use jl not jle - R15==data_stack means valid element at [R15]
    mov r14, [r15]          ; After sub, old second-on-stack is at [r15]
    jmp .zbranch_test_prim
.zbranch_empty_prim:
    mov r15, [stack_floor]
    xor r14, r14
.zbranch_test_prim:
    test rbx, rbx
    jz .do_branch
    jmp NEXT                ; Non-zero, don't branch
.do_branch:
    add rsi, rax            ; Zero, take branch
    jmp NEXT

KEY:
    ; Wait for keypress and return ASCII character
    call wait_key
    push rax
    jmp NEXT

BYE:
    cli
    hlt
    jmp $

; Print number in RAX (64-bit)
print_hex_screen:
    ; Print RAX as hex to screen
    push rax
    push rbx
    push rcx
    mov rbx, rax
    mov rcx, 16
.hex_loop:
    rol rbx, 4
    mov rax, rbx
    and rax, 0xF
    cmp al, 10
    jl .hex_digit
    add al, 7
.hex_digit:
    add al, '0'
    call emit_char
    dec rcx
    jnz .hex_loop
    pop rcx
    pop rbx
    pop rax
    ret

print_number:
    push rax
    push rbx
    push rcx
    push rdx

    mov rbx, 10
    xor rcx, rcx

    ; Check for zero
    test rax, rax
    jnz .check_neg
    mov al, '0'
    call emit_char
    jmp .done

.check_neg:
    ; Check if negative (signed)
    test rax, rax
    jns .conv               ; Jump if not negative
    ; Print minus sign
    push rax
    mov al, '-'
    call emit_char
    pop rax
    neg rax                 ; Make positive

.conv:
    xor rdx, rdx
    div rbx
    push rdx
    inc rcx
    test rax, rax
    jnz .conv

.print:
    pop rax
    add al, '0'
    call emit_char
    loop .print

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

emit_char:
    push rax
    push rbx
    mov rbx, [cursor]
    mov [rbx], al
    mov byte [rbx+1], 0x0E
    add rbx, 2
    mov [cursor], rbx
    call update_hw_cursor
    pop rbx
    pop rax
    ret

; Update hardware VGA cursor to match software cursor
update_hw_cursor:
    push rax
    push rbx
    push rdx

    ; Enable cursor and set shape (underline: scanlines 13-14)
    mov al, 0x0A            ; Cursor start register
    mov dx, 0x3D4
    out dx, al
    mov al, 13              ; Start scanline 13, cursor enabled (bit 5 = 0)
    mov dx, 0x3D5
    out dx, al

    mov al, 0x0B            ; Cursor end register
    mov dx, 0x3D4
    out dx, al
    mov al, 14              ; End scanline 14
    mov dx, 0x3D5
    out dx, al

    ; Calculate cursor position
    mov rax, [cursor]
    sub rax, 0xB8000
    shr rax, 1              ; Divide by 2 (char+attr)

    ; Send cursor position to VGA controller
    ; High byte
    mov rbx, rax
    shr rbx, 8
    mov al, 0x0E            ; Cursor high register
    mov dx, 0x3D4
    out dx, al
    mov al, bl
    mov dx, 0x3D5
    out dx, al

    ; Low byte
    mov rax, [cursor]
    sub rax, 0xB8000
    shr rax, 1
    mov rbx, rax
    mov al, 0x0F            ; Cursor low register
    mov dx, 0x3D4
    out dx, al
    mov al, bl
    mov dx, 0x3D5
    out dx, al

    pop rdx
    pop rbx
    pop rax
    ret

; Wait for keypress and return key code in RAX
; Returns: ASCII for normal keys, or special codes (KEY_UP, KEY_DOWN, etc.)
; ============================================================
; Interrupts: IDT, exception recovery, PIC, keyboard IRQ
; Exceptions print a report and drop back to the REPL instead of
; triple-faulting. Page faults in the heap window map fresh 2MB
; pages so the heap grows on demand up to HEAP_MAX.
; ============================================================

%macro EXC_NOERR 1
exc_stub_%1:
    push qword 0
    push qword %1
    jmp exc_common
%endmacro
%macro EXC_ERR 1
exc_stub_%1:
    push qword %1
    jmp exc_common
%endmacro

EXC_NOERR 0
EXC_NOERR 1
EXC_NOERR 2
EXC_NOERR 3
EXC_NOERR 4
EXC_NOERR 5
EXC_NOERR 6
EXC_NOERR 7
EXC_ERR 8
EXC_NOERR 9
EXC_ERR 10
EXC_ERR 11
EXC_ERR 12
EXC_ERR 13
EXC_ERR 14
EXC_NOERR 15
EXC_NOERR 16
EXC_ERR 17
EXC_NOERR 18
EXC_NOERR 19
EXC_NOERR 20
EXC_NOERR 21
EXC_NOERR 22
EXC_NOERR 23
EXC_NOERR 24
EXC_NOERR 25
EXC_NOERR 26
EXC_NOERR 27
EXC_NOERR 28
EXC_NOERR 29
EXC_NOERR 30
EXC_NOERR 31

exc_stub_table:
    dq exc_stub_0, exc_stub_1, exc_stub_2, exc_stub_3
    dq exc_stub_4, exc_stub_5, exc_stub_6, exc_stub_7
    dq exc_stub_8, exc_stub_9, exc_stub_10, exc_stub_11
    dq exc_stub_12, exc_stub_13, exc_stub_14, exc_stub_15
    dq exc_stub_16, exc_stub_17, exc_stub_18, exc_stub_19
    dq exc_stub_20, exc_stub_21, exc_stub_22, exc_stub_23
    dq exc_stub_24, exc_stub_25, exc_stub_26, exc_stub_27
    dq exc_stub_28, exc_stub_29, exc_stub_30, exc_stub_31

exc_common:
    ; Stack: vector, error code, RIP, CS, RFLAGS, RSP, SS
    push rax
    push rbx

    mov rax, [rsp+16]           ; vector
    cmp rax, 14
    jne .exc_fatal

    ; Page fault: demand-map the heap window
    mov rax, cr2
    cmp rax, HEAP_END
    jb .exc_fatal               ; below the boot-mapped area: real bug
    cmp rax, HEAP_MAX
    jae .exc_fatal
    mov rbx, rax
    shr rbx, 21                 ; PD index
    shl rbx, 3
    add rbx, 0x72000            ; PD base (both boot paths)
    shr rax, 21
    shl rax, 21                 ; 2MB-align the fault address
    or rax, 0x83                ; present | writable | 2MB
    mov [rbx], rax
    mov rax, cr2
    invlpg [rax]
    pop rbx
    pop rax
    add rsp, 16                 ; drop vector + error code
    iretq

.exc_fatal:
    ; Report and recover to the REPL
    push rsi
    mov rax, str_exc
    call print_string
    mov rax, [rsp+24]           ; vector (3 pushes deep now)
    call print_number
    mov rax, str_exc_at
    call print_string
    mov rax, [rsp+40]           ; RIP
    call print_number
    call newline
    jmp repl_recover

str_exc: db 13, 10, '(exception ', 0
str_exc_at: db ' at ', 0

; Shared IRQ stub: acknowledge and resume (keyboard bytes are read
; by the polling code; the interrupt only wakes HLT)
irq_stub:
    push rax
    mov al, 0x20
    out 0xA0, al
    out 0x20, al
    pop rax
    iretq

; idt_set_gate: RCX = vector, RAX = handler
idt_set_gate:
    push rbx
    push rdx
    mov rbx, rcx
    shl rbx, 4
    add rbx, IDT_ADDR
    mov rdx, rax
    mov [rbx], dx               ; offset 0-15
    mov word [rbx+2], 0x08      ; code selector
    mov word [rbx+4], 0x8E00    ; present, interrupt gate, IST 0
    shr rdx, 16
    mov [rbx+6], dx             ; offset 16-31
    shr rdx, 16
    mov [rbx+8], edx            ; offset 32-63
    mov dword [rbx+12], 0
    pop rdx
    pop rbx
    ret

init_interrupts:
    push rax
    push rcx
    push rsi
    push rdi

    ; Clear IDT
    mov rdi, IDT_ADDR
    xor eax, eax
    mov rcx, 512
    rep stosq

    ; Exception gates 0-31
    xor rcx, rcx
    mov rsi, exc_stub_table
.ii_exc:
    mov rax, [rsi + rcx*8]
    call idt_set_gate
    inc rcx
    cmp rcx, 32
    jb .ii_exc

    ; IRQ gates 0x20-0x2F all share the acknowledge stub
    mov rcx, 0x20
.ii_irq:
    mov rax, irq_stub
    call idt_set_gate
    inc rcx
    cmp rcx, 0x30
    jb .ii_irq

    lidt [idtr]

    ; Remap PIC: IRQs to vectors 0x20-0x2F
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 4
    out 0x21, al
    mov al, 2
    out 0xA1, al
    mov al, 1
    out 0x21, al
    out 0xA1, al
    ; Mask everything except the keyboard (IRQ1)
    mov al, 0xFD
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

align 8
idtr:
    dw 4095
    dq IDT_ADDR

wait_key:
    push rbx
.wait:
    ; Check if key available (port 0x64, bit 0)
    in al, 0x64
    test al, 1
    jnz .have_byte
    ; Idle until the keyboard interrupt wakes us (sti;hlt is atomic)
    sti
    hlt
    cli
    jmp .wait
.have_byte:

    ; Read scancode from port 0x60
    in al, 0x60

    ; Check for shift keys
    cmp al, 0x2A            ; Left shift press
    je .shift_press
    cmp al, 0x36            ; Right shift press
    je .shift_press
    cmp al, 0xAA            ; Left shift release
    je .shift_release
    cmp al, 0xB6            ; Right shift release
    je .shift_release

    ; Check for ctrl key
    cmp al, 0x1D            ; Ctrl press
    je .ctrl_press
    cmp al, 0x9D            ; Ctrl release
    je .ctrl_release

    ; Ignore other key releases (bit 7 set)
    test al, 0x80
    jnz .wait

    ; Check for special keys (arrow keys, escape, etc.)
    cmp al, 0x01            ; Escape
    je .key_escape
    cmp al, 0x48            ; Up arrow
    je .key_up
    cmp al, 0x50            ; Down arrow
    je .key_down
    cmp al, 0x4B            ; Left arrow
    je .key_left
    cmp al, 0x4D            ; Right arrow
    je .key_right
    cmp al, 0x47            ; Home
    je .key_home
    cmp al, 0x4F            ; End
    je .key_end
    cmp al, 0x49            ; Page Up
    je .key_pgup
    cmp al, 0x51            ; Page Down
    je .key_pgdn
    cmp al, 0x53            ; Delete
    je .key_delete

    ; Convert scancode to ASCII
    call scancode_to_ascii

    ; Apply ctrl modifier (Ctrl+A = 1, Ctrl+B = 2, etc.)
    cmp byte [ctrl_state], 0
    je .no_ctrl
    cmp rax, 'a'
    jl .no_ctrl
    cmp rax, 'z'
    jg .no_ctrl
    sub rax, 96             ; 'a' -> 1, 'b' -> 2, etc.
.no_ctrl:

    ; If zero (unmapped key), ignore it
    test rax, rax
    jz .wait

    pop rbx
    ret

.shift_press:
    mov byte [shift_state], 1
    jmp .wait

.shift_release:
    mov byte [shift_state], 0
    jmp .wait

.ctrl_press:
    mov byte [ctrl_state], 1
    jmp .wait

.ctrl_release:
    mov byte [ctrl_state], 0
    jmp .wait

.key_escape:
    mov rax, KEY_ESCAPE
    pop rbx
    ret

.key_up:
    mov rax, KEY_UP
    pop rbx
    ret

.key_down:
    mov rax, KEY_DOWN
    pop rbx
    ret

.key_left:
    mov rax, KEY_LEFT
    pop rbx
    ret

.key_right:
    mov rax, KEY_RIGHT
    pop rbx
    ret

.key_home:
    mov rax, KEY_HOME
    pop rbx
    ret

.key_end:
    mov rax, KEY_END
    pop rbx
    ret

.key_pgup:
    mov rax, KEY_PGUP
    pop rbx
    ret

.key_pgdn:
    mov rax, KEY_PGDN
    pop rbx
    ret

.key_delete:
    mov rax, KEY_DELETE
    pop rbx
    ret

; Check if key available without blocking
; Returns: key code in RAX, or 0 if no key
check_key:
    push rbx

    ; Check if key available
    in al, 0x64
    test al, 1
    jz .no_key

    ; Read scancode
    in al, 0x60

    ; Handle shift/ctrl state changes
    cmp al, 0x2A
    je .ck_shift_press
    cmp al, 0x36
    je .ck_shift_press
    cmp al, 0xAA
    je .ck_shift_release
    cmp al, 0xB6
    je .ck_shift_release
    cmp al, 0x1D
    je .ck_ctrl_press
    cmp al, 0x9D
    je .ck_ctrl_release

    ; Ignore releases
    test al, 0x80
    jnz .no_key

    ; Check special keys
    cmp al, 0x01
    je .ck_escape
    cmp al, 0x48
    je .ck_up
    cmp al, 0x50
    je .ck_down
    cmp al, 0x4B
    je .ck_left
    cmp al, 0x4D
    je .ck_right
    cmp al, 0x47
    je .ck_home
    cmp al, 0x4F
    je .ck_end
    cmp al, 0x49
    je .ck_pgup
    cmp al, 0x51
    je .ck_pgdn
    cmp al, 0x53
    je .ck_delete

    ; Normal key
    call scancode_to_ascii

    ; Apply ctrl
    cmp byte [ctrl_state], 0
    je .ck_done
    cmp rax, 'a'
    jl .ck_done
    cmp rax, 'z'
    jg .ck_done
    sub rax, 96

.ck_done:
    pop rbx
    ret

.no_key:
    xor rax, rax
    pop rbx
    ret

.ck_shift_press:
    mov byte [shift_state], 1
    jmp .no_key
.ck_shift_release:
    mov byte [shift_state], 0
    jmp .no_key
.ck_ctrl_press:
    mov byte [ctrl_state], 1
    jmp .no_key
.ck_ctrl_release:
    mov byte [ctrl_state], 0
    jmp .no_key

.ck_escape:
    mov rax, KEY_ESCAPE
    jmp .ck_done
.ck_up:
    mov rax, KEY_UP
    jmp .ck_done
.ck_down:
    mov rax, KEY_DOWN
    jmp .ck_done
.ck_left:
    mov rax, KEY_LEFT
    jmp .ck_done
.ck_right:
    mov rax, KEY_RIGHT
    jmp .ck_done
.ck_home:
    mov rax, KEY_HOME
    jmp .ck_done
.ck_end:
    mov rax, KEY_END
    jmp .ck_done
.ck_pgup:
    mov rax, KEY_PGUP
    jmp .ck_done
.ck_pgdn:
    mov rax, KEY_PGDN
    jmp .ck_done
.ck_delete:
    mov rax, KEY_DELETE
    jmp .ck_done

; Special key codes (above ASCII range)
KEY_ESCAPE equ 256
KEY_UP     equ 257
KEY_DOWN   equ 258
KEY_LEFT   equ 259
KEY_RIGHT  equ 260
KEY_HOME   equ 261
KEY_END    equ 262
KEY_PGUP   equ 263
KEY_PGDN   equ 264
KEY_DELETE equ 265

; Convert scancode to ASCII using direct table lookup
; Why: Faster than jump chain, cleaner code
scancode_to_ascii:
    push rbx
    movzx rbx, al           ; Scancode as index

    ; Select table based on shift state
    cmp byte [shift_state], 0
    je .use_normal

    ; Shifted - use shift table
    movzx rax, byte [scancode_shift_table + rbx]
    pop rbx
    ret

.use_normal:
    ; Normal - use normal table
    movzx rax, byte [scancode_normal_table + rbx]
    pop rbx
    ret

; Optimized scancode tables - Direct 256-byte lookup (no jumps)
; Why: Faster and cleaner than jump chain

scancode_normal_table:
    times 0x02 db 0
    db '1','2','3','4','5','6','7','8','9','0'          ; 0x02-0x0B
    db '-','=', 8, 0                                     ; 0x0C-0x0F (minus, equals, backspace, tab)
    db 'q','w','e','r','t','y','u','i','o','p'          ; 0x10-0x19
    db '[',']', 10, 0                                    ; 0x1A-0x1D (brackets, enter, ctrl)
    db 'a','s','d','f','g','h','j','k','l'              ; 0x1E-0x26
    db ';', 39, 96, 0, 0                                 ; 0x27-0x2B (semicolon, apostrophe, backtick, lshift, backslash)
    db 'z','x','c','v','b','n','m'                      ; 0x2C-0x32
    db ',','.','/', 0, 0, 0                              ; 0x33-0x38
    db ' ', 0, 0, 0, 0, 0, 0                            ; 0x39-0x3F (space + unmapped)
    db 0, 0, 0, 0, 0, 0, 0, 0, 0                         ; 0x40-0x48
    db 0, 0, 0, 0, 0, 0, 0                               ; 0x49-0x4F
    times 0xB0 db 0                                      ; Rest - will add Norwegian when we find scancodes

scancode_shift_table:
    times 0x02 db 0
    db '!','@','#','$','%','^','&','*','(',')'          ; 0x02-0x0B (shifted numbers)
    db '_','+', 8, 0                                     ; 0x0C-0x0F
    db 'Q','W','E','R','T','Y','U','I','O','P'          ; 0x10-0x19 (uppercase)
    db '{','}', 10, 0                                    ; 0x1A-0x1D
    db 'A','S','D','F','G','H','J','K','L'              ; 0x1E-0x26 (uppercase)
    db ':', 34, 126, 0, 0                                ; 0x27-0x2B (colon, quote, tilde)
    db 'Z','X','C','V','B','N','M'                      ; 0x2C-0x32 (uppercase)
    db '<','>','?', 0, 0, 0                              ; 0x33-0x38
    db ' '                                               ; 0x39
    times 0xC7 db 0

; Print null-terminated string from RAX
print_string:
    push rax
    push rbx
    push rcx
    mov rbx, [cursor]
    mov rcx, rax        ; Use RCX for string pointer
.loop:
    mov al, [rcx]
    cmp al, 0           ; Explicit zero comparison
    je .done
    mov [rbx], al
    mov byte [rbx+1], 0x0E
    add rbx, 2
    inc rcx
    jmp .loop
.done:
    mov [cursor], rbx
    call update_hw_cursor
    pop rcx
    pop rbx
    pop rax
    ret

; Print null-terminated string in gray
print_string_gray:
    push rax
    push rbx
    push rcx
    mov rbx, [cursor]
    mov rcx, rax
.loop:
    mov al, [rcx]
    cmp al, 0
    je .done
    mov [rbx], al
    mov byte [rbx+1], 0x03      ; Dark cyan
    add rbx, 2
    inc rcx
    jmp .loop
.done:
    mov [cursor], rbx
    call update_hw_cursor
    pop rcx
    pop rbx
    pop rax
    ret

; REPL program: Jump to assembly REPL
test_program:
    dq REPL

; Interactive REPL in assembly
REPL:
    ; Initialize stacks (banner already shown during boot)
    ; R15 points one past last item, R14 holds TOS
    mov r15, [stack_floor]    ; Data stack base
    mov r14, 0              ; Top of stack (TOS) - empty initially
    mov rbp, 0x90000        ; Return stack (away from page tables at 0x70000) (grows down)

    ; Pre-allocate the shared out-of-memory string (heap cap fallback)
    mov rsi, str_oom
    call create_string_from_cstr
    mov [oom_object], rax

    ; Probe for an ATA drive once (real hardware may have none)
    call ata_detect

    ; Load embedded apps (defines editor, invaders words)
    call load_apps
    mov qword [app_loading], 0  ; Done loading, enable def source saving
    call word_clstk             ; Clear stack after loading apps
    jmp repl_main

; Recovery entry: exceptions reset all interpreter state and land here
repl_recover:
    mov rsp, 0x80000
    mov qword [stack_floor], data_stack
    mov r15, [stack_floor]
    xor r14, r14
    mov rbp, 0x90000
    mov byte [compile_mode], 0
    mov byte [array_mode], 0
    mov byte [ctl_items], 0
    mov qword [app_active], 0
    fninit

repl_main:
.main_loop:
    ; Print prompt
    mov rax, str_prompt
    call print_string

    ; Read line into buffer with editing support
    mov rdi, input_buffer
    xor rcx, rcx                    ; Character count
    mov qword [cursor_pos], 0       ; Cursor at start

.read_char:
    call wait_key                   ; Get character in RAX

    ; Handle extended keys (>= 256) on full RAX first, so their low
    ; byte can never alias ASCII (e.g. KEY_PGDN=264 has AL=8)
    cmp rax, KEY_DELETE             ; Delete key (scancode)
    je .handle_delete
    cmp rax, KEY_UP
    je .arrow_up
    cmp rax, KEY_DOWN
    je .arrow_down
    cmp rax, KEY_LEFT
    je .arrow_left
    cmp rax, KEY_RIGHT
    je .arrow_right
    cmp rax, 256                    ; Other extended keys: ignore
    jae .read_char

    cmp al, 10                      ; Enter?
    je .execute_line

    cmp al, 8                       ; Backspace?
    je .handle_backspace

    cmp al, 127                     ; Delete (ASCII)?
    je .handle_delete

    cmp al, 32                      ; Printable?
    jl .read_char                   ; Ignore other control chars

    ; Regular character - insert at cursor
    cmp rcx, 79                     ; Max line length?
    jge .read_char

    ; If cursor not at end, shift characters right
    mov r8, rcx
    cmp r8, [cursor_pos]
    je .insert_at_end

    ; Shift characters right from cursor position
    ; Start at last char (rcx-1), copy to rcx, work backwards
    mov rsi, input_buffer
    add rsi, rcx
    dec rsi                         ; rsi = last char position (rcx-1)
    mov rdi, rsi
    inc rdi                         ; rdi = one position right (rcx)
    mov r9, rcx
    sub r9, [cursor_pos]            ; Chars to shift
.shift_right:
    test r9, r9
    jz .shift_done
    mov bl, [rsi]
    mov [rdi], bl
    dec rsi
    dec rdi
    dec r9
    jmp .shift_right
.shift_done:

.insert_at_end:
    ; Store character at cursor position
    mov rsi, input_buffer
    add rsi, [cursor_pos]
    mov [rsi], al
    inc rcx                         ; Increase length

    ; Redraw from current position (before incrementing cursor)
    call redraw_line

    ; Now move cursor forward
    inc qword [cursor_pos]
    call update_cursor_display
    jmp .read_char

.handle_backspace:
    mov rax, [cursor_pos]
    test rax, rax
    jz .read_char                   ; At start, can't backspace

    ; Shift characters left
    mov rsi, input_buffer
    add rsi, [cursor_pos]
    mov rdi, rsi
    dec rdi
    mov r9, rcx
    sub r9, [cursor_pos]
.shift_left:
    test r9, r9
    jz .backspace_done
    mov bl, [rsi]
    mov [rdi], bl
    inc rsi
    inc rdi
    dec r9
    jmp .shift_left
.backspace_done:
    dec qword [cursor_pos]
    dec rcx
    ; Move cursor back, then redraw from cursor to end
    mov rbx, [cursor]
    sub rbx, 2
    mov [cursor], rbx
    call redraw_line
    jmp .read_char

.handle_delete:
    mov rax, [cursor_pos]
    cmp rax, rcx
    jge .read_char                  ; At end, nothing to delete
    ; Similar to backspace but don't move cursor back
    mov rsi, input_buffer
    add rsi, [cursor_pos]
    inc rsi
    mov rdi, rsi
    dec rdi
    mov r9, rcx
    sub r9, [cursor_pos]
    dec r9
.shift_del:
    test r9, r9
    jz .delete_done
    mov bl, [rsi]
    mov [rdi], bl
    inc rsi
    inc rdi
    dec r9
    jmp .shift_del
.delete_done:
    dec rcx
    call redraw_line
    jmp .read_char

.arrow_left:
    mov rax, [cursor_pos]
    test rax, rax
    jz .read_char
    dec qword [cursor_pos]
    call update_cursor_display
    jmp .read_char

.arrow_right:
    mov rax, [cursor_pos]
    cmp rax, rcx
    jge .read_char
    inc qword [cursor_pos]
    call update_cursor_display
    jmp .read_char

.arrow_up:
    ; Check if we can go back in history
    push rax
    mov rax, [history_index]
    test rax, rax
    pop rax
    jz .read_char                   ; Already at oldest or no history
    ; Clear BEFORE history_prev (while cursor_pos is still old value)
    call clear_current_line
    call history_prev
    ; Reload line from history
    mov rcx, [line_length]
    ; Reprint loaded line
    call reprint_line
    call update_hw_cursor           ; Sync hardware cursor
    jmp .read_char

.arrow_down:
    ; Check if we can go forward in history
    push rax
    mov rax, [history_index]
    cmp rax, [history_count]
    pop rax
    jge .read_char                  ; Already at newest
    ; Clear BEFORE history_next (while cursor_pos is still old value)
    call clear_current_line
    call history_next
    ; Reload line from history
    mov rcx, [line_length]
    ; Reprint loaded line
    call reprint_line
    call update_hw_cursor           ; Sync hardware cursor
    jmp .read_char

.execute_line:
    ; Null-terminate input FIRST (before saving to history)
    mov rsi, input_buffer
    add rsi, rcx
    mov byte [rsi], 0

    ; Save to history (now properly null-terminated)
    call save_to_history

    call newline

    ; Use interpret_line - no code duplication!
    mov rsi, input_buffer
    call interpret_line
    ; interpret_line returns success in RAX (1=ok, 0=error)
    test rax, rax
    jz .line_error

.line_done:
    mov rax, str_ok
    call print_string_gray
    call newline
    jmp .main_loop

.line_error:
    mov rax, str_unknown
    call print_string_gray
    call newline
    jmp .main_loop

; Helper functions for line editing
clear_current_line:
    ; Clear the current input line on screen
    push rax
    push rbx
    push rcx

    ; Go to start of line (after prompt)
    mov rbx, [cursor]
    ; Calculate how far back to go (cursor_pos * 2 for VGA)
    mov rax, [cursor_pos]
    shl rax, 1
    sub rbx, rax

    ; Clear 77 chars (leave room for prompt)
    mov rcx, 77
    mov ax, 0x0E20              ; Space
.clear:
    mov [rbx], ax
    add rbx, 2
    dec rcx
    jnz .clear

    ; Reset cursor to after prompt
    mov rbx, [cursor]
    mov rax, [cursor_pos]
    shl rax, 1
    sub rbx, rax
    mov [cursor], rbx

    pop rcx
    pop rbx
    pop rax
    ret

reprint_line:
    ; Reprint input_buffer content
    push rax
    push rcx
    push rsi

    mov rsi, input_buffer
    mov rcx, [line_length]
.print:
    test rcx, rcx
    jz .done
    lodsb
    call emit_char
    dec rcx
    jmp .print
.done:

    pop rsi
    pop rcx
    pop rax
    ret

redraw_line:
    ; Redraw from cursor position to end of line + clear trailing
    ; RCX = total line length, cursor_pos = where we are
    push rax
    push rbx
    push rcx
    push rsi

    ; Print characters from cursor_pos to end
    mov rsi, input_buffer
    add rsi, [cursor_pos]
    mov rbx, rcx
    sub rbx, [cursor_pos]           ; Characters to print
.print_loop:
    test rbx, rbx
    jz .print_done
    lodsb
    call emit_char
    dec rbx
    jmp .print_loop
.print_done:

    ; Clear one trailing character (in case we deleted)
    mov al, ' '
    call emit_char

    ; Move cursor back to correct position (one extra for the space we printed)
    mov rbx, rcx
    sub rbx, [cursor_pos]           ; How many chars we printed
    inc rbx                         ; Plus the trailing space
    shl rbx, 1                      ; Convert to VGA offset
    mov rax, [cursor]
    sub rax, rbx
    mov [cursor], rax
    call update_hw_cursor

    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

update_cursor_display:
    ; Move VGA cursor to match cursor_pos
    push rax
    push rbx
    push rcx
    push rdx

    ; Get current line position (cursor / 160 = row)
    mov rax, [cursor]
    sub rax, 0xB8000
    xor rdx, rdx
    mov rcx, 160                    ; Bytes per row (80 chars * 2)
    div rcx                         ; RAX = row

    ; Calculate new position: row * 160 + (2 + cursor_pos) * 2
    mov rcx, 160
    mul rcx                         ; RAX = row * 160
    mov rbx, [cursor_pos]
    add rbx, 2                      ; Add prompt length
    shl rbx, 1                      ; Convert to bytes (* 2)
    add rax, rbx                    ; RAX = byte offset
    add rax, 0xB8000                ; Add VGA base

    mov [cursor], rax
    call update_hw_cursor

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

save_to_history:
    ; Save current line to history buffer (circular, 10 entries)
    push rax
    push rbx
    push rcx
    push rsi
    push rdi

    ; Don't save empty lines
    test rcx, rcx
    jz .save_done

    ; Calculate offset in history buffer (count % 10) * 80
    mov rax, [history_count]
    xor rdx, rdx
    mov rbx, 10
    div rbx                         ; RDX = count % 10
    mov rax, rdx
    mov rbx, 80
    mul rbx                         ; RAX = offset in bytes
    mov rdi, history_buffer
    add rdi, rax

    ; Copy from input_buffer to history
    mov rsi, input_buffer
    mov rcx, 80
    rep movsb

    ; Increment history count
    inc qword [history_count]
    ; Reset history index to end
    mov rax, [history_count]
    mov [history_index], rax

.save_done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

history_prev:
    ; Load previous history entry (up arrow)
    push rax
    push rbx
    push rcx
    push rsi
    push rdi

    ; Check if we have history
    mov rax, [history_count]
    test rax, rax
    jz .prev_done

    ; Floor: only the last 10 entries exist (ring buffer)
    mov rbx, [history_count]
    sub rbx, 10
    jns .prev_have_floor
    xor rbx, rbx
.prev_have_floor:
    mov rax, [history_index]
    cmp rax, rbx
    jbe .prev_done                  ; At oldest retained entry

    ; Move to previous entry
    dec qword [history_index]

    ; Load that entry
    call load_history_entry

.prev_done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

history_next:
    ; Load next history entry (down arrow)
    push rax
    push rbx
    push rcx
    push rsi
    push rdi

    ; Check if we can go forward
    mov rax, [history_index]
    cmp rax, [history_count]
    jge .next_done                  ; At newest

    ; Move to next entry
    inc qword [history_index]

    ; If at end, clear line
    mov rax, [history_index]
    cmp rax, [history_count]
    je .clear_line

    ; Load that entry
    call load_history_entry
    jmp .next_done

.clear_line:
    ; Clear input buffer
    mov rdi, input_buffer
    mov rcx, 80
    xor rax, rax
    rep stosb
    ; Reset cursor_pos and length
    mov qword [cursor_pos], 0
    mov qword [line_length], 0

.next_done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

load_history_entry:
    ; Load history entry at history_index into input_buffer
    ; Modifies: input_buffer, cursor_pos, RCX in caller
    push rax
    push rbx
    push rsi
    push rdi

    ; Calculate offset: (index % 10) * 80
    mov rax, [history_index]
    xor rdx, rdx
    mov rbx, 10
    div rbx
    mov rax, rdx
    mov rbx, 80
    mul rbx

    ; Copy from history to input_buffer
    mov rsi, history_buffer
    add rsi, rax
    mov rdi, input_buffer
    mov rcx, 80
    rep movsb

    ; Calculate actual length
    mov rsi, input_buffer
    xor rcx, rcx
.find_len:
    cmp byte [rsi], 0
    je .len_found
    inc rsi
    inc rcx
    cmp rcx, 80
    jl .find_len
.len_found:
    ; Update cursor to end
    mov [cursor_pos], rcx
    ; Store length for caller to retrieve
    mov [line_length], rcx

    pop rdi
    pop rsi
    pop rbx
    pop rax
    ret

; Create STRING object from C string (RSI = null-terminated string)
; Returns object address in RAX
create_string_from_cstr:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Count string length
    mov rdi, rsi
    xor rcx, rcx
.count:
    cmp byte [rdi], 0
    je .counted
    inc rdi
    inc rcx
    jmp .count
.counted:

    ; Allocate object
    push rcx
    push rsi
    add rcx, 17             ; Header + null
    call allocate_object
    pop rsi
    pop rcx

    ; Fill header
    mov qword [rax], TYPE_STRING
    mov [rax+8], rcx

    ; Copy string
    lea rdi, [rax+16]
.copy:
    mov bl, [rsi]
    mov [rdi], bl
    test bl, bl
    jz .done
    inc rsi
    inc rdi
    jmp .copy
.done:

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Get or create named variable (RDI=name, RCX=length)
; Returns address of value slot in RAX
get_or_create_named_var:
    ; Input: RDI = name pointer, RCX = name length
    ; Returns: RAX = address of value slot
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    mov r8, rdi             ; R8 = name pointer
    mov r9, rcx             ; R9 = name length

    ; Search existing variables
    mov rsi, named_vars
    mov rax, [named_var_count]
    shl rax, 4              ; Each entry is 16 bytes
    add rax, named_vars     ; End marker

.search_loop:
    cmp rsi, rax
    jge .not_found

    ; Get name STRING from this slot
    mov rbx, [rsi]
    test rbx, rbx
    jz .not_found

    ; Compare lengths first
    cmp r9, [rbx+8]         ; Compare with STRING length
    jne .next_entry

    ; Compare name bytes
    push rsi
    push rcx
    push r8                 ; Save search name ptr
    push r9                 ; Save length
    push rax                ; Save end marker (RAX gets corrupted by byte compare)

    lea rbx, [rbx+16]       ; String data
    mov rdi, r8             ; Name to find
    mov rcx, r9             ; Length
.cmp_loop:
    test rcx, rcx
    jz .names_match
    mov al, [rbx]
    cmp al, [rdi]
    jne .names_differ
    inc rbx
    inc rdi
    dec rcx
    jmp .cmp_loop
.names_differ:
    pop rax                 ; Restore end marker
    pop r9
    pop r8
    pop rcx
    pop rsi
.next_entry:
    add rsi, 16             ; Next entry
    jmp .search_loop
.names_match:
    pop rax                 ; Restore end marker
    pop r9
    pop r8
    pop rcx
    pop rsi
    jmp .found

.not_found:
    ; Create new entry
    mov rsi, [named_var_count]
    shl rsi, 4
    add rsi, named_vars

    ; Create name STRING with known length
    push rsi
    mov rcx, r9             ; Length
    add rcx, 17             ; Header (16) + null (1)
    call allocate_object
    mov qword [rax], TYPE_STRING
    mov [rax+8], r9         ; Store length

    ; Copy name bytes
    lea rdi, [rax+16]
    mov rsi, r8             ; Source = name
    mov rcx, r9             ; Length
    rep movsb
    mov byte [rdi], 0       ; Null terminate

    pop rsi                 ; Restore slot pointer
    mov [rsi], rax          ; Store STRING pointer

    ; Initialize value to 0
    mov qword [rsi+8], 0

    ; Increment count
    inc qword [named_var_count]

.found:
    ; Return address of value slot
    lea rax, [rsi+8]

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; Allocate object (RCX = total size in bytes)
; Returns address in RAX
allocate_object:
    ; RCX = bytes wanted, RAX = address out. Freed blocks are reused
    ; first-fit; otherwise bump-allocate (pages map on demand).
    push rbx
    push rcx
    push rsi
    push rdi

    ; Round request to 16
    add rcx, 15
    and rcx, ~15

    ; First fit from the free list
    mov rsi, free_list          ; RSI = address of link to current
    mov rax, [free_list]
.alloc_scan:
    test rax, rax
    jz .alloc_bump
    cmp [rax], rcx              ; block size >= wanted?
    jae .alloc_take
    lea rsi, [rax+8]
    mov rax, [rax+8]
    jmp .alloc_scan
.alloc_take:
    mov rdi, [rax+8]            ; unlink
    mov [rsi], rdi
    jmp .alloc_out

.alloc_bump:
    mov rax, [heap_ptr]
    add rax, 15
    and rax, ~15
    lea rbx, [rax + rcx]
    cmp rbx, HEAP_MAX
    jae .alloc_oom
    mov [heap_ptr], rbx

.alloc_out:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

.alloc_oom:
    mov rax, [oom_object]
    jmp .alloc_out

free_list: dq 0                 ; Freed blocks: [size:8][next:8]

; DOCOL - Marker for colon-defined words (not executable code)
; Why: Distinguishes user definitions from built-in words
; Code field contains DOCOL, followed by definition body
; Execution handled by .dict_word in REPL, not by calling this
DOCOL:
    ; Get address of this call (return address on stack)
    pop rsi                 ; Return address = start of definition body

    ; Execute each word until EXIT
.exec_loop:
    lodsq                   ; Load next word address
    cmp rax, EXIT
    je .done

    ; Check if it's LIT
    cmp rax, LIT
    jne .not_lit
    lodsq                   ; Get literal value
    mov [r15], r14          ; Save old TOS to memory
    add r15, 8
    mov r14, rax            ; New value becomes TOS
    jmp .exec_loop

.not_lit:
    ; Check for BRANCH (unconditional jump)
    cmp rax, BRANCH
    jne .not_branch
    lodsq                   ; Get offset
    add rsi, rax            ; Jump
    jmp .exec_loop

.not_branch:
    ; Check for ZBRANCH (branch if zero)
    cmp rax, ZBRANCH
    jne .do_call
    lodsq                   ; Get offset
    mov rbx, r14            ; Get TOS
    ; Pop TOS using R14/R15 convention
    sub r15, 8
    cmp r15, [stack_floor]
    jl .zbranch_empty_docol ; Use jl not jle - R15==data_stack means valid element at [R15]
    mov r14, [r15]          ; After sub, old second-on-stack is at [r15]
    jmp .zbranch_test
.zbranch_empty_docol:
    mov r15, [stack_floor]
    xor r14, r14
.zbranch_test:
    test rbx, rbx
    jnz .exec_loop          ; Non-zero, don't branch
    add rsi, rax            ; Zero, take branch
    jmp .exec_loop

.do_call:
    ; Call the word
    call rax
    jmp .exec_loop

.done:
    ret

; EXIT - Just a marker, not executed
EXIT:
    ret

; Create dictionary entry for new word
create_dict_entry:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Bounds: entry = link+len+name+align+DOCOL+code+EXIT (<= code+64)
    mov rax, [compile_ptr]
    sub rax, compile_buffer
    add rax, [dict_here]
    add rax, 64
    cmp rax, DICT_END
    jae .dict_full

    mov rdi, [dict_here]
    mov r8, rdi             ; Save entry start in R8 (not RAX!)

    ; Store link to previous entry
    mov rbx, [dict_latest]
    mov [rdi], rbx
    add rdi, 8

    ; Store name length
    mov rsi, new_word_name
    xor rcx, rcx
.count:
    cmp byte [rsi + rcx], 0
    je .name_done
    inc rcx
    jmp .count
.name_done:
    mov [rdi], cl
    inc rdi

    ; Store name
    mov rsi, new_word_name
    rep movsb

    ; Align to 8 bytes
    mov rax, rdi
    and rax, 7
    test rax, rax
    jz .aligned
    add rdi, 8
    and rdi, ~7
.aligned:

    ; Store code pointer (DOCOL)
    mov qword [rdi], DOCOL
    add rdi, 8

    ; Copy compiled code from compile_buffer
    mov rsi, compile_buffer
    mov rcx, [compile_ptr]
    sub rcx, compile_buffer
    shr rcx, 3              ; Divide by 8 (qwords)
    rep movsq

    ; Store EXIT at end
    mov qword [rdi], EXIT
    add rdi, 8

    ; Update dict_here (next free space)
    mov [dict_here], rdi

    ; Update dict_latest (this entry's start - saved in R8)
    mov [dict_latest], r8

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

.dict_full:
    mov rax, str_dict_full
    call print_string
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

str_dict_full: db '(dictionary full)', 13, 10, 0

; Helper: Print newline
newline:
    push rax
    mov rbx, [cursor]
    sub rbx, 0xB8000
    shr rbx, 1
    mov rax, rbx
    xor rdx, rdx
    mov rcx, 80
    div rcx
    inc rax
    xor rdx, rdx
    mul rcx
    shl rax, 1
    add rax, 0xB8000
    mov [cursor], rax
    call update_hw_cursor
    pop rax
    ret

; Skip spaces in buffer pointed by RSI
skip_spaces:
    push rax
.loop:
    mov al, [rsi]
    cmp al, ' '
    jne .done
    inc rsi
    jmp .loop
.done:
    pop rax
    ret

; Parse word from RSI, return start in RDI, length in RCX, advance RSI
parse_word:
    push rax
    mov rdi, rsi            ; Start of word
    xor rcx, rcx            ; Length
.loop:
    mov al, [rsi]
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    inc rsi
    inc rcx
    jmp .loop
.done:
    pop rax
    ret

; Check if word is a number (all digits), returns 1 in RAX if yes
is_number:
    push rbx
    push rcx
    push rdi

    test rcx, rcx
    jz .not_number

    mov rbx, rdi

    ; Check for leading minus sign
    mov al, [rbx]
    cmp al, '-'
    jne .check_loop
    inc rbx
    dec rcx
    jz .not_number              ; Just "-" is not a number

.check_loop:
    mov al, [rbx]
    cmp al, '0'
    jl .not_number
    cmp al, '9'
    jg .not_number
    inc rbx
    dec rcx
    jnz .check_loop

    mov rax, 1
    jmp .done

.not_number:
    xor rax, rax

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

; Parse number from word (RDI, RCX) into RAX
parse_number:
    push rbx
    push rcx
    push rdi
    push r9

    xor rax, rax            ; Result
    mov rbx, 10             ; Base
    xor r9, r9              ; Negative flag

    ; Check for leading minus
    cmp byte [rdi], '-'
    jne .loop
    mov r9, 1               ; Set negative flag
    inc rdi
    dec rcx

.loop:
    movzx r8, byte [rdi]
    sub r8, '0'
    imul rax, rbx
    add rax, r8
    inc rdi
    dec rcx
    jnz .loop

    ; Negate if needed
    test r9, r9
    jz .parse_done
    neg rax

.parse_done:
    pop r9
    pop rdi
    pop rcx
    pop rbx
    ret

; Search dictionary for word (RDI=name, RCX=length)
; Returns code address in RAX, or 0 if not found
search_dictionary:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Start at latest entry
    mov rsi, [dict_latest]
    test rsi, rsi
    jz .not_found           ; Empty dictionary (dict_latest = 0)

.search_loop:
    ; RSI points to start of entry (link field)

    ; Save link for later
    mov r8, [rsi]           ; R8 = link to previous entry

    ; Skip link pointer
    add rsi, 8

    ; Check name length
    movzx rbx, byte [rsi]
    inc rsi
    cmp rbx, rcx
    jne .next_entry

    ; Compare names character by character
    push rsi
    push rdi
    push rcx
.cmp_loop:
    mov al, [rdi]
    mov bl, [rsi]
    cmp al, bl
    jne .name_mismatch
    inc rdi
    inc rsi
    dec rcx
    jnz .cmp_loop

    ; Match! RSI now points right after name
    pop rcx
    pop rdi
    pop rsi

    ; Skip name bytes
    add rsi, rcx

    ; Align to 8 bytes to find code pointer
    mov rax, rsi
    and rax, 7
    test rax, rax
    jz .already_aligned
    add rsi, 8
    and rsi, ~7
.already_aligned:

    ; Return address of code field
    mov rax, rsi
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

.name_mismatch:
    pop rcx
    pop rdi
    pop rsi

.next_entry:
    ; Follow link to previous entry
    mov rsi, r8             ; R8 has the link we saved earlier
    test rsi, rsi
    jz .not_found           ; No more entries (link = 0)
    jmp .search_loop

.not_found:
    xor rax, rax
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Lookup word, return address in RAX (0 if not found)
lookup_word:
    push rbx
    push rcx
    push rdi
    push rsi

    ; Convert word to lowercase for case-insensitive matching
    push rdi
    push rcx
    mov rbx, rdi
.lower_loop:
    mov al, [rbx]
    cmp al, 'A'
    jl .next_char
    cmp al, 'Z'
    jg .next_char
    add byte [rbx], 32      ; Convert to lowercase
.next_char:
    inc rbx
    dec rcx
    jnz .lower_loop
    pop rcx
    pop rdi

    ; Search dictionary first
    call search_dictionary
    test rax, rax
    jz .not_in_dict

    ; Found in dictionary - return it
    jmp .done

.not_in_dict:

    ; Float words: s>f plus everything starting with 'f'
    call match_float_word
    test rax, rax
    jnz .done

    ; Check single-char operators first
    cmp rcx, 1
    jne .check_multi

    mov al, [rdi]
    cmp al, '+'
    je .found_plus
    cmp al, '-'
    je .found_minus
    cmp al, '*'
    je .found_mult
    cmp al, '/'
    je .found_div
    cmp al, '.'
    je .found_dot
    cmp al, ':'
    je .found_colon
    cmp al, ';'
    je .found_semi
    cmp al, '@'
    je .found_fetch
    cmp al, '!'
    je .found_store
    cmp al, '?'
    je .found_inspect
    cmp al, '='
    je .found_eq
    cmp al, '<'
    je .found_lt
    cmp al, '>'
    je .found_gt

    jmp .check_multi

.found_plus:
    mov rax, word_plus
    jmp .done
.found_minus:
    mov rax, word_minus
    jmp .done
.found_mult:
    mov rax, word_mult
    jmp .done
.found_div:
    mov rax, word_div
    jmp .done
.found_dot:
    mov rax, word_dot
    jmp .done
.found_colon:
    mov rax, word_colon
    jmp .done
.found_semi:
    mov rax, word_semi
    jmp .done_immediate    ; ';' is IMMEDIATE - must execute during compile mode
.found_fetch:
    mov rax, word_fetch
    jmp .done
.found_store:
    mov rax, word_store
    jmp .done
.found_inspect:
    mov rax, word_inspect
    jmp .done
.found_eq:
    mov rax, word_eq
    jmp .done
.found_lt:
    mov rax, word_lt
    jmp .done
.found_gt:
    mov rax, word_gt
    jmp .done

.check_multi:
    ; Check multi-char words
    ; .S (stack display)
    cmp rcx, 2
    jne .try_dup
    cmp byte [rdi], '.'
    jne .try_c_fetch
    cmp byte [rdi+1], 's'
    jne .try_c_fetch
    mov rax, word_dots
    jmp .done

.try_c_fetch:
    ; c@ (char fetch, 2 chars)
    cmp byte [rdi], 'c'
    jne .try_c_store
    cmp byte [rdi+1], '@'
    jne .try_c_store
    mov rax, word_c_fetch
    jmp .done

.try_c_store:
    ; c! (char store, 2 chars)
    cmp byte [rdi], 'c'
    jne .try_dup
    cmp byte [rdi+1], '!'
    jne .try_dup
    mov rax, word_c_store
    jmp .done

.try_dup:
    ; DUP
    cmp rcx, 3
    jne .try_drop
    cmp byte [rdi], 'd'
    jne .try_drop
    cmp byte [rdi+1], 'u'
    jne .try_drop
    cmp byte [rdi+2], 'p'
    jne .try_drop
    mov rax, word_dup
    jmp .done

.try_drop:
    cmp rcx, 4
    jne .try_clstk
    cmp byte [rdi], 'd'
    jne .try_clstk
    cmp byte [rdi+1], 'r'
    jne .try_clstk
    cmp byte [rdi+2], 'o'
    jne .try_clstk
    cmp byte [rdi+3], 'p'
    jne .try_clstk
    mov rax, word_drop
    jmp .done

.try_clstk:
    ; clstk (5 chars)
    cmp rcx, 5
    jne .try_varcount
    cmp byte [rdi], 'c'
    jne .try_varcount
    cmp byte [rdi+1], 'l'
    jne .try_varcount
    cmp byte [rdi+2], 's'
    jne .try_varcount
    cmp byte [rdi+3], 't'
    jne .try_varcount
    cmp byte [rdi+4], 'k'
    jne .try_varcount
    mov rax, word_clstk
    jmp .done

.try_varcount:
    ; varcount (8 chars)
    cmp rcx, 8
    jne .try_vars
    cmp byte [rdi], 'v'
    jne .try_vars
    cmp byte [rdi+1], 'a'
    jne .try_vars
    cmp byte [rdi+2], 'r'
    jne .try_vars
    cmp byte [rdi+3], 'c'
    jne .try_vars
    cmp byte [rdi+4], 'o'
    jne .try_vars
    cmp byte [rdi+5], 'u'
    jne .try_vars
    cmp byte [rdi+6], 'n'
    jne .try_vars
    cmp byte [rdi+7], 't'
    jne .try_vars
    mov rax, word_varcount
    jmp .done

.try_vars:
    ; vars (4 chars)
    cmp rcx, 4
    jne .try_swap
    cmp byte [rdi], 'v'
    jne .try_swap
    cmp byte [rdi+1], 'a'
    jne .try_swap
    cmp byte [rdi+2], 'r'
    jne .try_swap
    cmp byte [rdi+3], 's'
    jne .try_swap
    mov rax, word_vars
    jmp .done

.try_swap:
    cmp rcx, 4
    jne .try_over
    cmp byte [rdi], 's'
    jne .try_over
    cmp byte [rdi+1], 'w'
    jne .try_over
    cmp byte [rdi+2], 'a'
    jne .try_over
    cmp byte [rdi+3], 'p'
    jne .try_over
    mov rax, word_swap
    jmp .done

.try_over:
    cmp rcx, 4
    jne .try_emit
    cmp byte [rdi], 'o'
    jne .try_emit
    cmp byte [rdi+1], 'v'
    jne .try_emit
    cmp byte [rdi+2], 'e'
    jne .try_emit
    cmp byte [rdi+3], 'r'
    jne .try_emit
    mov rax, word_over
    jmp .done

.try_emit:
    cmp rcx, 4
    jne .try_rot
    cmp byte [rdi], 'e'
    jne .try_rot
    cmp byte [rdi+1], 'm'
    jne .try_rot
    cmp byte [rdi+2], 'i'
    jne .try_rot
    cmp byte [rdi+3], 't'
    jne .try_rot
    mov rax, word_emit
    jmp .done

.try_rot:
    cmp rcx, 3
    jne .try_cr
    cmp byte [rdi], 'r'
    jne .try_cr
    cmp byte [rdi+1], 'o'
    jne .try_cr
    cmp byte [rdi+2], 't'
    jne .try_cr
    mov rax, word_rot
    jmp .done

.try_cr:
    cmp rcx, 2
    jne .try_exit
    cmp byte [rdi], 'c'
    jne .try_exit
    cmp byte [rdi+1], 'r'
    jne .try_exit
    mov rax, word_cr
    jmp .done

.try_exit:
    cmp rcx, 4
    jne .try_words
    cmp byte [rdi], 'e'
    jne .try_words
    cmp byte [rdi+1], 'x'
    jne .try_words
    cmp byte [rdi+2], 'i'
    jne .try_words
    cmp byte [rdi+3], 't'
    jne .try_words
    mov rax, word_exit
    jmp .done

.try_words:
    cmp rcx, 5
    jne .try_define
    cmp byte [rdi], 'w'
    jne .try_allot
    cmp byte [rdi+1], 'o'
    jne .try_allot
    cmp byte [rdi+2], 'r'
    jne .try_allot
    cmp byte [rdi+3], 'd'
    jne .try_allot
    cmp byte [rdi+4], 's'
    jne .try_allot
    mov rax, word_words
    jmp .done

.try_allot:
    ; allot (5 chars)
    cmp byte [rdi], 'a'
    jne .try_define
    cmp byte [rdi+1], 'l'
    jne .try_define
    cmp byte [rdi+2], 'l'
    jne .try_define
    cmp byte [rdi+3], 'o'
    jne .try_define
    cmp byte [rdi+4], 't'
    jne .try_define
    mov rax, word_allot
    jmp .done

.try_define:
    cmp rcx, 6
    jne .try_forget
    cmp byte [rdi], 'd'
    jne .try_forget
    cmp byte [rdi+1], 'e'
    jne .try_forget
    cmp byte [rdi+2], 'f'
    jne .try_forget
    cmp byte [rdi+3], 'i'
    jne .try_forget
    cmp byte [rdi+4], 'n'
    jne .try_forget
    cmp byte [rdi+5], 'e'
    jne .try_forget
    mov rax, word_define
    jmp .done

.try_forget:
    cmp rcx, 6
    jne .try_execute
    cmp byte [rdi], 'f'
    jne .try_execute
    cmp byte [rdi+1], 'o'
    jne .try_execute
    cmp byte [rdi+2], 'r'
    jne .try_execute
    cmp byte [rdi+3], 'g'
    jne .try_execute
    cmp byte [rdi+4], 'e'
    jne .try_execute
    cmp byte [rdi+5], 't'
    jne .try_execute
    mov rax, word_forget
    jmp .done

.try_execute:
    cmp rcx, 7
    jne .try_array
    cmp byte [rdi], 'e'
    jne .try_see
    cmp byte [rdi+1], 'x'
    jne .try_see
    cmp byte [rdi+2], 'e'
    jne .try_see
    cmp byte [rdi+3], 'c'
    jne .try_see
    cmp byte [rdi+4], 'u'
    jne .try_see
    cmp byte [rdi+5], 't'
    jne .try_see
    cmp byte [rdi+6], 'e'
    jne .try_array
    mov rax, word_execute
    jmp .done

.try_array:
    cmp rcx, 5
    jne .try_at
    cmp byte [rdi], 'a'
    jne .try_at
    cmp byte [rdi+1], 'r'
    jne .try_at
    cmp byte [rdi+2], 'r'
    jne .try_at
    cmp byte [rdi+3], 'a'
    jne .try_at
    cmp byte [rdi+4], 'y'
    jne .try_at
    mov rax, word_array
    jmp .done

.try_at:
    cmp rcx, 2
    jne .try_put
    cmp byte [rdi], 'a'
    jne .try_put
    cmp byte [rdi+1], 't'
    jne .try_put
    mov rax, word_at
    jmp .done

.try_put:
    cmp rcx, 3
    jne .try_free
    cmp byte [rdi], 'p'
    jne .try_free
    cmp byte [rdi+1], 'u'
    jne .try_free
    cmp byte [rdi+2], 't'
    jne .try_free
    mov rax, word_put
    jmp .done

.try_free:
    cmp rcx, 4
    jne .try_cursor
    cmp byte [rdi], 'f'
    jne .try_see
    cmp byte [rdi+1], 'r'
    jne .try_see
    cmp byte [rdi+2], 'e'
    jne .try_see
    cmp byte [rdi+3], 'e'
    jne .try_cursor
    mov rax, word_free
    jmp .done

.try_cursor:
    ; cursor-hide (11) or cursor-show (11)
    cmp rcx, 11
    jne .try_screen_get
    cmp byte [rdi], 'c'
    jne .try_screen_get
    cmp byte [rdi+6], '-'
    jne .try_screen_get
    cmp byte [rdi+7], 'h'
    je .is_cursor_hide
    cmp byte [rdi+7], 's'
    je .is_cursor_show
    jmp .try_screen_get
.is_cursor_hide:
    mov rax, word_cursor_hide
    jmp .done
.is_cursor_show:
    mov rax, word_cursor_show
    jmp .done

.try_screen_get:
    ; Check if word starts with "screen-" (7 chars)
    cmp rcx, 10
    jl .try_see              ; Too short to be screen-*
    cmp byte [rdi], 's'
    jne .try_see
    cmp byte [rdi+1], 'c'
    jne .try_see
    cmp byte [rdi+2], 'r'
    jne .try_see
    cmp byte [rdi+3], 'e'
    jne .try_see
    cmp byte [rdi+4], 'e'
    jne .try_see
    cmp byte [rdi+5], 'n'
    jne .try_see
    cmp byte [rdi+6], '-'
    jne .try_see

    ; Has screen- prefix, check which variant
    cmp rcx, 10
    je .check_screen_get_set
    cmp rcx, 11
    je .check_screen_char
    cmp rcx, 12
    je .check_screen_clear
    cmp rcx, 13
    je .check_screen_scroll
    cmp rcx, 17
    je .check_screen_line_shift
    jmp .try_see             ; Unknown screen-* length

.check_screen_get_set:
    ; Could be screen-get or screen-set (both 10 chars)
    cmp byte [rdi+7], 'g'
    je .is_screen_get
    cmp byte [rdi+7], 's'
    jne .try_see
    cmp byte [rdi+8], 'e'
    jne .try_see
    cmp byte [rdi+9], 't'
    jne .try_see
    mov rax, word_screen_set
    jmp .done

.is_screen_get:
    cmp byte [rdi+8], 'e'
    jne .try_see
    cmp byte [rdi+9], 't'
    jne .try_see
    mov rax, word_screen_get
    jmp .done

.check_screen_char:
    ; screen-char (11 chars)
    cmp byte [rdi+7], 'c'
    jne .try_see
    cmp byte [rdi+8], 'h'
    jne .try_see
    cmp byte [rdi+9], 'a'
    jne .try_see
    cmp byte [rdi+10], 'r'
    jne .try_see
    mov rax, word_screen_char
    jmp .done

.check_screen_clear:
    ; screen-clear (12 chars)
    cmp byte [rdi+7], 'c'
    jne .try_see
    cmp byte [rdi+8], 'l'
    jne .try_see
    cmp byte [rdi+9], 'e'
    jne .try_see
    cmp byte [rdi+10], 'a'
    jne .try_see
    cmp byte [rdi+11], 'r'
    jne .try_see
    mov rax, word_screen_clear
    jmp .done

.check_screen_scroll:
    ; screen-scroll (13 chars)
    cmp byte [rdi+7], 's'
    jne .try_see
    cmp byte [rdi+8], 'c'
    jne .try_see
    cmp byte [rdi+9], 'r'
    jne .try_see
    cmp byte [rdi+10], 'o'
    jne .try_see
    cmp byte [rdi+11], 'l'
    jne .try_see
    cmp byte [rdi+12], 'l'
    jne .try_see
    mov rax, word_screen_scroll
    jmp .done

.check_screen_line_shift:
    ; screen-line-shift (17 chars)
    cmp byte [rdi+7], 'l'
    jne .try_see
    cmp byte [rdi+8], 'i'
    jne .try_see
    cmp byte [rdi+9], 'n'
    jne .try_see
    cmp byte [rdi+10], 'e'
    jne .try_see
    cmp byte [rdi+11], '-'
    jne .try_see
    cmp byte [rdi+12], 's'
    jne .try_see
    cmp byte [rdi+13], 'h'
    jne .try_see
    cmp byte [rdi+14], 'i'
    jne .try_see
    cmp byte [rdi+15], 'f'
    jne .try_see
    cmp byte [rdi+16], 't'
    jne .try_see
    mov rax, word_screen_line_shift
    jmp .done

.try_see:
    cmp rcx, 3
    jne .try_len
    cmp byte [rdi], 's'
    jne .try_len
    cmp byte [rdi+1], 'e'
    jne .try_len
    cmp byte [rdi+2], 'e'
    jne .try_len
    mov rax, word_see
    jmp .done

.try_len:
    cmp rcx, 3
    jne .try_str_eq
    cmp byte [rdi], 'l'
    jne .try_str_eq
    cmp byte [rdi+1], 'e'
    jne .try_str_eq
    cmp byte [rdi+2], 'n'
    jne .try_str_eq
    mov rax, word_len
    jmp .done

.try_str_eq:
    ; str= (4 chars) - compare two strings
    cmp rcx, 4
    jne .try_type
    cmp byte [rdi], 's'
    jne .try_type
    cmp byte [rdi+1], 't'
    jne .try_type
    cmp byte [rdi+2], 'r'
    jne .try_type
    cmp byte [rdi+3], '='
    jne .try_type
    mov rax, word_str_eq
    jmp .done

.try_type:
    cmp rcx, 4
    jne .try_type_new
    cmp byte [rdi], 't'
    jne .try_type_new
    cmp byte [rdi+1], 'y'
    jne .try_type_new
    cmp byte [rdi+2], 'p'
    jne .try_type_new
    cmp byte [rdi+3], 'e'
    jne .try_type_new
    mov rax, word_type
    jmp .done

.try_type_new:
    ; type-new (8 chars)
    cmp rcx, 8
    jne .try_type_name
    cmp byte [rdi], 't'
    jne .try_type_name
    cmp byte [rdi+1], 'y'
    jne .try_type_name
    cmp byte [rdi+2], 'p'
    jne .try_type_name
    cmp byte [rdi+3], 'e'
    jne .try_type_name
    cmp byte [rdi+4], '-'
    jne .try_type_name
    cmp byte [rdi+5], 'n'
    jne .try_type_name
    cmp byte [rdi+6], 'e'
    jne .try_type_name
    cmp byte [rdi+7], 'w'
    jne .try_type_name
    mov rax, word_type_new
    jmp .done

.try_type_name:
    ; type-name (9 chars)
    cmp rcx, 9
    jne .try_type_set
    cmp byte [rdi], 't'
    jne .try_type_set
    cmp byte [rdi+1], 'y'
    jne .try_type_set
    cmp byte [rdi+2], 'p'
    jne .try_type_set
    cmp byte [rdi+3], 'e'
    jne .try_type_set
    cmp byte [rdi+4], '-'
    jne .try_type_set
    cmp byte [rdi+5], 'n'
    jne .try_type_set
    cmp byte [rdi+6], 'a'
    jne .try_type_set
    cmp byte [rdi+7], 'm'
    jne .try_type_set
    cmp byte [rdi+8], 'e'
    jne .try_type_set
    mov rax, word_type_name
    jmp .done

.try_type_set:
    ; type-set (8 chars)
    cmp rcx, 8
    jne .try_type_name_get
    cmp byte [rdi], 't'
    jne .try_type_name_get
    cmp byte [rdi+1], 'y'
    jne .try_type_name_get
    cmp byte [rdi+2], 'p'
    jne .try_type_name_get
    cmp byte [rdi+3], 'e'
    jne .try_type_name_get
    cmp byte [rdi+4], '-'
    jne .try_type_name_get
    cmp byte [rdi+5], 's'
    jne .try_type_name_get
    cmp byte [rdi+6], 'e'
    jne .try_type_name_get
    cmp byte [rdi+7], 't'
    jne .try_type_name_get
    mov rax, word_type_set
    jmp .done

.try_type_name_get:
    ; type-name? (10 chars)
    cmp rcx, 10
    jne .try_key
    cmp byte [rdi], 't'
    jne .try_key
    cmp byte [rdi+1], 'y'
    jne .try_key
    cmp byte [rdi+2], 'p'
    jne .try_key
    cmp byte [rdi+3], 'e'
    jne .try_key
    cmp byte [rdi+4], '-'
    jne .try_key
    cmp byte [rdi+5], 'n'
    jne .try_key
    cmp byte [rdi+6], 'a'
    jne .try_key
    cmp byte [rdi+7], 'm'
    jne .try_key
    cmp byte [rdi+8], 'e'
    jne .try_key
    cmp byte [rdi+9], '?'
    jne .try_key
    mov rax, word_type_name_get
    jmp .done

.try_key:
    ; key (3 chars)
    cmp rcx, 3
    jne .try_key_check
    cmp byte [rdi], 'k'
    jne .try_key_check
    cmp byte [rdi+1], 'e'
    jne .try_key_check
    cmp byte [rdi+2], 'y'
    jne .try_key_check
    mov rax, word_key
    jmp .done

.try_key_check:
    ; key? (4 chars)
    cmp rcx, 4
    jne .try_key_escape
    cmp byte [rdi], 'k'
    jne .try_key_escape
    cmp byte [rdi+1], 'e'
    jne .try_key_escape
    cmp byte [rdi+2], 'y'
    jne .try_key_escape
    cmp byte [rdi+3], '?'
    jne .try_key_escape
    mov rax, word_key_check
    jmp .done

.try_key_escape:
    ; key-escape (10 chars)
    cmp rcx, 10
    jne .try_key_up
    cmp byte [rdi], 'k'
    jne .try_key_up
    cmp byte [rdi+1], 'e'
    jne .try_key_up
    cmp byte [rdi+2], 'y'
    jne .try_key_up
    cmp byte [rdi+3], '-'
    jne .try_key_up
    cmp byte [rdi+4], 'e'
    jne .try_key_up
    cmp byte [rdi+5], 's'
    jne .try_key_up
    cmp byte [rdi+6], 'c'
    jne .try_key_up
    cmp byte [rdi+7], 'a'
    jne .try_key_up
    cmp byte [rdi+8], 'p'
    jne .try_key_up
    cmp byte [rdi+9], 'e'
    jne .try_key_up
    mov rax, word_key_escape
    jmp .done

.try_key_up:
    ; key-up (6 chars)
    cmp rcx, 6
    jne .try_key_down
    cmp byte [rdi], 'k'
    jne .try_key_down
    cmp byte [rdi+1], 'e'
    jne .try_key_down
    cmp byte [rdi+2], 'y'
    jne .try_key_down
    cmp byte [rdi+3], '-'
    jne .try_key_down
    cmp byte [rdi+4], 'u'
    jne .try_key_down
    cmp byte [rdi+5], 'p'
    jne .try_key_down
    mov rax, word_key_up
    jmp .done

.try_key_down:
    ; key-down (8 chars)
    cmp rcx, 8
    jne .try_key_left
    cmp byte [rdi], 'k'
    jne .try_key_left
    cmp byte [rdi+1], 'e'
    jne .try_key_left
    cmp byte [rdi+2], 'y'
    jne .try_key_left
    cmp byte [rdi+3], '-'
    jne .try_key_left
    cmp byte [rdi+4], 'd'
    jne .try_key_left
    cmp byte [rdi+5], 'o'
    jne .try_key_left
    cmp byte [rdi+6], 'w'
    jne .try_key_left
    cmp byte [rdi+7], 'n'
    jne .try_key_left
    mov rax, word_key_down
    jmp .done

.try_key_left:
    ; key-left (8 chars)
    cmp rcx, 8
    jne .try_key_right
    cmp byte [rdi], 'k'
    jne .try_key_right
    cmp byte [rdi+1], 'e'
    jne .try_key_right
    cmp byte [rdi+2], 'y'
    jne .try_key_right
    cmp byte [rdi+3], '-'
    jne .try_key_right
    cmp byte [rdi+4], 'l'
    jne .try_key_right
    cmp byte [rdi+5], 'e'
    jne .try_key_right
    cmp byte [rdi+6], 'f'
    jne .try_key_right
    cmp byte [rdi+7], 't'
    jne .try_key_right
    mov rax, word_key_left
    jmp .done

.try_key_right:
    ; key-right (9 chars)
    cmp rcx, 9
    jne .try_key_delete
    cmp byte [rdi], 'k'
    jne .try_key_delete
    cmp byte [rdi+1], 'e'
    jne .try_key_delete
    cmp byte [rdi+2], 'y'
    jne .try_key_delete
    cmp byte [rdi+3], '-'
    jne .try_key_delete
    cmp byte [rdi+4], 'r'
    jne .try_key_delete
    cmp byte [rdi+5], 'i'
    jne .try_key_delete
    cmp byte [rdi+6], 'g'
    jne .try_key_delete
    cmp byte [rdi+7], 'h'
    jne .try_key_delete
    cmp byte [rdi+8], 't'
    jne .try_key_delete
    mov rax, word_key_right
    jmp .done

.try_key_delete:
    ; key-delete (10 chars)
    cmp rcx, 10
    jne .try_key_backspace
    cmp byte [rdi], 'k'
    jne .try_key_backspace
    cmp byte [rdi+1], 'e'
    jne .try_key_backspace
    cmp byte [rdi+2], 'y'
    jne .try_key_backspace
    cmp byte [rdi+3], '-'
    jne .try_key_backspace
    cmp byte [rdi+4], 'd'
    jne .try_key_backspace
    cmp byte [rdi+5], 'e'
    jne .try_key_backspace
    cmp byte [rdi+6], 'l'
    jne .try_key_backspace
    cmp byte [rdi+7], 'e'
    jne .try_key_backspace
    cmp byte [rdi+8], 't'
    jne .try_key_backspace
    cmp byte [rdi+9], 'e'
    jne .try_key_backspace
    mov rax, word_key_delete
    jmp .done

.try_key_backspace:
    ; key-backspace (13 chars)
    cmp rcx, 13
    jne .try_neq
    cmp byte [rdi], 'k'
    jne .try_neq
    cmp byte [rdi+1], 'e'
    jne .try_neq
    cmp byte [rdi+2], 'y'
    jne .try_neq
    cmp byte [rdi+3], '-'
    jne .try_neq
    cmp byte [rdi+4], 'b'
    jne .try_neq
    cmp byte [rdi+5], 'a'
    jne .try_neq
    cmp byte [rdi+6], 'c'
    jne .try_neq
    cmp byte [rdi+7], 'k'
    jne .try_neq
    cmp byte [rdi+8], 's'
    jne .try_neq
    cmp byte [rdi+9], 'p'
    jne .try_neq
    cmp byte [rdi+10], 'a'
    jne .try_neq
    cmp byte [rdi+11], 'c'
    jne .try_neq
    cmp byte [rdi+12], 'e'
    jne .try_neq
    mov rax, word_key_backspace
    jmp .done

.try_neq:
    ; <> (2 chars)
    cmp rcx, 2
    jne .try_le
    cmp byte [rdi], '<'
    jne .try_le
    cmp byte [rdi+1], '>'
    jne .try_le
    mov rax, word_neq
    jmp .done

.try_le:
    ; <= (2 chars)
    cmp rcx, 2
    jne .try_ge
    cmp byte [rdi], '<'
    jne .try_ge
    cmp byte [rdi+1], '='
    jne .try_ge
    mov rax, word_le
    jmp .done

.try_ge:
    ; >= (2 chars)
    cmp rcx, 2
    jne .try_zeq
    cmp byte [rdi], '>'
    jne .try_zeq
    cmp byte [rdi+1], '='
    jne .try_zeq
    mov rax, word_ge
    jmp .done

.try_zeq:
    ; 0= (2 chars)
    cmp rcx, 2
    jne .try_mod
    cmp byte [rdi], '0'
    jne .try_mod
    cmp byte [rdi+1], '='
    jne .try_mod
    mov rax, word_zeq
    jmp .done

.try_mod:
    ; mod (3 chars)
    cmp rcx, 3
    jne .try_and
    cmp byte [rdi], 'm'
    jne .try_and
    cmp byte [rdi+1], 'o'
    jne .try_and
    cmp byte [rdi+2], 'd'
    jne .try_and
    mov rax, word_mod
    jmp .done

.try_and:
    ; and (3 chars)
    cmp rcx, 3
    jne .try_or
    cmp byte [rdi], 'a'
    jne .try_or
    cmp byte [rdi+1], 'n'
    jne .try_or
    cmp byte [rdi+2], 'd'
    jne .try_or
    mov rax, word_and
    jmp .done

.try_or:
    ; or (2 chars)
    cmp rcx, 2
    jne .try_xor
    cmp byte [rdi], 'o'
    jne .try_xor
    cmp byte [rdi+1], 'r'
    jne .try_xor
    mov rax, word_or
    jmp .done

.try_xor:
    ; xor (3 chars)
    cmp rcx, 3
    jne .try_not
    cmp byte [rdi], 'x'
    jne .try_not
    cmp byte [rdi+1], 'o'
    jne .try_not
    cmp byte [rdi+2], 'r'
    jne .try_not
    mov rax, word_xor
    jmp .done

.try_not:
    ; not (3 chars)
    cmp rcx, 3
    jne .try_if
    cmp byte [rdi], 'n'
    jne .try_if
    cmp byte [rdi+1], 'o'
    jne .try_if
    cmp byte [rdi+2], 't'
    jne .try_if
    mov rax, word_not
    jmp .done

.try_if:
    ; if (2 chars) - IMMEDIATE
    cmp rcx, 2
    jne .try_then
    cmp byte [rdi], 'i'
    jne .try_then
    cmp byte [rdi+1], 'f'
    jne .try_then
    mov rax, word_if
    jmp .done_immediate

.try_then:
    ; then (4 chars) - IMMEDIATE
    cmp rcx, 4
    jne .try_else
    cmp byte [rdi], 't'
    jne .try_else
    cmp byte [rdi+1], 'h'
    jne .try_else
    cmp byte [rdi+2], 'e'
    jne .try_else
    cmp byte [rdi+3], 'n'
    jne .try_else
    mov rax, word_then
    jmp .done_immediate

.try_else:
    ; else (4 chars) - IMMEDIATE
    cmp rcx, 4
    jne .try_begin
    cmp byte [rdi], 'e'
    jne .try_begin
    cmp byte [rdi+1], 'l'
    jne .try_begin
    cmp byte [rdi+2], 's'
    jne .try_begin
    cmp byte [rdi+3], 'e'
    jne .try_begin
    mov rax, word_else
    jmp .done_immediate

.try_begin:
    ; begin (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_until
    cmp byte [rdi], 'b'
    jne .try_until
    cmp byte [rdi+1], 'e'
    jne .try_until
    cmp byte [rdi+2], 'g'
    jne .try_until
    cmp byte [rdi+3], 'i'
    jne .try_until
    cmp byte [rdi+4], 'n'
    jne .try_until
    mov rax, word_begin
    jmp .done_immediate

.try_until:
    ; until (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_while
    cmp byte [rdi], 'u'
    jne .try_while
    cmp byte [rdi+1], 'n'
    jne .try_while
    cmp byte [rdi+2], 't'
    jne .try_while
    cmp byte [rdi+3], 'i'
    jne .try_while
    cmp byte [rdi+4], 'l'
    jne .try_while
    mov rax, word_until
    jmp .done_immediate

.try_while:
    ; while (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_repeat
    cmp byte [rdi], 'w'
    jne .try_repeat
    cmp byte [rdi+1], 'h'
    jne .try_repeat
    cmp byte [rdi+2], 'i'
    jne .try_repeat
    cmp byte [rdi+3], 'l'
    jne .try_repeat
    cmp byte [rdi+4], 'e'
    jne .try_repeat
    mov rax, word_while
    jmp .done_immediate

.try_repeat:
    ; repeat (6 chars) - IMMEDIATE
    cmp rcx, 6
    jne .try_again
    cmp byte [rdi], 'r'
    jne .try_again
    cmp byte [rdi+1], 'e'
    jne .try_again
    cmp byte [rdi+2], 'p'
    jne .try_again
    cmp byte [rdi+3], 'e'
    jne .try_again
    cmp byte [rdi+4], 'a'
    jne .try_again
    cmp byte [rdi+5], 't'
    jne .try_again
    mov rax, word_repeat
    jmp .done_immediate

.try_again:
    ; again (5 chars) - IMMEDIATE
    cmp rcx, 5
    jne .try_app_enter
    cmp byte [rdi], 'a'
    jne .try_app_enter
    cmp byte [rdi+1], 'g'
    jne .try_app_enter
    cmp byte [rdi+2], 'a'
    jne .try_app_enter
    cmp byte [rdi+3], 'i'
    jne .try_app_enter
    cmp byte [rdi+4], 'n'
    jne .try_app_enter
    mov rax, word_again
    jmp .done_immediate

.try_app_enter:
    ; app-enter (9 chars)
    cmp rcx, 9
    jne .try_app_exit
    cmp byte [rdi], 'a'
    jne .try_app_exit
    cmp byte [rdi+1], 'p'
    jne .try_app_exit
    cmp byte [rdi+2], 'p'
    jne .try_app_exit
    cmp byte [rdi+3], '-'
    jne .try_app_exit
    cmp byte [rdi+4], 'e'
    jne .try_app_exit
    cmp byte [rdi+5], 'n'
    jne .try_app_exit
    cmp byte [rdi+6], 't'
    jne .try_app_exit
    cmp byte [rdi+7], 'e'
    jne .try_app_exit
    cmp byte [rdi+8], 'r'
    jne .try_app_exit
    mov rax, word_app_enter
    jmp .done

.try_app_exit:
    ; app-exit (8 chars)
    cmp rcx, 8
    jne .try_app_stack
    cmp byte [rdi], 'a'
    jne .try_app_stack
    cmp byte [rdi+1], 'p'
    jne .try_app_stack
    cmp byte [rdi+2], 'p'
    jne .try_app_stack
    cmp byte [rdi+3], '-'
    jne .try_app_stack
    cmp byte [rdi+4], 'e'
    jne .try_app_stack
    cmp byte [rdi+5], 'x'
    jne .try_app_stack
    cmp byte [rdi+6], 'i'
    jne .try_app_stack
    cmp byte [rdi+7], 't'
    jne .try_app_stack
    mov rax, word_app_exit
    jmp .done

.try_app_stack:
    ; app-stack (9 chars)
    cmp rcx, 9
    jne .try_app_depth
    cmp byte [rdi], 'a'
    jne .try_app_depth
    cmp byte [rdi+1], 'p'
    jne .try_app_depth
    cmp byte [rdi+2], 'p'
    jne .try_app_depth
    cmp byte [rdi+3], '-'
    jne .try_app_depth
    cmp byte [rdi+4], 's'
    jne .try_app_depth
    cmp byte [rdi+5], 't'
    jne .try_app_depth
    cmp byte [rdi+6], 'a'
    jne .try_app_depth
    cmp byte [rdi+7], 'c'
    jne .try_app_depth
    cmp byte [rdi+8], 'k'
    jne .try_app_depth
    mov rax, word_app_stack
    jmp .done

.try_app_depth:
    ; app-depth (9 chars)
    cmp rcx, 9
    jne .try_disk_read
    cmp byte [rdi], 'a'
    jne .try_disk_read
    cmp byte [rdi+1], 'p'
    jne .try_disk_read
    cmp byte [rdi+2], 'p'
    jne .try_disk_read
    cmp byte [rdi+3], '-'
    jne .try_disk_read
    cmp byte [rdi+4], 'd'
    jne .try_disk_read
    cmp byte [rdi+5], 'e'
    jne .try_disk_read
    cmp byte [rdi+6], 'p'
    jne .try_disk_read
    cmp byte [rdi+7], 't'
    jne .try_disk_read
    cmp byte [rdi+8], 'h'
    jne .try_disk_read
    mov rax, word_app_depth
    jmp .done

.try_disk_read:
    ; disk-read (9 chars) - read sector from disk
    cmp rcx, 9
    jne .try_disk_write
    cmp byte [rdi], 'd'
    jne .try_disk_write
    cmp byte [rdi+1], 'i'
    jne .try_disk_write
    cmp byte [rdi+2], 's'
    jne .try_disk_write
    cmp byte [rdi+3], 'k'
    jne .try_disk_write
    cmp byte [rdi+4], '-'
    jne .try_disk_write
    cmp byte [rdi+5], 'r'
    jne .try_disk_write
    cmp byte [rdi+6], 'e'
    jne .try_disk_write
    cmp byte [rdi+7], 'a'
    jne .try_disk_write
    cmp byte [rdi+8], 'd'
    jne .try_disk_write
    mov rax, word_disk_read
    jmp .done

.try_disk_write:
    ; disk-write (10 chars) - write sector to disk
    cmp rcx, 10
    jne .try_load
    cmp byte [rdi], 'd'
    jne .try_load
    cmp byte [rdi+1], 'i'
    jne .try_load
    cmp byte [rdi+2], 's'
    jne .try_load
    cmp byte [rdi+3], 'k'
    jne .try_load
    cmp byte [rdi+4], '-'
    jne .try_load
    cmp byte [rdi+5], 'w'
    jne .try_load
    cmp byte [rdi+6], 'r'
    jne .try_load
    cmp byte [rdi+7], 'i'
    jne .try_load
    cmp byte [rdi+8], 't'
    jne .try_load
    cmp byte [rdi+9], 'e'
    jne .try_load
    mov rax, word_disk_write
    jmp .done

.try_load:
    ; load (4 chars) - load and run app from disk
    cmp rcx, 4
    jne .try_save
    cmp byte [rdi], 'l'
    jne .try_edit
    cmp byte [rdi+1], 'o'
    jne .try_edit
    cmp byte [rdi+2], 'a'
    jne .try_edit
    cmp byte [rdi+3], 'd'
    jne .try_edit
    mov rax, word_load
    jmp .done

.try_edit:
    ; edit (4 chars) - shortcut to load editor
    cmp byte [rdi], 'e'
    jne .try_save
    cmp byte [rdi+1], 'd'
    jne .try_save
    cmp byte [rdi+2], 'i'
    jne .try_save
    cmp byte [rdi+3], 't'
    jne .try_save
    mov rax, word_edit
    jmp .done

.try_save:
    ; save (4 chars) - save user definitions to disk
    cmp rcx, 4
    jne .try_restore
    cmp byte [rdi], 's'
    jne .try_restore
    cmp byte [rdi+1], 'a'
    jne .try_sort_main
    cmp byte [rdi+2], 'v'
    jne .try_sort_main
    cmp byte [rdi+3], 'e'
    jne .try_sort_main
    mov rax, word_save
    jmp .done

.try_sort_main:
    ; sort (4 chars) - sort array (already know rcx=4, rdi[0]='s')
    cmp byte [rdi+1], 'o'
    jne .try_restore
    cmp byte [rdi+2], 'r'
    jne .try_restore
    cmp byte [rdi+3], 't'
    jne .try_restore
    mov rax, word_sort
    jmp .done

.try_restore:
    ; restore (7 chars) - load user definitions from disk
    cmp rcx, 7
    jne .try_info
    cmp byte [rdi], 'r'
    jne .try_info
    cmp byte [rdi+1], 'e'
    jne .try_info
    cmp byte [rdi+2], 's'
    jne .try_info
    cmp byte [rdi+3], 't'
    jne .try_info
    cmp byte [rdi+4], 'o'
    jne .try_info
    cmp byte [rdi+5], 'r'
    jne .try_info
    cmp byte [rdi+6], 'e'
    jne .try_info
    mov rax, word_restore
    jmp .done

.try_info:
    ; info (4 chars) - show word definition
    cmp rcx, 4
    jne .try_remove
    cmp byte [rdi], 'i'
    jne .try_remove
    cmp byte [rdi+1], 'n'
    jne .try_remove
    cmp byte [rdi+2], 'f'
    jne .try_remove
    cmp byte [rdi+3], 'o'
    jne .try_remove
    mov rax, word_info
    jmp .done

.try_remove:
    ; remove (6 chars) - delete user-defined word
    cmp rcx, 6
    jne .not_found
    cmp byte [rdi], 'r'
    jne .not_found
    cmp byte [rdi+1], 'e'
    jne .not_found
    cmp byte [rdi+2], 'm'
    jne .not_found
    cmp byte [rdi+3], 'o'
    jne .not_found
    cmp byte [rdi+4], 'v'
    jne .not_found
    cmp byte [rdi+5], 'e'
    jne .not_found
    mov rax, word_remove
    jmp .done

.done_immediate:
    ; Mark as immediate by setting high bit (bit 63)
    bts rax, 63
    jmp .done

.not_found:
    xor rax, rax

.done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Word implementations for REPL (using R15 as data stack)
; Shared underflow handler for binary ops: clamp stack, result 0
binop_underflow:
    mov r15, [stack_floor]
    xor r14, r14
    ret

; Pop second operand with underflow guard (jumps to handler if empty)
%macro BINOP_POP 0
    sub r15, 8
    cmp r15, [stack_floor]
    jl binop_underflow
%endmacro

word_plus:
    ; Add: pop second, add to TOS (in R14)
    BINOP_POP
    add r14, [r15]
    ret

word_minus:
    ; Subtract: second - TOS, result in TOS
    BINOP_POP
    mov rax, [r15]
    sub rax, r14
    mov r14, rax
    ret

word_mult:
    ; Multiply: second * TOS
    BINOP_POP
    imul r14, [r15]
    ret

word_div:
    ; Divide: second / TOS (signed; div by zero yields 0)
    BINOP_POP
    mov rax, [r15]          ; Dividend (second)
    mov rbx, r14            ; Divisor (TOS)
    test rbx, rbx
    jz .div_zero
    cmp rbx, -1             ; Guard INT_MIN / -1 overflow
    je .div_neg1
    cqo
    idiv rbx
    mov r14, rax            ; Quotient becomes TOS
    ret
.div_neg1:
    neg rax
    mov r14, rax
    ret
.div_zero:
    xor r14, r14
    ret

word_mod:
    ; Modulo: second mod TOS (signed; mod by zero yields 0)
    BINOP_POP
    mov rax, [r15]          ; Dividend (second)
    mov rbx, r14            ; Divisor (TOS)
    test rbx, rbx
    jz .mod_zero
    cmp rbx, -1             ; Guard INT_MIN / -1 overflow
    je .mod_zero            ; n mod -1 = 0
    cqo
    idiv rbx
    mov r14, rdx            ; Remainder becomes TOS
    ret
.mod_zero:
    xor r14, r14
    ret

word_eq:
    ; Equal: second = TOS -> flag ( a b -- flag )
    BINOP_POP
    mov rax, [r15]
    cmp rax, r14
    je .eq_true
    xor r14, r14            ; 0 = false
    ret
.eq_true:
    mov r14, -1             ; -1 = true (all bits set)
    ret

word_neq:
    ; Not equal: second <> TOS -> flag
    BINOP_POP
    mov rax, [r15]
    cmp rax, r14
    jne .neq_true
    xor r14, r14
    ret
.neq_true:
    mov r14, -1
    ret

word_lt:
    ; Less than: second < TOS -> flag
    BINOP_POP
    mov rax, [r15]
    cmp rax, r14
    jl .lt_true
    xor r14, r14
    ret
.lt_true:
    mov r14, -1
    ret

word_gt:
    ; Greater than: second > TOS -> flag
    BINOP_POP
    mov rax, [r15]
    cmp rax, r14
    jg .gt_true
    xor r14, r14
    ret
.gt_true:
    mov r14, -1
    ret

word_le:
    ; Less or equal: second <= TOS -> flag
    BINOP_POP
    mov rax, [r15]
    cmp rax, r14
    jle .le_true
    xor r14, r14
    ret
.le_true:
    mov r14, -1
    ret

word_ge:
    ; Greater or equal: second >= TOS -> flag
    BINOP_POP
    mov rax, [r15]
    cmp rax, r14
    jge .ge_true
    xor r14, r14
    ret
.ge_true:
    mov r14, -1
    ret

word_zeq:
    ; Zero equal: TOS = 0 -> flag ( n -- flag )
    test r14, r14
    jz .zeq_true
    xor r14, r14
    ret
.zeq_true:
    mov r14, -1
    ret

word_and:
    ; Bitwise AND ( a b -- a&b )
    BINOP_POP
    and r14, [r15]
    ret

word_or:
    ; Bitwise OR ( a b -- a|b )
    BINOP_POP
    or r14, [r15]
    ret

word_xor:
    ; Bitwise XOR ( a b -- a^b )
    BINOP_POP
    xor r14, [r15]
    ret

word_not:
    ; Logical NOT ( flag -- flag' )
    test r14, r14
    jz .not_true
    xor r14, r14
    ret
.not_true:
    mov r14, -1
    ret

; ============================================================
; Floating point words (x87)
; Doubles live as raw IEEE-754 bits in ordinary stack cells.
; Dedicated f-words operate on them; f. prints with FIX digits.
; ============================================================

; Scratch and configuration
fp_tmp1: dq 0
fp_tmp2: dq 0
fp_cw:   dw 0                   ; saved control word
fp_cw2:  dw 0                   ; truncation control word
fp_half: dq 0.5
fix_digits: dq 4                ; decimals for f. (0-9)
fp_pow10:                       ; 10^0 .. 10^9 as doubles
    dq 1.0, 10.0, 100.0, 1000.0, 10000.0
    dq 100000.0, 1000000.0, 10000000.0, 100000000.0, 1000000000.0
ip_pow10:                       ; 10^0 .. 10^9 as integers
    dq 1, 10, 100, 1000, 10000
    dq 100000, 1000000, 10000000, 100000000, 1000000000

; Switch x87 rounding to truncate / restore
fp_trunc_on:
    fnstcw [fp_cw]
    mov ax, [fp_cw]
    or ax, 0x0C00
    mov [fp_cw2], ax
    fldcw [fp_cw2]
    ret
fp_trunc_off:
    fldcw [fp_cw]
    ret

word_sf:
    ; s>f ( n -- f ) integer to float
    mov [fp_tmp1], r14
    fild qword [fp_tmp1]
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fs:
    ; f>s ( f -- n ) truncate toward zero
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]
    call fp_trunc_on
    fistp qword [fp_tmp1]
    call fp_trunc_off
    mov r14, [fp_tmp1]
    ret

word_fadd:
    ; f+ ( a b -- a+b )
    BINOP_POP
    mov [fp_tmp2], r14
    mov rax, [r15]
    mov [fp_tmp1], rax
    fld qword [fp_tmp1]
    fld qword [fp_tmp2]
    faddp
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fsub:
    ; f- ( a b -- a-b )
    BINOP_POP
    mov [fp_tmp2], r14
    mov rax, [r15]
    mov [fp_tmp1], rax
    fld qword [fp_tmp1]
    fld qword [fp_tmp2]
    fsubp
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fmul:
    ; f* ( a b -- a*b )
    BINOP_POP
    mov [fp_tmp2], r14
    mov rax, [r15]
    mov [fp_tmp1], rax
    fld qword [fp_tmp1]
    fld qword [fp_tmp2]
    fmulp
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fdiv:
    ; f/ ( a b -- a/b )
    BINOP_POP
    mov [fp_tmp2], r14
    mov rax, [r15]
    mov [fp_tmp1], rax
    fld qword [fp_tmp1]
    fld qword [fp_tmp2]
    fdivp
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

; Comparison helper: loads a,b; after fucompp+fnstsw+sahf:
;   ZF = (a=b), CF = (b<a), PF = unordered (NaN)
fp_compare:
    mov [fp_tmp2], r14
    mov rax, [r15]
    mov [fp_tmp1], rax
    fld qword [fp_tmp1]         ; a
    fld qword [fp_tmp2]         ; b (ST0), a (ST1)
    fucompp
    fnstsw ax
    sahf
    ret

word_flt:
    ; f< ( a b -- flag )  a<b means b>a: CF=0 and ZF=0
    BINOP_POP
    call fp_compare
    jp .flt_false               ; NaN: false
    seta al
    movzx r14, al
    neg r14
    ret
.flt_false:
    xor r14, r14
    ret

word_fgt:
    ; f> ( a b -- flag )  a>b means b<a: CF=1
    BINOP_POP
    call fp_compare
    jp .fgt_false               ; NaN: false
    setb al
    movzx r14, al
    neg r14
    ret
.fgt_false:
    xor r14, r14
    ret

word_feq:
    ; f= ( a b -- flag )
    BINOP_POP
    call fp_compare
    jp .feq_false               ; NaN: false
    sete al
    movzx r14, al
    neg r14
    ret
.feq_false:
    xor r14, r14
    ret

word_fneg:
    ; fneg ( f -- -f )
    btc r14, 63
    ret

word_fabs2:
    ; fabs ( f -- |f| )
    btr r14, 63
    ret

word_fsqrt:
    ; fsqrt ( f -- sqrt f )
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]
    fsqrt
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fsin:
    ; fsin ( f -- sin f ) radians
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]
    fsin
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fcos:
    ; fcos ( f -- cos f )
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]
    fcos
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_ftan:
    ; ftan ( f -- tan f )
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]
    fptan
    fstp st0                    ; drop the pushed 1.0
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fatan:
    ; fatan ( f -- atan f )
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]         ; x
    fld1                        ; 1 (ST0), x (ST1)
    fpatan                      ; atan(x/1)
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fln:
    ; fln ( f -- ln f )
    mov [fp_tmp1], r14
    fldln2
    fld qword [fp_tmp1]
    fyl2x                       ; ln2 * log2(x)
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_flog:
    ; flog ( f -- log10 f )
    mov [fp_tmp1], r14
    fldlg2
    fld qword [fp_tmp1]
    fyl2x
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

; Shared 2^t tail: ST0 = t, leaves ST0 = 2^t
fp_two_to:
    fld st0
    frndint                     ; n, t
    fsub st1, st0               ; n, f=t-n  (|f| <= 0.5)
    fxch st1                    ; f, n
    f2xm1                       ; 2^f-1, n
    fld1
    faddp                       ; 2^f, n
    fscale                      ; 2^f * 2^n, n
    fstp st1
    ret

word_fexp:
    ; fexp ( f -- e^f )
    mov [fp_tmp1], r14
    fld qword [fp_tmp1]
    fldl2e
    fmulp                       ; t = f * log2(e)
    call fp_two_to
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fpow:
    ; fpow ( a b -- a^b )  via 2^(b*log2 a); a must be positive
    BINOP_POP
    mov [fp_tmp2], r14
    mov rax, [r15]
    mov [fp_tmp1], rax
    fld qword [fp_tmp2]         ; b
    fld qword [fp_tmp1]         ; a (ST0), b (ST1)
    fyl2x                       ; t = b * log2(a)
    call fp_two_to
    fstp qword [fp_tmp1]
    mov r14, [fp_tmp1]
    ret

word_fpi:
    ; fpi ( -- pi )
    fldpi
    fstp qword [fp_tmp1]
    mov [r15], r14
    add r15, 8
    mov r14, [fp_tmp1]
    ret

word_fix:
    ; fix ( n -- ) set decimals for f. (clamped 0-9)
    mov rax, r14
    cmp rax, 0
    jge .fix_lo_ok
    xor rax, rax
.fix_lo_ok:
    cmp rax, 9
    jle .fix_hi_ok
    mov rax, 9
.fix_hi_ok:
    mov [fix_digits], rax
    sub r15, 8
    cmp r15, [stack_floor]
    jl .fix_empty
    mov r14, [r15]
    ret
.fix_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_fdot:
    ; f. ( f -- ) print with fix_digits decimals
    push rbx
    push r8
    push r9
    push r10

    mov r8, r14                 ; value bits

    ; Pop
    sub r15, 8
    cmp r15, [stack_floor]
    jl .fd_empty
    mov r14, [r15]
    jmp .fd_go
.fd_empty:
    mov r15, [stack_floor]
    xor r14, r14
.fd_go:

    ; Sign
    bt r8, 63
    jnc .fd_pos
    mov al, '-'
    call emit_char
    btr r8, 63
.fd_pos:

    ; Inf/NaN: exponent field all ones
    mov rbx, r8
    shr rbx, 52
    and rbx, 0x7FF
    cmp rbx, 0x7FF
    jne .fd_finite
    mov rbx, r8
    mov rax, 0x000FFFFFFFFFFFFF
    test rbx, rax
    jnz .fd_nan
    mov al, 'i'
    call emit_char
    mov al, 'n'
    call emit_char
    mov al, 'f'
    call emit_char
    jmp .fd_done
.fd_nan:
    mov al, 'n'
    call emit_char
    mov al, 'a'
    call emit_char
    mov al, 'n'
    call emit_char
    jmp .fd_done

.fd_finite:
    mov [fp_tmp1], r8
    fld qword [fp_tmp1]         ; x (>= 0)

    ; Integer part (truncated)
    call fp_trunc_on
    fld st0
    fistp qword [fp_tmp2]
    call fp_trunc_off
    mov r9, [fp_tmp2]           ; i
    mov rax, 0x8000000000000000
    cmp r9, rax
    jne .fd_int_ok
    fstp st0
    mov al, '('
    call emit_char
    mov al, 'b'
    call emit_char
    mov al, 'i'
    call emit_char
    mov al, 'g'
    call emit_char
    mov al, ')'
    call emit_char
    jmp .fd_done
.fd_int_ok:

    ; Fraction = x - i  (in [0,1))
    fild qword [fp_tmp2]
    fsubp st1, st0

    mov r10, [fix_digits]
    test r10, r10
    jnz .fd_have_frac
    ; FIX 0: round using the fraction, print integer only
    fadd qword [fp_half]
    call fp_trunc_on
    fistp qword [fp_tmp2]
    call fp_trunc_off
    mov rax, [fp_tmp2]
    add r9, rax
    mov rax, r9
    call print_number
    jmp .fd_done

.fd_have_frac:
    ; Scale, round, truncate to integer fraction
    fmul qword [fp_pow10 + r10*8]
    fadd qword [fp_half]
    call fp_trunc_on
    fistp qword [fp_tmp2]
    call fp_trunc_off
    mov rbx, [fp_tmp2]          ; rounded fraction

    ; Carry: fraction rounded up to 10^d
    cmp rbx, [ip_pow10 + r10*8]
    jne .fd_no_carry
    inc r9
    xor rbx, rbx
.fd_no_carry:

    ; Print integer part, point, zero-padded fraction
    mov rax, r9
    call print_number
    mov al, '.'
    call emit_char

.fd_frac_loop:
    dec r10
    js .fd_done
    mov rax, rbx
    xor rdx, rdx
    div qword [ip_pow10 + r10*8]
    ; rax = digit, rdx = remainder
    mov rbx, rdx
    add al, '0'
    call emit_char
    jmp .fd_frac_loop

.fd_done:
    mov al, ' '
    call emit_char
    pop r10
    pop r9
    pop r8
    pop rbx
    ret

; match_float_word: RDI = token (lowercased), RCX = length
; Returns RAX = word address or 0
match_float_word:
    ; s>f
    cmp rcx, 3
    jne .mf_not_sf
    cmp byte [rdi], 's'
    jne .mf_not_sf
    cmp byte [rdi+1], '>'
    jne .mf_no
    cmp byte [rdi+2], 'f'
    jne .mf_no
    mov rax, word_sf
    ret
.mf_not_sf:
    ; eval (4 chars)
    cmp rcx, 4
    jne .mf_not_eval
    cmp byte [rdi], 'e'
    jne .mf_not_eval
    cmp byte [rdi+1], 'v'
    jne .mf_not_eval
    cmp byte [rdi+2], 'a'
    jne .mf_not_eval
    cmp byte [rdi+3], 'l'
    jne .mf_not_eval
    mov rax, word_eval
    ret
.mf_not_eval:
    cmp byte [rdi], 'f'
    jne .mf_no
    cmp rcx, 2
    je .mf_len2
    cmp rcx, 3
    je .mf_len3
    cmp rcx, 4
    je .mf_len4
    cmp rcx, 5
    je .mf_len5
    jmp .mf_no

.mf_len2:
    mov al, [rdi+1]
    cmp al, '+'
    je .mf_fadd
    cmp al, '-'
    je .mf_fsub
    cmp al, '*'
    je .mf_fmul
    cmp al, '/'
    je .mf_fdiv
    cmp al, '<'
    je .mf_flt
    cmp al, '>'
    je .mf_fgt
    cmp al, '='
    je .mf_feq
    cmp al, '.'
    je .mf_fdot
    jmp .mf_no

.mf_len3:
    ; fix fpi fln f>s
    mov al, [rdi+1]
    cmp al, 'i'
    je .mf_chk_fix
    cmp al, 'p'
    je .mf_chk_fpi
    cmp al, 'l'
    je .mf_chk_fln
    cmp al, '>'
    je .mf_chk_fs
    jmp .mf_no
.mf_chk_fix:
    cmp byte [rdi+2], 'x'
    jne .mf_no
    mov rax, word_fix
    ret
.mf_chk_fpi:
    cmp byte [rdi+2], 'i'
    jne .mf_no
    mov rax, word_fpi
    ret
.mf_chk_fln:
    cmp byte [rdi+2], 'n'
    jne .mf_no
    mov rax, word_fln
    ret
.mf_chk_fs:
    cmp byte [rdi+2], 's'
    jne .mf_no
    mov rax, word_fs
    ret

.mf_len4:
    ; fneg fabs fsin fcos ftan fexp fpow flog (second char unique;
    ; 'r' falls through for the existing word free)
    mov al, [rdi+1]
    cmp al, 'n'
    je .mf_fneg
    cmp al, 'a'
    je .mf_fabs
    cmp al, 's'
    je .mf_fsin
    cmp al, 'c'
    je .mf_fcos
    cmp al, 't'
    je .mf_ftan
    cmp al, 'e'
    je .mf_fexp
    cmp al, 'p'
    je .mf_fpow
    cmp al, 'l'
    je .mf_flog
    jmp .mf_no

.mf_len5:
    ; fsqrt fatan
    mov al, [rdi+1]
    cmp al, 's'
    je .mf_fsqrt
    cmp al, 'a'
    je .mf_fatan
    jmp .mf_no

.mf_fadd:  mov rax, word_fadd
    ret
.mf_fsub:  mov rax, word_fsub
    ret
.mf_fmul:  mov rax, word_fmul
    ret
.mf_fdiv:  mov rax, word_fdiv
    ret
.mf_flt:   mov rax, word_flt
    ret
.mf_fgt:   mov rax, word_fgt
    ret
.mf_feq:   mov rax, word_feq
    ret
.mf_fdot:  mov rax, word_fdot
    ret
.mf_fneg:  mov rax, word_fneg
    ret
.mf_fabs:  mov rax, word_fabs2
    ret
.mf_fsin:  mov rax, word_fsin
    ret
.mf_fcos:  mov rax, word_fcos
    ret
.mf_ftan:  mov rax, word_ftan
    ret
.mf_fexp:  mov rax, word_fexp
    ret
.mf_fpow:  mov rax, word_fpow
    ret
.mf_flog:  mov rax, word_flog
    ret
.mf_fsqrt: mov rax, word_fsqrt
    ret
.mf_fatan: mov rax, word_fatan
    ret
.mf_no:
    xor rax, rax
    ret

; try_parse_float: RDI = token, RCX = length
; Returns RDX=1 and RAX=IEEE-754 bits if the token is a float literal
; (optional -, digits, exactly one ., only digits otherwise).
; Preserves RDI, RCX.
try_parse_float:
    push rbx
    push rsi
    push r8
    push r9
    push r10
    push r11
    push rdi
    push rcx

    xor r8, r8                  ; sign flag
    xor rbx, rbx                ; integer part
    xor r9, r9                  ; fraction digits value
    xor r10, r10                ; fraction digit count
    xor r11, r11                ; dot seen / any-digit (bit0 dot, bit1 digit)

    cmp rcx, 2
    jl .pf_no                   ; too short to be a float

    cmp byte [rdi], '-'
    jne .pf_scan
    mov r8, 1
    inc rdi
    dec rcx
    jz .pf_no

.pf_scan:
    test rcx, rcx
    jz .pf_check
    mov al, [rdi]
    cmp al, '.'
    je .pf_dot
    cmp al, '0'
    jb .pf_no
    cmp al, '9'
    ja .pf_no
    ; digit
    or r11, 2
    sub al, '0'
    movzx rsi, al
    test r11, 1
    jnz .pf_frac_digit
    imul rbx, 10
    add rbx, rsi
    jmp .pf_next
.pf_frac_digit:
    cmp r10, 9
    jae .pf_next                ; ignore digits beyond 9 decimals
    imul r9, 10
    add r9, rsi
    inc r10
    jmp .pf_next
.pf_dot:
    test r11, 1
    jnz .pf_no                  ; second dot: not a float
    or r11, 1
.pf_next:
    inc rdi
    dec rcx
    jmp .pf_scan

.pf_check:
    ; Need a dot and at least one digit
    cmp r11, 3
    jne .pf_no

    ; Build double: int + frac/10^count
    mov [fp_tmp1], rbx
    fild qword [fp_tmp1]
    test r10, r10
    jz .pf_no_frac
    mov [fp_tmp2], r9
    fild qword [fp_tmp2]
    fdiv qword [fp_pow10 + r10*8]
    faddp
.pf_no_frac:
    fstp qword [fp_tmp1]
    mov rax, [fp_tmp1]
    test r8, r8
    jz .pf_positive
    bts rax, 63
.pf_positive:
    mov rdx, 1
    jmp .pf_out

.pf_no:
    xor rdx, rdx
    xor rax, rax
.pf_out:
    pop rcx
    pop rdi
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rbx
    ret

word_dot:
    ; Print TOS and load new TOS
    mov rax, r14

    ; Object only if inside the live heap; everything else prints as int
    cmp rax, HEAP_START
    jl .print_immediate
    cmp rax, [heap_ptr]
    jge .print_immediate

    ; Object - check type
    mov rbx, [rax]          ; Get type tag
    cmp rbx, TYPE_STRING
    je .print_string_obj
    cmp rbx, TYPE_REF
    je .print_ref_obj
    cmp rbx, TYPE_ARRAY
    je .print_array_obj

    ; Check for user-defined type
    cmp rbx, TYPE_USER_BASE
    jge .print_user_obj

    ; Unknown type - print address
    call print_number
    jmp .dot_done

.print_array_obj:
    ; Print array contents: [ elem1 elem2 ... ]
    push rax
    mov al, '['
    call emit_char
    mov al, ' '
    call emit_char
    pop rax

    ; Get count and print elements
    push rax
    mov rcx, [rax+8]        ; Count
    lea rdi, [rax+16]       ; Data start
.print_arr_loop:
    test rcx, rcx
    jz .print_arr_done
    push rcx
    push rdi
    mov rax, [rdi]
    ; Untag bit-63-tagged literals (REPL array collection)
    bt rax, 63
    jnc .arr_elem_notag
    shl rax, 1
    sar rax, 1
.arr_elem_notag:
    ; Print element based on type
    cmp rax, HEAP_START
    jl .arr_elem_int
    cmp rax, [heap_ptr]
    jge .arr_elem_int
    ; Object element - check type
    mov rbx, [rax]
    cmp rbx, TYPE_STRING
    je .arr_elem_string
    cmp rbx, TYPE_REF
    je .arr_elem_ref
    ; Unknown object - print [type]
    push rax
    mov al, '['
    call emit_char
    mov rax, rbx
    call print_number
    mov al, ']'
    call emit_char
    pop rax
    jmp .arr_elem_done
.arr_elem_string:
    ; Print string with quotes
    push rax
    mov al, '"'
    call emit_char
    pop rax
    lea rax, [rax+16]       ; String data
    call print_string
    mov al, '"'
    call emit_char
    jmp .arr_elem_done
.arr_elem_ref:
    ; Print reference as ~name
    push rax
    mov al, '~'
    call emit_char
    pop rax
    mov rax, [rax+16]       ; Ref name pointer
    call print_string
    jmp .arr_elem_done
.arr_elem_int:
    call print_number
.arr_elem_done:
    mov al, ' '
    call emit_char
    pop rdi
    pop rcx
    add rdi, 8
    dec rcx
    jmp .print_arr_loop
.print_arr_done:
    pop rax
    mov al, ']'
    call emit_char
    jmp .dot_done

.print_user_obj:
    ; User type - print [typename: data...]
    push rax
    push rbx
    mov al, '['
    call emit_char

    ; Get type name
    mov rax, rbx
    sub rax, TYPE_USER_BASE
    mov rax, [type_registry + rax*8]
    test rax, rax
    jz .user_no_name

    ; Print type name
    lea rax, [rax+16]       ; String data
    call print_string
    jmp .user_after_name

.user_no_name:
    ; No name - print type number
    pop rbx
    push rbx
    mov rax, rbx
    call print_number

.user_after_name:
    mov al, ':'
    call emit_char
    mov al, ' '
    call emit_char

    ; Print array-like contents (user types are arrays with different tag)
    pop rbx
    pop rax
    push rax
    mov rcx, [rax+8]        ; Count/size
    lea rdi, [rax+16]       ; Data start
.user_print_loop:
    test rcx, rcx
    jz .user_print_done
    push rcx
    push rdi
    mov rax, [rdi]
    cmp rax, HEAP_START
    jl .user_elem_int
    cmp rax, [heap_ptr]
    jge .user_elem_int
    mov al, '.'
    call emit_char
    jmp .user_elem_done
.user_elem_int:
    call print_number
.user_elem_done:
    mov al, ' '
    call emit_char
    pop rdi
    pop rcx
    add rdi, 8
    dec rcx
    jmp .user_print_loop
.user_print_done:
    pop rax
    mov al, ']'
    call emit_char
    jmp .dot_done

.print_immediate:
    call print_number
    jmp .dot_done

.print_string_obj:
    ; Print string object data
    lea rax, [rax+16]       ; Skip header to data
    call print_string
    jmp .dot_done

.print_ref_obj:
    ; Print ref as "(code)"
    push rax
    mov rax, str_code_obj
    call print_string
    pop rax
    jmp .dot_done

.dot_done:
    ; Print trailing space (standard Forth behavior)
    mov al, ' '
    call emit_char
    ; Pop: decrement depth, load new TOS from memory
    ; Convention: R14=TOS, [R15-8]=second, R15=next free slot
    ; After pop: depth decreases by 1, new TOS comes from stack
    sub r15, 8
    cmp r15, [stack_floor]
    jl .dot_empty           ; jl not jle: R15==data_stack means valid item at [R15]
    ; Still have items - load new TOS from memory
    mov r14, [r15]          ; After sub, [r15] is old second item = new TOS
    ret

.dot_empty:
    ; Stack is now empty
    mov r15, [stack_floor]
    xor r14, r14            ; R14 undefined, set to 0
    ret

str_code_obj: db '(code)', 0

word_dots:
    ; Display stack: <depth> item1 item2 ...
    ; Shows type-aware representation: 42 "str" [arr:3] (ref)
    ; Convention: depth = (R15 - stack_base) / 8
    ; Depth 0: empty, Depth N: TOS in R14, rest in mem[0..N-2]
    ; App-aware: uses app_stack when app_active, else data_stack
    push rax
    push rbx
    push rcx
    push rdi
    push r8                 ; R8 = stack base

    ; Get correct stack base
    mov r8, data_stack
    cmp qword [app_active], 0
    je .have_base
    mov r8, app_stack
.have_base:

    ; Calculate depth
    mov rax, r15
    sub rax, r8
    shr rax, 3              ; Depth = (R15 - stack_base) / 8
    mov rcx, rax

    ; Print <depth>
    mov al, '<'
    call emit_char
    mov rax, rcx
    call print_number
    mov al, '>'
    call emit_char

    ; If empty, done
    test rcx, rcx
    jz .done

    mov al, ' '
    call emit_char

    ; Print memory items (depth - 1 items in mem[0..depth-2])
    dec rcx                 ; Memory items = depth - 1
    jz .print_tos           ; If was depth 1, skip to TOS

    ; Items stored at [base+8], [base+16], ..., [R15-8]
    lea rdi, [r8 + 8]       ; Start at base + 8 (first stored item)
.loop:
    mov rax, [rdi]
    call print_value_typed
    mov al, ' '
    call emit_char
    add rdi, 8
    dec rcx
    jnz .loop

.print_tos:
    ; Print TOS (R14)
    mov rax, r14
    call print_value_typed

.done:
    pop r8
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; Print value with type indicator
; RAX = value to print
print_value_typed:
    push rbx

    ; Object only if inside the live heap
    cmp rax, HEAP_START
    jl .print_int
    cmp rax, [heap_ptr]
    jge .print_int

    ; Object - check type
    mov rbx, [rax]
    cmp rbx, TYPE_STRING
    je .print_str
    cmp rbx, TYPE_ARRAY
    je .print_arr
    cmp rbx, TYPE_REF
    je .print_ref

    ; Unknown object - print address
    call print_number
    jmp .done

.print_int:
    call print_number
    jmp .done

.print_str:
    ; Print "content" (abbreviated if long)
    push rax
    mov al, '"'
    call emit_char
    pop rax
    push rax
    lea rax, [rax+16]       ; String data
    call print_string_short ; Max 10 chars
    pop rax
    push rax
    mov al, '"'
    call emit_char
    pop rax
    jmp .done

.print_arr:
    ; Print [arr:N]
    push rax
    mov al, '['
    call emit_char
    mov rax, str_arr_tag
    call print_string
    pop rax
    mov rax, [rax+8]        ; Size
    call print_number
    mov al, ']'
    call emit_char
    jmp .done

.print_ref:
    ; Print (ref)
    mov rax, str_ref_tag
    call print_string
    jmp .done

.done:
    pop rbx
    ret

str_arr_tag: db 'arr:', 0
str_ref_tag: db '(ref)', 0

; Print string, max 10 chars (for .s display)
print_string_short:
    push rbx
    push rcx
    mov rbx, rax
    mov rcx, 10             ; Max chars
.loop:
    mov al, [rbx]
    test al, al
    jz .done
    call emit_char
    inc rbx
    dec rcx
    jz .truncated
    jmp .loop
.truncated:
    mov al, '.'
    call emit_char
    call emit_char
    call emit_char
.done:
    pop rcx
    pop rbx
    ret

word_dup:
    ; Duplicate TOS: push R14, R14 unchanged
    mov [r15], r14
    add r15, 8
    ret

word_drop:
    ; Drop TOS: decrement depth, load new TOS from memory
    sub r15, 8
    cmp r15, [stack_floor]
    jl .drop_empty              ; jl not jle: R15==data_stack means valid item at [R15]
    mov r14, [r15]              ; After sub, [r15] is old second = new TOS
    ret
.drop_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_clstk:
    ; Clear entire stack ( ... -- )
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_varcount:
    ; Push named variable count ( -- n )
    mov [r15], r14
    add r15, 8
    mov r14, [named_var_count]
    ret

word_vars:
    ; Dump all named variables ( -- )
    push rbx
    push rcx
    push rsi
    push rdi

    mov rsi, named_vars
    mov rcx, [named_var_count]
    test rcx, rcx
    jz .vars_done

.vars_loop:
    push rcx
    push rsi

    ; Print variable number
    mov rax, [named_var_count]
    sub rax, rcx
    inc rax
    call print_number
    mov al, ':'
    call emit_char
    mov al, ' '
    call emit_char

    ; Get STRING pointer
    pop rsi
    push rsi
    mov rbx, [rsi]
    test rbx, rbx
    jz .vars_next

    ; Print name (STRING at rbx)
    lea rdi, [rbx+16]
    mov rcx, [rbx+8]
.vars_print_char:
    test rcx, rcx
    jz .vars_print_val
    mov al, [rdi]
    call emit_char
    inc rdi
    dec rcx
    jmp .vars_print_char

.vars_print_val:
    mov al, '='
    call emit_char
    pop rsi
    push rsi
    mov rax, [rsi+8]        ; Value
    call print_number
    call newline

.vars_next:
    pop rsi
    pop rcx
    add rsi, 16
    dec rcx
    jnz .vars_loop

.vars_done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

word_swap:
    ; Swap TOS with second: exchange R14 and [R15-8]
    sub r15, 8
    xchg r14, [r15]
    add r15, 8
    ret

word_rot:
    ; Rotate top 3: ( a b c -- b c a )
    sub r15, 8
    mov rax, [r15]          ; b
    sub r15, 8
    mov rbx, [r15]          ; a
    mov [r15], rax          ; b
    add r15, 8
    mov [r15], r14          ; c
    add r15, 8
    mov r14, rbx            ; a becomes TOS
    ret

word_over:
    ; Copy second to TOS: ( a b -- a b a )
    mov [r15], r14          ; Push current TOS
    add r15, 8
    mov r14, [r15-16]       ; Second becomes new TOS
    ret

word_emit:
    ; Emit character from TOS
    mov rax, r14
    ; Also output to serial for debugging
    push rax
    call serial_putchar
    pop rax
    ; Check if newline (10)
    cmp rax, 10
    je .emit_newline
    ; Regular character
    call emit_char
    sub r15, 8
    mov r14, [r15]          ; Load new TOS
    ret
.emit_newline:
    ; Call proper newline function
    call newline
    sub r15, 8
    mov r14, [r15]          ; Load new TOS
    ret

word_cr:
    ; Newline (doesn't consume stack)
    call newline
    ret

word_exit:
    ; Exit SimplicityOS cleanly
    ; Print goodbye message
    push rax
    mov rax, str_goodbye
    call print_string
    call newline
    pop rax

    ; ACPI shutdown for QEMU (port 0x604, value 0x2000)
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax

    ; Fallback: halt loop if shutdown fails
.halt:
    hlt
    jmp .halt

word_fetch:
    ; Fetch: TOS is address, replace with value at address
    ; Validate address: below 1000 or beyond mapped 4MB is invalid
    cmp r14, 1000
    jl .fetch_invalid       ; Very small values likely wrong
    cmp r14, HEAP_MAX
    jae .fetch_invalid      ; Beyond mapped memory: would triple fault

    mov rax, [r14]
    mov r14, rax
    ret

.fetch_invalid:
    ; Return error STRING
    push rsi
    mov rsi, str_bad_addr
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

word_store:
    ; Store: ( value addr -- ) second=value, TOS=addr
    ; Validate address (below 1000 or beyond mapped 4MB is invalid)
    cmp r14, 1000
    jl .store_invalid
    cmp r14, HEAP_MAX
    jae .store_invalid

    mov rax, r14            ; Address
    sub r15, 8
    mov rbx, [r15]          ; Value
    mov [rax], rbx          ; Store value at address
    ; Pop second argument, check for underflow
    sub r15, 8
    cmp r15, [stack_floor]
    jl .store_empty
    mov r14, [r15]          ; New TOS
    ret
.store_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

.store_invalid:
    ; Return error, clean stack (pop both args with underflow check)
    sub r15, 16             ; Pop both at once
    cmp r15, [stack_floor]
    jge .store_inv_ok
    mov r15, [stack_floor]
.store_inv_ok:
    push rsi
    mov rsi, str_bad_addr
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

str_bad_addr: db '(bad address)', 0

word_c_fetch:
    ; c@ ( addr -- byte ) - Fetch byte from address
    cmp r14, 1000
    jl .c_fetch_invalid
    cmp r14, HEAP_MAX
    jae .c_fetch_invalid
    movzx rax, byte [r14]   ; Read byte, zero-extend to 64-bit
    mov r14, rax
    ret
.c_fetch_invalid:
    push rsi
    mov rsi, str_bad_addr
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

word_c_store:
    ; c! ( byte addr -- ) - Store byte at address
    cmp r14, 1000
    jl .c_store_invalid
    cmp r14, HEAP_MAX
    jae .c_store_invalid
    mov rax, r14            ; Address
    sub r15, 8
    mov rbx, [r15]          ; Byte value
    mov [rax], bl           ; Store only low byte
    sub r15, 8
    cmp r15, [stack_floor]
    jl .c_store_empty
    mov r14, [r15]          ; New TOS
    ret
.c_store_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret
.c_store_invalid:
    sub r15, 16             ; Drop addr and byte
    cmp r15, [stack_floor]
    jge .c_store_inv_ok
    mov r15, [stack_floor]
.c_store_inv_ok:
    push rsi
    mov rsi, str_bad_addr
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

word_allot:
    ; allot ( n -- addr ) - Allocate n bytes from heap, return address
    mov rcx, r14            ; Size to allocate
    call allocate_object    ; Returns address in RAX
    mov r14, rax            ; Push address to TOS
    ret

word_inspect:
    ; ? - Inspect reference from TOS, push STRING description
    mov rax, r14            ; Get TOS reference

    test rax, rax
    jz .push_unknown

    ; Check if dictionary or built-in
    cmp rax, DICT_SPACE
    jl .push_builtin

    ; Dictionary word - create STRING "(colon)"
    push rsi
    mov rsi, str_colon_ref
    call create_string_from_cstr
    pop rsi
    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

.push_builtin:
    push rsi
    mov rsi, str_builtin_ref
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

.push_unknown:
    push rsi
    mov rsi, str_unknown
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

str_colon_ref: db '(colon)', 0
str_builtin_ref: db '(built-in)', 0

word_eval:
    ; eval ( str-or-addr -- ) interpret text as source code.
    ; Accepts a heap STRING object or a raw buffer address of
    ; null-terminated text (e.g. an allot'ed file buffer).
    mov rax, r14

    ; Pop with underflow clamp
    sub r15, 8
    cmp r15, [stack_floor]
    jl .ev_empty
    mov r14, [r15]
    jmp .ev_go
.ev_empty:
    mov r15, [stack_floor]
    xor r14, r14
.ev_go:

    ; Address sanity
    cmp rax, 1000
    jl .ev_bad
    cmp rax, HEAP_MAX
    jae .ev_bad

    ; STRING object: text at +16. Anything else (allot'ed buffers
    ; included, which are heap addresses too): raw text at the address.
    cmp rax, HEAP_START
    jb .ev_raw
    cmp rax, [heap_ptr]
    jae .ev_raw
    cmp qword [rax], TYPE_STRING
    jne .ev_raw
    lea rsi, [rax+16]
    jmp .ev_run

.ev_raw:
    mov rsi, rax

.ev_run:
    push r13
    call interpret_line
    pop r13
    ret

.ev_bad:
    push rsi
    mov rsi, str_eval_bad
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

str_eval_bad: db '(eval needs string or buffer)', 0

word_execute:
    ; Execute code reference from TOS ( ref -- )
    mov rax, r14            ; Get reference from TOS

    ; Pop with underflow check
    sub r15, 8
    cmp r15, [stack_floor]
    jl .exec_underflow
    mov r14, [r15]
    jmp .exec_validate

.exec_underflow:
    mov r15, [stack_floor]
    xor r14, r14

.exec_validate:
    ; Dictionary word?
    cmp rax, DICT_SPACE
    jb .exec_try_builtin
    cmp rax, [dict_here]
    jae .invalid_ref        ; Beyond dictionary (heap objects land here)
    push rbx
    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rbx
    jne .invalid_ref

    ; Colon definition: run through the canonical interpreter so
    ; nested user words, literals and branches all behave identically
    push rsi
    add rax, 8              ; Skip code field
    mov rsi, rax
    call exec_definition
    pop rsi
    ret

.exec_try_builtin:
    ; Builtin: must point inside the kernel image
    cmp rax, 0x10000
    jb .invalid_ref
    cmp rax, kernel_image_end
    jae .invalid_ref
    call rax
    ret

.invalid_ref:
    ; Push error STRING for invalid reference
    push rsi
    mov rsi, str_invalid_ref
    call create_string_from_cstr
    pop rsi
    mov r14, rax            ; Error STRING becomes TOS
    ret

str_invalid_ref: db '(invalid reference)', 0

word_array:
    ; Create ARRAY object ( size -- array )
    mov rax, r14            ; Size from TOS

    ; Allocate: header(16) + size*8 bytes
    push rax
    shl rax, 3              ; size * 8
    add rax, 16
    mov rcx, rax
    call allocate_object
    pop rcx                 ; Restore size

    ; Fill header
    mov qword [rax], TYPE_ARRAY
    mov [rax+8], rcx

    ; Initialize array to zeros
    lea rdi, [rax+16]
    push rax
    mov rax, rcx
.zero_loop:
    mov qword [rdi], 0
    add rdi, 8
    dec rax
    jnz .zero_loop
    pop rax

    ; Push array object to TOS
    mov r14, rax
    ret

word_at:
    ; Array access ( array index -- value ) TOS=index
    mov rbx, r14            ; Index from TOS
    sub r15, 8
    mov rax, [r15]          ; Array from second

    ; Validate: heap object, TYPE_ARRAY, index in bounds
    cmp rax, HEAP_START
    jb .at_invalid
    cmp rax, [heap_ptr]
    jae .at_invalid
    cmp qword [rax], TYPE_ARRAY
    jne .at_invalid
    cmp rbx, [rax+8]
    jae .at_invalid         ; Unsigned: catches negative too

    ; Get element: array[index]
    lea rax, [rax + 16 + rbx*8]
    mov r14, [rax]          ; Value becomes TOS
    ; Untag bit-63-tagged literals (arrays built with [ ... ] keep tags)
    bt r14, 63
    jnc .at_done
    shl r14, 1
    sar r14, 1
.at_done:
    ret

.at_invalid:
    push rsi
    mov rsi, str_bad_index
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

word_put:
    ; Array store ( value array index -- ) TOS=index
    mov rbx, r14            ; Index from TOS
    sub r15, 8
    mov rcx, [r15]          ; Array from second
    sub r15, 8
    mov rax, [r15]          ; Value from third

    ; Validate: heap object, TYPE_ARRAY, index in bounds
    cmp rcx, HEAP_START
    jb .put_invalid
    cmp rcx, [heap_ptr]
    jae .put_invalid
    cmp qword [rcx], TYPE_ARRAY
    jne .put_invalid
    cmp rbx, [rcx+8]
    jae .put_invalid        ; Unsigned: catches negative too

    ; Store: array[index] = value
    lea rcx, [rcx + 16 + rbx*8]
    mov [rcx], rax

    ; Load new TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .put_empty
    mov r14, [r15]
    ret

.put_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

.put_invalid:
    ; Drop value slot too, push error string
    sub r15, 8
    cmp r15, [stack_floor]
    jge .put_inv_ok
    mov r15, [stack_floor]
.put_inv_ok:
    push rsi
    mov rsi, str_bad_index
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

str_bad_index: db '(bad array index)', 0

word_free:
    ; free ( obj -- ) return a heap object's memory to the free list
    mov rax, r14
    sub r15, 8
    cmp r15, [stack_floor]
    jl .free_uflow
    mov r14, [r15]
    jmp .free_go
.free_uflow:
    mov r15, [stack_floor]
    xor r14, r14
.free_go:
    ; Only live heap objects are freeable
    cmp rax, HEAP_START
    jb .free_done
    cmp rax, [heap_ptr]
    jae .free_done
    push rbx
    push rcx
    mov rbx, [rax]              ; type tag
    cmp rbx, TYPE_STRING
    jne .free_not_str
    mov rcx, [rax+8]
    add rcx, 17                 ; header + text + null
    jmp .free_have_size
.free_not_str:
    cmp rbx, TYPE_ARRAY
    jb .free_skip               ; unknown layout: leak rather than guess
    mov rcx, [rax+8]            ; arrays and user types: count
    shl rcx, 3
    add rcx, 16
.free_have_size:
    add rcx, 15
    and rcx, ~15
    mov [rax], rcx              ; block header: size
    mov rbx, [free_list]
    mov [rax+8], rbx            ; block header: next
    mov [free_list], rax
.free_skip:
    pop rcx
    pop rbx
.free_done:
    ret

word_len:
    ; LEN - Get length of array or string ( obj -- length )
    mov rax, r14

    ; Check if immediate (no length)
    cmp rax, HEAP_START
    jl .len_zero
    cmp rax, [heap_ptr]
    jge .len_zero

    ; Get type
    mov rbx, [rax]
    cmp rbx, TYPE_STRING
    je .len_string
    cmp rbx, TYPE_ARRAY
    je .len_array

    ; Unknown type - return 0
.len_zero:
    xor r14, r14
    ret

.len_string:
    ; String length is in header
    mov r14, [rax+8]
    ret

.len_array:
    ; Array length is in header
    mov r14, [rax+8]
    ret

; STR= - Compare two strings for equality ( str1 str2 -- flag )
; Returns 1 if equal, 0 if not equal
word_str_eq:
    ; str= ( str1 str2 -- flag )  net one pop; flag replaces TOS
    mov rsi, r14            ; str2 from TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .str_eq_uflow
    mov rdi, [r15]          ; str1 from second
    jmp .str_eq_go
.str_eq_uflow:
    mov r15, [stack_floor]
    xor r14, r14
    ret
.str_eq_go:

    ; Check if both are STRING type
    cmp qword [rdi], TYPE_STRING
    jne .str_eq_false
    cmp qword [rsi], TYPE_STRING
    jne .str_eq_false

    ; Check lengths match
    mov rax, [rdi+8]        ; str1 length
    cmp rax, [rsi+8]        ; str2 length
    jne .str_eq_false

    ; Compare bytes (data starts at offset 16)
    add rdi, 16             ; str1 data
    add rsi, 16             ; str2 data
    mov rcx, rax            ; length
    test rcx, rcx
    jz .str_eq_true         ; Empty strings are equal

.str_eq_loop:
    mov al, [rdi]
    cmp al, [rsi]
    jne .str_eq_false
    inc rdi
    inc rsi
    dec rcx
    jnz .str_eq_loop

.str_eq_true:
    mov r14, -1             ; True, consistent with other predicates
    ret

.str_eq_false:
    xor r14, r14
    ret

word_type:
    ; TYPE - Get type tag of value ( val -- type )
    ; Returns: 0=INT, 1=STRING, 2=REF, 3=ARRAY, 4+=user
    mov rax, r14

    ; Check if immediate integer
    cmp rax, HEAP_START
    jl .type_int
    cmp rax, [heap_ptr]
    jge .type_int

    ; Get type from object header
    mov r14, [rax]
    ret

.type_int:
    xor r14, r14              ; TYPE_INT = 0
    ret

word_type_new:
    ; TYPE-NEW - Allocate a new type tag ( -- type_tag )
    ; Returns next available type tag and increments counter
    push rax

    ; Get current tag
    mov rax, [next_type_tag]

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ; Increment for next allocation
    inc qword [next_type_tag]

    pop rax
    ret

word_type_name:
    ; TYPE-NAME - Associate name with type ( str type_tag -- )
    ; str must be a STRING object, type_tag is the type number
    ; Stack before: ... str type_tag (R14=type_tag)
    ; Memory layout: [data_stack]=str (depth 2, R15=data_stack+16)
    mov rbx, r14            ; RBX = type_tag

    ; Pop type_tag; str is now at [R15]
    sub r15, 8
    mov rax, [r15]          ; RAX = str

    ; Validate type_tag >= TYPE_USER_BASE
    cmp rbx, TYPE_USER_BASE
    jl .tn_invalid

    ; Calculate registry index
    sub rbx, TYPE_USER_BASE
    cmp rbx, 256
    jge .tn_invalid

    ; Store name STRING in registry
    lea rcx, [type_registry + rbx*8]
    mov [rcx], rax

.tn_invalid:
    ; Pop str, load new TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .tn_empty
    mov r14, [r15]          ; Load new TOS from memory
    ret

.tn_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_type_set:
    ; TYPE-SET - Change object's type tag ( obj new_type -- obj )
    ; Returns same object with modified type
    mov rax, r14            ; new_type from TOS
    mov rbx, [r15-8]        ; obj from second

    ; Validate obj is actually an object (not immediate)
    cmp rbx, HEAP_START
    jl .ts_invalid
    cmp rbx, [heap_ptr]
    jge .ts_invalid

    ; Set new type in object header
    mov [rbx], rax

    ; Pop type, keep obj as TOS
    sub r15, 8
    mov r14, rbx
    ret

.ts_invalid:
    ; Can't set type on immediate - return obj unchanged
    sub r15, 8
    mov r14, rbx
    ret

word_type_name_get:
    ; TYPE-NAME? - Get type name ( type_tag -- str|0 )
    ; Returns STRING name or 0 if unnamed
    mov rax, r14            ; type_tag

    ; Check built-in types first
    cmp rax, TYPE_INT
    je .tng_int
    cmp rax, TYPE_STRING
    je .tng_string
    cmp rax, TYPE_REF
    je .tng_ref
    cmp rax, TYPE_ARRAY
    je .tng_array

    ; User type - look up in registry
    cmp rax, TYPE_USER_BASE
    jl .tng_unknown
    sub rax, TYPE_USER_BASE
    cmp rax, 256
    jge .tng_unknown

    ; Get name from registry
    mov r14, [type_registry + rax*8]
    ret

.tng_int:
    push rsi
    mov rsi, str_type_int
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_string:
    push rsi
    mov rsi, str_type_string
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_ref:
    push rsi
    mov rsi, str_type_ref
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_array:
    push rsi
    mov rsi, str_type_array
    call create_string_from_cstr
    pop rsi
    mov r14, rax
    ret

.tng_unknown:
    xor r14, r14            ; Return 0 for unknown
    ret

str_type_int: db 'int', 0
str_type_string: db 'string', 0
str_type_ref: db 'ref', 0
str_type_array: db 'array', 0

word_screen_get:
    ; SCREEN-GET - Query VGA text mode parameters
    ; Returns ARRAY: ( width height cursor_x cursor_y )

    ; Create 4-element array
    push rax
    push rbx
    push rcx

    ; Allocate array
    mov rcx, 48             ; 16 (header) + 4*8 (data)
    call allocate_object

    ; Fill header
    mov qword [rax], TYPE_ARRAY
    mov qword [rax+8], 4    ; 4 elements

    ; Save array address
    mov r8, rax

    ; Get cursor position from VGA cursor variable
    mov rbx, [cursor]       ; Get cursor address
    sub rbx, 0xB8000        ; Offset from VGA start
    shr rbx, 1              ; Convert bytes to char position

    ; Divide by 80 to get row and col
    mov rax, rbx
    xor rdx, rdx
    mov rcx, 80
    div rcx                 ; RAX = row (Y), RDX = col (X)

    ; Store params in array
    mov qword [r8+16], 80   ; [0] Width
    mov qword [r8+24], 25   ; [1] Height
    mov qword [r8+32], rdx  ; [2] Cursor X (col)
    mov qword [r8+40], rax  ; [3] Cursor Y (row)

    ; Restore and push array to TOS
    pop rcx
    pop rbx
    pop rax                 ; Restore RAX

    mov [r15], r14          ; Push old TOS
    add r15, 8
    mov r14, r8             ; Array becomes new TOS
    ret

word_screen_set:
    ; SCREEN-SET - Move cursor to x,y ( x y -- )
    ; TOS = y, second = x
    mov rax, r14            ; RAX = y
    sub r15, 8
    mov rbx, [r15]          ; RBX = x

    ; Calculate VGA offset: (y * 80 + x) * 2 + 0xB8000
    imul rax, 80            ; y * 80
    add rax, rbx            ; + x
    shl rax, 1              ; * 2 (char + attr)
    add rax, 0xB8000

    ; Update cursor
    mov [cursor], rax
    call update_hw_cursor

    ; Pop both, load new TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .ss_empty            ; jl not jle: R15==data_stack means valid item at [R15]
    mov r14, [r15]
    ret
.ss_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_screen_char:
    ; SCREEN-CHAR - Put char at x,y with color ( char color x y -- )
    ; TOS = y, then x, color, char
    mov rax, r14            ; RAX = y
    sub r15, 8
    mov rbx, [r15]          ; RBX = x
    sub r15, 8
    mov rcx, [r15]          ; RCX = color
    sub r15, 8
    mov rdx, [r15]          ; RDX = char

    ; Calculate VGA offset: (y * 80 + x) * 2 + 0xB8000
    imul rax, 80
    add rax, rbx
    shl rax, 1
    add rax, 0xB8000

    ; Write char and color
    mov [rax], dl           ; Character
    mov [rax+1], cl         ; Color attribute

    ; Pop all four, load new TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .sc_empty            ; jl not jle: R15==data_stack means valid item at [R15]
    mov r14, [r15]
    ret
.sc_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_cursor_hide:
    ; CURSOR-HIDE - Disable VGA text cursor ( -- )
    push rdx
    mov al, 0x0A
    mov dx, 0x3D4
    out dx, al
    mov al, 0x20            ; Bit 5 set = cursor disabled
    mov dx, 0x3D5
    out dx, al
    pop rdx
    ret

word_cursor_show:
    ; CURSOR-SHOW - Enable VGA text cursor ( -- )
    push rdx
    mov al, 0x0A
    mov dx, 0x3D4
    out dx, al
    mov al, 13              ; Start scanline 13, cursor enabled
    mov dx, 0x3D5
    out dx, al
    pop rdx
    ret

word_screen_clear:
    ; SCREEN-CLEAR - Clear screen ( -- )
    ; Uses black background (color 0)

    ; Clear all 80x25 characters with spaces on black
    mov rdi, 0xB8000
    mov rax, 0x0020002000200020  ; 4 spaces with black background (attr 0)

    mov rcx, 500            ; 2000 chars / 4 = 500 qwords
.clear_loop:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .clear_loop

    ; Reset cursor to top-left
    mov qword [cursor], 0xB8000
    call update_hw_cursor

    ; No argument to pop - just return
    ret
.scl_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_screen_scroll:
    ; SCREEN-SCROLL - Scroll screen up n lines ( n -- )
    mov rcx, r14            ; RCX = lines to scroll

    ; Validate: unsigned so negative n cannot pass; 0 is a no-op
    test rcx, rcx
    jz .scroll_done
    cmp rcx, 25
    jae .scroll_clear       ; If >= 25 (or negative), just clear

    ; Calculate bytes to copy: (25 - n) * 80 * 2
    mov rax, 25
    sub rax, rcx
    imul rax, 160           ; (25-n) * 80 * 2

    ; Source: line n = 0xB8000 + n * 160
    mov rsi, rcx
    imul rsi, 160
    add rsi, 0xB8000

    ; Dest: line 0
    mov rdi, 0xB8000

    ; Copy (rax bytes, but we'll do qwords)
    push rcx
    mov rcx, rax
    shr rcx, 3              ; Bytes to qwords
.copy_loop:
    mov rax, [rsi]
    mov [rdi], rax
    add rsi, 8
    add rdi, 8
    dec rcx
    jnz .copy_loop
    pop rcx

    ; Clear bottom n lines
    ; RDI is now at start of area to clear
    imul rcx, 160           ; Bytes to clear
    shr rcx, 3              ; Qwords
    mov rax, 0x0F200F200F200F20  ; Spaces with white-on-black
.clear_bottom:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .clear_bottom

    jmp .scroll_done

.scroll_clear:
    ; Clear entire screen
    mov rdi, 0xB8000
    mov rcx, 500
    mov rax, 0x0F200F200F200F20
.full_clear:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .full_clear

.scroll_done:
    ; Pop n, load new TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .scr_empty               ; jl not jle: R15==data_stack means valid item at [R15]
    mov r14, [r15]
    ret
.scr_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_screen_line_shift:
    ; SCREEN-LINE-SHIFT - Shift line content left from x,y ( x y -- )
    ; Shifts chars from x+1 to column 79 left by 1, puts space at end
    push rbx
    push rcx
    push rsi
    push rdi

    ; TOS = y, second = x
    mov rax, r14            ; RAX = y
    sub r15, 8
    mov rbx, [r15]          ; RBX = x

    ; Calculate start address: (y * 80 + x) * 2 + 0xB8000
    imul rax, 80
    add rax, rbx
    shl rax, 1
    add rax, 0xB8000
    mov rdi, rax            ; RDI = destination (current pos)
    lea rsi, [rax + 2]      ; RSI = source (next char)

    ; Calculate chars to shift: 79 - x
    mov rcx, 79
    sub rcx, rbx
    jle .sls_done           ; Nothing to shift if at end

    ; Shift characters left (copy char+attr pairs)
.sls_shift:
    mov ax, [rsi]           ; Read char+attr
    mov [rdi], ax           ; Write to destination
    add rsi, 2
    add rdi, 2
    dec rcx
    jnz .sls_shift

    ; Put space at end of line (column 79 of this row)
    mov byte [rdi], ' '
    ; Keep existing attribute

.sls_done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx

    ; Pop both args, load new TOS
    sub r15, 8
    cmp r15, [stack_floor]
    jl .sls_empty               ; jl not jle: R15==data_stack means valid item at [R15]
    mov r14, [r15]
    ret
.sls_empty:
    mov r15, [stack_floor]
    xor r14, r14
    ret

word_key:
    ; KEY - Wait for keypress ( -- char )
    call wait_key

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

word_key_check:
    ; KEY? - Check if key available, return key or 0 ( -- key|0 )
    call check_key

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

word_key_escape:
    ; KEY-ESCAPE - Push escape key constant ( -- 256 )
    mov [r15], r14
    add r15, 8
    mov r14, KEY_ESCAPE
    ret

word_key_up:
    ; KEY-UP - Push up arrow constant ( -- 257 )
    mov [r15], r14
    add r15, 8
    mov r14, KEY_UP
    ret

word_key_down:
    ; KEY-DOWN - Push down arrow constant ( -- 258 )
    mov [r15], r14
    add r15, 8
    mov r14, KEY_DOWN
    ret

word_key_left:
    ; KEY-LEFT - Push left arrow constant ( -- 259 )
    mov [r15], r14
    add r15, 8
    mov r14, KEY_LEFT
    ret

word_key_right:
    ; KEY-RIGHT - Push right arrow constant ( -- 260 )
    mov [r15], r14
    add r15, 8
    mov r14, KEY_RIGHT
    ret

word_key_delete:
    ; KEY-DELETE - Push delete key constant ( -- 265 )
    mov [r15], r14
    add r15, 8
    mov r14, KEY_DELETE
    ret

word_key_backspace:
    ; KEY-BACKSPACE - Push backspace constant ( -- 8 )
    mov [r15], r14
    add r15, 8
    mov r14, 8
    ret

; Control flow words - IMMEDIATE (execute during compilation)
; These use the control flow stack (reusing part of return stack)
; compile_ptr points to current compilation position

word_if:
    ; IF - compile ZBRANCH with placeholder, push address for THEN/ELSE
    ; Must be in compile mode
    cmp byte [compile_mode], 0
    je .if_error

    inc byte [ctl_items]        ; Track control-stack balance
    mov rbx, [compile_ptr]
    mov qword [rbx], ZBRANCH    ; Compile ZBRANCH
    add rbx, 8
    ; Push address of placeholder to control stack (using return stack)
    mov [rbp], rbx              ; Save location of offset
    sub rbp, 8
    mov qword [rbx], 0          ; Placeholder offset
    add rbx, 8
    mov [compile_ptr], rbx
    ret
.if_error:
    ret

word_then:
    ; THEN - resolve forward branch from IF or ELSE
    cmp byte [compile_mode], 0
    je .then_error
    cmp byte [ctl_items], 1
    jb .then_error              ; Unbalanced: nothing to resolve
    dec byte [ctl_items]

    ; Pop address from control stack
    add rbp, 8
    mov rbx, [rbp]              ; Address of placeholder
    mov rax, [compile_ptr]
    sub rax, rbx                ; Calculate offset
    sub rax, 8                  ; Adjust for already past placeholder
    mov [rbx], rax              ; Fill in the offset
    ret
.then_error:
    ret

word_else:
    ; ELSE - compile BRANCH, resolve IF's placeholder, push new placeholder
    cmp byte [compile_mode], 0
    je .else_error
    cmp byte [ctl_items], 1
    jb .else_error              ; Unbalanced: no IF open

    mov rcx, [compile_ptr]
    mov qword [rcx], BRANCH     ; Compile unconditional branch
    add rcx, 8

    ; Pop IF's placeholder, push ELSE's placeholder
    add rbp, 8
    mov rbx, [rbp]              ; IF's placeholder address

    mov [rbp], rcx              ; Push ELSE's placeholder address
    sub rbp, 8

    mov qword [rcx], 0          ; ELSE's placeholder
    add rcx, 8
    mov [compile_ptr], rcx

    ; Resolve IF's branch (to here, after ELSE's branch instruction)
    mov rax, [compile_ptr]
    sub rax, rbx
    sub rax, 8
    mov [rbx], rax
    ret
.else_error:
    ret

word_begin:
    ; BEGIN - mark loop start, push address
    cmp byte [compile_mode], 0
    je .begin_error
    inc byte [ctl_items]        ; Track control-stack balance

    ; Push current compile address to control stack
    mov rax, [compile_ptr]
    mov [rbp], rax
    sub rbp, 8
    ret
.begin_error:
    ret

word_until:
    ; UNTIL - compile ZBRANCH back to BEGIN
    cmp byte [compile_mode], 0
    je .until_error
    cmp byte [ctl_items], 1
    jb .until_error             ; Unbalanced: no BEGIN open
    dec byte [ctl_items]

    ; Pop loop start address
    add rbp, 8
    mov rbx, [rbp]              ; BEGIN address

    mov rcx, [compile_ptr]
    mov qword [rcx], ZBRANCH    ; Compile ZBRANCH
    add rcx, 8

    ; Calculate backward offset (negative)
    mov rax, rbx
    sub rax, rcx
    sub rax, 8                  ; Adjust for offset cell itself
    mov [rcx], rax
    add rcx, 8
    mov [compile_ptr], rcx
    ret
.until_error:
    ret

word_while:
    ; WHILE - like IF but inside a loop, push placeholder
    cmp byte [compile_mode], 0
    je .while_error
    cmp byte [ctl_items], 1
    jb .while_error             ; Unbalanced: no BEGIN open
    inc byte [ctl_items]

    mov rbx, [compile_ptr]
    mov qword [rbx], ZBRANCH
    add rbx, 8
    mov [rbp], rbx              ; Push placeholder address
    sub rbp, 8
    mov qword [rbx], 0          ; Placeholder
    add rbx, 8
    mov [compile_ptr], rbx
    ret
.while_error:
    ret

word_repeat:
    ; REPEAT - compile BRANCH back to BEGIN, resolve WHILE
    cmp byte [compile_mode], 0
    je .repeat_error
    cmp byte [ctl_items], 2
    jb .repeat_error            ; Unbalanced: needs BEGIN and WHILE
    sub byte [ctl_items], 2

    ; Pop WHILE placeholder
    add rbp, 8
    mov rbx, [rbp]              ; WHILE's placeholder

    ; Pop BEGIN address
    add rbp, 8
    mov rdx, [rbp]              ; BEGIN address

    mov rcx, [compile_ptr]
    mov qword [rcx], BRANCH     ; Compile unconditional branch
    add rcx, 8

    ; Calculate backward offset to BEGIN
    mov rax, rdx
    sub rax, rcx
    sub rax, 8
    mov [rcx], rax
    add rcx, 8
    mov [compile_ptr], rcx

    ; Resolve WHILE's branch (to here, after loop)
    mov rax, [compile_ptr]
    sub rax, rbx
    sub rax, 8
    mov [rbx], rax
    ret
.repeat_error:
    ret

word_again:
    ; AGAIN - compile unconditional BRANCH back to BEGIN
    cmp byte [compile_mode], 0
    je .again_error
    cmp byte [ctl_items], 1
    jb .again_error             ; Unbalanced: no BEGIN open
    dec byte [ctl_items]

    ; Pop loop start address
    add rbp, 8
    mov rbx, [rbp]              ; BEGIN address

    mov rcx, [compile_ptr]
    mov qword [rcx], BRANCH     ; Compile BRANCH
    add rcx, 8

    ; Calculate backward offset
    mov rax, rbx
    sub rax, rcx
    sub rax, 8
    mov [rcx], rax
    add rcx, 8
    mov [compile_ptr], rcx
    ret
.again_error:
    ret

; App stack isolation words
; Allow apps to run with their own isolated stack context

word_app_enter:
    ; APP-ENTER - Save current stack, start fresh app stack ( -- )
    ; Saves R14 (TOS), R15 (stack ptr) to app_saved_*
    ; Sets up fresh stack at app_stack for the app to use

    ; Save current stack state
    mov [app_saved_tos], r14
    mov [app_saved_sp], r15
    mov qword [app_active], 1

    ; Set up fresh app stack
    mov qword [stack_floor], app_stack
    mov r15, app_stack
    xor r14, r14                ; Empty TOS
    ret

word_app_exit:
    ; APP-EXIT - Restore saved stack, return to REPL ( -- )
    ; Restores R14, R15 from saved state

    ; Check if we're in an app
    cmp qword [app_active], 0
    je .not_in_app

    ; Restore saved stack state
    mov qword [stack_floor], data_stack
    mov r14, [app_saved_tos]
    mov r15, [app_saved_sp]
    mov qword [app_active], 0

    ; Reset interpreter modes: an app that ended mid-compile must not
    ; leave the REPL silently compiling every later line
    mov byte [compile_mode], 0
    mov byte [array_mode], 0
    mov byte [ctl_items], 0
    ret

.not_in_app:
    ; Not in app - push error string
    push rsi
    mov rsi, str_not_in_app
    call create_string_from_cstr
    pop rsi
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

word_app_stack:
    ; APP-STACK - Push current stack base address ( -- addr )
    ; Returns app_stack if in app, data_stack otherwise

    mov rax, data_stack
    cmp qword [app_active], 0
    je .use_main
    mov rax, app_stack
.use_main:
    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

word_app_depth:
    ; APP-DEPTH - Push current stack depth ( -- n )
    ; Calculate: (R15 - stack_base) / 8

    mov rax, data_stack
    cmp qword [app_active], 0
    je .use_main_depth
    mov rax, app_stack
.use_main_depth:
    mov rbx, r15
    sub rbx, rax
    shr rbx, 3                  ; Divide by 8

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rbx
    ret

str_not_in_app: db '(not in app)', 0

; ============================================================
; DISK I/O - IDE PIO mode disk access
; ============================================================
; disk-read ( sector addr -- ) - Read 512 bytes from sector to address
; disk-write ( addr sector -- ) - Write 512 bytes from address to sector
; Uses primary IDE controller at ports 0x1F0-0x1F7
; ============================================================

; IDE port definitions
IDE_DATA        equ 0x1F0
IDE_SECTOR_CNT  equ 0x1F2
IDE_LBA_LOW     equ 0x1F3
IDE_LBA_MID     equ 0x1F4
IDE_LBA_HIGH    equ 0x1F5
IDE_DRIVE_HEAD  equ 0x1F6
IDE_STATUS      equ 0x1F7
IDE_COMMAND     equ 0x1F7

IDE_CMD_READ    equ 0x20
IDE_CMD_WRITE   equ 0x30

; word_disk_read - Read 512 bytes from disk sector
; Stack: ( sector addr -- )
word_disk_read:
    ; Get addr from TOS (r14), sector from second (stack)
    mov rdi, r14            ; addr
    sub r15, 8
    mov rax, [r15]          ; sector
    sub r15, 8              ; pop second item too
    cmp r15, [stack_floor]
    jl .dr_uflow
    mov r14, [r15]          ; new TOS
    jmp .dr_go
.dr_uflow:
    mov r15, [stack_floor]
    xor r14, r14
.dr_go:
    call disk_read_direct
    ret

; word_disk_write - Write 512 bytes to disk sector
; Stack: ( addr sector -- )
word_disk_write:
    ; Get sector from TOS (r14), addr from second (stack)
    mov rax, r14            ; sector
    sub r15, 8
    mov rsi, [r15]          ; addr
    sub r15, 8              ; pop second item too
    cmp r15, [stack_floor]
    jl .dw_uflow
    mov r14, [r15]          ; new TOS
    jmp .dw_go
.dw_uflow:
    mov r15, [stack_floor]
    xor r14, r14
.dw_go:
    call disk_write_direct
    ret

; ============================================================
; SAVE - Save user definitions source to disk
; Stack: ( -- )
; Writes def_src_buffer (8 sectors = 4KB) to DEF_SAVE_SECTOR+
; ============================================================
word_save:
    push rbx
    push rcx
    push rdx
    push rsi

    ; Print status
    mov rax, str_saving
    call print_string

    ; Write 8 sectors (4KB total)
    mov rbx, DEF_SAVE_SECTOR    ; Starting sector
    mov rsi, def_src_buffer     ; Source address
    mov rcx, 8                  ; 8 sectors
.save_sector:
    push rcx
    push rsi
    push rbx

    ; Direct disk write (sector in EBX, source in RSI)
    mov eax, ebx                ; Sector number
    call disk_write_direct

    pop rbx
    pop rsi
    pop rcx

    add rsi, 512                ; Next 512 bytes
    inc rbx                     ; Next sector
    dec rcx
    jnz .save_sector

    ; Print done
    mov rax, str_done
    call print_string
    call newline

    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

str_saving: db 'Saving...', 0
str_done: db ' ok', 0

; ============================================================
; RESTORE - Load user definitions from disk and interpret
; Stack: ( -- )
; Reads from DEF_SAVE_SECTOR+ into def_src_buffer, then interprets
; ============================================================
word_restore:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Print status
    mov rax, str_loading
    call print_string

    ; Read 8 sectors (4KB total)
    mov rbx, DEF_SAVE_SECTOR    ; Starting sector
    mov rdi, def_src_buffer     ; Destination address
    mov rcx, 8                  ; 8 sectors
.load_sector:
    push rcx
    push rdi
    push rbx

    ; Direct disk read (sector in EBX, dest in RDI)
    mov eax, ebx                ; Sector number
    call disk_read_direct

    pop rbx
    pop rdi
    pop rcx

    add rdi, 512                ; Next 512 bytes
    inc rbx                     ; Next sector
    dec rcx
    jnz .load_sector

    ; Interpret loaded definitions
    mov rsi, def_src_buffer
    call interpret_source

    ; Update def_src_ptr to end of loaded text
    mov rsi, def_src_buffer
.find_end:
    cmp byte [rsi], 0
    je .found_end
    inc rsi
    jmp .find_end
.found_end:
    mov [def_src_ptr], rsi

    ; Print done
    mov rax, str_done
    call print_string
    call newline

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

str_loading: db 'Restoring...', 0

; ============================================================
; INFO - Show definition of a word
; Stack: ( "name" -- )
; Shows stack effect and description for builtins,
; or source for user-defined words
; ============================================================
word_info:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    ; Get name STRING from TOS
    mov rax, r14
    cmp qword [rax], TYPE_STRING
    jne .info_not_string

    ; Get name pointer and length
    lea rdi, [rax+16]           ; Name string data
    ; Calculate name length
    xor rcx, rcx
.info_namelen:
    cmp byte [rdi+rcx], 0
    je .info_gotlen
    inc rcx
    jmp .info_namelen
.info_gotlen:
    ; RCX = name length, RDI = name string
    mov r8, rcx                 ; Save length in R8

    ; First check builtin table
    mov rsi, builtin_info_table
.info_check_builtin:
    cmp byte [rsi], 0           ; End of table?
    je .info_try_user

    ; Get builtin name length
    push rdi
    push rcx
    mov rcx, r8                 ; Restore length
    xor rbx, rbx
.info_builtin_len:
    cmp byte [rsi+rbx], 0
    je .info_builtin_gotlen
    inc rbx
    jmp .info_builtin_len
.info_builtin_gotlen:
    ; RBX = builtin name length
    cmp rbx, rcx
    jne .info_next_builtin

    ; Compare names
    push rsi
.info_cmp_builtin:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .info_builtin_mismatch
    inc rsi
    inc rdi
    dec rcx
    jnz .info_cmp_builtin

    ; Match! Print the description (follows the name + null)
    pop rsi
    add rsi, rbx
    inc rsi                     ; Skip null after name
    pop rcx
    pop rdi

    ; Print description
    mov rax, rsi
    call print_string
    call newline
    jmp .info_done

.info_builtin_mismatch:
    pop rsi
    pop rcx
    pop rdi
    jmp .info_skip_name

.info_next_builtin:
    ; Skip to next entry (name + null + desc + null)
    pop rcx
    pop rdi
.info_skip_name:
    cmp byte [rsi], 0
    je .info_skip_desc_start
    inc rsi
    jmp .info_skip_name
.info_skip_desc_start:
    inc rsi                     ; Skip null
.info_skip_desc:
    cmp byte [rsi], 0
    je .info_next_entry
    inc rsi
    jmp .info_skip_desc
.info_next_entry:
    inc rsi                     ; Skip null
    jmp .info_check_builtin

.info_try_user:
    ; Search def_src_buffer for user-defined word
    mov rcx, r8                 ; Restore length
    mov rsi, def_src_buffer
.info_search:
    cmp byte [rsi], 0
    je .info_not_found

    ; Check if this line matches: "name" { ... } define
    ; or : name ... ;
    push rsi
    push rdi
    push rcx

    ; Skip leading whitespace
.info_skipws:
    cmp byte [rsi], ' '
    jne .info_check_quote
    inc rsi
    jmp .info_skipws

.info_check_quote:
    ; Check for "name" { ... } define format
    cmp byte [rsi], '"'
    jne .info_check_colon
    inc rsi                     ; Skip opening quote

    ; Compare name
.info_cmp_quoted:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .info_next_line
    inc rsi
    inc rdi
    dec rcx
    jnz .info_cmp_quoted

    ; Check for closing quote
    cmp byte [rsi], '"'
    jne .info_next_line
    jmp .info_found

.info_check_colon:
    ; Check for : name format
    cmp byte [rsi], ':'
    jne .info_next_line
    inc rsi
    ; Skip space after colon
    cmp byte [rsi], ' '
    jne .info_next_line
    inc rsi

    ; Compare name
.info_cmp_colon:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .info_next_line
    inc rsi
    inc rdi
    dec rcx
    jnz .info_cmp_colon

    ; Check for space or end after name
    cmp byte [rsi], ' '
    je .info_found
    cmp byte [rsi], 0
    je .info_found
    cmp byte [rsi], 10
    je .info_found
    jmp .info_next_line

.info_found:
    pop rcx
    pop rdi
    pop rsi

    ; Print this definition line
    push rsi
.info_print_line:
    lodsb
    cmp al, 0
    je .info_print_done
    cmp al, 10
    je .info_print_done
    call emit_char
    jmp .info_print_line
.info_print_done:
    call newline
    pop rsi
    jmp .info_done

.info_next_line:
    pop rcx
    pop rdi
    pop rsi
    ; Advance to next line
.info_skip_line:
    cmp byte [rsi], 0
    je .info_not_found
    cmp byte [rsi], 10
    je .info_got_newline
    inc rsi
    jmp .info_skip_line
.info_got_newline:
    inc rsi
    mov rcx, r8                 ; Restore length
    jmp .info_search

.info_not_found:
    mov rax, str_info_notfound
    call print_string
    call newline
    jmp .info_done

.info_not_string:
    mov rax, str_info_needstr
    call print_string
    call newline

.info_done:
    ; Pop name from stack
    sub r15, 8
    mov r14, [r15]

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

str_info_notfound: db 'No definition found', 0
str_info_needstr: db 'info requires STRING', 0

; Builtin info table: name, null, description with stack effect, null
; Terminated by double null
builtin_info_table:
    db '+', 0, '( a b -- a+b ) Add two numbers', 0
    db '-', 0, '( a b -- a-b ) Subtract b from a', 0
    db '*', 0, '( a b -- a*b ) Multiply two numbers', 0
    db '/', 0, '( a b -- a/b ) Divide a by b', 0
    db 'mod', 0, '( a b -- a%b ) Remainder of a/b', 0
    db '=', 0, '( a b -- flag ) True if equal', 0
    db '<', 0, '( a b -- flag ) True if a < b', 0
    db '>', 0, '( a b -- flag ) True if a > b', 0
    db '<>', 0, '( a b -- flag ) True if not equal', 0
    db '<=', 0, '( a b -- flag ) True if a <= b', 0
    db '>=', 0, '( a b -- flag ) True if a >= b', 0
    db '0=', 0, '( n -- flag ) True if zero', 0
    db 'and', 0, '( a b -- a&b ) Bitwise AND', 0
    db 'or', 0, '( a b -- a|b ) Bitwise OR', 0
    db 'xor', 0, '( a b -- a^b ) Bitwise XOR', 0
    db 'not', 0, '( a -- ~a ) Bitwise NOT', 0
    db '.', 0, '( x -- ) Print top of stack', 0
    db '.s', 0, '( -- ) Print entire stack', 0
    db 'dup', 0, '( a -- a a ) Duplicate top', 0
    db 'drop', 0, '( a -- ) Discard top', 0
    db 'clstk', 0, '( ... -- ) Clear entire stack', 0
    db 'swap', 0, '( a b -- b a ) Swap top two', 0
    db 'rot', 0, '( a b c -- b c a ) Rotate third to top', 0
    db 'over', 0, '( a b -- a b a ) Copy second to top', 0
    db '@', 0, '( addr -- value ) Fetch from memory', 0
    db '!', 0, '( value addr -- ) Store to memory', 0
    db 'emit', 0, '( char -- ) Output character', 0
    db 'cr', 0, '( -- ) Output newline', 0
    db ':', 0, '( -- ) Begin word definition', 0
    db ';', 0, '( -- ) End word definition', 0
    db '~', 0, '( -- xt ) Get execution token of next word', 0
    db '?', 0, '( addr -- ) Fetch and print', 0
    db 'words', 0, '( -- str ) List all words', 0
    db 'execute', 0, '( xt -- ) Execute token', 0
    db 'len', 0, '( str -- n ) String length', 0
    db 'type', 0, '( obj -- n ) Get type tag', 0
    db 'array', 0, '( n -- arr ) Create array of size n', 0
    db 'at', 0, '( arr i -- val ) Get array element', 0
    db 'put', 0, '( val arr i -- ) Set array element', 0
    db '[', 0, '( -- ) Begin array literal', 0
    db ']', 0, '( -- arr ) End array literal', 0
    db 'type-new', 0, '( -- tag ) Allocate new type tag', 0
    db 'type-name', 0, '( str tag -- ) Name a type', 0
    db 'type-set', 0, '( obj tag -- obj ) Set object type', 0
    db 'type-name?', 0, '( tag -- str ) Get type name', 0
    db 'if', 0, '( flag -- ) Conditional branch', 0
    db 'then', 0, '( -- ) End conditional', 0
    db 'else', 0, '( -- ) Alternative branch', 0
    db 'begin', 0, '( -- ) Start loop', 0
    db 'until', 0, '( flag -- ) Loop until true', 0
    db 'while', 0, '( flag -- ) Loop while true', 0
    db 'repeat', 0, '( -- ) End while loop', 0
    db 'again', 0, '( -- ) Infinite loop back', 0
    db 'key', 0, '( -- char ) Wait for keypress', 0
    db 'key?', 0, '( -- flag ) Check if key available', 0
    db 'disk-read', 0, '( sector addr -- ) Read disk sector to addr', 0
    db 'disk-write', 0, '( addr sector -- ) Write to disk', 0
    db 'ed', 0, '( -- ) Mini text editor', 0
    db 'save', 0, '( -- ) Save definitions to disk', 0
    db 'restore', 0, '( -- ) Load definitions from disk', 0
    db 'info', 0, '( "name" -- ) Show word info', 0
    db 'remove', 0, '( "name" -- ) Remove user word', 0
    db 'define', 0, '( "name" { body } -- ) Define new word', 0
    db 'sort', 0, '( array -- array ) Sort array in place', 0
    db 'eval', 0, '( str -- ) Interpret string as source code', 0
    db 's>f', 0, '( n -- f ) Integer to float', 0
    db 'f>s', 0, '( f -- n ) Float to integer, truncated', 0
    db 'f+', 0, '( a b -- a+b ) Float add', 0
    db 'f-', 0, '( a b -- a-b ) Float subtract', 0
    db 'f*', 0, '( a b -- a*b ) Float multiply', 0
    db 'f/', 0, '( a b -- a/b ) Float divide', 0
    db 'f<', 0, '( a b -- flag ) Float less-than', 0
    db 'f>', 0, '( a b -- flag ) Float greater-than', 0
    db 'f=', 0, '( a b -- flag ) Float equal', 0
    db 'f.', 0, '( f -- ) Print float with fix decimals', 0
    db 'fix', 0, '( n -- ) Set f. decimals (0-9)', 0
    db 'fpi', 0, '( -- pi ) Push pi', 0
    db 'fneg', 0, '( f -- -f ) Negate float', 0
    db 'fabs', 0, '( f -- |f| ) Float absolute value', 0
    db 'fsqrt', 0, '( f -- sqrt ) Square root', 0
    db 'fsin', 0, '( f -- sin ) Sine, radians', 0
    db 'fcos', 0, '( f -- cos ) Cosine, radians', 0
    db 'ftan', 0, '( f -- tan ) Tangent, radians', 0
    db 'fatan', 0, '( f -- atan ) Arc tangent', 0
    db 'fln', 0, '( f -- ln ) Natural log', 0
    db 'flog', 0, '( f -- log ) Base-10 log', 0
    db 'fexp', 0, '( f -- e^f ) Exponential', 0
    db 'fpow', 0, '( a b -- a^b ) Power, a positive', 0
    db 0  ; End of table

; ============================================================
; REMOVE - Remove a user-defined word
; Stack: ( "name" -- )
; Unlinks word from dictionary and removes from def_src_buffer
; ============================================================
word_remove:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Get name STRING from TOS
    mov rax, r14
    cmp qword [rax], TYPE_STRING
    jne .remove_not_string

    ; Get name pointer
    lea rdi, [rax+16]           ; Name string data
    ; Calculate name length
    xor rcx, rcx
.remove_namelen:
    cmp byte [rdi+rcx], 0
    je .remove_gotlen
    inc rcx
    jmp .remove_namelen
.remove_gotlen:
    ; RCX = name length, RDI = name string

    ; Search dictionary for this word
    mov rsi, [dict_latest]
    test rsi, rsi
    jz .remove_not_found

    xor r8, r8                  ; R8 = previous entry (0 = head)
.remove_search:
    ; RSI points to current entry
    mov r9, [rsi]               ; R9 = link to next entry

    ; Check name length at offset 8
    movzx rbx, byte [rsi+8]
    cmp rbx, rcx
    jne .remove_next

    ; Compare names
    push rdi
    push rcx
    lea rdx, [rsi+9]            ; Name in dict entry
.remove_cmp:
    mov al, [rdx]
    mov bl, [rdi]
    cmp al, bl
    jne .remove_cmp_fail
    inc rdx
    inc rdi
    dec rcx
    jnz .remove_cmp

    ; Found it!
    pop rcx
    pop rdi

    ; Unlink: set previous->link = this->link
    test r8, r8
    jz .remove_is_head
    ; R8 = previous entry, set its link to R9
    mov [r8], r9
    jmp .remove_unlinked

.remove_is_head:
    ; Removing head: dict_latest = this->link
    mov [dict_latest], r9

.remove_unlinked:
    ; Now remove from def_src_buffer
    ; Search for and remove the line
    call remove_def_from_buffer

    mov rax, str_removed
    call print_string
    call newline
    jmp .remove_done

.remove_cmp_fail:
    pop rcx
    pop rdi

.remove_next:
    mov r8, rsi                 ; Previous = current
    mov rsi, r9                 ; Current = next
    test rsi, rsi
    jnz .remove_search

.remove_not_found:
    mov rax, str_remove_notfound
    call print_string
    call newline
    jmp .remove_done

.remove_not_string:
    mov rax, str_remove_needstr
    call print_string
    call newline

.remove_done:
    ; Pop name from stack
    sub r15, 8
    mov r14, [r15]

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

str_removed: db 'Removed', 0
str_remove_notfound: db 'Word not found', 0
str_remove_needstr: db 'remove requires STRING', 0

; sort_is_obj: R11 = value; CF=1 if heap object; clobbers only flags
sort_is_obj:
    cmp r11, HEAP_START
    jl .sio_no                  ; Signed: negative values are ints
    cmp r11, [heap_ptr]
    jge .sio_no
    stc
    ret
.sio_no:
    clc
    ret

; ============================================================
; SORT - Sort an array in place
; Stack: ( array -- array )
; Sorts numerically (integers) or alphabetically (strings)
; ============================================================
word_sort:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r12
    push r13

    ; Get array from TOS (R14)
    mov rax, r14
    cmp qword [rax], TYPE_ARRAY
    jne .sort_done              ; Not an array, just return

    ; Get array count and data pointer
    mov r8, [rax+8]             ; R8 = count
    lea r9, [rax+16]            ; R9 = data start

    ; Need at least 2 elements to sort
    cmp r8, 2
    jl .sort_done

    ; Simple bubble sort for integers
.sort_outer:
    xor r10, r10                ; swapped = false
    mov rcx, 1                  ; i = 1

.sort_inner:
    cmp rcx, r8
    jge .sort_pass_done

    ; Calculate offset for elements[i-1]
    mov rax, rcx
    dec rax
    shl rax, 3                  ; rax = (i-1) * 8

    ; Get elements
    mov rsi, [r9 + rax]         ; elem1 = arr[i-1]
    mov rdi, [r9 + rax + 8]     ; elem2 = arr[i]

    ; Determine comparison type
    ; Check if both are immediate integers (heap-range test, signed)
    mov r11, rsi
    call sort_is_obj
    jc .sort_obj_cmp
    mov r11, rdi
    call sort_is_obj
    jc .sort_obj_cmp

    ; Both immediate integers - simple numeric compare
    cmp rsi, rdi
    jle .sort_no_swap
    jmp .sort_do_swap

.sort_obj_cmp:
    ; At least one is an object - compare as strings if both STRING
    mov r11, rsi
    call sort_is_obj
    jnc .sort_mixed             ; elem1 is int
    mov r11, rdi
    call sort_is_obj
    jnc .sort_mixed             ; elem2 is int

    ; Both objects - check if both strings
    mov rbx, [rsi]              ; type1
    cmp rbx, TYPE_STRING
    jne .sort_by_addr
    mov rbx, [rdi]              ; type2
    cmp rbx, TYPE_STRING
    jne .sort_by_addr

    ; Both strings - compare alphabetically
    push rcx
    push rax
    lea rsi, [rsi+16]           ; string1 data
    mov rdi, [r9 + rax + 8]     ; reload elem2
    lea rdi, [rdi+16]           ; string2 data

.sort_str_loop:
    mov al, [rsi]
    mov bl, [rdi]
    ; To lowercase
    cmp al, 'A'
    jb .s_no_low1
    cmp al, 'Z'
    ja .s_no_low1
    add al, 32
.s_no_low1:
    cmp bl, 'A'
    jb .s_no_low2
    cmp bl, 'Z'
    ja .s_no_low2
    add bl, 32
.s_no_low2:
    cmp al, bl
    jb .sort_str_less
    ja .sort_str_greater
    test al, al
    jz .sort_str_equal
    inc rsi
    inc rdi
    jmp .sort_str_loop

.sort_str_less:
    pop rax
    pop rcx
    jmp .sort_no_swap
.sort_str_greater:
    pop rax
    pop rcx
    jmp .sort_do_swap
.sort_str_equal:
    pop rax
    pop rcx
    jmp .sort_no_swap

.sort_mixed:
    ; Mixed types: integers sort before objects
    mov r11, rsi
    call sort_is_obj
    jnc .sort_no_swap           ; int < obj, already correct
    jmp .sort_do_swap           ; obj > int, swap

.sort_by_addr:
    ; Non-string objects: compare by address
    cmp rsi, rdi
    jle .sort_no_swap
    jmp .sort_do_swap

.sort_do_swap:
    ; rax still has (i-1)*8 offset
    mov rsi, [r9 + rax]
    mov rdi, [r9 + rax + 8]
    mov [r9 + rax], rdi
    mov [r9 + rax + 8], rsi
    mov r10, 1                  ; swapped = true

.sort_no_swap:
    inc rcx
    jmp .sort_inner

.sort_pass_done:
    test r10, r10
    jnz .sort_outer

.sort_done:
    ; TOS unchanged (array sorted in place)
    pop r13
    pop r12
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; Helper: Remove definition line from def_src_buffer
; Input: RDI = name pointer, RCX = name length
remove_def_from_buffer:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r10
    push r11

    mov rsi, def_src_buffer
.rdb_search:
    cmp byte [rsi], 0
    je .rdb_done

    ; Mark line start
    mov r10, rsi                ; R10 = line start

    ; Skip whitespace
.rdb_skipws:
    cmp byte [rsi], ' '
    jne .rdb_check
    inc rsi
    jmp .rdb_skipws

.rdb_check:
    ; Check for "name" format
    cmp byte [rsi], '"'
    jne .rdb_check_colon
    inc rsi

    push rdi
    push rcx
.rdb_cmp_quoted:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .rdb_cmp_fail
    inc rsi
    inc rdi
    dec rcx
    jnz .rdb_cmp_quoted

    cmp byte [rsi], '"'
    jne .rdb_cmp_fail
    pop rcx
    pop rdi
    jmp .rdb_found

.rdb_check_colon:
    cmp byte [rsi], ':'
    jne .rdb_next_line
    inc rsi
    cmp byte [rsi], ' '
    jne .rdb_next_line
    inc rsi

    push rdi
    push rcx
.rdb_cmp_colon:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .rdb_cmp_fail
    inc rsi
    inc rdi
    dec rcx
    jnz .rdb_cmp_colon

    cmp byte [rsi], ' '
    je .rdb_found_pop
    cmp byte [rsi], 0
    je .rdb_found_pop
    cmp byte [rsi], 10
    je .rdb_found_pop

.rdb_cmp_fail:
    pop rcx
    pop rdi

.rdb_next_line:
    mov rsi, r10                ; Back to line start
.rdb_skip_line:
    cmp byte [rsi], 0
    je .rdb_done
    cmp byte [rsi], 10
    je .rdb_got_nl
    inc rsi
    jmp .rdb_skip_line
.rdb_got_nl:
    inc rsi
    jmp .rdb_search

.rdb_found_pop:
    pop rcx
    pop rdi

.rdb_found:
    ; Find end of line
    mov rsi, r10
.rdb_find_eol:
    cmp byte [rsi], 0
    je .rdb_at_end
    cmp byte [rsi], 10
    je .rdb_got_eol
    inc rsi
    jmp .rdb_find_eol

.rdb_got_eol:
    inc rsi                     ; Include newline in removal
.rdb_at_end:
    ; R10 = line start, RSI = after line
    ; Shift rest of buffer down
    mov rdi, r10
.rdb_shift:
    mov al, [rsi]
    mov [rdi], al
    cmp al, 0
    je .rdb_shifted
    inc rsi
    inc rdi
    jmp .rdb_shift

.rdb_shifted:
    ; Update def_src_ptr
    mov rsi, def_src_buffer
.rdb_find_end:
    cmp byte [rsi], 0
    je .rdb_set_ptr
    inc rsi
    jmp .rdb_find_end
.rdb_set_ptr:
    mov [def_src_ptr], rsi

.rdb_done:
    pop r11
    pop r10
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================
; Direct disk I/O (register-based, no stack manipulation)
; ============================================================

; disk_read_direct - Read 512 bytes
; Input: EAX = sector, RDI = destination address
disk_read_direct:
    ; Input: RAX = sector, RDI = destination. Preserves all registers.
    ; Sectors 200-447 come from the boot-loaded RAM disk (works without
    ; any ATA drive, e.g. real hardware booted from USB). Other sectors
    ; use ATA PIO; zero-fill on missing drive, error or timeout.
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    cmp rax, RAMDISK_FIRST
    jb .drd_ata
    cmp rax, RAMDISK_FIRST + RAMDISK_COUNT
    jae .drd_ata
    sub rax, RAMDISK_FIRST
    shl rax, 9
    lea rsi, [rax + RAMDISK_ADDR]
    mov rcx, 64
    rep movsq
    jmp .drd_done

.drd_ata:
    cmp byte [ata_present], 0
    je .drd_zero

    mov ecx, eax                ; Save sector

    ; Wait for drive ready (bounded)
    mov dx, IDE_STATUS
    mov rbx, 1000000
.drd_wait:
    in al, dx
    test al, 0x80
    jz .drd_ready
    dec rbx
    jnz .drd_wait
    jmp .drd_zero
.drd_ready:

    mov dx, IDE_SECTOR_CNT
    mov al, 1
    out dx, al
    mov dx, IDE_LBA_LOW
    mov eax, ecx
    out dx, al
    mov dx, IDE_LBA_MID
    mov al, ah
    out dx, al
    mov dx, IDE_LBA_HIGH
    mov eax, ecx
    shr eax, 16
    out dx, al
    mov dx, IDE_DRIVE_HEAD
    mov eax, ecx
    shr eax, 24
    and al, 0x0F
    or al, 0xE0                 ; LBA mode, master, bits 24-27
    out dx, al

    mov dx, IDE_COMMAND
    mov al, IDE_CMD_READ
    out dx, al

    ; Wait for data (bounded, error-aware)
    mov dx, IDE_STATUS
    mov rbx, 1000000
.drd_drq:
    in al, dx
    test al, 0x01               ; ERR
    jnz .drd_zero
    test al, 0x08               ; DRQ
    jnz .drd_data
    dec rbx
    jnz .drd_drq
    jmp .drd_zero
.drd_data:
    mov dx, IDE_DATA
    mov rcx, 256
.drd_loop:
    in ax, dx
    stosw
    dec rcx
    jnz .drd_loop
    jmp .drd_done

.drd_zero:
    xor eax, eax
    mov rcx, 64
    rep stosq

.drd_done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; disk_write_direct - Write 512 bytes
; Input: RAX = sector, RSI = source address. Preserves all registers.
; Sectors 200-447 are written to the RAM disk AND to ATA when a drive
; exists (write-through keeps QEMU persistence). Other sectors: ATA only.
disk_write_direct:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    cmp rax, RAMDISK_FIRST
    jb .dwd_ata
    cmp rax, RAMDISK_FIRST + RAMDISK_COUNT
    jae .dwd_ata
    push rax
    push rsi
    sub rax, RAMDISK_FIRST
    shl rax, 9
    lea rdi, [rax + RAMDISK_ADDR]
    mov rcx, 64
    rep movsq
    pop rsi
    pop rax

.dwd_ata:
    cmp byte [ata_present], 0
    je .dwd_done

    mov ecx, eax                ; Save sector

    ; Wait for drive ready (bounded)
    mov dx, IDE_STATUS
    mov rbx, 1000000
.dwd_wait:
    in al, dx
    test al, 0x80
    jz .dwd_ready
    dec rbx
    jnz .dwd_wait
    jmp .dwd_done
.dwd_ready:

    mov dx, IDE_SECTOR_CNT
    mov al, 1
    out dx, al
    mov dx, IDE_LBA_LOW
    mov eax, ecx
    out dx, al
    mov dx, IDE_LBA_MID
    mov al, ah
    out dx, al
    mov dx, IDE_LBA_HIGH
    mov eax, ecx
    shr eax, 16
    out dx, al
    mov dx, IDE_DRIVE_HEAD
    mov eax, ecx
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    out dx, al

    mov dx, IDE_COMMAND
    mov al, IDE_CMD_WRITE
    out dx, al

    ; Wait for DRQ (bounded)
    mov dx, IDE_STATUS
    mov rbx, 1000000
.dwd_drq:
    in al, dx
    test al, 0x01
    jnz .dwd_done
    test al, 0x08
    jnz .dwd_data
    dec rbx
    jnz .dwd_drq
    jmp .dwd_done
.dwd_data:
    mov dx, IDE_DATA
    mov rcx, 256
.dwd_loop:
    lodsw
    out dx, ax
    dec rcx
    jnz .dwd_loop

    ; Flush cache (bounded)
    mov dx, IDE_COMMAND
    mov al, 0xE7
    out dx, al
    mov dx, IDE_STATUS
    mov rbx, 1000000
.dwd_flush:
    in al, dx
    test al, 0x80
    jz .dwd_done
    dec rbx
    jnz .dwd_flush

.dwd_done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ata_detect - Probe primary ATA once at boot; sets ata_present
ata_detect:
    push rax
    push rdx
    mov dx, IDE_STATUS
    in al, dx
    cmp al, 0xFF                ; Floating bus: no drive
    je .ad_none
    mov byte [ata_present], 1
.ad_none:
    pop rdx
    pop rax
    ret

ata_present: db 0

; ============================================================
; LOAD - Load and run app from disk
; Stack: ( name-string -- )
; Reads app directory from sector 200, finds app, loads and runs
; ============================================================
; Directory entry format (16 bytes):
;   [name: 12 bytes null-padded]
;   [start_sector: 2 bytes LE]
;   [length_sectors: 2 bytes LE]
; ============================================================

APP_DIR_SECTOR  equ 200
APP_BUFFER_ADDR equ 0x100000    ; 1MB - buffer for loading apps (see memory map)

word_load:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13

    ; Get app name string from TOS
    mov r12, r14                ; r12 = STRING object address
    sub r15, 8
    mov r14, [r15]              ; Pop, get new TOS (after sub, [r15] = old second)

    ; Validate it's a string object
    mov rax, [r12]              ; Get type header
    cmp al, TYPE_STRING
    jne .load_error

    ; Get string data pointer (skip 16-byte header)
    lea r13, [r12 + 16]         ; r13 = pointer to name chars

    ; Read app directory sector (200) into load buffer
    mov rax, APP_DIR_SECTOR
    mov rdi, APP_BUFFER_ADDR
    call read_sector_to_addr

    ; Search directory for matching app name
    mov rbx, APP_BUFFER_ADDR    ; rbx = current directory entry
    mov rcx, 32                 ; max 32 entries per sector

.search_loop:
    ; Check if entry is empty (first byte = 0)
    cmp byte [rbx], 0
    je .not_found

    ; Compare name (up to 12 chars)
    push rcx
    mov rsi, r13                ; App name we're looking for
    mov rdi, rbx                ; Directory entry name
    mov rcx, 12
.cmp_name:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, 0                   ; End of search name?
    je .name_match_check
    cmp al, ah
    jne .next_entry
    inc rsi
    inc rdi
    dec rcx
    jnz .cmp_name
    jmp .name_match_check

.name_match_check:
    ; If we got here, names match (or search name ended)
    ; Check that entry name also ends or matches
    cmp ah, 0
    je .found
    cmp ah, ' '                 ; Space padding also OK
    je .found

.next_entry:
    pop rcx
    add rbx, 16                 ; Next entry
    dec rcx
    jnz .search_loop

.not_found:
    ; Print error
    mov rax, str_app_not_found
    call print_string
    jmp .load_done

.found:
    pop rcx                     ; Clean up saved rcx

    ; Get start sector and length from entry
    movzx rax, word [rbx + 12]  ; Start sector
    movzx rcx, word [rbx + 14]  ; Length in sectors

    ; Load app sectors into buffer
    mov rdi, APP_BUFFER_ADDR
.load_sectors:
    push rcx
    push rdi
    push rax
    call read_sector_to_addr
    pop rax
    pop rdi
    pop rcx
    inc rax                     ; Next sector
    add rdi, 512                ; Advance buffer
    dec rcx
    jnz .load_sectors

    ; Null-terminate the loaded code
    mov byte [rdi], 0

    ; Print loading message
    mov rax, str_loading_app
    call print_string
    mov rax, r13                ; App name (null-terminated)
    call print_string
    call newline

    ; Interpret the loaded source
    mov rsi, APP_BUFFER_ADDR
    call interpret_source

.load_done:
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

.load_error:
    mov rax, str_load_error
    call print_string
    jmp .load_done

; Helper: Read sector to address (RAM-disk aware)
; Input: RAX = sector, RDI = destination address
read_sector_to_addr:
    call disk_read_direct
    ret

str_app_not_found: db 'App not found', 13, 10, 0
str_loading_app: db 'Loading app: ', 0
str_sector200_debug: db 'Sector200: ', 0
str_load_error: db 'Error: expected string', 13, 10, 0

; edit - shortcut to load editor app
word_edit:
    ; Create "editor" string and call load
    push rsi
    mov rsi, str_editor_name
    call create_string_from_cstr
    pop rsi
    mov [r15], r14          ; Spill old TOS before overwriting
    add r15, 8
    mov r14, rax            ; Push string
    jmp word_load           ; Tail call to load

str_editor_name: db 'editor', 0

word_words:
    ; Push STRING listing all words (builtins + user-defined), sorted
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12

    ; Step 1: Collect all word pointers and lengths
    xor r8, r8                  ; R8 = word count

    ; Parse builtin words
    mov rsi, str_builtins
.parse_builtins:
    ; Skip spaces
    cmp byte [rsi], ' '
    jne .got_word_start
    inc rsi
    jmp .parse_builtins
.got_word_start:
    cmp byte [rsi], 0
    je .builtins_parsed
    cmp r8, 512
    jae .builtins_parsed        ; Table full

    ; Store pointer (word_ptrs uses qwords, index*8)
    mov rax, r8
    shl rax, 3                  ; *8 for qword
    mov [word_ptrs + rax], rsi

    ; Find word length
    xor rcx, rcx
.find_word_end:
    cmp byte [rsi + rcx], ' '
    je .found_end
    cmp byte [rsi + rcx], 0
    je .found_end
    inc rcx
    jmp .find_word_end
.found_end:
    ; Store length (word_lens uses bytes, just index)
    mov [word_lens + r8], cl
    add rsi, rcx                ; Move past word
    inc r8                      ; word count++
    jmp .parse_builtins

.builtins_parsed:
    ; Add user-defined words from dictionary
    mov rsi, [dict_latest]
.add_user_words:
    test rsi, rsi
    jz .all_words_collected
    cmp r8, 512
    jae .all_words_collected    ; Table full

    ; Store pointer to name (at offset 9)
    mov rax, r8
    shl rax, 3
    lea rdx, [rsi+9]
    mov [word_ptrs + rax], rdx

    ; Store length (at offset 8) - word_lens uses bytes
    movzx rcx, byte [rsi+8]
    mov [word_lens + r8], cl

    inc r8
    mov rsi, [rsi]              ; Next entry
    jmp .add_user_words

.all_words_collected:
    ; R8 = total word count
    mov [word_count], r8

.sort_done:
    ; Step 3: Build output string from sorted words
    mov rdi, words_buffer
    mov r10, 0                  ; index
.build_output:
    cmp r10, [word_count]
    jge .output_done
    cmp rdi, words_buffer + 8192 - 40
    jae .output_done            ; Buffer nearly full

    ; Add space between words (not before first)
    test r10, r10
    jz .no_space
    mov al, ' '
    stosb
.no_space:

    ; Copy word
    mov rax, r10
    shl rax, 3
    mov rsi, [word_ptrs + rax]
    movzx rcx, byte [word_lens + r10]
.copy_word:
    lodsb
    stosb
    dec rcx
    jnz .copy_word

    inc r10
    jmp .build_output

.output_done:
    mov byte [rdi], 0           ; Null terminate

    ; Create STRING from buffer
    mov rsi, words_buffer
    call create_string_from_cstr

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax

    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

str_builtins: db '+ - * / mod = < > <> <= >= 0= and or xor not . .s dup drop swap rot over @ ! c@ c! emit cr : ; ~ ? words execute len type array at put [ ] type-new type-name type-set type-name? screen-* key? key-* if then else begin until while repeat again app-* disk-read disk-write save restore info remove define sort allot load edit eval s>f f>s f+ f- f* f/ f< f> f= f. fix fpi fneg fabs fsqrt fsin fcos ftan fatan fln flog fexp fpow', 0
words_buffer: times 8192 db 0   ; Buffer for word list
word_ptrs: times 512 dq 0       ; Pointers to words (max 512 words)
word_lens: times 512 db 0       ; Lengths of words
word_count: dq 0                ; Number of words
last_word_ptr: dq 0             ; Pointer to last parsed word (for error messages)
last_word_len: dq 0             ; Length of last parsed word

word_forget:
    ; Simplified FORGET - just removes latest word
    push rax
    mov rax, [dict_latest]
    test rax, rax
    jz .done

    ; Get link from latest entry (points to previous)
    mov rax, [rax]
    mov [dict_latest], rax

.done:
    pop rax
    ret

word_define:
    ; Pure RPN define: ( name-string body-array -- )
    ; Stack has: second=name, TOS=array
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Get array from TOS (R14)
    mov rax, r14
    ; Validate it's an array
    cmp qword [rax], TYPE_ARRAY
    jne .define_error

    ; Get array count and data
    mov rcx, [rax+8]            ; Element count
    lea rsi, [rax+16]           ; Array data

    ; Process array elements into compile_buffer
    ; - Literals (numbers, heap objects): wrap with LIT
    ; - Immediate words (begin, until, if, then, else): execute to generate branches
    ; - Other code references: store directly
    mov qword [compile_ptr], compile_buffer
    mov byte [compile_mode], 1  ; Enable compile mode for control flow words
    mov byte [ctl_items], 0     ; Fresh control-flow balance

.define_copy_loop:
    test rcx, rcx
    jz .define_copy_done
    mov rdi, [compile_ptr]
    cmp rdi, compile_buffer + 4096*8 - 64
    jae .define_copy_done       ; Compile buffer full: truncate
    lodsq                       ; Get element into RAX
    push rcx
    push rsi

    ; Check if tagged literal (bit 63 set during array collection for positive numbers)
    ; Must check this FIRST since tagged numbers appear negative due to bit 63
    bt rax, 63
    jc .define_is_tagged_literal

    ; Check if naturally negative - these are literals (can't be code addresses)
    ; Only reach here if bit 63 was NOT set, so true negatives won't exist here
    ; (negative numbers are tagged, and we handled that above)

    ; Check if heap object (>= HEAP_START) - also a literal
    ; (dictionary entries at DICT_SPACE..DICT_END stay code references)
    cmp rax, HEAP_START
    jae .define_is_literal

    ; It's a code reference - check if control flow immediate
    cmp rax, word_begin
    je .define_exec_immediate
    cmp rax, word_until
    je .define_exec_immediate
    cmp rax, word_if
    je .define_exec_immediate
    cmp rax, word_then
    je .define_exec_immediate
    cmp rax, word_else
    je .define_exec_immediate
    cmp rax, word_while
    je .define_exec_immediate
    cmp rax, word_repeat
    je .define_exec_immediate
    cmp rax, word_again
    je .define_exec_immediate

    ; Regular code reference - store directly
    mov rdi, [compile_ptr]
    mov [rdi], rax
    add rdi, 8
    mov [compile_ptr], rdi
    jmp .define_next_element

.define_exec_immediate:
    ; Execute the control flow word to generate branches
    call rax
    jmp .define_next_element

.define_is_tagged_literal:
    ; Tagged literal: bit 63 set, value is 63-bit two's complement.
    ; Untag = drop bit 63, sign-extend from bit 62 (shl+sar does both).
    shl rax, 1
    sar rax, 1
    ; Fall through to wrap with LIT

.define_is_literal:
    ; Wrap with LIT
    mov rdi, [compile_ptr]
    mov qword [rdi], LIT
    mov [rdi+8], rax
    add rdi, 16
    mov [compile_ptr], rdi

.define_next_element:
    pop rsi
    pop rcx
    dec rcx
    jmp .define_copy_loop

.define_copy_done:
    mov byte [compile_mode], 0  ; Disable compile mode

    ; Get name from [r15-8] (second on stack, array is TOS in R14)
    mov rax, [r15-8]

    ; Validate it's a STRING
    cmp qword [rax], TYPE_STRING
    jne .define_error

    ; Copy name to new_word_name (max 31 chars + null)
    lea rsi, [rax+16]           ; String data
    mov rdi, new_word_name
    mov rcx, 31
.copy_name:
    lodsb
    test al, al
    jz .name_copied
    stosb
    dec rcx
    jnz .copy_name
.name_copied:
    mov byte [rdi], 0

    ; Pop both array and name from stack
    sub r15, 16                 ; Remove two items
    cmp r15, [stack_floor]
    jl .define_pop_empty
    mov r14, [r15]              ; New TOS
    jmp .define_popped
.define_pop_empty:
    mov r15, [stack_floor]
    xor r14, r14
.define_popped:

    ; Ensure modes are reset
    mov byte [compile_mode], 0
    mov byte [array_mode], 0

    ; Create dictionary entry
    call create_dict_entry

    ; Save definition source for persistence (only from REPL, not during app load)
    cmp qword [app_loading], 0
    jne .skip_save_def
    call save_def_source
.skip_save_def:

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

.define_error:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

word_see:
    ; Show word info - parse name and look it up
    call skip_spaces
    call parse_word
    push rsi
    call lookup_word
    pop rsi

    test rax, rax
    jz .not_found

    ; Check if dictionary word
    cmp rax, DICT_SPACE
    jl .is_builtin

    ; Print ": name (colon def)"
    push rax
    mov al, ':'
    call emit_char
    mov al, ' '
    call emit_char
    mov rax, new_word_name
    call print_string
    mov al, ' '
    call emit_char
    mov rax, str_colon_type
    call print_string
    pop rax
    ret

.is_builtin:
    push rax
    mov rax, str_builtin_type
    call print_string
    pop rax
    ret

.not_found:
    push rax
    mov rax, str_unknown
    call print_string
    pop rax
    ret

str_colon_type: db '(colon)', 0
str_builtin_type: db '(built-in)', 0

word_colon:
    ; Set mode to get name next
    mov byte [compile_mode], 2
    mov byte [ctl_items], 0     ; Fresh control-flow balance

    ; Reset compilation buffer
    mov rax, compile_buffer
    mov [compile_ptr], rax
    ret

word_semi:
    ; End compilation mode
    mov byte [compile_mode], 0

    ; Create dictionary entry
    call create_dict_entry

    ; Save definition source for persistence (only from REPL, not during app load)
    cmp qword [app_loading], 0
    jne .skip_save              ; Don't save during app loading
    call save_def_source
.skip_save:
    ret

; Save current input line to definition source buffer
save_def_source:
    push rax
    push rcx
    push rsi
    push rdi

    ; Get destination pointer
    mov rdi, [def_src_ptr]

    ; Check if we have space (leave room for null + newline)
    mov rax, def_src_buffer
    add rax, 4008               ; Max buffer minus one full line (82 bytes)
    cmp rdi, rax
    jge .src_full               ; Buffer full, skip

    ; Copy input_buffer to def_src_buffer (max 80 chars)
    mov rsi, input_buffer
    mov rcx, 80                 ; Safety limit
.copy_loop:
    lodsb
    test al, al
    jz .copy_done
    stosb
    dec rcx
    jnz .copy_loop
.copy_done:
    ; Add newline
    mov byte [rdi], 10
    inc rdi
    mov byte [rdi], 0           ; Keep null-terminated
    mov [def_src_ptr], rdi

.src_full:
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; =============================================================
; interpret_source - Interpret RPN source from memory
; Input: RSI = pointer to null-terminated source
; Preserves: R14, R15, RBP (stacks)
; =============================================================
interpret_source:
    push rbx
    push r12
    push r13
    mov r12, rsi                ; Save source pointer

.next_line:
    ; Copy line to app_input_buffer (separate from REPL's input_buffer)
    mov rdi, app_input_buffer
    xor rcx, rcx                ; Line length

.copy_char:
    mov al, [r12]
    cmp al, 0                   ; End of source?
    je .done_copying
    cmp al, 10                  ; Newline?
    je .end_line
    cmp al, 13                  ; CR?
    je .skip_cr
    mov [rdi], al
    inc rdi
    inc r12
    inc rcx
    cmp rcx, 1023               ; Max line length
    jl .copy_char
    jmp .end_line

.skip_cr:
    inc r12
    jmp .copy_char

.end_line:
    inc r12                     ; Skip newline

.done_copying:
    mov byte [rdi], 0           ; Null terminate

    ; Skip empty lines
    test rcx, rcx
    jz .check_more

    ; Process the line
    mov rsi, app_input_buffer
    call interpret_line

.check_more:
    ; Check if more source
    mov al, [r12]
    test al, al
    jnz .next_line

    pop r13
    pop r12
    pop rbx
    ret

; interpret_line - Interpret tokens from RSI until null
; Returns: RAX = 1 on success, 0 on error
interpret_line:
    push rbx
    push r13
    push r12
    mov r13, rsi                ; Save source pointer
    mov r12, 1                  ; R12 = success flag (1=ok, 0=error)

.iline_parse_loop:
    mov rsi, r13
    ; Skip spaces
    call skip_spaces
    mov r13, rsi

    cmp byte [rsi], 0
    je .iline_done

    ; Check for comments (backslash or parenthesis)
    cmp byte [rsi], '\'
    je .iline_done              ; Skip rest of line on backslash
    cmp byte [rsi], '('
    je .iline_skip_comment

    ; Check for tick (~) - get reference to next word
    cmp byte [rsi], 126         ; Tilde
    je .iline_handle_tick

    ; Check for quote (") - string literal
    cmp byte [rsi], 34          ; Double quote
    je .iline_handle_string

    ; Check for variable {name} - named variable access
    cmp byte [rsi], '{'
    je .iline_handle_variable

    ; Check for array literal start [
    cmp byte [rsi], '['
    je .iline_handle_array_start

    ; Check for array literal end ]
    cmp byte [rsi], ']'
    je .iline_handle_array_end

    ; Get word using parse_word
    call parse_word             ; RDI = word start, RCX = length
    mov r13, rsi                ; Update position after parse

    test rcx, rcx
    jz .iline_parse_loop

    ; Save word info for error reporting
    mov [last_word_ptr], rdi    ; Save word start
    mov [last_word_len], rcx    ; Save word length

    ; Check if getting name for definition
    cmp byte [compile_mode], 2
    je .iline_save_name

    ; Check if number
    ; Float literal? (digits with one dot, e.g. 3.14)
    call try_parse_float
    test rdx, rdx
    jnz .iline_float

    call is_number
    test rax, rax
    jnz .iline_push_number

    ; Check if known word
    call lookup_word
    test rax, rax
    jz .iline_unknown

    ; Check if in array mode FIRST - all words become references
    ; This allows control flow words to be stored in arrays for later compilation
    cmp byte [array_mode], 1
    je .iline_push_ref_clean

    ; Check for immediate flag (bit 63 set by lookup_word)
    ; Immediate words are executed even during compilation
    bt rax, 63
    jnc .iline_not_immediate
    ; It's immediate - clear the flag and execute
    btr rax, 63
    jmp .iline_exec_immediate

.iline_push_ref_clean:
    ; Clear immediate flag if set before storing
    btr rax, 63
    jmp .iline_push_ref

.iline_not_immediate:

    ; Execute or compile word
    cmp byte [compile_mode], 0
    jne .iline_compile_word

    ; Check if dictionary word
    push rax
    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rax
    je .iline_dict_word

.iline_exec_immediate:
    ; Execute immediate/built-in word
    push r13                    ; Save parse position
    call rax
    pop r13                     ; Restore parse position
    jmp .iline_parse_loop

.iline_push_ref:
    ; Array mode - store reference to collection buffer
    push rbx
    mov rbx, [array_collect_ptr]
    cmp rbx, array_collect_buffer + 4096
    jae .iline_ref_full
    mov [rbx], rax              ; Store reference
    add rbx, 8
    mov [array_collect_ptr], rbx
.iline_ref_full:
    pop rbx
    jmp .iline_parse_loop

.iline_dict_word:
    ; Execute dictionary word using the standard mechanism
    push r13                    ; Save parse position
    add rax, 8                  ; Skip code pointer
    mov rsi, rax
    call exec_definition
    pop r13
    jmp .iline_parse_loop

.iline_compile_word:
    ; Compiling - store word address
    mov rbx, [compile_ptr]
    cmp rbx, compile_buffer + 4096*8 - 64
    jae .iline_parse_loop       ; Compile buffer full: drop
    ; Check if dictionary word
    push rax
    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rax
    jne .iline_compile_builtin

    ; Dictionary word - store code field address
    mov rbx, [compile_ptr]
    mov [rbx], rax
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_compile_builtin:
    ; Built-in - store function address
    mov rbx, [compile_ptr]
    mov [rbx], rax
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_push_number:
    ; Parse the actual number value (RDI=word start, RCX=length still valid)
    call parse_number           ; Convert string to number in RAX

    ; Check if in array mode - numbers go to collection buffer
    cmp byte [array_mode], 1
    je .iline_number_to_array

    ; Check if compiling
    cmp byte [compile_mode], 0
    jne .iline_compile_number

    ; Push number to stack (interpret mode)
    mov [r15], r14              ; Push old TOS
    add r15, 8
    mov r14, rax                ; New TOS
    jmp .iline_parse_loop

.iline_number_to_array:
    ; Store number in collection buffer, tagged with bit 63.
    ; Values are 63-bit two's complement; define/at untag with shl+sar.
    ; (bts on a negative is a no-op: bit 63 is already set.)
    push rbx
    mov rbx, [array_collect_ptr]
    cmp rbx, array_collect_buffer + 4096
    jae .iline_number_full      ; Buffer full: drop element
    bts rax, 63
    mov [rbx], rax
    add rbx, 8
    mov [array_collect_ptr], rbx
.iline_number_full:
    pop rbx
    jmp .iline_parse_loop

.iline_float:
    ; Float literal in RAX (raw double bits)
    cmp byte [array_mode], 1
    je .iline_float_to_array
    cmp byte [compile_mode], 0
    jne .iline_float_compile
    ; Interpret: push raw bits
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_float_compile:
    mov rbx, [compile_ptr]
    cmp rbx, compile_buffer + 4096*8 - 64
    jae .iline_parse_loop
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_float_to_array:
    ; Positive double bits are huge values: define classifies them as
    ; literals untouched. Negatives would collide with bit-63 tagging,
    ; so store the absolute value plus a reference to fneg.
    ; 0.0 has bits 0: store as tagged integer zero (same value).
    push rbx
    mov rbx, [array_collect_ptr]
    cmp rbx, array_collect_buffer + 4096 - 16
    jae .iline_flt_full
    test rax, rax
    jnz .iline_flt_nonzero
    mov rax, 0x8000000000000000 ; tagged 0
    mov [rbx], rax
    add rbx, 8
    jmp .iline_flt_store_done
.iline_flt_nonzero:
    bt rax, 63
    jnc .iline_flt_pos
    btr rax, 63
    mov [rbx], rax
    add rbx, 8
    mov rax, word_fneg
    mov [rbx], rax
    add rbx, 8
    jmp .iline_flt_store_done
.iline_flt_pos:
    mov [rbx], rax
    add rbx, 8
.iline_flt_store_done:
    mov [array_collect_ptr], rbx
.iline_flt_full:
    pop rbx
    jmp .iline_parse_loop

.iline_compile_number:
    push rbx
    mov rbx, [compile_ptr]
    cmp rbx, compile_buffer + 4096*8 - 64
    pop rbx
    jae .iline_parse_loop       ; Compile buffer full: drop
    ; Compile LIT + number
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_save_name:
    ; Save word name for definition (cap at 31 chars + null)
    push rdi
    push rcx
    cmp rcx, 31
    jbe .isn_len_ok
    mov rcx, 31
.isn_len_ok:
    mov rsi, rdi
    mov rdi, new_word_name
    rep movsb
    mov byte [rdi], 0
    pop rcx
    pop rdi
    mov byte [compile_mode], 1  ; Switch to compile mode
    jmp .iline_parse_loop

.iline_unknown:
    ; Unknown word - print it and set error flag
    ; Print the unknown word from saved info
    mov al, ' '
    call emit_char
    mov rdi, [last_word_ptr]
    mov rcx, [last_word_len]
.iline_print_unknown_word:
    test rcx, rcx
    jz .iline_print_unknown_done
    mov al, [rdi]
    call emit_char
    inc rdi
    dec rcx
    jmp .iline_print_unknown_word
.iline_print_unknown_done:
    mov al, '?'
    call emit_char
    mov r12, 0                  ; Error!
    jmp .iline_parse_loop

.iline_skip_comment:
    ; Skip until )
.iline_skip_to_paren:
    inc r13
    cmp byte [r13], 0
    je .iline_done
    cmp byte [r13], ')'
    jne .iline_skip_to_paren
    inc r13                     ; Skip )
    jmp .iline_parse_loop

.iline_handle_variable:
    ; Handle {name} variable access
    inc r13                     ; Skip {
    mov rdi, r13
    xor rcx, rcx
.iline_get_varname:
    mov al, [r13]
    cmp al, '}'
    je .iline_got_varname
    cmp al, 0
    je .iline_done
    inc r13
    inc rcx
    jmp .iline_get_varname

.iline_got_varname:
    inc r13                     ; Skip }
    ; RDI = name start, RCX = length
    call get_or_create_named_var  ; Returns address in RAX

    ; Check if in array mode - store address in array buffer
    cmp byte [array_mode], 1
    je .iline_var_to_array

    ; Check if compiling
    cmp byte [compile_mode], 0
    jne .iline_compile_var

    ; Push address to stack
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_var_to_array:
    ; Store variable address in array collection buffer with bit 63 set
    ; define will wrap it with LIT when processing
    push rbx
    mov rbx, [array_collect_ptr]
    cmp rbx, array_collect_buffer + 4096
    jae .iline_var_full
    bts rax, 63                 ; Set bit 63 to tag as literal
    mov [rbx], rax
    add rbx, 8
    mov [array_collect_ptr], rbx
.iline_var_full:
    pop rbx
    jmp .iline_parse_loop

.iline_compile_var:
    push rbx
    mov rbx, [compile_ptr]
    cmp rbx, compile_buffer + 4096*8 - 64
    pop rbx
    jae .iline_parse_loop       ; Compile buffer full: drop
    ; Compile LIT + address
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_handle_tick:
    ; Tick (~) - get reference to next word
    inc r13                     ; Skip ~
    mov rsi, r13
    call skip_spaces
    mov r13, rsi
    call parse_word             ; RDI = word, RCX = length
    mov r13, rsi
    call lookup_word
    test rax, rax
    jz .iline_parse_loop        ; Unknown word, skip
    ; Push reference
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_handle_string:
    ; String literal
    inc r13                     ; Skip opening quote
    mov rsi, r13
    ; Count length
    push rsi
    xor rcx, rcx
.iline_count_str:
    mov al, [rsi]
    test al, al
    jz .iline_str_counted
    cmp al, 34                  ; Closing quote?
    je .iline_str_counted
    inc rsi
    inc rcx
    jmp .iline_count_str
.iline_str_counted:
    pop rsi
    ; Allocate STRING object
    push rcx
    add rcx, 17                 ; Header + null
    call allocate_object
    pop rcx
    ; Fill header
    mov qword [rax], TYPE_STRING
    mov [rax+8], rcx
    ; Copy string
    lea rdi, [rax+16]
    mov rbx, r13
.iline_copy_str:
    mov r8b, [rbx]
    test r8b, r8b
    jz .iline_str_done
    inc rbx
    cmp r8b, 34                 ; Closing quote?
    je .iline_str_done
    mov [rdi], r8b
    inc rdi
    jmp .iline_copy_str
.iline_str_done:
    mov byte [rdi], 0
    mov r13, rbx                ; Update position

    ; Check if in array mode - strings go to collection buffer
    cmp byte [array_mode], 1
    je .iline_string_to_array

    ; Check compile mode
    cmp byte [compile_mode], 0
    jne .iline_compile_string
    ; Push to stack (interpret mode)
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_string_to_array:
    ; Store string in collection buffer
    push rbx
    mov rbx, [array_collect_ptr]
    cmp rbx, array_collect_buffer + 4096
    jae .iline_str_full
    mov [rbx], rax              ; Store string object address
    add rbx, 8
    mov [array_collect_ptr], rbx
.iline_str_full:
    pop rbx
    jmp .iline_parse_loop

.iline_compile_string:
    push rbx
    mov rbx, [compile_ptr]
    cmp rbx, compile_buffer + 4096*8 - 64
    pop rbx
    jae .iline_parse_loop       ; Compile buffer full: drop
    ; Compile LIT + string address
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT
    mov [rbx+8], rax
    add rbx, 16
    mov [compile_ptr], rbx
    jmp .iline_parse_loop

.iline_handle_array_start:
    ; [ - Start array collection (data mode, no control flow)
    inc r13                     ; Skip [
    ; Initialize collection buffer
    mov qword [array_collect_ptr], array_collect_buffer
    mov byte [array_mode], 1    ; Enable auto-tick mode (refs, not execution)
    jmp .iline_parse_loop

.iline_handle_array_end:
    ; ] - Create array from collection buffer
    inc r13                     ; Skip ]
    mov byte [array_mode], 0    ; Disable auto-tick mode

    ; Calculate element count from collection buffer
    mov rcx, [array_collect_ptr]
    sub rcx, array_collect_buffer
    shr rcx, 3                  ; Count in qwords

    ; Allocate array object
    push rcx
    shl rcx, 3
    add rcx, 16                 ; Add header size
    call allocate_object
    pop rcx

    ; Fill array header
    mov qword [rax], TYPE_ARRAY
    mov [rax+8], rcx

    ; Copy from collection buffer to array
    lea rdi, [rax+16]
    mov rsi, array_collect_buffer
    push rcx
.copy_loop:
    test rcx, rcx
    jz .copy_done
    movsq
    dec rcx
    jmp .copy_loop
.copy_done:
    pop rcx

    ; Push array to data stack
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .iline_parse_loop

.iline_done:
    mov rax, r12                ; Return success flag
    pop r12
    pop r13
    pop rbx
    ret

; exec_definition - Execute a colon definition
; Input: RSI = pointer to definition body (after DOCOL)
exec_definition:
    push r13
.exec_def_loop:
    lodsq
    cmp rax, EXIT
    je .exec_def_done

    ; Check for LIT
    cmp rax, LIT
    jne .exec_not_lit
    lodsq
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .exec_def_loop

.exec_not_lit:
    ; Check for BRANCH
    cmp rax, BRANCH
    jne .exec_not_branch
    lodsq
    add rsi, rax
    jmp .exec_def_loop

.exec_not_branch:
    ; Check for ZBRANCH
    cmp rax, ZBRANCH
    jne .exec_not_zbranch
    lodsq                       ; Get offset into RAX
    mov rbx, r14                ; Save TOS for test
    sub r15, 8
    cmp r15, [stack_floor]
    jl .exec_zbranch_empty      ; Stack empty after pop
    mov r14, [r15]              ; Pop new TOS
    jmp .exec_zbranch_test
.exec_zbranch_empty:
    mov r15, [stack_floor]         ; Reset stack pointer
    xor r14, r14                ; TOS = 0
.exec_zbranch_test:
    test rbx, rbx               ; Test saved TOS (after pop to preserve flags)
    jnz .exec_def_loop          ; If not zero, don't branch
    add rsi, rax                ; Branch
    jmp .exec_def_loop

.exec_not_zbranch:
    ; Check if nested dictionary word
    cmp rax, DICT_SPACE
    jb .exec_is_builtin         ; Use unsigned comparison for addresses
    mov rcx, [dict_here]
    cmp rax, rcx
    jae .exec_is_builtin        ; Use unsigned comparison for addresses
    mov rbx, [rax]
    cmp rbx, DOCOL
    jne .exec_is_builtin

    ; Nested definition - recurse
    push rsi
    add rax, 8
    mov rsi, rax
    call exec_definition
    pop rsi
    jmp .exec_def_loop

.exec_is_builtin:
    push rsi
    call rax
    pop rsi
    jmp .exec_def_loop

.exec_def_done:
    pop r13
    ret

; serial_putchar - Output a character to serial port (for debugging)
; Input: AL = character
serial_putchar:
    push rdx
    push rax
    mov dx, 0x3F8 + 5       ; Line status register
.wait:
    in al, dx
    test al, 0x20           ; Transmit buffer empty?
    jz .wait
    pop rax
    mov dx, 0x3F8           ; Data register
    out dx, al
    pop rdx
    ret

; serial_print_hex - Output 64-bit value as hex to serial port
; Input: RAX = value to print
serial_print_hex:
    push rax
    push rcx
    push rdx
    mov rcx, 16             ; 16 hex digits
.hex_loop:
    rol rax, 4              ; Rotate left 4 bits
    push rax
    and al, 0x0F            ; Get low 4 bits
    add al, '0'
    cmp al, '9'
    jle .not_letter
    add al, 7               ; Convert to A-F
.not_letter:
    call serial_putchar
    pop rax
    dec rcx
    jnz .hex_loop
    pop rdx
    pop rcx
    pop rax
    ret

; serial_print - Output string to serial port
; Input: RSI = null-terminated string
serial_print:
    push rsi
    push rax
.loop:
    lodsb
    test al, al
    jz .done
    call serial_putchar
    jmp .loop
.done:
    pop rax
    pop rsi
    ret

; load_apps - Load apps from disk at boot
; Uses the disk catalog at sector 200 to load apps
load_apps:
    push rbx
    push r12
    push r13

    ; Load core (first - provides utility words for other apps)
    mov rsi, serial_loading_core
    call serial_print
    mov rsi, app_name_core
    call load_app_by_cstring

    ; Load hello
    mov rsi, serial_loading_hello
    call serial_print
    mov rsi, app_name_hello
    call load_app_by_cstring

    ; Load invaders
    mov rsi, serial_loading_invaders
    call serial_print
    mov rsi, app_name_invaders
    call load_app_by_cstring

    ; Load editor (before test, since test uses editor words)
    mov rsi, serial_loading_editor
    call serial_print
    mov rsi, app_name_editor
    call load_app_by_cstring

    ; Load test
    mov rsi, serial_loading_test
    call serial_print
    mov rsi, app_name_test
    call load_app_by_cstring

    ; Load xrpn runtime, then programs that use it
    mov rsi, serial_loading_xrpn
    call serial_print
    mov rsi, app_name_xrpn
    call load_app_by_cstring
    mov rsi, app_name_demo
    call load_app_by_cstring

    ; Done
    mov rsi, serial_apps_done
    call serial_print

    pop r13
    pop r12
    pop rbx
    ret

; App names for boot loading
app_name_core: db 'core', 0
app_name_editor: db 'editor', 0
app_name_invaders: db 'invaders', 0
app_name_hello: db 'hello', 0
app_name_test: db 'test', 0
app_name_xrpn: db 'xrpn', 0
app_name_demo: db 'demo', 0

; load_app_by_cstring - Load app by C string name (for boot time)
; Input: RSI = pointer to null-terminated app name
; Uses disk catalog at sector 200
load_app_by_cstring:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13

    mov r13, rsi                ; r13 = app name

    ; Read app directory sector (200) into load buffer
    mov rax, APP_DIR_SECTOR
    mov rdi, APP_BUFFER_ADDR
    call read_sector_to_addr

    ; DEBUG: Print what we read from sector 200
    push rsi
    mov rsi, str_sector200_debug
    call serial_print
    mov rax, [APP_BUFFER_ADDR]       ; First 8 bytes
    call serial_print_hex
    mov al, ' '
    call serial_putchar
    mov rax, [APP_BUFFER_ADDR + 8]   ; Next 8 bytes
    call serial_print_hex
    mov al, 13
    call serial_putchar
    mov al, 10
    call serial_putchar
    pop rsi

    ; Search directory for matching app name
    mov rbx, APP_BUFFER_ADDR    ; rbx = current directory entry
    mov rcx, 32                 ; max 32 entries per sector

.labc_search_loop:
    ; Check if entry is empty (first byte = 0)
    cmp byte [rbx], 0
    je .labc_not_found

    ; Compare name (up to 12 chars)
    push rcx
    mov rsi, r13                ; App name we're looking for
    mov rdi, rbx                ; Directory entry name
    mov rcx, 12
.labc_cmp_name:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, 0                   ; End of search name?
    je .labc_name_match_check
    cmp al, ah
    jne .labc_next_entry
    inc rsi
    inc rdi
    dec rcx
    jnz .labc_cmp_name
    jmp .labc_name_match_check

.labc_name_match_check:
    ; If we got here, names match (or search name ended)
    cmp ah, 0
    je .labc_found
    cmp ah, ' '                 ; Space padding also OK
    je .labc_found

.labc_next_entry:
    pop rcx
    add rbx, 16                 ; Next entry (16 bytes each)
    dec rcx
    jnz .labc_search_loop

.labc_not_found:
    ; App not found - just print error and continue
    mov rsi, str_app_not_found
    call serial_print
    jmp .labc_done

.labc_found:
    pop rcx                     ; Clean up saved rcx

    ; Get start sector and length from entry
    movzx rax, word [rbx + 12]  ; Start sector
    movzx rcx, word [rbx + 14]  ; Length in sectors

    ; Load app sectors into buffer
    mov rdi, APP_BUFFER_ADDR
.labc_load_sectors:
    push rcx
    push rdi
    push rax
    call read_sector_to_addr
    pop rax
    pop rdi
    pop rcx
    inc rax                     ; Next sector
    add rdi, 512                ; Advance buffer
    dec rcx
    jnz .labc_load_sectors

    ; Null-terminate the loaded code
    mov byte [rdi], 0

    ; Interpret the loaded source
    mov rsi, APP_BUFFER_ADDR
    call interpret_source

.labc_done:
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

serial_loading_core: db 'Loading core...', 13, 10, 0
serial_loading_hello: db 'Loading hello...', 13, 10, 0
serial_loading_editor: db 'Loading editor...', 13, 10, 0
serial_loading_invaders: db 'Loading invaders...', 13, 10, 0
serial_loading_test: db 'Loading test...', 13, 10, 0
serial_loading_xrpn: db 'Loading xrpn...', 13, 10, 0
serial_apps_done: db 'Apps loaded OK', 13, 10, 0
debug_if_entry: db 'IF rbp=', 0
debug_else_entry: db 'ELSE entry, IF placeholder=', 0
debug_parse_word: db 'parse_word done', 13, 10, 0
debug_lookup_word: db 'lookup: ', 0
debug_lookup_result: db 'result: ', 0
debug_imm_call: db 'IMM addr=', 0
debug_else_done: db 'ELSE done', 13, 10, 0
debug_unknown_word: db 'Unknown: ', 0
debug_semicolon: db 'Created word: ', 0
debug_compile_mode_msg: db '[compile_mode=', 0
debug_boot_line_msg: db 'BOOT: ', 0
debug_semi_buffer_msg: db '; compiled=', 0
debug_semi_name_msg: db ' name=', 0
debug_semi_code_msg: db '  code: ', 0
debug_exec_word_msg: db 'EXEC: ', 0
debug_dict_latest_msg: db '  dict_latest=', 0
debug_dict_name_msg: db '  dict entry: len=', 0
debug_check_docol_msg: db 'CHECK addr=', 0
debug_check_docol_val_msg: db ' val=', 0
debug_define_enter: db 'DEFINE called', 13, 10, 0
debug_define_tos_type: db 'TOS type=', 0
debug_define_array_ok: db 'Array OK', 13, 10, 0
debug_define_name_ok: db 'Name OK', 13, 10, 0
debug_define_creating: db 'Creating: ', 0
debug_define_done: db 'Define done', 13, 10, 0
debug_define_error: db 'DEFINE ERROR', 13, 10, 0
debug_define_start: db 'DEFINE: start', 13, 10, 0
debug_define_arr_valid: db 'DEFINE: array valid', 13, 10, 0
debug_define_got_name: db 'DEFINE: got name addr', 13, 10, 0
debug_define_name_copied: db 'DEFINE: name copied: ', 0
debug_define_creating_entry: db 'DEFINE: creating entry', 13, 10, 0
debug_define_entry_created: db 'DEFINE: entry created!', 13, 10, 0
debug_exec_dict_word: db 'EXEC: dict word found', 13, 10, 0
debug_exec_calling: db 'EXEC: calling exec_definition', 13, 10, 0
debug_exec_returned: db 'EXEC: returned from exec_definition', 13, 10, 0
debug_exec_def_enter: db 'exec_definition: entered', 13, 10, 0
debug_exec_def_rsi: db '  RSI=', 0
debug_exec_def_lodsq: db '  lodsq from=', 0
debug_exec_def_instr: db '  instr=', 0
str_define_name_is: db '[NAME:', 0
str_stack_dump: db '[STACK] ', 0
str_banner: db 'Simplicity v0.3 - 64-bit RPN "Lego" OS', 0
str_prompt: db '> ', 0
str_ok: db ' ok', 0
str_goodbye: db 'Goodbye!', 0
str_unknown: db ' ?', 0

input_buffer: times 1024 db 0
app_input_buffer: times 1024 db 0   ; Separate buffer for app loading (avoids nested buffer corruption)
history_buffer: times 10*80 db 0    ; 10 lines of history
history_count: dq 0                  ; Number of lines in history
history_index: dq 0                  ; Current position in history
cursor_pos: dq 0                     ; Cursor position in current line
line_length: dq 0                    ; Current line length (for history)
shift_state: db 0
ctrl_state: db 0
data_stack: times 64 dq 0      ; Data stack (64 cells)

; App stack isolation
app_stack: times 64 dq 0        ; Separate stack for apps (64 cells)
app_saved_tos: dq 0             ; Saved TOS (R14) when entering app
app_saved_sp: dq 0              ; Saved stack pointer (R15) when entering app
app_active: dq 0                ; 1 if inside app context, 0 otherwise
stack_floor: dq data_stack      ; Active stack base for guards (app-aware)
app_loading: dq 1               ; 1 during boot app loading, 0 after (starts at 1)
array_mode: db 0                ; 1 if inside array literal, 0 otherwise
compile_mode: db 0              ; 0 = interpret, 1 = compile
ctl_items: db 0                 ; Open control-flow constructs while compiling
array_collect_buffer: times 512 dq 0  ; Temporary buffer for array collection (512 elements max)
array_collect_ptr: dq 0         ; Pointer into collection buffer
dict_here: dq DICT_SPACE  ; Next free space in dictionary
dict_latest: dq 0               ; Pointer to most recent entry (0 = empty)
compile_buffer equ 0x240000     ; Compilation buffer (4096 cells, 32KB)
                                ; lives between dictionary and heap
compile_ptr: dq compile_buffer  ; Current compilation position
new_word_name: times 32 db 0    ; Name of word being defined
string_pool: times 2048 db 0    ; Temporary string pool
string_here: dq string_pool     ; Next free space

; Object model
heap_start: dq HEAP_START       ; Heap start (after dictionary)
heap_ptr: dq HEAP_START         ; Current heap position
oom_object: dq 0                ; Pre-allocated "(out of memory)" STRING

; Type tags
TYPE_INT equ 0
TYPE_STRING equ 1
TYPE_REF equ 2
TYPE_ARRAY equ 3
TYPE_USER_BASE equ 4            ; User types start at 4

; Type registry (for user-defined types)
; Each entry: [name_ptr:8] - pointer to STRING object with type name
; Index = type_tag - TYPE_USER_BASE
type_registry: times 256 dq 0   ; Up to 256 user types
next_type_tag: dq TYPE_USER_BASE ; Next available type tag

; Named variables namespace (simple linear list)
named_vars: times 1024 dq 0     ; 128 variable slots (name_hash, value)
named_var_count: dq 0

cursor: dq 0xB8000 + 160

; Dictionary lives at DICT_SPACE (256KB); see memory map at top

; Definition source storage (for SAVE/LOAD persistence)
def_src_buffer: times 4096 db 0     ; Stores source text of definitions
def_src_ptr: dq def_src_buffer      ; Next free position
DEF_SAVE_SECTOR equ 400             ; Disk sector for saved definitions
                                    ; (apps own 200-399, editor owns 450+)

msg64: db 'Simplicity v0.1 - 64-bit RPN "Lego" OS (v1.0 = Doom!)', 0
str_oom: db '(out of memory)', 0

kernel_image_end:
