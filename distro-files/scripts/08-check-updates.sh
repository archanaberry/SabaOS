#!/bin/bash
# =============================================================================
# SABAOS - Check Updates Script
# =============================================================================
# Memeriksa versi terbaru dari paket-paket SabaOS
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
# CHECK FUNCTIONS
# =============================================================================

check_gnu_package() {
    local name="$1"
    local current_ver="$2"
    local url="$3"
    
    log_info "Checking ${name}..."
    
    # Try to get latest version from FTP listing
    local latest=$(curl -sL "$url" 2>/dev/null | grep -oP 'href="[^"]*'"${name}"'-[0-9]+\.[0-9]+[^"]*' | grep -oP '[0-9]+\.[0-9]+[a-z0-9.-]*' | sort -V | tail -1)
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$current_ver" ]; then
            log_warn "${name}: ${current_ver} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "${name}: ${current_ver} (up to date)"
        fi
    else
        log_info "${name}: ${current_ver} (cannot check)"
    fi
}

check_kernel() {
    log_info "Checking Linux kernel..."
    
    local latest=$(curl -sL "https://www.kernel.org/releases.json" 2>/dev/null | grep -oP '"version":"\K[0-9]+\.[0-9]+' | head -1)
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$LINUX_VER" ]; then
            log_warn "Linux: ${LINUX_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "Linux: ${LINUX_VER} (up to date)"
        fi
    else
        log_info "Linux: ${LINUX_VER} (cannot check)"
    fi
}

check_musl() {
    log_info "Checking musl..."
    
    local latest=$(curl -sL "https://musl.libc.org/releases.html" 2>/dev/null | grep -oP 'musl-[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/musl-//')
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$MUSL_VER" ]; then
            log_warn "musl: ${MUSL_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "musl: ${MUSL_VER} (up to date)"
        fi
    else
        log_info "musl: ${MUSL_VER} (cannot check)"
    fi
}

check_busybox() {
    log_info "Checking BusyBox..."
    
    local latest=$(curl -sL "https://busybox.net/downloads/" 2>/dev/null | grep -oP 'busybox-[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/busybox-//')
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$BUSYBOX_VER" ]; then
            log_warn "BusyBox: ${BUSYBOX_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "BusyBox: ${BUSYBOX_VER} (up to date)"
        fi
    else
        log_info "BusyBox: ${BUSYBOX_VER} (cannot check)"
    fi
}

check_limine() {
    log_info "Checking Limine..."
    
    local latest=$(curl -sL "https://api.github.com/repos/limine-bootloader/limine/releases/latest" 2>/dev/null | grep -oP '"tag_name": "v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$LIMINE_VER" ]; then
            log_warn "Limine: ${LIMINE_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "Limine: ${LIMINE_VER} (up to date)"
        fi
    else
        log_info "Limine: ${LIMINE_VER} (cannot check)"
    fi
}

check_wayland() {
    log_info "Checking Wayland..."
    
    local latest=$(curl -sL "https://wayland.freedesktop.org/releases.html" 2>/dev/null | grep -oP 'wayland-[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's/wayland-//')
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$WAYLAND_VER" ]; then
            log_warn "Wayland: ${WAYLAND_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "Wayland: ${WAYLAND_VER} (up to date)"
        fi
    else
        log_info "Wayland: ${WAYLAND_VER} (cannot check)"
    fi
}

check_sway() {
    log_info "Checking Sway..."
    
    local latest=$(curl -sL "https://api.github.com/repos/swaywm/sway/releases/latest" 2>/dev/null | grep -oP '"tag_name": "\K[0-9]+\.[0-9]+' | head -1)
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$SWAY_VER" ]; then
            log_warn "Sway: ${SWAY_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "Sway: ${SWAY_VER} (up to date)"
        fi
    else
        log_info "Sway: ${SWAY_VER} (cannot check)"
    fi
}

check_fish() {
    log_info "Checking Fish shell..."
    
    local latest=$(curl -sL "https://api.github.com/repos/fish-shell/fish-shell/releases/latest" 2>/dev/null | grep -oP '"tag_name": "\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -n "$latest" ]; then
        if [ "$latest" != "$FISH_VER" ]; then
            log_warn "Fish: ${FISH_VER} -> ${latest} (UPDATE AVAILABLE)"
        else
            log_success "Fish: ${FISH_VER} (up to date)"
        fi
    else
        log_info "Fish: ${FISH_VER} (cannot check)"
    fi
}

# =============================================================================
# CHECK ALL PACKAGES
# =============================================================================

check_all() {
    log_step "CHECKING FOR UPDATES"
    
    log_info "Current versions in versions.conf:"
    echo ""
    
    # Core toolchain
    check_gnu_package "binutils" "$BINUTILS_VER" "https://ftp.gnu.org/gnu/binutils/"
    check_gnu_package "gcc" "$GCC_VER" "https://ftp.gnu.org/gnu/gcc/"
    check_musl
    
    # Init & bootloader
    check_limine
    
    # Core utilities
    check_busybox
    check_gnu_package "coreutils" "$COREUTILS_VER" "https://ftp.gnu.org/gnu/coreutils/"
    check_gnu_package "bash" "$BASH_VER" "https://ftp.gnu.org/gnu/bash/"
    
    # Wayland/Graphics
    check_wayland
    check_sway
    
    # Userland
    check_fish
    
    echo ""
    log_info "Note: Some packages may not be checkable due to API limitations"
}

# =============================================================================
# CHECK FISHIX KERNEL
# =============================================================================

check_fishix() {
    log_step "CHECKING FISHIX KERNEL"
    
    local kernel_dir="${SABAOS_ROOT}/kernel"
    
    if [ ! -d "$kernel_dir" ]; then
        log_warn "Fishix kernel not found at ${kernel_dir}"
        return 1
    fi
    
    cd "$kernel_dir"
    
    # Check if it's a git repository
    if [ -d ".git" ]; then
        log_info "Fetching latest Fishix updates..."
        git fetch origin 2>/dev/null || true
        
        local local_commit=$(git rev-parse HEAD 2>/dev/null)
        local remote_commit=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
        
        if [ "$local_commit" != "$remote_commit" ]; then
            log_warn "Fishix kernel updates available!"
            log_info "Local:  ${local_commit:0:8}"
            log_info "Remote: ${remote_commit:0:8}"
            echo ""
            log_info "To update, run:"
            echo "  cd ${kernel_dir} && git pull"
        else
            log_success "Fishix kernel is up to date"
        fi
        
        # Show last commit
        echo ""
        log_info "Last commit:"
        git log -1 --oneline 2>/dev/null || echo "  N/A"
    else
        log_info "Fishix kernel is not a git repository"
    fi
}

# =============================================================================
# GENERATE UPDATE SCRIPT
# =============================================================================

generate_update_script() {
    log_step "GENERATING UPDATE SCRIPT"
    
    local update_script="${SABAOS_ROOT}/update-versions.sh"
    
    cat > "$update_script" << 'EOF'
#!/bin/bash
# SABAOS - Version Update Script
# Generated by 08-check-updates.sh

# This script contains the latest detected versions
# Review and apply changes to versions.conf as needed

EOF
    
    echo "# Update date: $(date)" >> "$update_script"
    echo "" >> "$update_script"
    echo "# Latest detected versions:" >> "$update_script"
    echo "# Edit versions.conf to apply these updates" >> "$update_script"
    echo "" >> "$update_script"
    
    chmod +x "$update_script"
    
    log_success "Update script generated: ${update_script}"
    log_info "Review the script and apply changes manually to versions.conf"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_step "SABAOS - Check for Updates"
    
    local action="${1:-all}"
    
    case "$action" in
        all)
            check_all
            check_fishix
            ;;
        fishix|kernel)
            check_fishix
            ;;
        toolchain)
            check_gnu_package "binutils" "$BINUTILS_VER" "https://ftp.gnu.org/gnu/binutils/"
            check_gnu_package "gcc" "$GCC_VER" "https://ftp.gnu.org/gnu/gcc/"
            check_musl
            ;;
        wayland)
            check_wayland
            check_sway
            ;;
        generate)
            generate_update_script
            ;;
        *)
            log_error "Unknown action: $action"
            log_info "Usage: $0 [all|fishix|toolchain|wayland|generate]"
            exit 1
            ;;
    esac
    
    echo ""
    log_step "CHECK COMPLETE"
}

main "$@"
