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
APPS_DIR = apps
TOOLS_DIR = tools

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

# Kernel load address (must match stage2 jump target)
KERNEL_ADDR = 0x10000

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

# Stage 2 loader (minimal - mode transitions only)
$(STAGE2_BIN): $(BOOT_DIR)/stage2.asm
	@echo "→ Assembling stage2 loader..."
	$(NASM) -f bin -o $@ $<
	@echo "✓ Stage2 assembled ($$(stat -c%s $@) bytes)"

# Kernel (64-bit RPN system)
$(KERNEL_BIN): $(KERNEL_DIR)/simplicity.asm
	@echo "→ Assembling kernel..."
	$(NASM) -f bin -o $@ $<
	@echo "✓ Kernel assembled ($$(stat -c%s $@) bytes)"

# Create bootable disk image
# Layout: [boot.bin (512B)] [padding to sector 1] [stage2.bin] [padding to 0x10000] [kernel.bin]
$(IMAGE): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	@echo "→ Creating disk image..."
	@# Start with boot sector
	@cp $(BOOT_BIN) $@
	@# Calculate padding: stage2 starts at sector 1 (offset 512)
	@# Kernel should be at 0x10000 (65536), which is offset 0x10000 - 0x7E00 = 0x8200 from stage2 start
	@# But we need to figure out total layout
	@# Boot sector: 0x7C00 (512 bytes) - sectors 0
	@# Stage2 loads to: 0x7E00 - starts at sector 1
	@# Kernel loads to: 0x10000
	@# In file: boot (512) + stage2 (pad to fit) + kernel
	@# stage2 offset in file: 512
	@# kernel offset in file: we want it at 0x10000 physical address
	@# Boot loads from sector 1 to 0x7E00, so sector 1 = file offset 512 = address 0x7E00
	@# To get kernel at 0x10000, we need: 0x10000 - 0x7E00 = 0x8200 bytes from sector 1
	@# So kernel starts at file offset 512 + 0x8200 = 512 + 33280 = 33792 bytes (sector 66)
	@# Append stage2, padded to 33280 bytes (0x8200)
	@truncate -s 512 $@
	@cat $(STAGE2_BIN) >> $@
	@# Pad to put kernel at correct offset (33792 from file start = sector 66)
	@truncate -s 33792 $@
	@cat $(KERNEL_BIN) >> $@
	@# Pad to floppy size
	@truncate -s $(IMAGE_SIZE) $@
	@# Pack apps into disk image (directory at sector 200)
	@if [ -d "$(APPS_DIR)" ] && [ -n "$$(ls -A $(APPS_DIR)/*.forth 2>/dev/null)" ]; then \
		echo "→ Packing apps..."; \
		$(TOOLS_DIR)/pack-apps.sh $@ $(APPS_DIR); \
	fi
	@echo "✓ Disk image created ($$(stat -c%s $@) bytes)"
	@echo "  Boot: sector 0, Stage2: sector 1, Kernel: sector 66 (0x10000)"

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
