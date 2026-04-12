#!/bin/bash
# =============================================================================
# SABAOS - Fishix Kernel Build Script
# =============================================================================
# Build Fishix kernel dengan meson build system
# Kernel hasil build akan dimasukkan ke rootfs
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
export KERNEL_DIR="${SABAOS_ROOT}/kernel"
export FISHIX_TEMP="${SABAOS_TEMP}/fishix"

# Fishix repository
export FISHIX_REPO="${FISHIX_URL}"
export FISHIX_BRANCH="${FISHIX_BRANCH:-main}"

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
# FISHIX KERNEL DOWNLOAD
# =============================================================================

download_fishix() {
    log_step "DOWNLOADING FISHIX KERNEL"
    
    # Check if kernel directory already exists
    if [ -d "${KERNEL_DIR}/.git" ]; then
        log_info "Fishix kernel already cloned, updating..."
        cd "${KERNEL_DIR}"
        git fetch origin
        git checkout "${FISHIX_BRANCH}"
        git pull origin "${FISHIX_BRANCH}"
    elif [ -d "${KERNEL_DIR}" ] && [ -f "${KERNEL_DIR}/Makefile" ]; then
        log_info "Fishix kernel already exists, skipping download"
    else
        log_info "Cloning Fishix kernel from ${FISHIX_REPO}..."
        mkdir -p "${KERNEL_DIR}"
        git clone --depth 1 --branch "${FISHIX_BRANCH}" "${FISHIX_REPO}" "${KERNEL_DIR}"
    fi
    
    log_success "Fishix kernel ready at ${KERNEL_DIR}"
}

# =============================================================================
# FISHIX KERNEL BUILD WITH MESON
# =============================================================================

build_fishix_meson() {
    log_step "BUILDING FISHIX KERNEL WITH MESON"
    
    local kernel_src="${KERNEL_DIR}/kernel"
    local build_dir="${kernel_src}/build"
    
    if [ ! -d "$kernel_src" ]; then
        log_error "Kernel source not found at ${kernel_src}"
        log_info "Trying alternate location..."
        
        # Try alternate locations
        if [ -f "${KERNEL_DIR}/meson.build" ]; then
            kernel_src="${KERNEL_DIR}"
            build_dir="${KERNEL_DIR}/build"
        else
            log_error "Cannot find meson.build in kernel directory"
            return 1
        fi
    fi
    
    log_info "Kernel source: ${kernel_src}"
    log_info "Build directory: ${build_dir}"
    
    cd "$kernel_src"
    
    # Setup meson build if not already done
    if [ ! -d "$build_dir" ] || [ ! -f "${build_dir}/build.ninja" ]; then
        log_info "Setting up meson build..."
        meson setup "$build_dir" \
            --buildtype=release \
            --prefix=/usr \
            2>&1 | tee "${SABAOS_TEMP}/logs/fishix-meson-setup.log"
    fi
    
    # Compile
    log_info "Compiling Fishix kernel..."
    meson compile --jobs "${NPROC}" -C "$build_dir" 2>&1 | tee "${SABAOS_TEMP}/logs/fishix-meson-compile.log"
    
    # Check for kernel binary
    if [ -f "${build_dir}/fishix" ]; then
        log_success "Fishix kernel binary built: ${build_dir}/fishix"
    elif [ -f "${build_dir}/kernel" ]; then
        log_success "Kernel binary built: ${build_dir}/kernel"
        # Rename to fishix
        cp "${build_dir}/kernel" "${build_dir}/fishix"
    else
        log_warn "Kernel binary not found in expected location"
        log_info "Searching for kernel binary..."
        find "$build_dir" -type f -executable -name "*kernel*" -o -name "fishix" 2>/dev/null | head -5
    fi
}

# =============================================================================
# FISHIX KERNEL BUILD WITH MAKE (FALLBACK)
# =============================================================================

build_fishix_make() {
    log_step "BUILDING FISHIX KERNEL WITH MAKE"
    
    cd "${KERNEL_DIR}"
    
    log_info "Building with make..."
    make -j"${NPROC}" 2>&1 | tee "${SABAOS_TEMP}/logs/fishix-make.log"
    
    # Check for kernel binary
    if [ -f "${KERNEL_DIR}/kernel/build/fishix" ]; then
        log_success "Fishix kernel binary built: kernel/build/fishix"
    elif [ -f "${KERNEL_DIR}/build/fishix" ]; then
        log_success "Fishix kernel binary built: build/fishix"
    fi
}

# =============================================================================
# INSTALL KERNEL TO ROOTFS
# =============================================================================

install_kernel() {
    log_step "INSTALLING KERNEL TO ROOTFS"
    
    local kernel_binary=""
    local possible_locations=(
        "${KERNEL_DIR}/kernel/build/fishix"
        "${KERNEL_DIR}/build/fishix"
        "${KERNEL_DIR}/kernel/build/kernel"
        "${KERNEL_DIR}/build/kernel"
    )
    
    # Find kernel binary
    for loc in "${possible_locations[@]}"; do
        if [ -f "$loc" ]; then
            kernel_binary="$loc"
            break
        fi
    done
    
    if [ -z "$kernel_binary" ]; then
        log_error "Kernel binary not found!"
        log_info "Searched in:"
        printf '  %s\n' "${possible_locations[@]}"
        return 1
    fi
    
    log_info "Found kernel binary: ${kernel_binary}"
    
    # Create boot directory in rootfs
    mkdir -p "${SYSROOT}/boot"
    
    # Copy kernel to rootfs
    cp "$kernel_binary" "${SYSROOT}/boot/fishix"
    chmod 644 "${SYSROOT}/boot/fishix"
    
    log_success "Kernel installed to ${SYSROOT}/boot/fishix"
    
    # Copy kernel headers if available
    if [ -d "${KERNEL_DIR}/kernel/include" ]; then
        log_info "Installing kernel headers..."
        mkdir -p "${SYSROOT}/usr/include"
        cp -r "${KERNEL_DIR}/kernel/include/"* "${SYSROOT}/usr/include/" 2>/dev/null || true
        log_success "Kernel headers installed"
    fi
    
    # Display kernel info
    log_info "Kernel binary info:"
    ls -lh "${SYSROOT}/boot/fishix"
    file "${SYSROOT}/boot/fishix" 2>/dev/null || true
}

# =============================================================================
# CREATE INITRAMFS
# =============================================================================

create_initramfs() {
    log_step "CREATING INITRAMFS"
    
    local initramfs_dir="${SABAOS_TEMP}/initramfs"
    local initramfs_file="${SYSROOT}/boot/initramfs-sabaos.img"
    
    # Create initramfs directory structure
    rm -rf "$initramfs_dir"
    mkdir -p "$initramfs_dir"/{bin,sbin,etc,proc,sys,dev,run,tmp,lib,lib64,newroot,usr}
    mkdir -p "$initramfs_dir/usr"/{bin,sbin,lib}
    
    # Copy essential binaries from rootfs
    log_info "Copying essential binaries..."
    
    # Copy busybox or coreutils binaries
    for binary in sh bash mount umount switch_root sleep echo cat mkdir mknod ln ls cp mv rm; do
        if [ -f "${SYSROOT}/bin/${binary}" ]; then
            cp "${SYSROOT}/bin/${binary}" "${initramfs_dir}/bin/" 2>/dev/null || true
        elif [ -f "${SYSROOT}/usr/bin/${binary}" ]; then
            cp "${SYSROOT}/usr/bin/${binary}" "${initramfs_dir}/bin/" 2>/dev/null || true
        fi
    done
    
    # Copy libraries
    log_info "Copying libraries..."
    for lib in "${SYSROOT}/lib/"*.so* "${SYSROOT}/lib64/"*.so* 2>/dev/null; do
        if [ -f "$lib" ]; then
            cp -L "$lib" "${initramfs_dir}/lib/" 2>/dev/null || true
        fi
    done
    
    # Copy musl dynamic linker
    for ld in "${SYSROOT}/lib/ld-musl"* "${SYSROOT}/lib64/ld-musl"*; do
        if [ -f "$ld" ]; then
            cp -L "$ld" "${initramfs_dir}/lib/" 2>/dev/null || true
        fi
    done
    
    # Create init script
    log_info "Creating init script..."
    cat > "${initramfs_dir}/init" << 'EOF'
#!/bin/sh
# SabaOS Initramfs Init

echo "================================"
echo "  SabaOS - Sameko Saba"
echo "  Initializing..."
echo "================================"

# Mount essential filesystems
/bin/mount -t proc proc /proc 2>/dev/null || true
/bin/mount -t sysfs sysfs /sys 2>/dev/null || true
/bin/mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
/bin/mount -t tmpfs tmpfs /run 2>/dev/null || true

# Create necessary device nodes
[ -e /dev/console ] || /bin/mknod -m 622 /dev/console c 5 1 2>/dev/null || true
[ -e /dev/null ] || /bin/mknod -m 666 /dev/null c 1 3 2>/dev/null || true
[ -e /dev/zero ] || /bin/mknod -m 666 /dev/zero c 1 5 2>/dev/null || true
[ -e /dev/random ] || /bin/mknod -m 666 /dev/random c 1 8 2>/dev/null || true
[ -e /dev/urandom ] || /bin/mknod -m 666 /dev/urandom c 1 9 2>/dev/null || true
[ -e /dev/tty ] || /bin/mknod -m 666 /dev/tty c 5 0 2>/dev/null || true
[ -e /dev/tty1 ] || /bin/mknod -m 620 /dev/tty1 c 4 1 2>/dev/null || true

# Detect root device
ROOT_DEV=""
for arg in $(cat /proc/cmdline); do
    case "$arg" in
        root=*)
            ROOT_DEV="${arg#root=}"
            ;;
    esac
done

# If no root device specified, try to find one
if [ -z "$ROOT_DEV" ]; then
    # Try common devices
    for dev in /dev/sda2 /dev/vda2 /dev/nvme0n1p2 /dev/hda2; do
        if [ -b "$dev" ]; then
            ROOT_DEV="$dev"
            break
        fi
    done
fi

if [ -n "$ROOT_DEV" ]; then
    echo "Mounting root filesystem from ${ROOT_DEV}..."
    /bin/mkdir -p /newroot
    
    # Wait for device
    for i in 1 2 3 4 5; do
        if [ -b "$ROOT_DEV" ]; then
            break
        fi
        echo "Waiting for ${ROOT_DEV}..."
        /bin/sleep 1
    done
    
    if /bin/mount -o rw "$ROOT_DEV" /newroot 2>/dev/null; then
        echo "Root filesystem mounted successfully"
        
        # Move mount points
        /bin/mount --move /proc /newroot/proc 2>/dev/null || true
        /bin/mount --move /sys /newroot/sys 2>/dev/null || true
        /bin/mount --move /dev /newroot/dev 2>/dev/null || true
        /bin/mount --move /run /newroot/run 2>/dev/null || true
        
        # Switch to real root
        echo "Switching to real root..."
        exec /bin/switch_root /newroot /sbin/init
    else
        echo "Failed to mount root filesystem!"
    fi
else
    echo "No root device specified or found!"
fi

# If we get here, something went wrong
echo ""
echo "================================"
echo "  EMERGENCY SHELL"
echo "================================"
echo "Starting emergency shell..."
exec /bin/sh
EOF
    chmod +x "${initramfs_dir}/init"
    
    # Create cpio archive
    log_info "Creating cpio archive..."
    (cd "$initramfs_dir" && find . | cpio -H newc -o 2>/dev/null | gzip -9 > "$initramfs_file")
    
    if [ -f "$initramfs_file" ]; then
        log_success "Initramfs created: ${initramfs_file}"
        ls -lh "$initramfs_file"
    else
        log_error "Failed to create initramfs!"
        return 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_step "SABAOS - Fishix Kernel Build"
    
    # Create logs directory
    mkdir -p "${SABAOS_TEMP}/logs"
    
    # Download Fishix kernel
    download_fishix
    
    # Build kernel (try meson first, then make)
    if command -v meson &> /dev/null; then
        if build_fishix_meson; then
            log_success "Meson build successful"
        else
            log_warn "Meson build failed, trying make..."
            build_fishix_make
        fi
    else
        log_warn "Meson not found, using make..."
        build_fishix_make
    fi
    
    # Install kernel to rootfs
    install_kernel
    
    # Create initramfs
    create_initramfs
    
    log_step "KERNEL BUILD COMPLETE"
    log_info "Kernel: ${SYSROOT}/boot/fishix"
    log_info "Initramfs: ${SYSROOT}/boot/initramfs-sabaos.img"
    log_success "Fishix kernel is ready!"
}

main "$@"
