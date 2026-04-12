#!/bin/bash
# =============================================================================
# SABAOS - Master Build Script
# =============================================================================
# Skrip utama untuk build SabaOS lengkap dengan Fishix kernel
# 
# Mode Build:
#   - compile: Download dan compile di /tmp, hasil sementara
#   - ready:   Langsung siap pakai di distro-files/rootfs
#
# Usage:
#   ./00-master-build.sh [mode] [target]
#
# Examples:
#   ./00-master-build.sh              # Interactive menu
#   ./00-master-build.sh compile      # Compile mode (default)
#   ./00-master-build.sh ready        # Ready-to-use mode
#   ./00-master-build.sh compile iso  # Build ISO only
#   ./00-master-build.sh compile disk # Build disk image only
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "${SCRIPT_DIR}/versions.conf"

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

# =============================================================================
# MODE SELECTION
# =============================================================================

select_build_mode() {
    log_step "SELECT BUILD MODE"
    echo ""
    echo "Pilih mode build:"
    echo ""
    echo "  1) Compile Mode (RECOMMENDED)"
    echo "     - Download dan compile di /tmp"
    echo "     - Hasil build di /tmp/sabaos-build/"
    echo "     - Cocok untuk development dan testing"
    echo ""
    echo "  2) Ready-to-Use Mode"
    echo "     - Langsung siap pakai di distro-files/rootfs"
    echo "     - Hasil permanen di project directory"
    echo "     - Cocok untuk production build"
    echo ""
    echo "  0) Exit"
    echo ""
    read -p "Pilihan Anda [0-2]: " mode_choice
    
    case $mode_choice in
        1)
            export SABAOS_BUILD_MODE="compile"
            log_info "Mode: COMPILE (building in /tmp)"
            ;;
        2)
            export SABAOS_BUILD_MODE="ready"
            log_info "Mode: READY-TO-USE (building in distro-files/rootfs)"
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_warn "Pilihan tidak valid, menggunakan default: compile"
            export SABAOS_BUILD_MODE="compile"
            ;;
    esac
    
    # Reload configuration with new mode
    source "${SCRIPT_DIR}/versions.conf"
}

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

setup_directories() {
    log_step "SETUP DIRECTORIES"
    
    # Create all necessary directories
    mkdir -p "${SABAOS_SOURCES}"
    mkdir -p "${SABAOS_BUILD}"
    mkdir -p "${SABAOS_ROOTFS}"
    mkdir -p "${SABAOS_ISO}"
    mkdir -p "${SABAOS_DISK}"
    mkdir -p "${SABAOS_TEMP}/logs"
    
    log_success "Directories created:"
    log_info "  Sources: ${SABAOS_SOURCES}"
    log_info "  Build:   ${SABAOS_BUILD}"
    log_info "  Rootfs:  ${SABAOS_ROOTFS}"
    log_info "  ISO:     ${SABAOS_ISO}"
    log_info "  Disk:    ${SABAOS_DISK}"
}

check_prerequisites() {
    log_step "CHECK PREREQUISITES"
    
    local missing=()
    local tools=("wget" "curl" "tar" "xz" "gcc" "g++" "make" "meson" "ninja")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Tools yang diperlukan tidak ditemukan:"
        printf '  - %s\n' "${missing[@]}"
        echo ""
        log_info "Install dengan:"
        echo "  Debian/Ubuntu: sudo apt-get install build-essential meson ninja-build"
        echo "  Arch Linux:    sudo pacman -S base-devel meson ninja"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

download_sources() {
    log_step "DOWNLOAD SOURCES"
    "${SABAOS_SCRIPTS}/01-download.sh"
}

build_toolchain() {
    log_step "BUILD TOOLCHAIN"
    "${SABAOS_SCRIPTS}/02-toolchain.sh"
}

build_base_system() {
    log_step "BUILD BASE SYSTEM"
    "${SABAOS_SCRIPTS}/03-base-system.sh"
}

build_kernel() {
    log_step "BUILD FISHIX KERNEL"
    "${SABAOS_SCRIPTS}/04-kernel.sh"
}

setup_bootloader() {
    log_step "SETUP BOOTLOADER"
    "${SABAOS_SCRIPTS}/05-bootloader.sh"
}

create_image() {
    log_step "CREATE BOOTABLE IMAGE"
    "${SABAOS_SCRIPTS}/06-create-image.sh" "$1"
}

setup_chroot() {
    log_step "SETUP CHROOT ENVIRONMENT"
    "${SABAOS_SCRIPTS}/07-chroot-lfs.sh"
}

check_updates() {
    log_step "CHECK FOR UPDATES"
    "${SABAOS_SCRIPTS}/08-check-updates.sh"
}

cleanup() {
    log_step "CLEANUP"
    "${SABAOS_SCRIPTS}/09-clean.sh" "$1"
}

# =============================================================================
# FULL BUILD
# =============================================================================

build_all() {
    log_step "FULL BUILD - SABAOS"
    sabaos_print_config
    
    local start_time=$(date +%s)
    
    # Execute all build steps
    setup_directories
    check_prerequisites
    download_sources
    build_toolchain
    build_base_system
    build_kernel
    setup_bootloader
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "Build completed in $(($duration / 60))m $(($duration % 60))s"
    
    # Ask for image creation
    echo ""
    read -p "Create bootable image? [iso/qcow2/img/vdi/vmdk/n]: " img_choice
    case $img_choice in
        iso|qcow2|img|vdi|vmdk)
            create_image "$img_choice"
            ;;
        *)
            log_info "Skipping image creation"
            ;;
    esac
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}SABAOS - Master Build System${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}           ${YELLOW}Sameko Saba 🐟🐈${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Build Mode: ${GREEN}${SABAOS_BUILD_MODE}${NC}"
    echo -e "  Target:     ${GREEN}${TARGET}${NC}"
    echo ""
    echo "  MAIN OPTIONS:"
    echo "    1) Full Build (All Steps)"
    echo "    2) Download Sources Only"
    echo "    3) Build Toolchain Only"
    echo "    4) Build Base System Only"
    echo "    5) Build Fishix Kernel Only"
    echo "    6) Setup Bootloader Only"
    echo "    7) Create Bootable Image"
    echo "    8) Enter Chroot Environment"
    echo "    9) Check for Updates"
    echo ""
    echo "  CLEANUP OPTIONS:"
    echo "    c) Clean Build Artifacts"
    echo "    C) Clean Everything (including sources)"
    echo ""
    echo "  OTHER OPTIONS:"
    echo "    m) Change Build Mode"
    echo "    s) Show Configuration"
    echo "    q) Quit"
    echo ""
}

run_menu() {
    while true; do
        show_menu
        read -p "Select option [1-9/c/C/m/s/q]: " choice
        
        case $choice in
            1) build_all ;;
            2) download_sources ;;
            3) build_toolchain ;;
            4) build_base_system ;;
            5) build_kernel ;;
            6) setup_bootloader ;;
            7) 
                echo ""
                read -p "Image format [iso/qcow2/img/vdi/vmdk]: " fmt
                create_image "$fmt"
                ;;
            8) setup_chroot ;;
            9) check_updates ;;
            c|C) cleanup "$choice" ;;
            m) 
                select_build_mode
                source "${SCRIPT_DIR}/versions.conf"
                ;;
            s) sabaos_print_config ;;
            q) 
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_warn "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Check if running as root for certain operations
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. Some operations may require root privileges."
    fi
    
    # Parse command line arguments
    local mode="${1:-}"
    local target="${2:-}"
    
    # Set build mode from argument or interactive
    if [ -n "$mode" ] && [[ "$mode" != "iso" && "$mode" != "qcow2" && "$mode" != "img" && "$mode" != "vdi" && "$mode" != "vmdk" ]]; then
        export SABAOS_BUILD_MODE="$mode"
        source "${SCRIPT_DIR}/versions.conf"
    fi
    
    # Handle image format as first argument
    if [[ "$mode" == "iso" || "$mode" == "qcow2" || "$mode" == "img" || "$mode" == "vdi" || "$mode" == "vmdk" ]]; then
        create_image "$mode"
        exit 0
    fi
    
    # Handle specific targets
    case "$target" in
        iso|qcow2|img|vdi|vmdk)
            build_all
            create_image "$target"
            exit 0
            ;;
    esac
    
    # If no arguments, show interactive menu
    if [ -z "$mode" ]; then
        select_build_mode
        run_menu
    else
        # Run full build with specified mode
        build_all
    fi
}

# Run main function
main "$@"
