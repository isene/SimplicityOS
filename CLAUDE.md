# Simplicity OS - Project Directives

## Vision
Bare-metal x86_64 operating system built on Forth principles.
Everything is a WORD. Hardware is directly composable.

## Core Philosophy
1. **Everything is a WORD** - No APIs, no system calls, just Forth
2. **Stack-based interface** - Query returns values, -SET consumes values
3. **Direct hardware access** - No abstraction layers
4. **Lego composability** - Complex from simple, always
5. **Introspectable** - See and modify everything at runtime

## CRITICAL ARCHITECTURAL GUARDRAILS

### Pure Data Model (NEVER VIOLATE)
1. **ONLY `.` prints** - No other operation produces output
2. **Everything pushes to stack** - All operations return data
3. **No side-effect output** - Operations manipulate, don't display

### Object Model (MANDATORY)
1. **No fixed-size allocations** - Everything grows dynamically
2. **All data is objects** - With type headers
3. **Scalable to petabytes** - 1TB apps, 2PB data supported
4. **Type-tagged** - Every object knows its type

### Consistency Rules (STRICT)
1. **Pure RPN** - All operations including meta (tick + operator)
2. **No prefix operations** - Always: data then operation
3. **Tick for references** - ~word gets reference, word executes
4. **Objects, not primitives** - Strings are objects, not char arrays

### Error Handling (MANDATORY)
1. **No crashes** - All operations must validate input
2. **Return error objects** - Push STRING error descriptions
3. **Graceful degradation** - Invalid refs → "(invalid reference)"
4. **Stack safety** - Check bounds before pop/push

### Stack Discipline (STRICT)
1. **Document stack effects** - Every word shows ( in -- out )
2. **Validate critical operations** - @ and ! check address validity
3. **Correct order** - `!` is ( value addr -- ) so use: `100 [x] !` not `[x] 100 !`
4. **Type awareness** - Operations should check when possible

### Register Conventions (DOCUMENTED)
```
R14 = Top of stack (TOS) - Cached for performance
R15 = Data stack pointer (second-on-stack and below)
RBP = Return stack pointer (grows down: push = [RBP], RBP-=8)
RSI = Instruction pointer during definition execution
RSP = Machine stack (for function calls, preserved)

Why TOS register: Reduces memory accesses, improves performance
Stack layout: R14 = TOS, [R15-8] = second, [R15-16] = third, ...

Scratch registers (caller-saved):
RAX, RBX, RCX, RDX = Temporary, not preserved across operations
R8, R9, R10, R11, R12, R13 = Available for complex operations

Preserved across word calls:
R14, R15, RBP = Stack pointers (never corrupted)
RSI = Only modified during definition execution
```

### Memory Model (ENFORCED)
1. **Heap starts at 2MB** - Grows upward, unbounded
2. **No hardcoded addresses** - All pointers allocated
3. **Object headers** - [type:8][size:8][data:N]
4. **Page tables map as needed** - Currently 0-4MB, expand on demand

### Type System (REQUIRED)
```
TYPE_INT = 0        (immediate, no header, value < 0x100000)
TYPE_STRING = 1     (null-terminated text)
TYPE_REF = 2        (execution token)
TYPE_ARRAY = 3      (future)
TYPE_IMAGE = 4      (future)
TYPE_APP = 5        (future)
```

## Design Constraints
- BIOS boot (simpler than UEFI)
- x86_64 protected mode → long mode
- JonesForth-based kernel (minimal, portable)
- QEMU primary test platform
- Real hardware secondary target

## Naming Conventions
- `DEVICE` - Query device state, returns stack values
- `DEVICE-SET` - Configure device, consumes stack values
- `DEVICE-READ` - Read from device
- `DEVICE-WRITE` - Write to device

**Examples:**
```
SCREEN          ( -- x y brightness type manufacturer )
SCREEN-SET      ( x y brightness -- )
DISK-READ       ( sector -- addr len )
DISK-WRITE      ( addr len sector -- )
KEYBOARD-READ   ( -- scancode )
```

## Development Workflow
1. Write assembly/Forth in `src/`
2. Build with `make`
3. Test in QEMU: `make run`
4. Verify functionality works
5. Commit with clear message
6. Push to GitHub

## Testing Protocol
- Every feature tested in QEMU before commit
- Boot test: Does it boot and show prompt?
- Functionality test: Does new WORD work as specified?
- Integration test: Do existing WORDs still work?
- Manual verification required before marking complete

## Code Standards
- Assembly: NASM syntax, well-commented
- Forth: Lowercase words, stack effects in comments
- Comments: Explain WHY, not WHAT
- Keep WORDs small (< 20 lines typically)
- One feature per commit

## Directory Structure
```
/boot      - Bootloader and early initialization
/kernel    - Forth kernel core
/drivers   - Hardware drivers as Forth WORDs
/stdlib    - Standard Forth word library
/tools     - Build and development utilities
/docs      - Technical documentation
```

## Hardware Support Priority
1. **Stage 1**: VGA text mode, keyboard input
2. **Stage 2**: Disk I/O (IDE/AHCI)
3. **Stage 3**: Framebuffer graphics
4. **Stage 4**: Network, USB, etc.

## Debugging
- QEMU with `-d int,cpu_reset` for debugging
- Use INT3 breakpoints in assembly
- Print stack state frequently during development
- Keep GDB ready for low-level debugging

## Security Model
- No privilege separation initially
- All code runs in ring 0
- Trust through simplicity and transparency
- Evolve security model as system matures

## Remember
- Simplest solution always wins
- Working code beats perfect design
- Test before commit, always
- Document as you build, not after
