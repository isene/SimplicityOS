# TODO: Fix define Word Execution

## Status

**Working:**
- ✓ Array literal creation `{ items }`
- ✓ Auto-tick inside arrays (words become references)
- ✓ Stack preservation (R14 pushed before marker)
- ✓ Name extraction from [r15-16]
- ✓ Empty arrays: `"nop" { } define` works
- ✓ Array element count correct: `[2]` for `{ ~dup ~+ }`
- ✓ Dictionary entry created
- ✓ Word can be looked up

**Not Working:**
- ✗ Non-empty arrays crash when executed
- ✗ `"double" { ~dup ~+ } define` then `double` → crash/reboot
- ✗ `"t1" { 1 } define` then `t1` → crash/reboot

## Investigation Findings

### Compilation Comparison

**Old syntax (WORKS):**
```
: double dup + ;
```
Compiles to: `[DOCOL][addr_dup][addr_+][EXIT]`

**New syntax (CRASHES):**
```
"double" { ~dup ~+ } define
```
Should compile to: `[DOCOL][addr_dup][addr_+][EXIT]`

Both should be identical!

### Debug Output Analysis

When calling `double` created by `define`:
1. Word is found by lookup_word ✓
2. DOCOL check happens ✓
3. Then instant crash (no exec_definition entry)

When calling `double` created by `:`:
1. Word is found ✓
2. DOCOL check ✓
3. exec_definition runs ✓
4. Outputs correct result (14) ✓

### Stack Layout (SOLVED)

After `"name" { words }`:
- [r15-16] = name STRING ✓
- [r15-8] = 0 (was collected by array)
- R14 = ARRAY
- Depth = 2 ✓

Fix applied: Push R14 before saving marker in `{`

### Remaining Mystery

Why does `define`-created word crash but `:`-created word works when they should produce identical bytecode?

## Next Steps

1. **Compare actual bytecode** - Add serial debug to dump:
   - compile_buffer contents after `define`
   - compile_buffer contents after `:`
   - See if they differ

2. **Check dict_here/dict_latest** - Verify pointers are correct

3. **Verify DOCOL marker** - Check if DOCOL is being written correctly

4. **Test with working word** - Try:
   ```
   : test dup + ;
   test           (works)
   "test" info    (would show definition if info implemented)
   ```

5. **Minimal test case** - Single word:
   ```
   "id" { dup drop } define
   5 id .s        (should show <1> 5)
   ```

## Hypotheses to Test

1. **compile_ptr not set** - Maybe final value wrong?
2. **DOCOL alignment** - Misaligned DOCOL marker?
3. **EXIT missing** - create_dict_entry not adding EXIT?
4. **Memory corruption** - compile_buffer getting overwritten?
5. **dict_here wrong** - Writing to wrong location?

## Code Locations

- `word_define`: kernel/simplicity.asm:4741
- `create_dict_entry`: kernel/simplicity.asm:972
- `exec_definition`: kernel/simplicity.asm:5347
- `.iline_handle_array_start`: kernel/simplicity.asm:5415 (FIXED)
- `.iline_handle_array_end`: kernel/simplicity.asm:5427

## Test Protocol

```bash
make run

# Test 1: Empty array (WORKS)
"nop" { } define
nop
# Result: ok ✓

# Test 2: Array with words (CRASHES)
"double" { ~dup ~+ } define
7 double .
# Result: crash/reboot ✗

# Test 3: Old syntax (WORKS)
: double dup + ;
7 double .
# Result: 14 ✓
```

## Session Stats

- Tokens used: ~378K / 1M
- Commits: 58
- Lines changed: ~1000+
- Major bugs fixed: 8
- Architecture preserved: ✓ (all apps on disk)

## For Next Session

Start fresh with clean mind. The bug is subtle - bytecode LOOKS identical but execution differs. Need systematic comparison of:
1. What `:` stores in compile_buffer
2. What `define` stores in compile_buffer
3. What create_dict_entry copies to dictionary
4. What lookup_word returns for each
5. What exec_definition receives

One of these steps has a difference we haven't spotted yet.
