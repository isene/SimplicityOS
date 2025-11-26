; Simplicity OS - Forth Kernel
; Minimal Forth implementation for bare metal x86_64
; Based on JonesForth architecture

[BITS 64]
[ORG 0x100000]      ; Kernel loaded at 1MB

; Register usage (following JonesForth convention):
; RSI = Forth instruction pointer (IP)
; RAX = working register
; RBX = working register
; RSP = data stack pointer
; RBP = return stack pointer

; Macro for defining primitive words - must be before use
%macro defcode 3
    align 8
name_%3:
    dq link
    %define link name_%3
    db %1, 0
    align 8
%3:
    dq code_%3
code_%3:
%endmacro

kernel_start:
    ; Set up stacks
    mov rsp, 0x80000        ; Data stack at 512KB
    mov rbp, 0x70000        ; Return stack at 448KB

    ; Print welcome message
    mov rsi, msg_welcome
    call print_vga

    ; Initialize Forth system
    mov qword [var_state], 0    ; Start in interpret mode
    mov qword [var_here], freespace  ; Dictionary pointer

    ; Start interpreter with test code
    mov rsi, cold_start
    jmp NEXT

; NEXT - The inner interpreter
; Fetches next word address from [RSI] and executes it
NEXT:
    lodsq               ; Load qword from [RSI] into RAX, increment RSI
    jmp [rax]           ; Jump to code address

; DOCOL - Enter a colon definition
; Pushes current IP to return stack and sets IP to word body
DOCOL:
    sub rbp, 8          ; Make space on return stack
    mov [rbp], rsi      ; Save current IP
    add rax, 8          ; Skip code pointer, point to word body
    mov rsi, rax        ; Set IP to word body
    jmp NEXT

; Link pointer for dictionary (initialize to 0)
%define link 0

; EXIT - Return from colon definition
defcode "EXIT", 4, EXIT
    mov rsi, [rbp]      ; Restore IP from return stack
    add rbp, 8          ; Pop return stack
    jmp NEXT

; Stack manipulation words

defcode "DROP", 4, DROP
    add rsp, 8
    jmp NEXT

defcode "DUP", 3, DUP
    mov rax, [rsp]
    push rax
    jmp NEXT

defcode "SWAP", 4, SWAP
    pop rax
    pop rbx
    push rax
    push rbx
    jmp NEXT

defcode "OVER", 4, OVER
    mov rax, [rsp+8]
    push rax
    jmp NEXT

defcode "ROT", 3, ROT
    pop rax             ; a
    pop rbx             ; b
    pop rcx             ; c
    push rbx            ; b
    push rax            ; a
    push rcx            ; c
    jmp NEXT

; Arithmetic words

defcode "+", 1, PLUS
    pop rax
    add [rsp], rax
    jmp NEXT

defcode "-", 1, MINUS
    pop rax
    sub [rsp], rax
    jmp NEXT

defcode "*", 1, MULT
    pop rax
    pop rbx
    imul rax, rbx
    push rax
    jmp NEXT

defcode "/", 1, DIV
    xor rdx, rdx
    pop rbx             ; divisor
    pop rax             ; dividend
    idiv rbx
    push rax            ; quotient
    jmp NEXT

; Memory access words

defcode "@", 1, FETCH
    pop rax
    mov rax, [rax]
    push rax
    jmp NEXT

defcode "!", 1, STORE
    pop rax             ; address
    pop rbx             ; value
    mov [rax], rbx
    jmp NEXT

defcode "C@", 2, CFETCH
    pop rax
    xor rbx, rbx
    mov bl, [rax]
    push rbx
    jmp NEXT

defcode "C!", 2, CSTORE
    pop rax             ; address
    pop rbx             ; value
    mov [rax], bl
    jmp NEXT

; I/O words

defcode "EMIT", 4, EMIT
    pop rax
    call emit_char
    jmp NEXT

defcode ".", 1, DOT
    pop rax
    call print_number
    mov al, ' '
    call emit_char
    jmp NEXT

; Dictionary words

defcode "HERE", 4, HERE
    mov rax, [var_here]
    push rax
    jmp NEXT

defcode ",", 1, COMMA
    mov rax, [var_here]
    pop rbx
    mov [rax], rbx
    add rax, 8
    mov [var_here], rax
    jmp NEXT

; Literal value support
defcode "LIT", 3, LIT
    lodsq
    push rax
    jmp NEXT

; System words

defcode "BYE", 3, BYE
    ; Halt system
    cli
    hlt
    jmp $

; Helper functions

; Print null-terminated string via VGA
print_vga:
    push rax
    push rbx
    mov rbx, [var_vga_cursor]
.loop:
    lodsb
    test al, al
    jz .done
    cmp al, 10          ; Newline?
    je .newline
    mov [rbx], al
    mov byte [rbx+1], 0x0F
    add rbx, 2
    jmp .loop
.newline:
    ; Move to next line
    mov rax, rbx
    sub rax, 0xB8000
    shr rax, 1          ; Divide by 2 (char + attribute)
    xor rdx, rdx
    mov rcx, 80
    div rcx             ; RAX = row, RDX = col
    inc rax             ; Next row
    xor rdx, rdx
    mul rcx
    shl rax, 1
    add rax, 0xB8000
    mov rbx, rax
    jmp .loop
.done:
    mov [var_vga_cursor], rbx
    pop rbx
    pop rax
    ret

; Emit single character
emit_char:
    push rax
    push rbx
    mov rbx, [var_vga_cursor]
    mov [rbx], al
    mov byte [rbx+1], 0x0F
    add rbx, 2
    mov [var_vga_cursor], rbx
    pop rbx
    pop rax
    ret

; Print number in decimal
print_number:
    push rax
    push rbx
    push rcx
    push rdx

    mov rbx, 10
    xor rcx, rcx        ; Digit counter

    ; Handle zero specially
    test rax, rax
    jnz .convert
    mov al, '0'
    call emit_char
    jmp .done

.convert:
    xor rdx, rdx
    div rbx             ; Divide by 10
    add rdx, '0'        ; Convert remainder to ASCII
    push rdx            ; Save digit
    inc rcx
    test rax, rax
    jnz .convert

.print:
    pop rax
    call emit_char
    loop .print

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Variables
align 8
var_state:      dq 0        ; 0 = interpret, 1 = compile
var_here:       dq 0        ; Dictionary pointer
var_vga_cursor: dq 0xB8000  ; VGA cursor position

; Messages
msg_welcome:    db 'Simplicity OS v0.1', 10, 'Forth kernel ready', 10, 10, 0

; Cold start sequence - test code
align 8
cold_start:
    dq LIT, 2
    dq LIT, 3
    dq PLUS
    dq DOT
    dq LIT, 5
    dq LIT, 7
    dq MULT
    dq DOT
    dq BYE

; Free space for user definitions
align 4096
freespace:
    times 65536 db 0    ; 64KB for user dictionary
