#!/bin/bash
# ============================================================================
# SABAOS BUSYBOX BUILD HELPER
# Builds BusyBox 1.36.x with SabaOS defconfig (Fishix-compatible)
# 
# Problem: BusyBox bleeding edge (1.37+) hardcodes Linux ioctl
#          Example: linux/vt.h (virtual terminal - Linux only)
# 
# Solution: Use stable 1.36.x with kernel-agnostic defconfig
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_DIR="${HOME}/saba_os_sources"
BUSYBOX_VERSION="1.36.1"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
BUSYBOX_DIR="busybox-${BUSYBOX_VERSION}"
BUSYBOX_URL="https://busybox.net/downloads/${BUSYBOX_TAR}"
DEFCONFIG="${SCRIPT_DIR}/sabaos_busybox.defconfig"

# ============================================================================
# FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Download BusyBox
download_busybox() {
    log_section "DOWNLOAD BUSYBOX ${BUSYBOX_VERSION}"
    
    if [ -f "${SOURCES_DIR}/${BUSYBOX_TAR}" ]; then
        log_info "BusyBox archive sudah ada, melewati download"
        return 0
    fi
    
    mkdir -p "${SOURCES_DIR}"
    
    log_info "Downloading dari: $BUSYBOX_URL"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar "$BUSYBOX_URL" -o "${SOURCES_DIR}/${BUSYBOX_TAR}"
    elif command -v wget >/dev/null 2>&1; then
        wget --progress=bar:force -O "${SOURCES_DIR}/${BUSYBOX_TAR}" "$BUSYBOX_URL"
    else
        log_error "curl atau wget tidak tersedia"
        return 1
    fi
    
    log_success "Download selesai"
}

# Extract BusyBox
extract_busybox() {
    log_section "EXTRACT BUSYBOX"
    
    if [ -d "${BUSYBOX_DIR}" ]; then
        log_warning "BusyBox directory sudah ada, cleaning..."
        rm -rf "${BUSYBOX_DIR}"
    fi
    
    log_info "Extracting ${BUSYBOX_TAR}..."
    tar -xjf "${SOURCES_DIR}/${BUSYBOX_TAR}"
    
    log_success "Extract selesai"
}

# Verify defconfig exists
verify_defconfig() {
    log_section "VERIFY DEFCONFIG"
    
    if [ ! -f "$DEFCONFIG" ]; then
        log_error "sabaos_busybox.defconfig tidak ditemukan di: $DEFCONFIG"
        log_info "File harus ada di: $SCRIPT_DIR/"
        return 1
    fi
    
    log_info "Found: $DEFCONFIG"
    log_info "Size: $(wc -l < "$DEFCONFIG") lines"
    log_success "Defconfig verified"
}

# Apply SabaOS defconfig
apply_defconfig() {
    log_section "APPLY SABAOS DEFCONFIG"
    
    cd "${BUSYBOX_DIR}"
    
    log_info "Copying defconfig to .config..."
    cp "$DEFCONFIG" .config
    
    log_info "Running 'make oldconfig' untuk validate..."
    make oldconfig >/dev/null 2>&1 || {
        log_warning "oldconfig ada warnings (normal, lanjut...)"
    }
    
    log_success "Defconfig applied"
    
    # Show key settings
    log_info ""
    log_info "Key BusyBox Settings (SabaOS Profile):"
    echo ""
    echo -e "  ${BLUE}Static Build:${NC}"
    grep "^CONFIG_STATIC=" .config
    grep "^CONFIG_PIE=" .config
    echo ""
    echo -e "  ${BLUE}Shell (ash only):${NC}"
    grep "^CONFIG_ASH=" .config
    grep "^CONFIG_HUSH=" .config | head -1
    echo ""
    echo -e "  ${BLUE}Init System:${NC}"
    grep "^CONFIG_INIT=" .config
    echo ""
    echo -e "  ${BLUE}DISABLED (Linux-specific):${NC}"
    grep "^CONFIG_SETFONT=" .config
    grep "^CONFIG_SYSLOG=" .config | head -1
    grep "^CONFIG_FEATURE_UTMP=" .config
    echo ""
}

# Build BusyBox
build_busybox() {
    log_section "BUILD BUSYBOX ${BUSYBOX_VERSION}"
    
    cd "${BUSYBOX_DIR}"
    
    log_info "Cleaning previous build..."
    make distclean 2>/dev/null || true
    
    # Apply defconfig again to be sure
    cp "$DEFCONFIG" .config
    make oldconfig >/dev/null 2>&1 || true
    
    log_info "Building (this may take a few minutes)..."
    log_info "Command: CFLAGS='-O2 -static' make -j\$(nproc)"
    echo ""
    
    CFLAGS="-O2 -static" make -j$(nproc) 2>&1 | tee build.log
    
    # Check result
    if [ ! -f busybox ]; then
        log_error "Build gagal! Binary tidak dihasilkan"
        log_info "Check build.log untuk detail"
        return 1
    fi
    
    log_success "Build selesai"
}

# Verify binary
verify_binary() {
    log_section "VERIFY BINARY"
    
    cd "${BUSYBOX_DIR}"
    
    local size=$(stat -c%s busybox 2>/dev/null || stat -f%z busybox 2>/dev/null)
    local size_mb=$(echo "scale=2; $size / 1048576" | bc)
    
    log_info "Binary: busybox"
    log_info "Size: ${size_mb} MB (${size} bytes)"
    
    # Check if static
    if file busybox | grep -q "statically linked"; then
        log_success "✓ Statically linked (good for Fishix)"
    else
        log_warning "⚠ Dynamic linked (may have glibc dependencies)"
    fi
    
    # Check dependencies
    if command -v ldd >/dev/null 2>&1; then
        log_info "Dependencies:"
        ldd busybox 2>&1 | head -5 || log_info "  (none - static binary)"
    fi
    
    # Test binary
    log_info ""
    log_info "Quick test:"
    ./busybox --version
    ./busybox ls | head -3
}

# Show usage
show_usage() {
    cat << 'EOF'
USAGE

Build BusyBox untuk SabaOS:

  1. Download:     ./build_busybox.sh download
  2. Extract:      ./build_busybox.sh extract
  3. Configure:    ./build_busybox.sh config
  4. Build:        ./build_busybox.sh build
  5. Verify:       ./build_busybox.sh verify

Atau semua langkah sekaligus:

  ./build_busybox.sh all

Opsi lainnya:

  ./build_busybox.sh menuconfig    # Interactive config
  ./build_busybox.sh clean         # Hapus build artifacts

TROUBLESHOOTING

Jika error "linux/vt.h: No such file":

  ✓ Gunakan script ini dengan SabaOS defconfig
  ✓ Jangan pakai BusyBox 1.37+ (terlalu banyak Linux assumption)
  ✓ Pastikan defconfig disable semua linux/tty features

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local action="${1:-all}"
    
    case "$action" in
        download)
            download_busybox
            ;;
        extract)
            download_busybox
            extract_busybox
            ;;
        config)
            download_busybox
            extract_busybox
            verify_defconfig
            apply_defconfig
            ;;
        build)
            download_busybox
            extract_busybox
            verify_defconfig
            apply_defconfig
            build_busybox
            ;;
        verify)
            if [ ! -d "${BUSYBOX_DIR}" ]; then
                log_error "BusyBox directory not found, run 'build' first"
                return 1
            fi
            verify_binary
            ;;
        all)
            download_busybox
            extract_busybox
            verify_defconfig
            apply_defconfig
            build_busybox
            verify_binary
            
            log_section "BUILD COMPLETE"
            log_success "BusyBox ${BUSYBOX_VERSION} siap digunakan!"
            echo ""
            echo "Binary: $(pwd)/${BUSYBOX_DIR}/busybox"
            echo "Config: $(pwd)/${BUSYBOX_DIR}/.config"
            echo ""
            echo "Untuk menggunakan di chroot:"
            echo "  make CONFIG_PREFIX=/mnt/saba_os install"
            ;;
        menuconfig)
            if [ ! -d "${BUSYBOX_DIR}" ]; then
                download_busybox
                extract_busybox
            fi
            cd "${BUSYBOX_DIR}"
            log_info "Opening menuconfig..."
            make menuconfig
            ;;
        clean)
            log_section "CLEANUP"
            if [ -d "${BUSYBOX_DIR}" ]; then
                log_info "Removing BusyBox build directory..."
                rm -rf "${BUSYBOX_DIR}"
                log_success "Cleaned"
            fi
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown action: $action"
            echo ""
            show_usage
            return 1
            ;;
    esac
}

# Run main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
