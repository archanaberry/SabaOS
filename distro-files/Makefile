# =============================================================================
# SABAOS - Makefile
# =============================================================================
# Makefile untuk kemudahan build SabaOS
# =============================================================================

# Load configuration
include versions.conf

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
CYAN := \033[0;36m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# HELP
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo -e "$(CYAN)╔══════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(CYAN)║$(NC)           $(GREEN)SABAOS - Build System$(NC)                          $(CYAN)║$(NC)"
	@echo -e "$(CYAN)║$(NC)           $(YELLOW)Sameko Saba 🐟🐈$(NC)                               $(CYAN)║$(NC)"
	@echo -e "$(CYAN)╚══════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "MAIN TARGETS:"
	@echo "  make all              - Full build (all steps)"
	@echo "  make build            - Build all components"
	@echo "  make download         - Download all sources"
	@echo "  make toolchain        - Build cross-compilation toolchain"
	@echo "  make base             - Build base system"
	@echo "  make kernel           - Build Fishix kernel"
	@echo "  make bootloader       - Setup Limine bootloader"
	@echo ""
	@echo "IMAGE TARGETS:"
	@echo "  make iso              - Create bootable ISO"
	@echo "  make qcow2            - Create QCOW2 disk image"
	@echo "  make img              - Create raw disk image"
	@echo "  make vdi              - Create VDI disk image"
	@echo "  make vmdk             - Create VMDK disk image"
	@echo "  make all-images       - Create all image formats"
	@echo ""
	@echo "UTILITY TARGETS:"
	@echo "  make menu             - Interactive build menu"
	@echo "  make chroot           - Enter chroot environment"
	@echo "  make check-updates    - Check for package updates"
	@echo "  make clean            - Clean build artifacts"
	@echo "  make clean-all        - Clean everything"
	@echo "  make distclean        - Full cleanup including sources"
	@echo ""
	@echo "INFO TARGETS:"
	@echo "  make config           - Show build configuration"
	@echo "  make status           - Show build status"
	@echo "  make usage            - Show disk usage"
	@echo ""

# =============================================================================
# MAIN TARGETS
# =============================================================================

.PHONY: all
all: ## Full build (all steps)
	@echo -e "$(CYAN)Starting full SabaOS build...$(NC)"
	./00-master-build.sh compile

.PHONY: build
build: download toolchain base kernel bootloader ## Build all components
	@echo -e "$(GREEN)All components built successfully!$(NC)"

.PHONY: menu
menu: ## Interactive build menu
	@./00-master-build.sh

# =============================================================================
# COMPONENT TARGETS
# =============================================================================

.PHONY: download
download: ## Download all sources
	@echo -e "$(CYAN)Downloading sources...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@./scripts/01-download.sh

.PHONY: toolchain
toolchain: ## Build cross-compilation toolchain
	@echo -e "$(CYAN)Building toolchain...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@./scripts/02-toolchain.sh

.PHONY: base
base: ## Build base system
	@echo -e "$(CYAN)Building base system...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@./scripts/03-base-system.sh

.PHONY: kernel
kernel: ## Build Fishix kernel
	@echo -e "$(CYAN)Building Fishix kernel...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@./scripts/04-kernel.sh

.PHONY: bootloader
bootloader: ## Setup Limine bootloader
	@echo -e "$(CYAN)Setting up bootloader...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@./scripts/05-bootloader.sh

# =============================================================================
# IMAGE TARGETS
# =============================================================================

.PHONY: iso
iso: ## Create bootable ISO
	@echo -e "$(CYAN)Creating ISO image...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@./scripts/06-create-image.sh iso

.PHONY: qcow2
qcow2: ## Create QCOW2 disk image
	@echo -e "$(CYAN)Creating QCOW2 image...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@DISK_FORMAT=qcow2 ./scripts/06-create-image.sh qcow2

.PHONY: img
img: ## Create raw disk image
	@echo -e "$(CYAN)Creating raw disk image...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@DISK_FORMAT=img ./scripts/06-create-image.sh img

.PHONY: vdi
vdi: ## Create VDI disk image
	@echo -e "$(CYAN)Creating VDI image...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@DISK_FORMAT=vdi ./scripts/06-create-image.sh vdi

.PHONY: vmdk
vmdk: ## Create VMDK disk image
	@echo -e "$(CYAN)Creating VMDK image...$(NC)"
	@mkdir -p $(SABAOS_TEMP)/logs
	@DISK_FORMAT=vmdk ./scripts/06-create-image.sh vmdk

.PHONY: all-images
all-images: iso qcow2 img ## Create all image formats
	@echo -e "$(GREEN)All images created!$(NC)"

# =============================================================================
# UTILITY TARGETS
# =============================================================================

.PHONY: chroot
chroot: ## Enter chroot environment
	@echo -e "$(CYAN)Entering chroot environment...$(NC)"
	@./scripts/07-chroot-lfs.sh

.PHONY: chroot-shell
chroot-shell: ## Enter chroot shell directly
	@echo -e "$(CYAN)Entering chroot shell...$(NC)"
	@./scripts/07-chroot-lfs.sh shell

.PHONY: check-updates
check-updates: ## Check for package updates
	@echo -e "$(CYAN)Checking for updates...$(NC)"
	@./scripts/08-check-updates.sh

.PHONY: check-fishix
check-fishix: ## Check for Fishix kernel updates
	@echo -e "$(CYAN)Checking Fishix kernel updates...$(NC)"
	@./scripts/08-check-updates.sh fishix

# =============================================================================
# CLEAN TARGETS
# =============================================================================

.PHONY: clean
clean: ## Clean build artifacts
	@echo -e "$(CYAN)Cleaning build artifacts...$(NC)"
	@./scripts/09-clean.sh build

.PHONY: clean-temp
clean-temp: ## Clean temporary files
	@echo -e "$(CYAN)Cleaning temporary files...$(NC)"
	@./scripts/09-clean.sh temp

.PHONY: clean-sources
clean-sources: ## Clean sources
	@echo -e "$(CYAN)Cleaning sources...$(NC)"
	@./scripts/09-clean.sh sources

.PHONY: clean-rootfs
clean-rootfs: ## Clean rootfs
	@echo -e "$(CYAN)Cleaning rootfs...$(NC)"
	@./scripts/09-clean.sh rootfs

.PHONY: clean-kernel
clean-kernel: ## Clean kernel build
	@echo -e "$(CYAN)Cleaning kernel build...$(NC)"
	@./scripts/09-clean.sh kernel

.PHONY: clean-toolchain
clean-toolchain: ## Clean toolchain
	@echo -e "$(CYAN)Cleaning toolchain...$(NC)"
	@./scripts/09-clean.sh toolchain

.PHONY: clean-all
clean-all: ## Clean everything (except sources)
	@echo -e "$(CYAN)Cleaning all build artifacts...$(NC)"
	@./scripts/09-clean.sh all

.PHONY: distclean
distclean: ## Full cleanup including sources
	@echo -e "$(RED)WARNING: This will remove ALL files including sources!$(NC)"
	@read -p "Are you sure? [yes/no]: " confirm && [ "$$confirm" = "yes" ] && ./scripts/09-clean.sh all || echo "Cancelled"

# =============================================================================
# INFO TARGETS
# =============================================================================

.PHONY: config
config: ## Show build configuration
	@echo ""
	@echo -e "$(CYAN)========================================$(NC)"
	@echo -e "$(CYAN)  SABAOS Build Configuration$(NC)"
	@echo -e "$(CYAN)========================================$(NC)"
	@echo ""
	@echo "Build Mode: $(SABAOS_BUILD_MODE)"
	@echo "Target: $(TARGET)"
	@echo "Architecture: $(TARGET_ARCH)"
	@echo ""
	@echo "Directories:"
	@echo "  Root:      $(SABAOS_ROOT)"
	@echo "  Sources:   $(SABAOS_SOURCES)"
	@echo "  Build:     $(SABAOS_BUILD)"
	@echo "  Rootfs:    $(SABAOS_ROOTFS)"
	@echo "  ISO:       $(SABAOS_ISO)"
	@echo "  Disk:      $(SABAOS_DISK)"
	@echo ""
	@echo "Core Versions:"
	@echo "  GCC:       $(GCC_VER)"
	@echo "  musl:      $(MUSL_VER)"
	@echo "  Binutils:  $(BINUTILS_VER)"
	@echo "  Limine:    $(LIMINE_VER)"
	@echo "  Wayland:   $(WAYLAND_VER)"
	@echo "  Sway:      $(SWAY_VER)"
	@echo ""

.PHONY: status
status: ## Show build status
	@echo ""
	@echo -e "$(CYAN)========================================$(NC)"
	@echo -e "$(CYAN)  SABAOS Build Status$(NC)"
	@echo -e "$(CYAN)========================================$(NC)"
	@echo ""
	@echo -n "Sources:      "
	@if [ -d "$(SABAOS_SOURCES)" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo -n "Toolchain:    "
	@if [ -d "$(SABAOS_BUILD)/tools" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo -n "Rootfs:       "
	@if [ -d "$(SABAOS_ROOTFS)" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo -n "Kernel:       "
	@if [ -f "$(SABAOS_ROOTFS)/boot/fishix" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo -n "Initramfs:    "
	@if [ -f "$(SABAOS_ROOTFS)/boot/initramfs-sabaos.img" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo -n "ISO:          "
	@if [ -f "$(SABAOS_ISO)/$(ISO_NAME)" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo -n "QCOW2:        "
	@if [ -f "$(SABAOS_DISK)/$(DISK_NAME).qcow2" ]; then echo -e "$(GREEN)EXISTS$(NC)"; else echo -e "$(RED)MISSING$(NC)"; fi
	@echo ""

.PHONY: usage
usage: ## Show disk usage
	@./scripts/09-clean.sh usage

# =============================================================================
# QEMU TARGETS
# =============================================================================

.PHONY: run-iso
run-iso: ## Run ISO in QEMU
	@echo -e "$(CYAN)Running ISO in QEMU...$(NC)"
	qemu-system-x86_64 -cdrom $(SABAOS_ISO)/$(ISO_NAME) -m 2G -enable-kvm 2>/dev/null || \
	qemu-system-x86_64 -cdrom $(SABAOS_ISO)/$(ISO_NAME) -m 2G

.PHONY: run-qcow2
run-qcow2: ## Run QCOW2 in QEMU
	@echo -e "$(CYAN)Running QCOW2 in QEMU...$(NC)"
	qemu-system-x86_64 -hda $(SABAOS_DISK)/$(DISK_NAME).qcow2 -m 2G -enable-kvm 2>/dev/null || \
	qemu-system-x86_64 -hda $(SABAOS_DISK)/$(DISK_NAME).qcow2 -m 2G

.PHONY: run-img
run-img: ## Run raw image in QEMU
	@echo -e "$(CYAN)Running raw image in QEMU...$(NC)"
	qemu-system-x86_64 -hda $(SABAOS_DISK)/$(DISK_NAME).img -m 2G -enable-kvm 2>/dev/null || \
	qemu-system-x86_64 -hda $(SABAOS_DISK)/$(DISK_NAME).img -m 2G

# =============================================================================
# DEVELOPMENT TARGETS
# =============================================================================

.PHONY: dev-setup
dev-setup: ## Setup development environment
	@echo -e "$(CYAN)Setting up development environment...$(NC)"
	@sudo apt-get update && sudo apt-get install -y \
		build-essential \
		meson \
		ninja-build \
		git \
		wget \
		curl \
		xorriso \
		qemu-utils \
		parted \
		dosfstools \
		e2fsprogs \
		|| echo "Please install dependencies manually"

.PHONY: format
format: ## Format all shell scripts
	@echo -e "$(CYAN)Formatting shell scripts...$(NC)"
	@find . -name "*.sh" -exec shfmt -w {} \; 2>/dev/null || echo "shfmt not installed"

.PHONY: lint
lint: ## Lint all shell scripts
	@echo -e "$(CYAN)Linting shell scripts...$(NC)"
	@find . -name "*.sh" -exec shellcheck {} \; 2>/dev/null || echo "shellcheck not installed"
