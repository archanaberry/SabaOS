#!/bin/bash
# ============================================================================
# SABA OS v2.0 - ISO Creation Script (Fishix Kernel Edition)
# Membuat bootable ISO image dari Saba OS build dengan Fishix kernel
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ISO_NAME="${1:-sabaos-2.0-fishix.iso}"
SYSROOT="${2:-/mnt/saba_os}"
LIMINE_DIR="${3:-../limine}"

# Detect Fishix paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FISHIX_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd || echo "")"
FISHIX_KERNEL_DIR="${FISHIX_ROOT}/kernel"
FISHIX_BUILD_DIR="${FISHIX_KERNEL_DIR}/build"
FISHIX_DISTRO_FILES="${FISHIX_ROOT}/distro-files"

echo -e "${BLUE}==============================================================${NC}"
echo -e "${BLUE}||${NC}       SABA OS v2.0 - ISO Creation Tool (Fishix)          ${BLUE}||${NC}"
echo -e "${BLUE}==============================================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  ISO Name:   $ISO_NAME"
echo "  Sysroot:    $SYSROOT"
echo "  Limine Dir: $LIMINE_DIR"
echo "  Fishix Root: $FISHIX_ROOT"
echo "  Fishix Kernel: $FISHIX_KERNEL_DIR"
echo ""

# Check prerequisites
check_prereqs() {
    local missing=()
    
    if ! command -v xorriso >/dev/null 2>&1; then
        missing+=("xorriso")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing[*]}${NC}"
        echo "Install with:"
        echo "  Debian/Ubuntu: sudo apt-get install xorriso"
        echo "  Arch Linux:    sudo pacman -S libisoburn"
        exit 1
    fi
}

check_prereqs

# Create temporary directory
WORK_DIR=$(mktemp -d)
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    echo -e "${RED}Error: Could not create temp dir${NC}"
    exit 1
fi

cleanup() {
    echo -e "${BLUE}Cleaning up...${NC}"
    rm -rf "$WORK_DIR"
    echo -e "${GREEN}Deleted temp working directory $WORK_DIR${NC}"
}
trap cleanup EXIT

ISOROOT="$WORK_DIR/isoroot"
mkdir -pv "$ISOROOT/boot"

# Check sysroot
echo -e "${BLUE}Checking sysroot...${NC}"
if [ ! -d "$SYSROOT" ]; then
    echo -e "${RED}Error: Sysroot directory not found: $SYSROOT${NC}"
    echo "Please build Saba OS first with: sudo ./build_sabaos.sh"
    exit 1
fi

# Check for Fishix kernel
echo -e "${BLUE}Checking Fishix kernel...${NC}"
KERNEL_FILE=""
KERNEL_NAME="fishix"

# Priority order for kernel location
if [ -f "${SYSROOT}/boot/fishix" ]; then
    KERNEL_FILE="${SYSROOT}/boot/fishix"
    log_success "Found Fishix kernel in sysroot: $KERNEL_FILE"
elif [ -f "${FISHIX_BUILD_DIR}/fishix" ]; then
    KERNEL_FILE="${FISHIX_BUILD_DIR}/fishix"
    log_success "Found Fishix kernel in build dir: $KERNEL_FILE"
elif [ -f "${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage" ]; then
    KERNEL_FILE="${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage"
    log_success "Found Fishix bzImage: $KERNEL_FILE"
elif [ -f "${SYSROOT}/boot/vmlinuz-sabaos-2.0" ]; then
    KERNEL_FILE="${SYSROOT}/boot/vmlinuz-sabaos-2.0"
    KERNEL_NAME="vmlinuz-sabaos"
    log_success "Found SabaOS kernel: $KERNEL_FILE"
else
    echo -e "${RED}Error: Fishix kernel not found!${NC}"
    echo "Searched in:"
    echo "  ${SYSROOT}/boot/fishix"
    echo "  ${FISHIX_BUILD_DIR}/fishix"
    echo "  ${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage"
    echo ""
    echo "Please build Fishix kernel first:"
    echo "  cd ${FISHIX_KERNEL_DIR} && make"
    echo "Or run: sudo ./build_sabaos.sh and select option 3"
    exit 1
fi

echo -e "${GREEN}Using kernel: $KERNEL_FILE${NC}"

# Check initramfs
echo -e "${BLUE}Checking initramfs...${NC}"
INITRAMFS_FILE=""

if [ -f "${SYSROOT}/boot/initramfs-sabaos.img" ]; then
    INITRAMFS_FILE="${SYSROOT}/boot/initramfs-sabaos.img"
elif [ -f "${SYSROOT}/boot/initramfs-Fishix-1.0.5.img" ]; then
    INITRAMFS_FILE="${SYSROOT}/boot/initramfs-Fishix-1.0.5.img"
else
    echo -e "${YELLOW}Warning: Initramfs not found, creating minimal one...${NC}"
    # Create minimal initramfs
    INITRAMFS_DIR="$WORK_DIR/initramfs"
    mkdir -p "$INITRAMFS_DIR"/{bin,sbin,etc,proc,sys,dev,run,tmp,lib,lib64,newroot}
    
    # Copy busybox if available
    if [ -f "${SYSROOT}/bin/busybox" ]; then
        cp "${SYSROOT}/bin/busybox" "$INITRAMFS_DIR/bin/"
    elif [ -f "${SYSROOT}/tools/bin/busybox" ]; then
        cp "${SYSROOT}/tools/bin/busybox" "$INITRAMFS_DIR/bin/"
    fi
    
    # Create symlinks
    for applet in sh mount umount switch_root sleep echo cat mkdir mknod; do
        ln -sf busybox "$INITRAMFS_DIR/bin/$applet" 2>/dev/null || true
    done
    
    # Copy libraries
    for lib in "${SYSROOT}/lib/ld-musl"*.so* "${SYSROOT}/tools/lib/ld-musl"*.so*; do
        if [ -f "$lib" ]; then
            cp "$lib" "$INITRAMFS_DIR/lib/" 2>/dev/null || true
        fi
    done
    
    # Create init script
    cat > "$INITRAMFS_DIR/init" << 'INITEOF'
#!/bin/sh
echo "Saba OS Emergency Initramfs"
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t devtmpfs devtmpfs /dev
exec /bin/sh
INITEOF
    chmod +x "$INITRAMFS_DIR/init"
    
    # Create cpio archive
    INITRAMFS_FILE="$WORK_DIR/initramfs.img"
    (cd "$INITRAMFS_DIR" && find . | cpio -H newc -o | gzip -9 > "$INITRAMFS_FILE")
fi

echo -e "${GREEN}Using initramfs: $INITRAMFS_FILE${NC}"

# Copy kernel and initramfs to ISO root
echo -e "${BLUE}Copying kernel and initramfs...${NC}"
cp "$KERNEL_FILE" "$ISOROOT/boot/fishix"
cp "$INITRAMFS_FILE" "$ISOROOT/boot/initramfs-sabaos.img"

# Copy distro-files if available
if [ -d "$FISHIX_DISTRO_FILES" ]; then
    echo -e "${BLUE}Copying distro files...${NC}"
    mkdir -pv "$ISOROOT/distro-files"
    cp -r "$FISHIX_DISTRO_FILES"/* "$ISOROOT/distro-files/" 2>/dev/null || true
fi

# Create limine config
echo -e "${BLUE}Creating limine configuration...${NC}"
cat > "$ISOROOT/boot/limine.conf" << 'EOF'
TIMEOUT=5
DEFAULT_ENTRY=1

:Saba OS 2.0 (Fishix)
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw quiet

:Saba OS 2.0 (Fishix Recovery)
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw single

:Saba OS 2.0 (Fishix Debug)
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw debug
EOF

# Install limine if available
if [ -d "$LIMINE_DIR" ]; then
    echo -e "${BLUE}Installing limine bootloader...${NC}"
    
    # Copy limine binaries
    if [ -f "$LIMINE_DIR/limine-bios.sys" ]; then
        cp "$LIMINE_DIR/limine-bios.sys" "$ISOROOT/boot/"
    fi
    if [ -f "$LIMINE_DIR/limine-bios-cd.bin" ]; then
        cp "$LIMINE_DIR/limine-bios-cd.bin" "$ISOROOT/boot/"
    fi
    if [ -f "$LIMINE_DIR/limine-uefi-cd.bin" ]; then
        cp "$LIMINE_DIR/limine-uefi-cd.bin" "$ISOROOT/boot/"
    fi
    
    # Copy UEFI files
    mkdir -pv "$ISOROOT/EFI/BOOT"
    for efi_file in "$LIMINE_DIR"/BOOT*.EFI; do
        if [ -f "$efi_file" ]; then
            cp "$efi_file" "$ISOROOT/EFI/BOOT/"
        fi
    done
    
    # Create ISO with limine
    echo -e "${BLUE}Creating ISO image with limine...${NC}"
    xorriso -as mkisofs \
        -b boot/limine-bios-cd.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --efi-boot boot/limine-uefi-cd.bin \
        -efi-boot-part \
        --efi-boot-image \
        --protective-msdos-label \
        "$ISOROOT" \
        -o "$ISO_NAME" 2>&1 | tee "$WORK_DIR/iso.log"
    
    # Install limine to ISO
    if [ -f "$LIMINE_DIR/limine" ]; then
        echo -e "${BLUE}Installing limine to ISO...${NC}"
        "$LIMINE_DIR/limine" bios-install "$ISO_NAME" 2>/dev/null || true
    fi
else
    # Create basic ISO without limine
    echo -e "${YELLOW}Limine not found, creating basic ISO...${NC}"
    xorriso -as mkisofs \
        -r -V "Saba OS 2.0 (Fishix)" \
        -J -joliet-long \
        -o "$ISO_NAME" \
        "$ISOROOT" 2>&1 | tee "$WORK_DIR/iso.log"
fi

# Verify ISO was created
if [ -f "$ISO_NAME" ]; then
    echo ""
    echo -e "${GREEN}==============================================================${NC}"
    echo -e "${GREEN}||${NC}              ISO Created Successfully!                     ${GREEN}||${NC}"
    echo -e "${GREEN}==============================================================${NC}"
    echo ""
    echo -e "${BLUE}ISO File:${NC} $ISO_NAME"
    echo -e "${BLUE}Size:${NC} $(ls -lh "$ISO_NAME" | awk '{print $5}')"
    echo ""
    echo -e "${BLUE}To test with QEMU:${NC}"
    echo "  qemu-system-x86_64 -cdrom $ISO_NAME -m 2G"
    echo ""
    echo -e "${BLUE}To write to USB:${NC}"
    echo "  sudo dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress"
    echo "  (Replace /dev/sdX with your USB device)"
    echo ""
else
    echo -e "${RED}Error: ISO creation failed!${NC}"
    exit 1
fi
