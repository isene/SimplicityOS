# Simplicity RPN - Complete Guide

## What is RPN?

**RPN (Reverse Polish Notation)** means you put the operation AFTER the data:

```
Regular math:  5 + 3
RPN:           5 3 +
```

**Why RPN?**
- No parentheses needed
- Natural for stack-based computing
- Composable and simple
- Every operation works the same way

## The Stack

Everything in Simplicity RPN uses a **stack** - a list where you add and remove from the top:

```
5           Stack: [5]
3           Stack: [5, 3]
+           Stack: [8]        (popped 5 and 3, pushed result)
```

**Top of stack** is on the right. Operations take inputs from the top.

## Basic Operations

### Numbers
Just type a number to push it:
```
42          Stack: [42]
100         Stack: [42, 100]
```

### Math
Operators pop inputs and push results:
```
5 3 +       Result: 8        (5 + 3)
10 2 -      Result: 8        (10 - 2)
4 3 *       Result: 12       (4 * 3)
20 4 /      Result: 5        (20 / 4)
```

### Printing
```
.           Print top of stack
42 .        Prints: 42
```

### Stack Manipulation
```
dup         Duplicate top          [5] → [5, 5]
drop        Remove top             [5, 3] → [5]
swap        Exchange top two       [5, 3] → [3, 5]
rot         Rotate top three       [1, 2, 3] → [2, 3, 1]
over        Copy second to top     [5, 3] → [5, 3, 5]
```

## Strings

Strings are created with double quotes:
```
"Hello"     Pushes string object
.           Prints: Hello
```

String operations:
```
"Hello" "World" +    Concatenates (if implemented)
"test" len           Gets length
```

## Variables

Variables use bracket notation:
```
100 [x] !            Store 100 in variable x
[x] @                Fetch from variable x
.                    Print value
```

Variables are created automatically when first used.

## Arrays

Arrays collect multiple items:
```
{ 1 2 3 }            Creates array [1, 2, 3]
{ "a" "b" "c" }      Creates array of strings
```

**Important:** Inside `{ }`, words become references automatically:
```
{ 5 dup }            Creates: [5, REF(dup)]
                     NOT: [5, 5]
```

This lets you store operations to execute later!

## Defining Words (Creating Functions)

### Simple Definitions

**Old Forth way (DON'T USE):**
```
: hello "Hi" . ;
```

**New Pure RPN way:**
```
"hello" { "Hi" . } define
```

**How it works:**
1. `"hello"` - Push the word name as a string
2. `{ "Hi" . }` - Create array containing: STRING("Hi"), REF(.)
3. `define` - Pop name and array, create dictionary entry

**Using the defined word:**
```
hello               Prints: Hi
```

### More Complex Definitions
```
"greet" { "Hello" . "World" . } define

"square" { dup * } define

"sum3" { + + } define
```

### Multi-step Example
```
\ Define a word that doubles a number
"double" { 2 * } define

\ Use it
5 double .          Prints: 10

\ Define a word using another word
"quad" { double double } define

5 quad .            Prints: 20
```

## Immediate Words (Advanced)

**Most users won't need to create immediate words!** They're for meta-programming.

### What Are Immediate Words?

Normal words execute **when you call them**.
Immediate words execute **when defining other words**.

### Example: The if Word

**Regular word:**
```
"greet" { "Hello" . } define
greet                      \ Executes when you call it
```

**Immediate word:**
```
"if" { <compile-branch-code> } define-immediate

"test" { 5 0 > if "yes" . }    \ if executes NOW during compilation!
        ↑
        While building "test", if runs immediately
        and inserts conditional branch bytecode
```

### Why Immediate Matters

Control flow **must** be compiled, not deferred:

**Without immediate (broken):**
```
"test" { 5 0 > if "yes" . } define
        When test runs: 5 0 > → true → if (tries to execute)
        But if can't modify test's code anymore - too late!
```

**With immediate (correct):**
```
"test" { 5 0 > if "yes" . } define
        While compiling: if executes NOW, emits ZBRANCH into test
        When test runs: 5 0 > → ZBRANCH → skips "yes" if false
```

### Built-in Immediate Words

These are already immediate (you don't redefine them):
- `if`, `then`, `else` - Conditionals
- `begin`, `until`, `while`, `repeat`, `again` - Loops

### When to Use define-immediate

**Never, unless you're:**
1. Implementing new control flow
2. Building compiler directives
3. Creating meta-programming tools

**99% of the time, use regular `define`!**

## Control Flow

### Conditionals
```
5 0 > if "positive" . then

5 0 < if "negative" . else "not negative" . then
```

### Loops
```
\ begin...until (loop until true)
0 [i] !
begin
  [i] @ .
  [i] @ 1 + [i] !
  [i] @ 5 =
until

\ begin...again (infinite loop)
begin
  "forever" .
again
```

## Complete Example Program

```
\ Variable to store count
0 [count] !

\ Define increment function
"inc" { [count] @ 1 + [count] ! } define

\ Define print-count function
"show" { "Count: " . [count] @ . cr } define

\ Use them
show        Prints: Count: 0
inc
show        Prints: Count: 1
inc inc inc
show        Prints: Count: 4
```

## Common Patterns

### Math calculation
```
\ Calculate (5 + 3) * 2
5 3 + 2 *           Result: 16
```

### Conditional logic
```
\ Absolute value
"abs" { dup 0 < if -1 * then } define

-5 abs .            Prints: 5
```

### Working with variables
```
\ Counter that doubles each time
"next" { [n] @ dup . 2 * [n] ! } define

1 [n] !
next                Prints: 1 (n becomes 2)
next                Prints: 2 (n becomes 4)
next                Prints: 4 (n becomes 8)
```

## Quick Reference

### Stack Operations
- Number → push number
- `dup` → duplicate top
- `drop` → remove top
- `swap` → exchange top two
- `.` → print and remove top
- `.s` → show entire stack

### Math
- `+` `-` `*` `/` → arithmetic
- `mod` → modulo (remainder)
- `=` `<` `>` → comparisons (push 1 or 0)

### Variables
- `[name] !` → store to variable
- `[name] @` → fetch from variable

### Strings
- `"text"` → create string
- `.` → print string

### Arrays
- `{ items }` → create array
- Words inside auto-tick

### Defining Words
- `"name" { body } define` → create word
- `"name" { body } define-immediate` → create immediate word
- `"name" info` → show definition

### Control Flow (already immediate)
- `if ... then`
- `if ... else ... then`
- `begin ... until`
- `begin ... again`

## Tips for Beginners

1. **Think backwards** - Write the data first, operation last
2. **Use .s often** - See what's on the stack
3. **One step at a time** - Build complex operations from simple ones
4. **Test in REPL** - Try operations interactively before defining words
5. **Keep words small** - Better to have many small words than one big one

## Common Mistakes

**Mistake:** Forgetting stack order
```
10 5 -              Result: 5 (not -5!)
                    Means: 10 - 5, not 5 - 10
```

**Mistake:** Not pushing enough arguments
```
+                   Error! Need two numbers on stack
```

**Mistake:** Using old Forth syntax
```
: hello ...;        DON'T USE - This is old Forth!
"hello" { ... } define     USE THIS - Pure RPN
```

## What's Next?

Once you're comfortable with basics:
1. Learn about references with `~word`
2. Explore array operations
3. Build more complex programs
4. Create your own control flow (advanced)

## Getting Help

- `words` - List all available words
- `"word-name" info` - Show word definition
- `.s` - Show current stack state
- In REPL, experiments are safe - just try things!
