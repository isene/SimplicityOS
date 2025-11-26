#!/bin/bash
# Post-commit hook for Simplicity OS

echo "→ Post-commit actions..."

# Get the commit message
COMMIT_MSG=$(git log -1 --pretty=%B)

echo "✓ Committed: $COMMIT_MSG"

# Suggest testing in QEMU
if [ -f Makefile ] && grep -q "run:" Makefile; then
    echo "→ Reminder: Test with 'make run' in QEMU"
fi

exit 0
