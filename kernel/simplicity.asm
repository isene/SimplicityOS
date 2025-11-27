[BITS 64]
long_mode_64:
    ; Setup 64-bit segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Clear screen in 64-bit mode
    mov rdi, 0xB8000
    mov rcx, 2000
    mov rax, 0x0F200F20
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

    ; Initialize Forth (64-bit)
    mov rsp, 0x80000        ; Data stack
    mov rbp, 0x70000        ; Return stack
    mov rsi, test_program   ; Instruction pointer
    jmp NEXT

; NEXT - Forth inner interpreter (64-bit)
NEXT:
    lodsq                   ; Load qword
    jmp rax

; Core Forth words (64-bit)

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
    lodsq
    push rax
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
print_number:
    push rax
    push rbx
    push rcx
    push rdx

    mov rbx, 10
    xor rcx, rcx

    test rax, rax
    jnz .conv
    mov al, '0'
    call emit_char
    jmp .done

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

; Wait for keypress and return ASCII in RAX
wait_key:
    push rbx
.wait:
    ; Check if key available (port 0x64, bit 0)
    in al, 0x64
    test al, 1
    jz .wait

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

    ; Ignore other key releases (bit 7 set)
    test al, 0x80
    jnz .wait

    ; Convert scancode to ASCII
    call scancode_to_ascii

    ; If zero (unmapped key), wait for another
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

; Convert scancode in AL to ASCII in RAX
scancode_to_ascii:
    push rbx
    movzx rbx, al           ; Zero-extend AL to RBX

    ; Backspace (scancode 0x0E)
    cmp rbx, 0x0E
    jne .check_numbers
    mov rax, 8              ; ASCII backspace
    jmp .done

.check_numbers:
    ; Numbers 1-9,0 (scancodes 0x02-0x0B)
    cmp rbx, 0x02
    jl .letters
    cmp rbx, 0x0B
    jg .check_special

    ; Check if shift pressed
    cmp byte [shift_state], 0
    je .numbers_no_shift

    ; Shifted number keys: !@#$%^&*()
    sub rbx, 0x02
    lea rax, [shift_numbers]
    add rax, rbx
    movzx rax, byte [rax]
    jmp .done

.numbers_no_shift:
    ; Numbers 1-9,0
    sub rbx, 0x02
    cmp rbx, 9
    jne .digit
    mov rax, '0'            ; Scancode 0x0B = '0'
    jmp .done
.digit:
    add rbx, '1'
    mov rax, rbx
    jmp .done

.check_special:
    ; Minus/underscore (scancode 0x0C)
    cmp rbx, 0x0C
    jne .check_equals
    mov rax, '-'
    cmp byte [shift_state], 0
    je .done
    mov rax, '_'
    jmp .done

.check_equals:
    ; Equals/plus (scancode 0x0D)
    cmp rbx, 0x0D
    jne .check_period
    mov rax, '='
    cmp byte [shift_state], 0
    je .done
    mov rax, '+'
    jmp .done

.check_period:
    ; Period (scancode 0x34)
    cmp rbx, 0x34
    jne .check_comma
    mov rax, '.'
    cmp byte [shift_state], 0
    je .done
    mov rax, '>'
    jmp .done

.check_comma:
    ; Comma (scancode 0x33)
    cmp rbx, 0x33
    jne .check_slash
    mov rax, ','
    cmp byte [shift_state], 0
    je .done
    mov rax, '<'
    jmp .done

.check_slash:
    ; Slash (scancode 0x35)
    cmp rbx, 0x35
    jne .check_semicolon
    mov rax, '/'
    cmp byte [shift_state], 0
    je .done
    mov rax, '?'
    jmp .done

.check_semicolon:
    ; Semicolon/colon (scancode 0x27)
    cmp rbx, 0x27
    jne .check_backtick
    mov rax, ';'
    cmp byte [shift_state], 0
    je .done
    mov rax, ':'
    jmp .done

.check_backtick:
    ; Backtick/tilde (scancode 0x29)
    cmp rbx, 0x29
    jne .check_apostrophe
    mov rax, 96             ; Backtick `
    cmp byte [shift_state], 0
    je .done
    mov rax, 126            ; Tilde ~
    jmp .done

.check_apostrophe:
    ; Apostrophe/quote (scancode 0x28)
    cmp rbx, 0x28
    jne .letters
    mov rax, 39             ; Apostrophe '
    cmp byte [shift_state], 0
    je .done
    mov rax, 34             ; Double quote "
    jmp .done

.letters:
    ; Letter scancodes (0x10-0x19 = QWERTYUIOP, etc)
    ; Simple mapping for common keys
    mov rax, 0

    ; Space (scancode 0x39)
    cmp bl, 0x39
    jne .check_enter
    mov rax, ' '
    jmp .done

.check_enter:
    ; Enter (scancode 0x1C)
    cmp bl, 0x1C
    jne .check_letters
    mov rax, 10             ; Newline
    jmp .done

.check_letters:
    ; Q-P (0x10-0x1C)
    lea rax, [scancode_table]
    cmp bl, 0x50
    jge .done
    add rax, rbx
    movzx rax, byte [rax]

    ; If shift pressed, convert to uppercase
    test rax, rax
    jz .done
    cmp byte [shift_state], 0
    je .done

    ; Convert a-z to A-Z
    cmp al, 'a'
    jl .done
    cmp al, 'z'
    jg .done
    sub al, 32              ; 'a' - 'A' = 32

.done:
    pop rbx
    ret

; Scancode to ASCII table
scancode_table:
    times 0x10 db 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'  ; 0x10-0x19
    db '[', ']', 0, 0                                     ; 0x1A-0x1D (brackets)
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'      ; 0x1E-0x26
    db 0, 0, 0, 0, 0                                      ; 0x27-0x2B (5 zeros!)
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm'                ; 0x2C-0x32
    times 0x20 db 0

; Shifted number row: 1-9,0 → !@#$%^&*()
shift_numbers:
    db '!', '@', '#', '$', '%', '^', '&', '*', '(', ')'

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
    ; Print banner
    mov rax, str_banner
    call print_string
    call newline

    ; Initialize stacks
    ; R15 points one past last item, R14 holds TOS
    mov r15, forth_stack    ; Data stack base
    mov r14, 0              ; Top of stack (TOS) - empty initially
    mov rbp, 0x70000        ; Return stack (grows down)

.main_loop:
    ; Print prompt
    mov rax, str_prompt
    call print_string

    ; Read line into buffer
    mov rdi, input_buffer
    xor rcx, rcx            ; Character count

.read_char:
    call wait_key           ; Get character in RAX

    cmp al, 10              ; Enter?
    je .execute_line

    cmp al, 8               ; Backspace?
    je .backspace

    ; Regular character - echo and store
    call emit_char
    mov [rdi], al
    inc rdi
    inc rcx
    cmp rcx, 79             ; Max line length
    jl .read_char
    jmp .execute_line

.backspace:
    test rcx, rcx
    jz .read_char           ; Nothing to delete
    dec rdi
    dec rcx
    ; Move cursor back, print space, move back again
    mov rbx, [cursor]
    sub rbx, 2              ; Move back one char
    mov byte [rbx], ' '     ; Erase with space
    mov byte [rbx+1], 0x0F
    mov [cursor], rbx       ; Update cursor
    call update_hw_cursor
    jmp .read_char

.execute_line:
    ; Null-terminate input
    mov byte [rdi], 0

    call newline

    ; Parse and execute the line
    mov rsi, input_buffer   ; RSI = parse pointer
    ; R15 already points to Forth stack (don't reset!)

.parse_loop:
    ; Skip leading spaces
    call skip_spaces
    cmp byte [rsi], 0
    je .line_done

    ; Check for tick (~) - get reference to next word
    cmp byte [rsi], 126     ; Tilde
    je .handle_tick

    ; Check for quote (") - string literal
    cmp byte [rsi], 34      ; Double quote
    je .handle_string

    ; Check for bracket [name] - named variable access
    cmp byte [rsi], '['
    je .handle_bracket

    ; Get word
    call parse_word         ; Returns word in RDI, length in RCX

    ; Check if getting name for definition
    cmp byte [compile_mode], 2
    je .save_name

    ; Check if number
    call is_number
    test rax, rax
    jnz .push_number

    ; Check if known word
    call lookup_word
    test rax, rax
    jz .unknown_word

    ; Check if it's a dictionary word (has DOCOL code pointer)
    push rax
    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rax
    je .dict_word

    ; Built-in word
.builtin_word:
    ; Built-in word - RAX is function address
    ; Check if compiling
    cmp byte [compile_mode], 0
    jne .compile_word

    ; Execute built-in word (interpret mode)
    call rax
    jmp .parse_loop

.dict_word:
    ; Dictionary word - execute definition
    cmp byte [compile_mode], 0
    jne .compile_dictword

    ; Save parse position
    push rsi

    ; Execute colon definition
    add rax, 8              ; Skip code pointer to body
    mov rsi, rax
.exec_def:
    lodsq
    cmp rax, EXIT
    je .dict_done

    ; Check if it's LIT (from old Forth code)
    cmp rax, LIT
    jne .not_lit

    ; It's LIT - next qword is the number
    lodsq
    mov [r15], rax
    add r15, 8
    jmp .exec_def

.not_lit:
    ; Check if it's a nested dictionary word
    push rbx
    push rcx

    ; Is it in dict range?
    cmp rax, dictionary_space
    jl .is_builtin
    mov rcx, [dict_here]
    cmp rax, rcx
    jge .is_builtin

    ; Check if DOCOL
    mov rbx, [rax]
    cmp rbx, DOCOL
    jne .is_builtin

    ; Nested dictionary word - save RSI to return stack and recurse
    mov [rbp], rsi
    sub rbp, 8
    add rax, 8              ; Point to body
    mov rsi, rax
    pop rcx
    pop rbx
    jmp .exec_def           ; Continue executing (now nested definition)

.is_builtin:
    pop rcx
    pop rbx
    call rax
    jmp .exec_def

.dict_done:
    ; Check if we're in a nested call
    ; If RBP < initial value (0x70000), we have saved RSI on return stack
    cmp rbp, 0x70000
    jge .top_level

    ; Nested - restore RSI from return stack and continue
    add rbp, 8
    mov rsi, [rbp]
    jmp .exec_def

.top_level:
    ; Top level - restore parse position from machine stack
    pop rsi
    jmp .parse_loop

.compile_dictword:
    ; When compiling, store the code field address
    mov rbx, [compile_ptr]
    mov [rbx], rax
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .parse_loop

.compile_word:
    ; Special case: ; is IMMEDIATE - executes even in compile mode
    cmp rax, word_semi
    je .execute_now

    ; Add built-in word address to compilation buffer
    mov rbx, [compile_ptr]
    ; RAX already has function address for built-in words
    mov [rbx], rax
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .parse_loop

.execute_now:
    call rax
    jmp .parse_loop

.save_name:
    ; Save word as definition name
    push rsi
    push rdi
    push rcx
    mov rsi, rdi
    mov rdi, new_word_name
    rep movsb
    mov byte [rdi], 0       ; Null terminate
    pop rcx
    pop rdi
    pop rsi

    ; Now enter compile mode
    mov byte [compile_mode], 1
    jmp .parse_loop

.push_number:
    call parse_number       ; Converts word to number in RAX

    ; Check if compiling
    cmp byte [compile_mode], 0
    jne .compile_literal

    ; Interpret mode - push to stack with TOS
    ; Push old TOS to memory, new value becomes TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .parse_loop

.compile_literal:
    ; Compile mode - add LIT and number to buffer
    mov rbx, [compile_ptr]
    mov qword [rbx], LIT    ; Compile LIT word
    add rbx, 8
    mov [rbx], rax          ; Compile the number
    add rbx, 8
    mov [compile_ptr], rbx
    jmp .parse_loop

.unknown_word:
    ; Print error
    mov rax, str_unknown
    call print_string
    jmp .line_done

.handle_tick:
    ; Tick - get reference to next word
    inc rsi                 ; Skip apostrophe
    call skip_spaces
    call parse_word         ; Get the word name

    ; Look it up
    push rsi
    call lookup_word
    pop rsi

    ; Push reference to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .parse_loop

.handle_bracket:
    ; [name] - Get/create named variable and push address of its value
    inc rsi                 ; Skip [

    ; Parse name until ]
    mov rdi, rsi
    xor rcx, rcx
.bracket_parse:
    mov al, [rsi]
    test al, al
    jz .bracket_done
    cmp al, ']'
    je .bracket_done
    inc rsi
    inc rcx
    jmp .bracket_parse
.bracket_done:
    inc rsi                 ; Skip ]

    ; Look up or create named variable
    push rsi
    push rdi
    push rcx
    call get_or_create_named_var    ; Returns value slot address in RAX
    pop rcx
    pop rdi
    pop rsi

    ; Push address to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .parse_loop

.handle_string:
    ; Create STRING object
    inc rsi                 ; Skip opening quote

    ; Count string length first
    push rsi
    xor rcx, rcx
.count_loop:
    mov al, [rsi]
    test al, al
    jz .count_done
    cmp al, 34              ; Closing quote?
    je .count_done
    inc rsi
    inc rcx
    jmp .count_loop
.count_done:
    pop rsi

    ; Allocate object: 16 bytes header + string + null
    push rcx
    add rcx, 17             ; Header(16) + null(1)
    call allocate_object    ; Returns address in RAX
    pop rcx

    ; Fill object header
    mov qword [rax], TYPE_STRING
    mov [rax+8], rcx

    ; Copy string data
    lea rdi, [rax+16]
.copy_loop:
    mov bl, [rsi]
    test bl, bl
    jz .copy_done
    inc rsi
    cmp bl, 34
    je .copy_done
    mov [rdi], bl
    inc rdi
    jmp .copy_loop
.copy_done:
    mov byte [rdi], 0       ; Null terminate
    inc rsi                 ; Skip closing quote

    ; Push object to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    jmp .parse_loop

.line_done:
    mov rax, str_ok
    call print_string_gray
    call newline

    jmp .main_loop

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
    push rbx
    push rcx
    push rdi
    push rsi

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
    test rbx, rax
    jz .not_found

    ; Compare names (simplified - just compare first char for now)
    ; TODO: Full string comparison
    lea rbx, [rbx+16]       ; String data
    mov r8b, [rbx]
    mov r9b, [rdi]
    cmp r8b, r9b
    je .found               ; Found it (simplified match)

    add rsi, 16             ; Next entry
    jmp .search_loop

.not_found:
    ; Create new entry
    mov rsi, [named_var_count]
    shl rsi, 4
    add rsi, named_vars

    ; Create name STRING
    push rsi
    push rdi
    push rcx
    mov rax, rdi
    push rax
    mov rsi, rax
    call create_string_from_cstr
    pop rcx
    pop rcx
    pop rdi
    pop rsi

    ; Store name STRING
    mov [rsi], rax

    ; Initialize value to 0
    mov qword [rsi+8], 0

    ; Increment count
    inc qword [named_var_count]

.found:
    ; Return address of value slot
    lea rax, [rsi+8]

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Allocate object (RCX = total size in bytes)
; Returns address in RAX
allocate_object:
    push rbx
    push rcx

    ; Get current heap position
    mov rax, [heap_ptr]

    ; Align to 16 bytes
    add rax, 15
    and rax, ~15

    ; Update heap pointer
    add rcx, rax
    mov [heap_ptr], rcx

    pop rcx
    pop rbx
    ret

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
    mov [r15], rax          ; Push to stack
    add r15, 8
    jmp .exec_loop

.not_lit:
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

    xor rax, rax            ; Result
    mov rbx, 10             ; Base

.loop:
    movzx r8, byte [rdi]
    sub r8, '0'
    imul rax, rbx
    add rax, r8
    inc rdi
    dec rcx
    jnz .loop

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
    jmp .done
.found_fetch:
    mov rax, word_fetch
    jmp .done
.found_store:
    mov rax, word_store
    jmp .done
.found_inspect:
    mov rax, word_inspect
    jmp .done

.check_multi:
    ; Check multi-char words
    ; .S (stack display)
    cmp rcx, 2
    jne .try_dup
    cmp byte [rdi], '.'
    jne .try_dup
    cmp byte [rdi+1], 's'
    jne .try_dup
    mov rax, word_dots
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
    jne .try_swap
    cmp byte [rdi], 'd'
    jne .try_swap
    cmp byte [rdi+1], 'r'
    jne .try_swap
    cmp byte [rdi+2], 'o'
    jne .try_swap
    cmp byte [rdi+3], 'p'
    jne .try_swap
    mov rax, word_drop
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
    jne .try_words
    cmp byte [rdi], 'c'
    jne .try_words
    cmp byte [rdi+1], 'r'
    jne .try_words
    mov rax, word_cr
    jmp .done

.try_words:
    cmp rcx, 5
    jne .try_forget
    cmp byte [rdi], 'w'
    jne .try_forget
    cmp byte [rdi+1], 'o'
    jne .try_forget
    cmp byte [rdi+2], 'r'
    jne .try_forget
    cmp byte [rdi+3], 'd'
    jne .try_forget
    cmp byte [rdi+4], 's'
    jne .try_forget
    mov rax, word_words
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
    jne .try_see
    cmp byte [rdi], 'f'
    jne .try_see
    cmp byte [rdi+1], 'r'
    jne .try_see
    cmp byte [rdi+2], 'e'
    jne .try_see
    cmp byte [rdi+3], 'e'
    jne .try_see
    mov rax, word_free
    jmp .done

.try_see:
    cmp rcx, 3
    jne .not_found
    cmp byte [rdi], 's'
    jne .not_found
    cmp byte [rdi+1], 'e'
    jne .not_found
    cmp byte [rdi+2], 'e'
    jne .not_found
    mov rax, word_see
    jmp .done

.not_found:
    xor rax, rax

.done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; Word implementations for REPL (using R15 as Forth stack)
word_plus:
    ; Add: pop second, add to TOS (in R14)
    sub r15, 8
    add r14, [r15]
    ret

word_minus:
    ; Subtract: second - TOS, result in TOS
    sub r15, 8
    mov rax, [r15]
    sub rax, r14
    mov r14, rax
    ret

word_mult:
    ; Multiply: second * TOS
    sub r15, 8
    imul r14, [r15]
    ret

word_div:
    ; Divide: second / TOS
    sub r15, 8
    mov rax, [r15]          ; Dividend (second)
    mov rbx, r14            ; Divisor (TOS)
    xor rdx, rdx
    div rbx
    mov r14, rax            ; Quotient becomes TOS
    ret

word_dot:
    ; Print TOS and load new TOS
    mov rax, r14

    ; Check if immediate integer (< 0x100000)
    cmp rax, 0x100000
    jl .print_immediate

    ; Object - check type
    mov rbx, [rax]          ; Get type tag
    cmp rbx, TYPE_STRING
    je .print_string_obj
    cmp rbx, TYPE_REF
    je .print_ref_obj

    ; Unknown type - print address
    call print_number
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
    ; Load new TOS after printing
    sub r15, 8
    mov r14, [r15]
    ret

str_code_obj: db '(code)', 0

word_dots:
    ; Display stack: <depth> item1 item2 ...
    push rax
    push rbx
    push rcx
    push rdi

    ; Calculate depth
    mov rax, r15
    sub rax, forth_stack
    shr rax, 3              ; Divide by 8
    mov rcx, rax            ; Save depth

    ; Print <depth>
    mov al, '<'
    call emit_char
    mov rax, rcx
    call print_number
    mov al, '>'
    call emit_char
    mov al, ' '
    call emit_char

    ; Print each stack item
    test rcx, rcx
    jz .done
    mov rdi, forth_stack
.loop:
    mov rax, [rdi]
    call print_number
    mov al, ' '
    call emit_char
    add rdi, 8
    dec rcx
    jnz .loop

.done:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

word_dup:
    ; Duplicate TOS: push R14, R14 unchanged
    mov [r15], r14
    add r15, 8
    ret

word_drop:
    ; Drop TOS: load new TOS from stack
    sub r15, 8
    mov r14, [r15]
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
    call emit_char
    sub r15, 8
    mov r14, [r15]          ; Load new TOS
    ret

word_cr:
    ; Newline (doesn't consume stack)
    call newline
    ret

word_fetch:
    ; Fetch: TOS is address, replace with value at address
    mov rax, [r14]
    mov r14, rax
    ret

word_store:
    ; Store: ( value addr -- ) second=value, TOS=addr
    mov rax, r14            ; Address
    sub r15, 8
    mov rbx, [r15]          ; Value
    mov [rax], rbx
    sub r15, 8
    mov r14, [r15]          ; New TOS
    ret

word_inspect:
    ; ? - Inspect reference from TOS, push STRING description
    mov rax, r14            ; Get TOS reference

    test rax, rax
    jz .push_unknown

    ; Check if dictionary or built-in
    cmp rax, dictionary_space
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

word_execute:
    ; Execute code reference from TOS
    mov rax, r14            ; Get reference from TOS

    ; Load new TOS
    sub r15, 8
    mov r14, [r15]

    ; Validate reference (check for null/invalid)
    test rax, rax
    jz .invalid_ref

    ; Check if dictionary word
    push rbx
    cmp rax, dictionary_space
    jl .exec_builtin

    mov rbx, [rax]
    cmp rbx, DOCOL
    pop rbx
    jne .exec_builtin

    ; Dictionary word - execute definition body
    mov [rbp], rsi
    sub rbp, 8
    add rax, 8              ; Skip to body
    mov rsi, rax

.exec_loop:
    lodsq
    cmp rax, EXIT
    je .exec_end

    cmp rax, LIT
    jne .exec_call
    lodsq
    mov [r15], rax
    add r15, 8
    jmp .exec_loop

.exec_call:
    call rax
    jmp .exec_loop

.exec_end:
    add rbp, 8
    mov rsi, [rbp]
    ret

.exec_builtin:
    call rax
    ret

.invalid_ref:
    ; Push error STRING for invalid reference (TOS model)
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

    ; Get element: array[index]
    lea rax, [rax + 16 + rbx*8]
    mov r14, [rax]          ; Value becomes TOS
    ret

word_put:
    ; Array store ( value array index -- ) TOS=index
    mov rbx, r14            ; Index from TOS
    sub r15, 8
    mov rcx, [r15]          ; Array from second
    sub r15, 8
    mov rax, [r15]          ; Value from third

    ; Store: array[index] = value
    lea rcx, [rcx + 16 + rbx*8]
    mov [rcx], rax

    ; Load new TOS
    sub r15, 8
    mov r14, [r15]
    ret

word_free:
    ; Free object from TOS (stub - just drops it)
    sub r15, 8
    mov r14, [r15]
    ret

word_words:
    ; Push STRING listing all words
    push rsi
    mov rsi, str_builtins
    call create_string_from_cstr
    pop rsi

    ; Push to TOS
    mov [r15], r14
    add r15, 8
    mov r14, rax
    ret

str_builtins: db '+ - * / . .s dup drop swap rot over @ ! emit cr : ; ~square ? words execute ', 0

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
    cmp rax, dictionary_space
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

    ; Reset compilation buffer
    mov rax, compile_buffer
    mov [compile_ptr], rax
    ret

word_semi:
    ; End compilation mode
    mov byte [compile_mode], 0

    ; Create dictionary entry
    call create_dict_entry
    ret

str_banner: db 'Simplicity Forth REPL v0.3', 0
str_prompt: db '> ', 0
str_ok: db ' ok', 0
str_unknown: db ' ?', 0

input_buffer: times 80 db 0
shift_state: db 0
forth_stack: times 64 dq 0      ; Forth data stack (64 cells)
compile_mode: db 0              ; 0 = interpret, 1 = compile
dict_here: dq dictionary_space  ; Next free space in dictionary
dict_latest: dq 0               ; Pointer to most recent entry (0 = empty)
compile_buffer: times 256 dq 0  ; Compilation buffer
compile_ptr: dq compile_buffer  ; Current compilation position
new_word_name: times 32 db 0    ; Name of word being defined
string_pool: times 2048 db 0    ; Temporary string pool
string_here: dq string_pool     ; Next free space

; Object model
heap_start: dq 0x200000         ; Heap starts at 2MB
heap_ptr: dq 0x200000           ; Current heap position

; Type tags
TYPE_INT equ 0
TYPE_STRING equ 1
TYPE_REF equ 2
TYPE_ARRAY equ 3

; Named variables namespace (simple linear list)
named_vars: times 1024 dq 0     ; 128 variable slots (name_hash, value)
named_var_count: dq 0

cursor: dq 0xB8000 + 160

; Dictionary space (4KB for user-defined words)
dictionary_space: times 4096 db 0

; GDT - 32-bit for now (we'll stay in compatibility mode)
align 8
gdt_start:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 11001111b        ; 32-bit (D=1, L=0)
    db 0

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
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

msg: db 'Simplicity OS - Long mode test', 0
msg64: db 'Simplicity OS v0.2 - 64-bit Forth', 0
