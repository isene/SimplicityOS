# Simplicity OS - Makefile

# Tools
NASM = nasm
LD = ld
QEMU = qemu-system-x86_64

# Directories
BOOT_DIR = boot
KERNEL_DIR = kernel
DRIVERS_DIR = drivers
BUILD_DIR = build

# Output
IMAGE = $(BUILD_DIR)/simplicity.img
BOOT_BIN = $(BUILD_DIR)/boot.bin
STAGE2_BIN = $(BUILD_DIR)/stage2.bin
KERNEL_BIN = $(BUILD_DIR)/kernel.bin

# QEMU flags
QEMU_FLAGS = -drive file=$(IMAGE),format=raw,if=ide -display curses
QEMU_DEBUG_FLAGS = -s -S -d int,cpu_reset

# Image size (1.44MB floppy)
IMAGE_SIZE = 1474560

.PHONY: all clean run debug test dirs

all: dirs $(IMAGE)

dirs:
	@mkdir -p $(BUILD_DIR)

# Bootloader (512 bytes, must fit in boot sector)
$(BOOT_BIN): $(BOOT_DIR)/boot.asm
	@echo "→ Assembling boot sector..."
	$(NASM) -f bin -o $@ $<
	@if [ $$(stat -c%s $@) -ne 512 ]; then \
		echo "✗ Boot sector must be exactly 512 bytes!"; \
		exit 1; \
	fi
	@echo "✓ Boot sector assembled (512 bytes)"

# Stage 2 loader
$(STAGE2_BIN): $(BOOT_DIR)/stage2.asm
	@echo "→ Assembling stage2 loader..."
	$(NASM) -f bin -o $@ $<
	@echo "✓ Stage2 assembled ($$(stat -c%s $@) bytes)"

# Kernel
$(KERNEL_BIN): $(KERNEL_DIR)/forth.asm
	@echo "→ Assembling kernel..."
	$(NASM) -f bin -o $@ $<
	@echo "✓ Kernel assembled ($$(stat -c%s $@) bytes)"

# Create bootable disk image
$(IMAGE): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	@echo "→ Creating disk image..."
	@cat $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN) > $@
	@truncate -s $(IMAGE_SIZE) $@
	@echo "✓ Disk image created ($$(stat -c%s $@) bytes)"

# Run in QEMU
run: $(IMAGE)
	@echo "→ Starting QEMU..."
	$(QEMU) $(QEMU_FLAGS)

# Run in QEMU with GDB debugging
debug: $(IMAGE)
	@echo "→ Starting QEMU in debug mode..."
	@echo "→ Connect GDB with: gdb -ex 'target remote localhost:1234'"
	$(QEMU) $(QEMU_FLAGS) $(QEMU_DEBUG_FLAGS)

# Test boot (headless, 3 second timeout)
test: $(IMAGE)
	@echo "→ Testing boot..."
	@timeout 3 $(QEMU) -drive format=raw,file=$(IMAGE) -nographic || true
	@echo ""
	@echo "✓ Boot test complete"

# Clean build artifacts
clean:
	@echo "→ Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(IMAGE)
	@echo "✓ Clean complete"

# Install to USB drive (be very careful!)
install: $(IMAGE)
	@echo "⚠ This will overwrite the target device!"
	@echo "→ Available devices:"
	@lsblk -d -o NAME,SIZE,TYPE | grep disk
	@read -p "Enter device (e.g., sdb): " device; \
	read -p "Write to /dev/$$device? [yes/NO]: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		sudo dd if=$(IMAGE) of=/dev/$$device bs=512 status=progress; \
		echo "✓ Installed to /dev/$$device"; \
	else \
		echo "✗ Cancelled"; \
	fi
