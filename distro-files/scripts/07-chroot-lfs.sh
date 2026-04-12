#!/bin/bash
# =============================================================================
# SABAOS - Chroot Environment Setup Script
# =============================================================================
# Setup dan masuk ke chroot environment untuk konfigurasi sistem
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

export SYSROOT="${SABAOS_ROOTFS}"

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
# MOUNT VIRTUAL FILESYSTEMS
# =============================================================================

mount_vfs() {
    log_step "MOUNTING VIRTUAL FILESYSTEMS"
    
    # Mount proc
    if ! mountpoint -q "${SYSROOT}/proc"; then
        sudo mount -t proc proc "${SYSROOT}/proc"
        log_success "Mounted /proc"
    fi
    
    # Mount sysfs
    if ! mountpoint -q "${SYSROOT}/sys"; then
        sudo mount -t sysfs sysfs "${SYSROOT}/sys"
        log_success "Mounted /sys"
    fi
    
    # Mount devtmpfs
    if ! mountpoint -q "${SYSROOT}/dev"; then
        sudo mount -t devtmpfs devtmpfs "${SYSROOT}/dev"
        log_success "Mounted /dev"
    fi
    
    # Mount devpts
    if ! mountpoint -q "${SYSROOT}/dev/pts"; then
        sudo mount -t devpts devpts "${SYSROOT}/dev/pts" -o gid=5,mode=620
        log_success "Mounted /dev/pts"
    fi
    
    # Mount tmpfs for /run
    if ! mountpoint -q "${SYSROOT}/run"; then
        sudo mount -t tmpfs tmpfs "${SYSROOT}/run"
        log_success "Mounted /run"
    fi
    
    # Bind mount /tmp
    if ! mountpoint -q "${SYSROOT}/tmp"; then
        sudo mount -t tmpfs tmpfs "${SYSROOT}/tmp"
        log_success "Mounted /tmp"
    fi
}

# =============================================================================
# UNMOUNT VIRTUAL FILESYSTEMS
# =============================================================================

unmount_vfs() {
    log_step "UNMOUNTING VIRTUAL FILESYSTEMS"
    
    # Unmount in reverse order
    for mount_point in "${SYSROOT}/tmp" "${SYSROOT}/run" "${SYSROOT}/dev/pts" "${SYSROOT}/dev" "${SYSROOT}/sys" "${SYSROOT}/proc"; do
        if mountpoint -q "$mount_point"; then
            sudo umount "$mount_point" 2>/dev/null || true
            log_info "Unmounted $mount_point"
        fi
    done
    
    log_success "Virtual filesystems unmounted"
}

# =============================================================================
# COPY RESOLV CONF
# =============================================================================

setup_network() {
    log_step "SETTING UP NETWORK IN CHROOT"
    
    # Copy resolv.conf for DNS
    if [ -f /etc/resolv.conf ]; then
        sudo cp /etc/resolv.conf "${SYSROOT}/etc/resolv.conf"
        log_success "Copied resolv.conf"
    fi
    
    # Copy hosts
    if [ -f /etc/hosts ]; then
        sudo cp /etc/hosts "${SYSROOT}/etc/hosts"
        log_success "Copied hosts"
    fi
}

# =============================================================================
# SETUP DEVICE NODES
# =============================================================================

setup_devices() {
    log_step "SETTING UP DEVICE NODES"
    
    # Create essential device nodes if they don't exist
    sudo mkdir -p "${SYSROOT}/dev"
    
    # Create null device
    if [ ! -e "${SYSROOT}/dev/null" ]; then
        sudo mknod -m 666 "${SYSROOT}/dev/null" c 1 3 2>/dev/null || true
    fi
    
    # Create zero device
    if [ ! -e "${SYSROOT}/dev/zero" ]; then
        sudo mknod -m 666 "${SYSROOT}/dev/zero" c 1 5 2>/dev/null || true
    fi
    
    # Create random device
    if [ ! -e "${SYSROOT}/dev/random" ]; then
        sudo mknod -m 666 "${SYSROOT}/dev/random" c 1 8 2>/dev/null || true
    fi
    
    # Create urandom device
    if [ ! -e "${SYSROOT}/dev/urandom" ]; then
        sudo mknod -m 666 "${SYSROOT}/dev/urandom" c 1 9 2>/dev/null || true
    fi
    
    # Create tty device
    if [ ! -e "${SYSROOT}/dev/tty" ]; then
        sudo mknod -m 666 "${SYSROOT}/dev/tty" c 5 0 2>/dev/null || true
    fi
    
    # Create console device
    if [ ! -e "${SYSROOT}/dev/console" ]; then
        sudo mknod -m 622 "${SYSROOT}/dev/console" c 5 1 2>/dev/null || true
    fi
    
    log_success "Device nodes created"
}

# =============================================================================
# ENTER CHROOT
# =============================================================================

enter_chroot() {
    log_step "ENTERING CHROOT ENVIRONMENT"
    
    log_info "Chroot directory: ${SYSROOT}"
    log_info "Type 'exit' to leave chroot"
    echo ""
    
    # Export variables for chroot
    export PS1='(sabaos-chroot) \u@\h:\w\$ '
    
    # Enter chroot
    sudo chroot "$SYSROOT" /bin/bash --login
    
    echo ""
    log_success "Exited chroot environment"
}

# =============================================================================
# RUN COMMAND IN CHROOT
# =============================================================================

run_in_chroot() {
    local cmd="$1"
    
    log_info "Running in chroot: $cmd"
    sudo chroot "$SYSROOT" /bin/sh -c "$cmd"
}

# =============================================================================
# SETUP BASE CONFIGURATION
# =============================================================================

setup_base_config() {
    log_step "SETTING UP BASE CONFIGURATION IN CHROOT"
    
    # Set root password
    log_info "Setting root password..."
    run_in_chroot "echo 'root:sabaos' | chpasswd" 2>/dev/null || true
    
    # Set timezone
    log_info "Setting timezone..."
    run_in_chroot "ln -sf /usr/share/zoneinfo/UTC /etc/localtime" 2>/dev/null || true
    
    # Generate locale
    log_info "Generating locale..."
    run_in_chroot "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen" 2>/dev/null || true
    
    log_success "Base configuration complete"
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${GREEN}SABAOS - Chroot Environment Manager${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Rootfs: ${GREEN}${SYSROOT}${NC}"
    echo ""
    echo "  OPTIONS:"
    echo "    1) Enter chroot (interactive shell)"
    echo "    2) Mount virtual filesystems"
    echo "    3) Unmount virtual filesystems"
    echo "    4) Setup base configuration"
    echo "    5) Run custom command in chroot"
    echo "    6) Install additional packages"
    echo ""
    echo "    s) Show status"
    echo "    q) Quit"
    echo ""
}

run_interactive() {
    while true; do
        show_menu
        read -p "Select option [1-6/s/q]: " choice
        
        case $choice in
            1)
                mount_vfs
                setup_network
                enter_chroot
                unmount_vfs
                ;;
            2)
                mount_vfs
                setup_network
                ;;
            3)
                unmount_vfs
                ;;
            4)
                mount_vfs
                setup_network
                setup_base_config
                unmount_vfs
                ;;
            5)
                read -p "Enter command to run in chroot: " cmd
                mount_vfs
                run_in_chroot "$cmd"
                unmount_vfs
                ;;
            6)
                mount_vfs
                setup_network
                log_info "Package installation not yet implemented"
                unmount_vfs
                ;;
            s)
                echo ""
                log_info "Mount status:"
                mount | grep "$SYSROOT" || echo "  No mounts found"
                echo ""
                log_info "Disk usage:"
                du -sh "$SYSROOT" 2>/dev/null || echo "  N/A"
                ;;
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
    log_step "SABAOS - Chroot Environment"
    
    # Check if rootfs exists
    if [ ! -d "$SYSROOT" ]; then
        log_error "Rootfs not found: ${SYSROOT}"
        log_info "Please build the base system first"
        exit 1
    fi
    
    # Parse arguments
    local action="${1:-menu}"
    
    case "$action" in
        mount)
            mount_vfs
            setup_network
            ;;
        umount|unmount)
            unmount_vfs
            ;;
        setup|config)
            mount_vfs
            setup_network
            setup_base_config
            unmount_vfs
            ;;
        run)
            mount_vfs
            setup_network
            run_in_chroot "$2"
            unmount_vfs
            ;;
        shell|bash|sh)
            mount_vfs
            setup_network
            enter_chroot
            unmount_vfs
            ;;
        menu|*)
            run_interactive
            ;;
    esac
}

main "$@"
