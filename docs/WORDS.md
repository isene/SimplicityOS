# Simplicity OS - Word Reference

Complete reference for all words in Simplicity OS, organized alphabetically.

## Word Categories

- **Kernel Words** - Implemented in x86_64 assembly
- **Core Words** - Implemented in RPN, loaded at boot
- **User Words** - Defined in apps or by user

## Notation

Stack effects use the notation `( before -- after )`:
- Items to the left of `--` are consumed
- Items to the right are produced
- TOS (top of stack) is rightmost

## All Words (Alphabetical)

### !
**Category:** Kernel
**Stack:** `( value addr -- )`
**Description:** Store 64-bit value at address.
```forth
> 42 {myvar} !    ( store 42 in myvar )
```

### *
**Category:** Kernel
**Stack:** `( a b -- a*b )`
**Description:** Multiply two numbers.
```forth
> 6 7 * .
42 ok
```

### +
**Category:** Kernel
**Stack:** `( a b -- a+b )`
**Description:** Add two numbers.
```forth
> 3 4 + .
7 ok
```

### -
**Category:** Kernel
**Stack:** `( a b -- a-b )`
**Description:** Subtract b from a.
```forth
> 10 3 - .
7 ok
```

### .
**Category:** Kernel
**Stack:** `( x -- )`
**Description:** Print top of stack. Detects type and formats appropriately.
```forth
> 42 .
42 ok
> "Hello" .
Hello ok
```

### .s
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Display entire stack without consuming it.
```forth
> 1 2 3 .s
<3> 1 2 3 ok
```

### /
**Category:** Kernel
**Stack:** `( a b -- a/b )`
**Description:** Signed integer division. Division by zero yields 0.
```forth
> 20 4 / .
5 ok
```

### 0=
**Category:** Kernel
**Stack:** `( n -- flag )`
**Description:** True (-1) if n equals zero, false (0) otherwise.
```forth
> 0 0= .
-1 ok
> 5 0= .
0 ok
```

### <
**Category:** Kernel
**Stack:** `( a b -- flag )`
**Description:** True if a < b.
```forth
> 3 5 < .
-1 ok
```

### <=
**Category:** Kernel
**Stack:** `( a b -- flag )`
**Description:** True if a <= b.
```forth
> 5 5 <= .
-1 ok
```

### <>
**Category:** Kernel
**Stack:** `( a b -- flag )`
**Description:** True if a not equal to b.
```forth
> 3 5 <> .
-1 ok
```

### =
**Category:** Kernel
**Stack:** `( a b -- flag )`
**Description:** True if a equals b.
```forth
> 5 5 = .
-1 ok
```

### >
**Category:** Kernel
**Stack:** `( a b -- flag )`
**Description:** True if a > b.
```forth
> 5 3 > .
-1 ok
```

### >=
**Category:** Kernel
**Stack:** `( a b -- flag )`
**Description:** True if a >= b.
```forth
> 5 5 >= .
-1 ok
```

### ?
**Category:** Kernel
**Stack:** `( ref -- )`
**Description:** Show information about a word reference.
```forth
> ~dup ?
(builtin) ok
```

### @
**Category:** Kernel
**Stack:** `( addr -- value )`
**Description:** Fetch 64-bit value from address.
```forth
> {myvar} @ .
42 ok
```

### [
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Begin array/definition collection. Words inside become references.
```forth
> [ dup * ]
```

### ]
**Category:** Kernel
**Stack:** `( -- array )`
**Description:** End array collection, push resulting array. Use `[ ... ]`
for word bodies passed to `define`. For data arrays, use `array` and `put`
(`{name}` is variable syntax, not an array literal).

### again
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Unconditional jump back to matching `begin`. Creates infinite loop.
```forth
> "forever" [ begin dup . 1 + again ] define
```

### allot
**Category:** Kernel
**Stack:** `( n -- addr )`
**Description:** Allocate n bytes from heap, return address.
```forth
> 512 allot {buffer} !
ok
```

### and
**Category:** Kernel
**Stack:** `( a b -- a&b )`
**Description:** Bitwise AND.
```forth
> 255 15 and .
15 ok
```

### app-enter
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Save current stack and start isolated app stack.
```forth
> 1 2 3 .s
<3> 1 2 3 ok
> app-enter .s
<0> ok
```

### app-exit
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Restore main stack from before app-enter.
```forth
> app-exit .s
<3> 1 2 3 ok
```

### array
**Category:** Kernel
**Stack:** `( n -- arr )`
**Description:** Create array of n elements on the heap.
```forth
> 3 array {a} !
```

### at
**Category:** Kernel
**Stack:** `( array index -- value )`
**Description:** Get element at index from array (0-based). Out-of-bounds
index or non-array pushes "(bad array index)".
```forth
> {a} @ 1 at .
20 ok
```

### begin
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Mark start of loop. Used with `until`, `while/repeat`, or `again`.
```forth
> "count" [ 5 begin dup . 1 - dup 0 = until drop ] define
```

### c!
**Category:** Kernel
**Stack:** `( byte addr -- )`
**Description:** Store single byte at address.
```forth
> 65 {buf} @ c!    ( store 'A' )
```

### c@
**Category:** Kernel
**Stack:** `( addr -- byte )`
**Description:** Fetch single byte from address.
```forth
> {buf} @ c@ .
65 ok
```

### cursor-hide
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Disable the VGA text cursor (used by games).

### cursor-show
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Re-enable the VGA text cursor.

### clstk
**Category:** Kernel
**Stack:** `( ... -- )`
**Description:** Clear entire stack.
```forth
> 1 2 3 clstk .s
<0> ok
```

### cr
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Print newline (carriage return + line feed).
```forth
> "Hello" . cr "World" .
Hello
World ok
```

### define
**Category:** Kernel
**Stack:** `( name-string body-array -- )`
**Description:** Create new word from name and body array.
```forth
> "double" [ dup + ] define
ok
> 5 double .
10 ok
```

### disk-read
**Category:** Kernel
**Stack:** `( sector addr -- )`
**Description:** Read 512-byte sector from disk into memory at addr.
```forth
> 100 {buf} @ disk-read
```

### disk-write
**Category:** Kernel
**Stack:** `( addr sector -- )`
**Description:** Write 512 bytes from addr to disk sector.
```forth
> {buf} @ 100 disk-write
```

### drop
**Category:** Kernel
**Stack:** `( x -- )`
**Description:** Discard top of stack.
```forth
> 1 2 3 drop .s
<2> 1 2 ok
```

### dup
**Category:** Kernel
**Stack:** `( x -- x x )`
**Description:** Duplicate top of stack.
```forth
> 5 dup .s
<2> 5 5 ok
```

### edit
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Alias for editor. Launch text editor.
```forth
> edit
```

### editor
**Category:** User (apps/editor.forth)
**Stack:** `( filename-or-0 -- )`
**Description:** Launch vim-style text editor.
```forth
> 0 editor              ( new buffer )
> "myfile" editor       ( open file )
```
**Modes:**
- Normal: `h/j/k/l` move, `i` insert, `:` command
- Insert: Type text, `Ctrl+C`/`ESC` exit
- Command: `:w file` save, `:q` quit, `:wq` both

### else
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Alternative branch in if/then/else.
```forth
> "sign" [ 0 < if "negative" else "positive" then . ] define
```

### emit
**Category:** Kernel
**Stack:** `( char -- )`
**Description:** Output single character (ASCII code).
```forth
> 65 emit
A ok
```

### eval
**Category:** Kernel
**Stack:** `( str -- )`
**Description:** Interpret text as source code. Accepts a STRING or an
allot'ed buffer of null-terminated text. Together with the editor and
`runfile` this allows writing and running programs entirely on the OS.
```forth
> "3 4 + ." eval
7 ok
```

### execute
**Category:** Kernel
**Stack:** `( ref -- )`
**Description:** Execute word reference. Anything that is not a word
reference (an integer, a string, an array) pushes "(invalid reference)".
```forth
> ~dup execute .s
```

### if
**Category:** Kernel
**Stack:** `( flag -- )`
**Description:** Conditional execution. If flag is non-zero, execute following code.
```forth
> 5 3 > if "yes" . then
yes ok
```

### info
**Category:** Kernel
**Stack:** `( name-string -- )`
**Description:** Show stack effect and description for a word.
```forth
> "dup" info
( a -- a a ) Duplicate top ok
```

### key
**Category:** Kernel
**Stack:** `( -- char )`
**Description:** Wait for keypress, return ASCII code.
```forth
> key .
( press 'a' )
97 ok
```

### key?
**Category:** Kernel
**Stack:** `( -- key|0 )`
**Description:** Non-blocking key check. Returns the keycode if a key is
available, 0 otherwise (not a boolean flag).
```forth
> key? .
0 ok    ( no key pressed )
```

### key-escape
**Category:** Kernel
**Stack:** `( -- 256 )`
**Description:** Push escape key code constant.

### key-up, key-down, key-left, key-right
**Category:** Kernel
**Stack:** `( -- code )`
**Description:** Push arrow key code constants.

### len
**Category:** Kernel
**Stack:** `( obj -- n )`
**Description:** Get length of string or array.
```forth
> "Hello" len .
5 ok
```

### load
**Category:** Kernel
**Stack:** `( name-string -- )`
**Description:** Load and execute an app by name.
```forth
> "hello" load
```

### mod
**Category:** Kernel
**Stack:** `( a b -- a%b )`
**Description:** Signed modulo (remainder of a/b). Modulo by zero yields 0.
```forth
> 17 5 mod .
2 ok
```

### not
**Category:** Kernel
**Stack:** `( flag -- flag' )`
**Description:** Logical NOT: 0 becomes -1, anything else becomes 0.
```forth
> 0 not .
-1 ok
> 12 not .
0 ok
```

### or
**Category:** Kernel
**Stack:** `( a b -- a|b )`
**Description:** Bitwise OR.
```forth
> 12 3 or .
15 ok
```

### over
**Category:** Kernel
**Stack:** `( a b -- a b a )`
**Description:** Copy second item to top.
```forth
> 1 2 over .s
<3> 1 2 1 ok
```

### put
**Category:** Kernel
**Stack:** `( value array index -- )`
**Description:** Set element at index in array. Consumes all three;
out-of-bounds index or non-array pushes "(bad array index)".
```forth
> 99 {a} @ 1 put
ok
```

### remove
**Category:** Kernel
**Stack:** `( name-string -- )`
**Description:** Remove a word from dictionary.
```forth
> "myword" remove
```

### repeat
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Jump back to `begin`, used with `while`.
```forth
> "loop" [ 0 begin dup 5 < while dup . 1 + repeat drop ] define
```

### restore
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Restore app state from disk.

### rot
**Category:** Kernel
**Stack:** `( a b c -- b c a )`
**Description:** Rotate third item to top.
```forth
> 1 2 3 rot .s
<3> 2 3 1 ok
```

### save
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Save app state to disk.

### screen-char
**Category:** Kernel
**Stack:** `( char attr x y -- )`
**Description:** Draw character at screen position with attribute.
```forth
> 65 7 10 5 screen-char    ( 'A' white at 10,5 )
```

### screen-clear
**Category:** Kernel
**Stack:** `( -- )`
**Description:** Clear entire screen.

### screen-scroll
**Category:** Kernel
**Stack:** `( n -- )`
**Description:** Scroll screen up n lines.

### screen-set
**Category:** Kernel
**Stack:** `( x y -- )`
**Description:** Set cursor position.
```forth
> 0 0 screen-set    ( top-left )
```

### sort
**Category:** Kernel
**Stack:** `( array -- sorted-array )`
**Description:** Sort array in ascending order.
```forth
> {a} @ sort .
[1 1 3 4 5 ] ok
```

### swap
**Category:** Kernel
**Stack:** `( a b -- b a )`
**Description:** Exchange top two items.
```forth
> 1 2 swap .s
<2> 2 1 ok
```

### then
**Category:** Kernel
**Stack:** `( -- )`
**Description:** End conditional block started by `if`.
```forth
> 5 0 > if "positive" . then
positive ok
```

### type
**Category:** Kernel
**Stack:** `( obj -- type-code )`
**Description:** Get type code of object. Note: this consumes the object
and replaces it with the code; it does NOT print (use `.` for that).
```forth
> 42 type .
0 ok        ( INT )
> "hi" type .
1 ok        ( STRING )
```

### type-name
**Category:** Kernel
**Stack:** `( name-string type-code -- )`
**Description:** Associate name with type code.
```forth
> "point" 4 type-name
```

### type-name?
**Category:** Kernel
**Stack:** `( type-code -- name-string )`
**Description:** Get name associated with type code.
```forth
> 4 type-name? .
point ok
```

### type-new
**Category:** Kernel
**Stack:** `( -- type-code )`
**Description:** Allocate new user type code.
```forth
> type-new .
4 ok
```

### type-set
**Category:** Kernel
**Stack:** `( array type-code -- typed-array )`
**Description:** Set type of array to user type.
```forth
> {a} @ 4 type-set .
[point: 10 20 ] ok
```

### until
**Category:** Kernel
**Stack:** `( flag -- )`
**Description:** If flag is zero, jump back to `begin`. Exit loop when non-zero.
```forth
> "count" [ 5 begin dup . cr 1 - dup 0 = until drop ] define
> count
5
4
3
2
1
ok
```

### varcount
**Category:** Kernel
**Stack:** `( -- n )`
**Description:** Get count of named variables.

### while
**Category:** Kernel
**Stack:** `( flag -- )`
**Description:** If flag is zero, exit loop. Otherwise continue to `repeat`.
```forth
> "loop" [ 0 begin dup 3 < while dup . 1 + repeat drop ] define
> loop
0
1
2
ok
```

### words
**Category:** Kernel
**Stack:** `( -- string )`
**Description:** Push string listing all defined words.
```forth
> words .
square cube ... ok
```

### xor
**Category:** Kernel
**Stack:** `( a b -- a^b )`
**Description:** Bitwise XOR.
```forth
> 12 10 xor .
6 ok
```

### ~
**Category:** Kernel
**Stack:** `( -- ref )`
**Description:** Get reference to following word (tick).
```forth
> ~dup        ( push reference to dup )
> execute .s  ( execute it )
```

---

## Kernel Words Summary

### Arithmetic
`+` `-` `*` `/` `mod`

### Comparison
`=` `<` `>` `<>` `<=` `>=` `0=`

### Logic
`and` `or` `xor` `not`

### Stack
`dup` `drop` `swap` `rot` `over` `.` `.s` `clstk`

### Memory
`@` `!` `c@` `c!` `allot`

### Control Flow
`if` `then` `else` `begin` `until` `while` `repeat` `again`

### I/O
`emit` `cr` `key` `key?`

### Float
Doubles live as raw IEEE-754 bits in ordinary stack cells; only
f-words interpret them. Literals: `3.14`, `-0.5` (no exponent form).

| Words | Stack | Notes |
|-------|-------|-------|
| `s>f` | ( n -- f ) | integer to float |
| `f>s` | ( f -- n ) | truncated |
| `f+ f- f* f/` | ( a b -- r ) | arithmetic |
| `f< f> f=` | ( a b -- flag ) | comparison |
| `fneg fabs fsqrt` | ( f -- r ) | |
| `fsin fcos ftan fatan` | ( f -- r ) | radians |
| `fln flog fexp` | ( f -- r ) | |
| `fpow` | ( a b -- a^b ) | a positive |
| `fpi` | ( -- pi ) | |
| `fix` | ( n -- ) | set decimals 0-9 |
| `f.` | ( f -- ) | print |

`.` prints float bits as a large integer; use `f.`. Integer parts
beyond 2^63 print as "(big)".

### Screen
`screen-char` `screen-clear` `screen-get` `screen-line-shift`
`screen-scroll` `screen-set` `cursor-hide` `cursor-show`

### Disk
`disk-read` `disk-write`

### Types
`type` `len` `type-new` `type-name` `type-name?` `type-set`

### Arrays
`at` `put` `sort`

### Dictionary
`define` `words` `~` `?` `execute` `remove`

### Apps
`load` `save` `restore` `app-enter` `app-exit` `info`

---

## User Words (Apps)

### editor
Full-featured vim-style text editor. See [EDITOR.md](EDITOR.md) for details.

### hello
Simple "Hello World" demo app.
```forth
> "hello" load
```

### invaders
Space Invaders: 18 aliens in 3 rows, alien bombs, 3 lives, levels with
increasing speed. Controls: h/l or arrows move, x or space fires, q quits.
Loaded at boot; start with:
```forth
> invaders
```
