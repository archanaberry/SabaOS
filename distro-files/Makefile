# ============================================================================
# SABA OS BUILD SYSTEM v2.0 - Fishix Kernel Edition
# Makefile untuk mengelola build Saba OS dengan Fishix kernel
# ============================================================================

# Konfigurasi
ROOT_DIR := $(shell pwd)
FISHIX_ROOT := $(shell cd $(ROOT_DIR)/.. && pwd)
FISHIX_KERNEL_DIR := $(FISHIX_ROOT)/kernel
BUILD_SCRIPT := $(ROOT_DIR)/build_sabaos.sh
SABA_VERSION := 2.0

# Phony targets
.PHONY: all help build-sabaos menu \
        phase0 phase1 phase2 phase3 phase4 phase5 phase6 \
        build-all clean verify download-sources \
        fishix-kernel fishix-clean

# Default target
all: help

# ============================================================================
# HELP / INFO
# ============================================================================

help:
	@echo "=============================================================="
	@echo "||        SABA OS BUILD SYSTEM v2.0 (Fishix Edition)        ||"
	@echo "=============================================================="
	@echo ""
	@echo "Fishix Paths:"
	@echo "  Fishix Root: $(FISHIX_ROOT)"
	@echo "  Fishix Kernel: $(FISHIX_KERNEL_DIR)"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  Fishix Kernel Setup:"
	@echo "    make kernel-selector   - Pilih & download Fishix kernel"
	@echo "      • Official (tunis4)"
	@echo "      • Community (archanaberry)"
	@echo "      • Custom URL"
	@echo ""
	@echo "  Fishix Kernel Build:"
	@echo "    make fishix-kernel     - Build Fishix kernel"
	@echo "    make fishix-clean      - Clean Fishix kernel build"
	@echo ""
	@echo "  Download & Preparation:"
	@echo "    make download-sources  - Download semua source code"
	@echo "    make verify            - Verifikasi build environment"
	@echo ""
	@echo "  Saba OS Build (Interactive):"
	@echo "    make menu              - Jalankan menu interaktif"
	@echo "    make build-sabaos      - Alias untuk make menu"
	@echo ""
	@echo "  Saba OS Build (Individual Phases):"
	@echo "    make phase0            - Fase 0: Persiapan Sistem"
	@echo "    make phase1            - Fase 1: Cross-Toolchain (musl)"
	@echo "    make phase2            - Fase 2: Chroot & Sistem Dasar"
	@echo "    make phase3            - Fase 3: Import Fishix Kernel"
	@echo "    make phase4            - Fase 4: Wayland & Sway"
	@echo "    make phase5            - Fase 5: Konfigurasi Sistem"
	@echo "    make phase6            - Fase 6: Bootloader"
	@echo ""
	@echo "  Full Build:"
	@echo "    make build-all         - Jalankan semua fase (0-6)"
	@echo ""
	@echo "  ISO Creation:"
	@echo "    make iso               - Buat ISO bootable"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make clean             - Bersihkan temporary files"
	@echo "    make help              - Tampilkan bantuan ini"
	@echo ""

# ============================================================================
# FISHIX KERNEL
# ============================================================================

fishix-kernel:
	@echo "Building Fishix kernel..."
	@if [ ! -d "$(FISHIX_KERNEL_DIR)" ]; then \
		echo "Error: Fishix kernel directory not found at $(FISHIX_KERNEL_DIR)"; \
		echo "Please clone Fishix kernel first:"; \
		echo "  git clone https://github.com/archanaberry/Fishix $(FISHIX_ROOT)/kernel"; \
		exit 1; \
	fi
	@cd $(FISHIX_KERNEL_DIR) && make clean && make

fishix-clean:
	@echo "Cleaning Fishix kernel build..."
	@if [ -d "$(FISHIX_KERNEL_DIR)" ]; then \
		cd $(FISHIX_KERNEL_DIR) && make clean; \
	fi

# ============================================================================
# DOWNLOAD SOURCES
# ============================================================================

download-sources:
	@echo "Downloading Saba OS sources..."
	@mkdir -p $(HOME)/saba_os_sources
	@cd $(HOME)/saba_os_sources && \
		curl -fLO --progress-bar https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.25.tar.xz || echo "Kernel download skipped/failed" && \
		curl -fLO --progress-bar https://musl.libc.org/releases/musl-1.2.5.tar.gz || echo "musl download skipped/failed" && \
		curl -fLO --progress-bar https://ftp.gnu.org/gnu/binutils/binutils-2.44.tar.xz || echo "binutils download skipped/failed" && \
		curl -fLO --progress-bar https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz || echo "gcc download skipped/failed" && \
		curl -fLO --progress-bar https://busybox.net/downloads/busybox-1.37.0.tar.bz2 || echo "busybox download skipped/failed" && \
		curl -fLO --progress-bar https://ftp.gnu.org/gnu/coreutils/coreutils-9.6.tar.xz || echo "coreutils download skipped/failed" && \
		curl -fLO --progress-bar http://smarden.org/runit/runit-2.1.2.tar.gz || echo "runit download skipped/failed"
	@echo "Download complete!"

# ============================================================================
# FISHIX KERNEL SELECTOR
# ============================================================================

KERNEL_SELECTOR := $(ROOT_DIR)/fishix_kernel_selector.sh

kernel-selector:
	@echo "Running Fishix Kernel Selector..."
	@chmod +x $(KERNEL_SELECTOR)
	@bash $(KERNEL_SELECTOR)

# ============================================================================
# SABA OS BUILD - INTERACTIVE
# ============================================================================

check-script:
	@if [ ! -f "$(BUILD_SCRIPT)" ]; then \
		echo "Error: build_sabaos.sh not found at $(BUILD_SCRIPT)"; \
		exit 1; \
	fi
	@chmod +x $(BUILD_SCRIPT)

menu: kernel-selector check-script
	@echo "Starting Saba OS Builder (Interactive Mode)..."
	@sudo bash $(BUILD_SCRIPT)

build-sabaos: menu

# ============================================================================
# SABA OS BUILD - INDIVIDUAL PHASES
# ============================================================================

phase0: check-script
	@echo "Running Phase 0: System Preparation..."
	@echo "0" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase0.log

phase1: check-script
	@echo "Running Phase 1: Cross-Toolchain..."
	@echo "1" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase1.log

phase2: check-script
	@echo "Running Phase 2: Chroot & Base System..."
	@echo "2" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase2.log

phase3: check-script
	@echo "Running Phase 3: Import Fishix Kernel..."
	@echo "3" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase3.log

phase4: check-script
	@echo "Running Phase 4: Wayland & Sway..."
	@echo "4" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase4.log

phase5: check-script
	@echo "Running Phase 5: System Configuration..."
	@echo "5" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase5.log

phase6: check-script
	@echo "Running Phase 6: Bootloader..."
	@echo "6" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee phase6.log

# ============================================================================
# FULL BUILD
# ============================================================================

build-all: kernel-selector check-script
	@echo "=============================================================="
	@echo "STARTING FULL SABA OS BUILD (Fishix Edition)..."
	@echo "This will run all phases automatically..."
	@echo "=============================================================="
	@echo ""
	@echo "a" | sudo bash $(BUILD_SCRIPT) 2>&1 | tee build-all.log

# ============================================================================
# ISO CREATION
# ============================================================================

iso:
	@echo "Creating Saba OS ISO..."
	@chmod +x makeiso.sh
	@./makeiso.sh

# ============================================================================
# CLEANUP
# ============================================================================

clean:
	@echo "Cleaning up..."
	@rm -f *.log
	@echo "Removed: log files"
	@echo "Cleanup complete!"

clean-all: clean
	@echo "Removing build directory..."
	@sudo rm -rf /mnt/saba_os
	@echo "Removed: /mnt/saba_os"
	@echo "Full cleanup complete!"

# ============================================================================
# VERIFICATION
# ============================================================================

verify:
	@echo "Verifying Saba OS build environment..."
	@echo ""
	@echo "Fishix Paths:"
	@test -d "$(FISHIX_ROOT)" && echo "  [OK] Fishix Root: $(FISHIX_ROOT)" || echo "  [FAIL] Fishix Root: NOT FOUND"
	@test -d "$(FISHIX_KERNEL_DIR)" && echo "  [OK] Fishix Kernel: $(FISHIX_KERNEL_DIR)" || echo "  [WARN] Fishix Kernel: NOT FOUND (run 'make fishix-kernel')"
	@test -f "$(BUILD_SCRIPT)" && echo "  [OK] Build script: $(BUILD_SCRIPT)" || echo "  [FAIL] Build script: NOT FOUND"
	@echo ""
	@echo "Tools:"
	@which git >/dev/null && echo "  [OK] git" || echo "  [MISSING] git"
	@which bash >/dev/null && echo "  [OK] bash" || echo "  [MISSING] bash"
	@which make >/dev/null && echo "  [OK] make" || echo "  [MISSING] make"
	@which gcc >/dev/null && echo "  [OK] gcc" || echo "  [MISSING] gcc"
	@which g++ >/dev/null && echo "  [OK] g++" || echo "  [MISSING] g++"
	@which curl >/dev/null && echo "  [OK] curl" || echo "  [MISSING] curl"
	@which wget >/dev/null && echo "  [OK] wget" || echo "  [MISSING] wget"
	@which python3 >/dev/null && echo "  [OK] python3" || echo "  [MISSING] python3"
	@echo ""
	@echo "Verification complete!"

# ============================================================================
# INSTALL DEPENDENCIES (Ubuntu/Debian)
# ============================================================================

install-deps-debian:
	@echo "Installing dependencies for Debian/Ubuntu..."
	sudo apt-get update
	sudo apt-get install -y \
		build-essential \
		bison \
		flex \
		libgmp3-dev \
		libmpc-dev \
		libmpfr-dev \
		texinfo \
		libssl-dev \
		libelf-dev \
		bc \
		xz-utils \
		bzip2 \
		gzip \
		curl \
		wget \
		git \
		python3 \
		python3-tk \
		ninja-build \
		meson \
		pkg-config \
		libwayland-dev \
		wayland-protocols \
		libxkbcommon-dev \
		libpixman-1-dev \
		libcairo2-dev \
		libpango1.0-dev \
		libinput-dev \
		libseat-dev \
		libxcb-composite0-dev \
		libxcb-xfixes0-dev \
		libxcb-render0-dev \
		libxcb-res0-dev \
		libxcb-icccm4-dev \
		libxcb-image0-dev \
		libxcb-keysyms1-dev \
		libxcb-randr0-dev \
		libxcb-shape0-dev \
		libxcb-sync-dev \
		libxcb-xinerama0-dev \
		libxcb-util-dev \
		libxcb-cursor-dev \
		xorriso
	@echo "Dependencies installed!"

# ============================================================================
# INSTALL DEPENDENCIES (Arch Linux)
# ============================================================================

install-deps-arch:
	@echo "Installing dependencies for Arch Linux..."
	sudo pacman -S --needed \
		base-devel \
		bison \
		flex \
		gmp \
		libmpc \
		mpfr \
		texinfo \
		openssl \
		bc \
		xz \
		bzip2 \
		gzip \
		curl \
		wget \
		git \
		python \
		tk \
		ninja \
		meson \
		pkgconf \
		wayland \
		wayland-protocols \
		xkbcommon \
		pixman \
		cairo \
		pango \
		libinput \
		seatd \
		xcb-util \
		xcb-util-wm \
		xcb-util-image \
		xcb-util-keysyms \
		xcb-util-renderutil \
		xcb-util-cursor \
		libisoburn
	@echo "Dependencies installed!"
