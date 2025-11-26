#!/bin/bash
# Pre-commit hook for Simplicity OS

echo "→ Pre-commit checks for Simplicity OS..."

# Check if bootable image can be built
if [ -f Makefile ]; then
    echo "→ Testing build..."
    if ! make clean > /dev/null 2>&1; then
        echo "✗ Clean failed"
        exit 1
    fi

    if ! make > /dev/null 2>&1; then
        echo "✗ Build failed - fix compilation errors before committing"
        exit 1
    fi
    echo "✓ Build successful"
fi

# Verify assembly syntax if NASM files changed
NASM_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.asm$')
if [ -n "$NASM_FILES" ]; then
    echo "→ Checking NASM syntax..."
    for file in $NASM_FILES; do
        if ! nasm -f elf64 "$file" -o /tmp/test.o 2>/dev/null; then
            echo "✗ NASM syntax error in $file"
            exit 1
        fi
    done
    echo "✓ NASM syntax valid"
    rm -f /tmp/test.o
fi

echo "✓ All pre-commit checks passed"
exit 0
