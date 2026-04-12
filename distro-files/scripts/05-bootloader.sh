#!/bin/bash
# =============================================================================
# SABAOS - Bootloader Setup Script
# =============================================================================
# Setup Limine bootloader untuk SabaOS
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../versions.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
export SYSROOT="${SABAOS_ROOTFS}"
export LIMINE_DIR="${SABAOS_BUILD}/limine-${LIMINE_VER}"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

extract_archive() {
    local archive="$1"
    local dest="$2"
    
    log_info "Extracting: $(basename $archive)"
    
    case "$archive" in
        *.tar.xz)
            tar -xf "$archive" -C "$dest"
            ;;
        *.tar.gz)
            tar -xzf "$archive" -C "$dest"
            ;;
        *.tar.bz2)
            tar -xjf "$archive" -C "$dest"
            ;;
        *)
            log_error "Unknown archive format: $archive"
            return 1
            ;;
    esac
}

# =============================================================================
# BUILD LIMINE
# =============================================================================

build_limine() {
    log_step "BUILDING LIMINE ${LIMINE_VER}"
    
    if [ ! -d "$LIMINE_DIR" ]; then
        if [ -f "${SABAOS_SOURCES}/limine-${LIMINE_VER}.tar.xz" ]; then
            extract_archive "${SABAOS_SOURCES}/limine-${LIMINE_VER}.tar.xz" "${SABAOS_BUILD}"
        else
            log_info "Downloading Limine..."
            mkdir -p "${SABAOS_BUILD}"
            cd "${SABAOS_BUILD}"
            git clone --depth 1 --branch "v${LIMINE_VER}" https://github.com/limine-bootloader/limine.git "limine-${LIMINE_VER}"
        fi
    fi
    
    cd "$LIMINE_DIR"
    
    # Check if already built
    if [ -f "${LIMINE_DIR}/limine" ]; then
        log_success "Limine already built"
        return 0
    fi
    
    log_info "Configuring Limine..."
    ./configure \
        --prefix=/usr \
        --enable-bios \
        --enable-uefi-x86-64 \
        --enable-uefi-ia32 \
        2>&1 | tee "${SABAOS_TEMP}/logs/limine-configure.log"
    
    log_info "Building Limine..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/limine-build.log"
    
    log_success "Limine built successfully"
}

# =============================================================================
# SETUP BOOTLOADER IN ROOTFS
# =============================================================================

setup_bootloader() {
    log_step "SETTING UP BOOTLOADER IN ROOTFS"
    
    # Create boot directories
    mkdir -p "${SYSROOT}/boot/limine"
    mkdir -p "${SYSROOT}/EFI/BOOT"
    
    # Copy Limine binaries
    log_info "Copying Limine binaries..."
    
    # BIOS files
    if [ -f "${LIMINE_DIR}/limine-bios.sys" ]; then
        cp "${LIMINE_DIR}/limine-bios.sys" "${SYSROOT}/boot/limine/"
        log_success "Copied limine-bios.sys"
    fi
    
    if [ -f "${LIMINE_DIR}/limine-bios-cd.bin" ]; then
        cp "${LIMINE_DIR}/limine-bios-cd.bin" "${SYSROOT}/boot/limine/"
        log_success "Copied limine-bios-cd.bin"
    fi
    
    if [ -f "${LIMINE_DIR}/limine-bios-pxe.bin" ]; then
        cp "${LIMINE_DIR}/limine-bios-pxe.bin" "${SYSROOT}/boot/limine/"
        log_success "Copied limine-bios-pxe.bin"
    fi
    
    # UEFI files
    if [ -f "${LIMINE_DIR}/limine-uefi-cd.bin" ]; then
        cp "${LIMINE_DIR}/limine-uefi-cd.bin" "${SYSROOT}/boot/limine/"
        log_success "Copied limine-uefi-cd.bin"
    fi
    
    # EFI executables
    for efi_file in "${LIMINE_DIR}"/BOOT*.EFI; do
        if [ -f "$efi_file" ]; then
            cp "$efi_file" "${SYSROOT}/EFI/BOOT/"
            log_success "Copied $(basename $efi_file)"
        fi
    done
    
    # Copy limine utility
    if [ -f "${LIMINE_DIR}/limine" ]; then
        cp "${LIMINE_DIR}/limine" "${SYSROOT}/boot/limine/"
        log_success "Copied limine utility"
    fi
}

# =============================================================================
# CREATE LIMINE CONFIG
# =============================================================================

create_limine_config() {
    log_step "CREATING LIMINE CONFIGURATION"
    
    cat > "${SYSROOT}/boot/limine/limine.conf" << 'EOF'
# SabaOS Limine Configuration

TIMEOUT=5
DEFAULT_ENTRY=1

# Graphical boot
:SabaOS (Fishix - Graphical)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw quiet startwm

# Standard boot
:SabaOS (Fishix)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw

# Recovery mode
:SabaOS (Recovery Mode)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw single

# Debug mode
:SabaOS (Debug Mode)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw debug initcall_debug
EOF
    
    log_success "Limine configuration created"
}

# =============================================================================
# CREATE SYSLINUX CONFIG (FALLBACK)
# =============================================================================

create_syslinux_config() {
    log_step "CREATING SYSLINUX CONFIGURATION (FALLBACK)"
    
    mkdir -p "${SYSROOT}/boot/syslinux"
    
    cat > "${SYSROOT}/boot/syslinux/syslinux.cfg" << 'EOF'
# SabaOS Syslinux Configuration

DEFAULT sabaos
TIMEOUT 50
UI menu.c32

MENU TITLE SabaOS Boot Menu
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL sabaos
    MENU LABEL SabaOS (Fishix)
    LINUX /boot/fishix
    INITRD /boot/initramfs-sabaos.img
    APPEND root=/dev/sda2 rw

LABEL sabaos-graphical
    MENU LABEL SabaOS (Graphical)
    LINUX /boot/fishix
    INITRD /boot/initramfs-sabaos.img
    APPEND root=/dev/sda2 rw quiet startwm

LABEL sabaos-recovery
    MENU LABEL SabaOS (Recovery)
    LINUX /boot/fishix
    INITRD /boot/initramfs-sabaos.img
    APPEND root=/dev/sda2 rw single
EOF
    
    log_success "Syslinux configuration created"
}

# =============================================================================
# CREATE GRUB CONFIG (FALLBACK)
# =============================================================================

create_grub_config() {
    log_step "CREATING GRUB CONFIGURATION (FALLBACK)"
    
    mkdir -p "${SYSROOT}/boot/grub"
    
    cat > "${SYSROOT}/boot/grub/grub.cfg" << 'EOF'
# SabaOS GRUB Configuration

set timeout=5
set default=0

menuentry "SabaOS (Fishix)" {
    multiboot2 /boot/fishix
    module2 /boot/initramfs-sabaos.img
    set root=(hd0,2)
    linux /boot/fishix root=/dev/sda2 rw
    initrd /boot/initramfs-sabaos.img
}

menuentry "SabaOS (Recovery)" {
    set root=(hd0,2)
    linux /boot/fishix root=/dev/sda2 rw single
    initrd /boot/initramfs-sabaos.img
}

menuentry "SabaOS (Debug)" {
    set root=(hd0,2)
    linux /boot/fishix root=/dev/sda2 rw debug
    initrd /boot/initramfs-sabaos.img
}
EOF
    
    log_success "GRUB configuration created"
}

# =============================================================================
# VERIFY BOOTLOADER SETUP
# =============================================================================

verify_bootloader() {
    log_step "VERIFYING BOOTLOADER SETUP"
    
    local errors=0
    
    # Check kernel
    if [ ! -f "${SYSROOT}/boot/fishix" ]; then
        log_error "Kernel not found: ${SYSROOT}/boot/fishix"
        errors=$((errors + 1))
    else
        log_success "Kernel found"
    fi
    
    # Check initramfs
    if [ ! -f "${SYSROOT}/boot/initramfs-sabaos.img" ]; then
        log_error "Initramfs not found: ${SYSROOT}/boot/initramfs-sabaos.img"
        errors=$((errors + 1))
    else
        log_success "Initramfs found"
    fi
    
    # Check Limine config
    if [ ! -f "${SYSROOT}/boot/limine/limine.conf" ]; then
        log_error "Limine config not found"
        errors=$((errors + 1))
    else
        log_success "Limine config found"
    fi
    
    # Check Limine binaries
    if [ ! -f "${SYSROOT}/boot/limine/limine-bios.sys" ]; then
        log_warn "limine-bios.sys not found"
    else
        log_success "limine-bios.sys found"
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Bootloader setup verified"
    else
        log_error "Bootloader setup has ${errors} error(s)"
        return 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_step "SABAOS - Bootloader Setup"
    
    # Create logs directory
    mkdir -p "${SABAOS_TEMP}/logs"
    
    # Build Limine
    build_limine
    
    # Setup bootloader in rootfs
    setup_bootloader
    
    # Create configurations
    create_limine_config
    create_syslinux_config
    create_grub_config
    
    # Verify setup
    verify_bootloader
    
    log_step "BOOTLOADER SETUP COMPLETE"
    log_info "Bootloader: Limine ${LIMINE_VER}"
    log_info "Config: ${SYSROOT}/boot/limine/limine.conf"
    log_success "Bootloader is ready!"
}

main "$@"
