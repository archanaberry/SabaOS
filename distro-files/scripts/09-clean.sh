#!/bin/bash
# =============================================================================
# SABAOS - Cleanup Script
# =============================================================================
# Membersihkan file build, sementara, atau semua
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
# CLEAN FUNCTIONS
# =============================================================================

clean_build() {
    log_step "CLEANING BUILD ARTIFACTS"
    
    if [ -d "${SABAOS_BUILD}" ]; then
        log_info "Removing build directory..."
        rm -rf "${SABAOS_BUILD}"
        log_success "Build directory removed"
    else
        log_info "Build directory not found"
    fi
    
    # Clean kernel build
    local kernel_build="${SABAOS_ROOT}/kernel/kernel/build"
    if [ -d "$kernel_build" ]; then
        log_info "Removing kernel build directory..."
        rm -rf "$kernel_build"
        log_success "Kernel build directory removed"
    fi
}

clean_temp() {
    log_step "CLEANING TEMPORARY FILES"
    
    if [ -d "${SABAOS_TEMP}" ]; then
        log_info "Removing temp directory..."
        rm -rf "${SABAOS_TEMP}"
        log_success "Temp directory removed"
    else
        log_info "Temp directory not found"
    fi
    
    # Clean old logs
    log_info "Cleaning old log files..."
    find "${SABAOS_ROOT}" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
    log_success "Old logs cleaned"
}

clean_sources() {
    log_step "CLEANING SOURCES"
    
    if [ -d "${SABAOS_SOURCES}" ]; then
        log_warn "This will remove all downloaded sources!"
        read -p "Are you sure? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Removing sources directory..."
            rm -rf "${SABAOS_SOURCES}"
            log_success "Sources directory removed"
        else
            log_info "Skipped"
        fi
    else
        log_info "Sources directory not found"
    fi
}

clean_rootfs() {
    log_step "CLEANING ROOTFS"
    
    if [ -d "${SABAOS_ROOTFS}" ]; then
        log_warn "This will remove the entire rootfs!"
        read -p "Are you sure? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Removing rootfs directory..."
            rm -rf "${SABAOS_ROOTFS}"
            log_success "Rootfs directory removed"
        else
            log_info "Skipped"
        fi
    else
        log_info "Rootfs directory not found"
    fi
}

clean_iso() {
    log_step "CLEANING ISO FILES"
    
    if [ -d "${SABAOS_ISO}" ]; then
        log_info "Removing ISO directory..."
        rm -rf "${SABAOS_ISO}"
        log_success "ISO directory removed"
    else
        log_info "ISO directory not found"
    fi
}

clean_disk() {
    log_step "CLEANING DISK IMAGES"
    
    if [ -d "${SABAOS_DISK}" ]; then
        log_info "Removing disk directory..."
        rm -rf "${SABAOS_DISK}"
        log_success "Disk directory removed"
    else
        log_info "Disk directory not found"
    fi
}

clean_all() {
    log_step "CLEANING EVERYTHING"
    
    log_warn "This will remove ALL build artifacts, sources, and images!"
    read -p "Are you absolutely sure? [yes/no]: " confirm
    
    if [ "$confirm" = "yes" ]; then
        clean_build
        clean_temp
        clean_sources
        clean_rootfs
        clean_iso
        clean_disk
        
        log_step "FULL CLEANUP COMPLETE"
        log_success "All directories cleaned"
    else
        log_info "Cleanup cancelled"
    fi
}

clean_kernel() {
    log_step "CLEANING KERNEL"
    
    local kernel_dir="${SABAOS_ROOT}/kernel"
    
    if [ -d "$kernel_dir" ]; then
        log_info "Cleaning kernel build..."
        cd "$kernel_dir"
        
        # Try make clean first
        if [ -f "Makefile" ]; then
            make clean 2>/dev/null || true
        fi
        
        # Remove build directory
        if [ -d "kernel/build" ]; then
            rm -rf "kernel/build"
            log_success "Kernel build directory removed"
        fi
        
        # Remove any leftover object files
        find "$kernel_dir" -name "*.o" -delete 2>/dev/null || true
        find "$kernel_dir" -name "*.a" -delete 2>/dev/null || true
        
        log_success "Kernel cleaned"
    else
        log_info "Kernel directory not found"
    fi
}

clean_toolchain() {
    log_step "CLEANING TOOLCHAIN"
    
    local toolchain_dir="${SABAOS_BUILD}/tools"
    
    if [ -d "$toolchain_dir" ]; then
        log_warn "This will remove the entire cross-compilation toolchain!"
        read -p "Are you sure? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Removing toolchain directory..."
            rm -rf "$toolchain_dir"
            log_success "Toolchain directory removed"
        else
            log_info "Skipped"
        fi
    else
        log_info "Toolchain directory not found"
    fi
}

# =============================================================================
# SHOW DISK USAGE
# =============================================================================

show_usage() {
    log_step "DISK USAGE"
    
    echo ""
    echo "Directory sizes:"
    echo ""
    
    local dirs=(
        "Sources:${SABAOS_SOURCES}"
        "Build:${SABAOS_BUILD}"
        "Rootfs:${SABAOS_ROOTFS}"
        "ISO:${SABAOS_ISO}"
        "Disk:${SABAOS_DISK}"
        "Temp:${SABAOS_TEMP}"
    )
    
    for dir_info in "${dirs[@]}"; do
        local name="${dir_info%%:*}"
        local path="${dir_info##*:}"
        
        if [ -d "$path" ]; then
            local size=$(du -sh "$path" 2>/dev/null | cut -f1)
            printf "  %-10s %8s\n" "$name:" "$size"
        else
            printf "  %-10s %8s\n" "$name:" "N/A"
        fi
    done
    
    echo ""
    log_info "Total project size:"
    du -sh "${SABAOS_ROOT}" 2>/dev/null || echo "  N/A"
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           ${GREEN}SABAOS - Cleanup Manager${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  CLEANUP OPTIONS:"
    echo "    1) Clean build artifacts"
    echo "    2) Clean temporary files"
    echo "    3) Clean sources"
    echo "    4) Clean rootfs"
    echo "    5) Clean ISO files"
    echo "    6) Clean disk images"
    echo "    7) Clean kernel build"
    echo "    8) Clean toolchain"
    echo ""
    echo "    C) Clean everything (ALL)"
    echo ""
    echo "    s) Show disk usage"
    echo "    q) Quit"
    echo ""
}

run_interactive() {
    while true; do
        show_menu
        read -p "Select option [1-8/C/s/q]: " choice
        
        case $choice in
            1) clean_build ;;
            2) clean_temp ;;
            3) clean_sources ;;
            4) clean_rootfs ;;
            5) clean_iso ;;
            6) clean_disk ;;
            7) clean_kernel ;;
            8) clean_toolchain ;;
            C|c) clean_all ;;
            s) show_usage ;;
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
    log_step "SABAOS - Cleanup"
    
    local action="${1:-menu}"
    
    case "$action" in
        build)
            clean_build
            ;;
        temp)
            clean_temp
            ;;
        sources)
            clean_sources
            ;;
        rootfs)
            clean_rootfs
            ;;
        iso)
            clean_iso
            ;;
        disk)
            clean_disk
            ;;
        kernel)
            clean_kernel
            ;;
        toolchain)
            clean_toolchain
            ;;
        all|C|c)
            clean_all
            ;;
        usage|status|s)
            show_usage
            ;;
        menu|*)
            run_interactive
            ;;
    esac
}

main "$@"
