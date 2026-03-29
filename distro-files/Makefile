# ============================================================================
# SABA OS BUILD SYSTEM
# Makefile untuk mengelola build Saba OS dan import kernel Fishix
# ============================================================================

# Konfigurasi
KERNEL_REPO ?= https://github.com/archanaberry/Fishix
ROOT_DIR := $(abspath ..)
TEMP_DIR := $(ROOT_DIR)/.fishix_temp
BUILD_SCRIPT := build_sabaos.sh

# Phony targets
.PHONY: all help import-kernel build-sabaos build-all menu \
        phase0 phase1 phase2 phase3 phase4 phase5 phase6 clean

# Default target
all: help

# ============================================================================
# HELP / INFO
# ============================================================================

help:
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║              🐟 SABA OS BUILD SYSTEM 🐟                       ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  Kernel Management:"
	@echo "    make import-kernel  - Clone dan import kernel Fishix ke ../"
	@echo ""
	@echo "  Saba OS Build (Interactive):"
	@echo "    make menu           - Jalankan menu interaktif build_sabaos.sh"
	@echo "    make build-sabaos   - Alias untuk make menu"
	@echo ""
	@echo "  Saba OS Build (Individual Phases):"
	@echo "    make phase0         - Fase 0: Persiapan Sistem"
	@echo "    make phase1         - Fase 1: Cross-Toolchain (musl)"
	@echo "    make phase2         - Fase 2: Chroot & Sistem Dasar"
	@echo "    make phase3         - Fase 3: Import Kernel Fishix"
	@echo "    make phase4         - Fase 4: Wayland & Sway"
	@echo "    make phase5         - Fase 5: Konfigurasi Sistem"
	@echo "    make phase6         - Fase 6: Bootloader"
	@echo ""
	@echo "  Full Build:"
	@echo "    make build-all      - Jalankan semua fase (0-6) otomatis"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make clean          - Bersihkan temporary files"
	@echo "    make help           - Tampilkan bantuan ini"
	@echo ""

# ============================================================================
# KERNEL IMPORT (FISHIX)
# ============================================================================

import-kernel:
	@echo "🐟 Importing kernel from $(KERNEL_REPO)..."
	@echo "   Target: $(ROOT_DIR)"
	@if [ -d "$(TEMP_DIR)" ]; then \
		echo "   Cleaning old temp directory..."; \
		rm -rf "$(TEMP_DIR)"; \
	fi
	@echo "   Cloning repository..."
	@git clone --depth 1 "$(KERNEL_REPO)" "$(TEMP_DIR)"
	@echo "   Moving contents to $(ROOT_DIR)..."
	@bash -c 'shopt -s dotglob; \
		mv "$(TEMP_DIR)"/* "$(ROOT_DIR)"/ 2>/dev/null || true; \
		mv "$(TEMP_DIR)"/.[!.]* "$(ROOT_DIR)"/ 2>/dev/null || true; \
		mv "$(TEMP_DIR)"/..?* "$(ROOT_DIR)"/ 2>/dev/null || true'
	@rm -rf "$(TEMP_DIR)"
	@echo "✅ Kernel Fishix imported successfully!"
	@echo "   Location: $(ROOT_DIR)"

# ============================================================================
# SABA OS BUILD - INTERACTIVE
# ============================================================================

menu: check-script
	@echo "🐟 Starting Saba OS Builder (Interactive Mode)..."
	@bash $(BUILD_SCRIPT)

build-sabaos: menu

# ============================================================================
# SABA OS BUILD - INDIVIDUAL PHASES
# ============================================================================

check-script:
	@if [ ! -f "$(BUILD_SCRIPT)" ]; then \
		echo "❌ Error: build_sabaos.sh not found at $(BUILD_SCRIPT)"; \
		exit 1; \
	fi

phase0: check-script
	@echo "🚀 Running Phase 0: System Preparation..."
	@bash -c 'echo "0" | bash $(BUILD_SCRIPT) 2>&1 | head -100'

phase1: check-script
	@echo "🚀 Running Phase 1: Cross-Toolchain..."
	@bash -c 'echo "1" | bash $(BUILD_SCRIPT) 2>&1 | head -200'

phase2: check-script
	@echo "🚀 Running Phase 2: Chroot & Base System..."
	@bash -c 'echo "2" | bash $(BUILD_SCRIPT) 2>&1 | head -300'

phase3: check-script
	@echo "🚀 Running Phase 3: Kernel Fishix..."
	@bash -c 'echo "3" | bash $(BUILD_SCRIPT) 2>&1 | head -100'

phase4: check-script
	@echo "🚀 Running Phase 4: Wayland & Sway..."
	@bash -c 'echo "4" | bash $(BUILD_SCRIPT) 2>&1 | head -500'

phase5: check-script
	@echo "🚀 Running Phase 5: System Configuration..."
	@bash -c 'echo "5" | bash $(BUILD_SCRIPT) 2>&1 | head -100'

phase6: check-script
	@echo "🚀 Running Phase 6: Bootloader..."
	@bash -c 'echo "6" | bash $(BUILD_SCRIPT) 2>&1 | head -100'

# ============================================================================
# FULL BUILD
# ============================================================================

build-all: check-script
	@echo "🐟🚀 STARTING FULL SABA OS BUILD..."
	@echo "    This will run all phases automatically..."
	@echo ""
	@bash -c 'echo "a" | bash $(BUILD_SCRIPT)'

# ============================================================================
# CLEANUP
# ============================================================================

clean:
	@echo "🧹 Cleaning up..."
	@rm -rf $(TEMP_DIR)
	@echo "   Removed: $(TEMP_DIR)"
	@echo "✅ Cleanup complete!"

# ============================================================================
# VERIFICATION
# ============================================================================

verify:
	@echo "🔍 Verifying Saba OS build environment..."
	@echo ""
	@echo "Directories:"
	@test -d "$(ROOT_DIR)" && echo "  ✅ ROOT_DIR: $(ROOT_DIR)" || echo "  ❌ ROOT_DIR: NOT FOUND"
	@test -f "$(BUILD_SCRIPT)" && echo "  ✅ Build script: $(BUILD_SCRIPT)" || echo "  ❌ Build script: NOT FOUND"
	@test -d "$(ROOT_DIR)/kernel" && echo "  ✅ Kernel dir: $(ROOT_DIR)/kernel" || echo "  ⚠️  Kernel dir: NOT FOUND (run make import-kernel)"
	@echo ""
	@echo "Tools:"
	@which git >/dev/null && echo "  ✅ git" || echo "  ❌ git"
	@which bash >/dev/null && echo "  ✅ bash" || echo "  ❌ bash"
	@which make >/dev/null && echo "  ✅ make" || echo "  ❌ make"
	@echo ""
	@echo "Verification complete!"