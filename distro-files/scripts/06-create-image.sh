#!/bin/bash
# =============================================================================
# SABAOS - Bootable Image Creation Script
# =============================================================================
# Membuat berbagai format image: ISO, qcow2, img, vdi, vmdk
# 
# Usage:
#   ./06-create-image.sh [format]
#
# Format options:
#   iso    - Bootable ISO (read-only, live CD/DVD)
#   qcow2  - QEMU Copy-On-Write v2 (dynamic, writable)
#   img    - Raw disk image (writable)
#   vdi    - VirtualBox Disk Image (dynamic, writable)
#   vmdk   - VMware Disk Image (dynamic, writable)
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

# Configuration
export SYSROOT="${SABAOS_ROOTFS}"
export IMAGE_FORMAT="${1:-${DISK_FORMAT}}"
export IMAGE_NAME="${DISK_NAME}"
export IMAGE_SIZE="${DISK_SIZE}"
export LIMINE_DIR="${SABAOS_BUILD}/limine-${LIMINE_VER}"

# Image paths
export ISO_PATH="${SABAOS_ISO}/${ISO_NAME}"
export DISK_PATH="${SABAOS_DISK}/${IMAGE_NAME}.${IMAGE_FORMAT}"

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
# PREREQUISITES CHECK
# =============================================================================

check_prerequisites() {
    local format="$1"
    local missing=()
    
    log_info "Checking prerequisites for ${format}..."
    
    case "$format" in
        iso)
            if ! command -v xorriso &> /dev/null; then
                missing+=("xorriso")
            fi
            ;;
        qcow2|img)
            if ! command -v qemu-img &> /dev/null; then
                missing+=("qemu-utils")
            fi
            if ! command -v mkfs.ext4 &> /dev/null; then
                missing+=("e2fsprogs")
            fi
            if ! command -v parted &> /dev/null; then
                missing+=("parted")
            fi
            ;;
        vdi)
            if ! command -v VBoxManage &> /dev/null && ! command -v qemu-img &> /dev/null; then
                missing+=("virtualbox or qemu-utils")
            fi
            ;;
        vmdk)
            if ! command -v qemu-img &> /dev/null; then
                missing+=("qemu-utils")
            fi
            ;;
    esac
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install with:"
        echo "  Debian/Ubuntu: sudo apt-get install ${missing[*]}"
        echo "  Arch Linux:    sudo pacman -S ${missing[*]}"
        return 1
    fi
    
    log_success "All prerequisites satisfied"
}

# =============================================================================
# ISO CREATION (Read-only, Live CD/DVD)
# =============================================================================

create_iso() {
    log_step "CREATING BOOTABLE ISO"
    
    check_prerequisites "iso"
    
    local work_dir=$(mktemp -d)
    local iso_root="${work_dir}/isoroot"
    
    trap "rm -rf $work_dir" EXIT
    
    mkdir -p "$iso_root"
    mkdir -p "${SABAOS_ISO}"
    
    log_info "Creating ISO structure..."
    
    # Create boot directory
    mkdir -p "${iso_root}/boot"
    
    # Copy kernel and initramfs
    if [ -f "${SYSROOT}/boot/fishix" ]; then
        cp "${SYSROOT}/boot/fishix" "${iso_root}/boot/"
        log_success "Copied kernel"
    else
        log_error "Kernel not found!"
        return 1
    fi
    
    if [ -f "${SYSROOT}/boot/initramfs-sabaos.img" ]; then
        cp "${SYSROOT}/boot/initramfs-sabaos.img" "${iso_root}/boot/"
        log_success "Copied initramfs"
    else
        log_error "Initramfs not found!"
        return 1
    fi
    
    # Copy Limine files
    if [ -d "${LIMINE_DIR}" ]; then
        log_info "Installing Limine bootloader..."
        
        # Copy Limine binaries
        cp "${LIMINE_DIR}/limine-bios.sys" "${iso_root}/boot/" 2>/dev/null || true
        cp "${LIMINE_DIR}/limine-bios-cd.bin" "${iso_root}/boot/" 2>/dev/null || true
        cp "${LIMINE_DIR}/limine-uefi-cd.bin" "${iso_root}/boot/" 2>/dev/null || true
        
        # Create EFI directory
        mkdir -p "${iso_root}/EFI/BOOT"
        for efi in "${LIMINE_DIR}"/BOOT*.EFI; do
            if [ -f "$efi" ]; then
                cp "$efi" "${iso_root}/EFI/BOOT/"
            fi
        done
        
        # Create Limine config
        cat > "${iso_root}/boot/limine.conf" << 'EOF'
TIMEOUT=5
DEFAULT_ENTRY=1

:SabaOS (Fishix)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sr0 ro quiet

:SabaOS (Debug)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sr0 ro debug

:SabaOS (Recovery)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sr0 ro single
EOF
        log_success "Limine bootloader installed"
    else
        log_warn "Limine not found, creating basic ISO..."
    fi
    
    # Create ISO
    log_info "Creating ISO image..."
    xorriso -as mkisofs \
        -b boot/limine-bios-cd.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --efi-boot boot/limine-uefi-cd.bin \
        -efi-boot-part \
        --efi-boot-image \
        --protective-msdos-label \
        -V "${ISO_LABEL}" \
        -o "$ISO_PATH" \
        "$iso_root" 2>&1 | tee "${SABAOS_TEMP}/logs/iso-creation.log"
    
    # Install Limine to ISO
    if [ -f "${LIMINE_DIR}/limine" ]; then
        log_info "Installing Limine to ISO..."
        "${LIMINE_DIR}/limine" bios-install "$ISO_PATH" 2>/dev/null || true
    fi
    
    if [ -f "$ISO_PATH" ]; then
        log_success "ISO created successfully!"
        log_info "Location: $ISO_PATH"
        log_info "Size: $(ls -lh "$ISO_PATH" | awk '{print $5}')"
        echo ""
        log_info "To test with QEMU:"
        echo "  qemu-system-x86_64 -cdrom $ISO_PATH -m 2G"
        echo ""
        log_info "To write to USB:"
        echo "  sudo dd if=$ISO_PATH of=/dev/sdX bs=4M status=progress"
    else
        log_error "ISO creation failed!"
        return 1
    fi
}

# =============================================================================
# DISK IMAGE CREATION (Writable formats)
# =============================================================================

create_disk_image() {
    local format="$1"
    local img_path="$2"
    
    log_step "CREATING ${format^^} DISK IMAGE"
    
    check_prerequisites "$format"
    
    local work_dir=$(mktemp -d)
    local loop_dev=""
    
    cleanup() {
        if [ -n "$loop_dev" ]; then
            sudo losetup -d "$loop_dev" 2>/dev/null || true
        fi
        rm -rf "$work_dir"
    }
    trap cleanup EXIT
    
    mkdir -p "${SABAOS_DISK}"
    
    # Create raw disk image first
    local raw_img="${work_dir}/disk.raw"
    log_info "Creating raw disk image (${IMAGE_SIZE})..."
    
    # Create sparse file
    truncate -s "$IMAGE_SIZE" "$raw_img"
    
    # Create partition table
    log_info "Creating partition table..."
    parted -s "$raw_img" mklabel gpt
    parted -s "$raw_img" mkpart primary fat32 1MiB 100MiB
    parted -s "$raw_img" mkpart primary ext4 100MiB 100%
    parted -s "$raw_img" set 1 esp on
    
    # Setup loop device
    log_info "Setting up loop device..."
    loop_dev=$(sudo losetup -fP --show "$raw_img")
    
    # Wait for partitions
    sleep 1
    
    local efi_part="${loop_dev}p1"
    local root_part="${loop_dev}p2"
    
    # Format partitions
    log_info "Formatting EFI partition (FAT32)..."
    sudo mkfs.vfat -F32 -n "EFI" "$efi_part" 2>&1 | tee "${SABAOS_TEMP}/logs/mkfs-efi.log"
    
    log_info "Formatting root partition (ext4)..."
    sudo mkfs.ext4 -L "SABAOS" "$root_part" 2>&1 | tee "${SABAOS_TEMP}/logs/mkfs-root.log"
    
    # Mount and copy files
    local mount_dir="${work_dir}/mnt"
    mkdir -p "$mount_dir"
    
    # Mount root partition
    log_info "Mounting root partition..."
    sudo mount "$root_part" "$mount_dir"
    
    # Copy rootfs
    log_info "Copying rootfs to disk..."
    sudo cp -a "${SYSROOT}/." "$mount_dir/"
    
    # Create boot directory
    sudo mkdir -p "${mount_dir}/boot"
    
    # Mount EFI partition
    local efi_mount="${mount_dir}/boot/efi"
    sudo mkdir -p "$efi_mount"
    sudo mount "$efi_part" "$efi_mount"
    
    # Setup EFI boot
    log_info "Setting up EFI boot..."
    sudo mkdir -p "${efi_mount}/EFI/BOOT"
    
    # Copy EFI files
    if [ -d "${LIMINE_DIR}" ]; then
        for efi in "${LIMINE_DIR}"/BOOT*.EFI; do
            if [ -f "$efi" ]; then
                sudo cp "$efi" "${efi_mount}/EFI/BOOT/"
            fi
        done
    fi
    
    # Copy Limine files to boot
    if [ -d "${LIMINE_DIR}" ]; then
        sudo cp "${LIMINE_DIR}/limine-bios.sys" "${mount_dir}/boot/" 2>/dev/null || true
    fi
    
    # Create Limine config
    sudo mkdir -p "${mount_dir}/boot/limine"
    sudo tee "${mount_dir}/boot/limine/limine.conf" << 'EOF'
TIMEOUT=5
DEFAULT_ENTRY=1

:SabaOS (Fishix)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw

:SabaOS (Debug)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw debug

:SabaOS (Recovery)
    PROTOCOL=limine
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw single
EOF
    
    # Unmount
    log_info "Unmounting partitions..."
    sudo umount "$efi_mount" 2>/dev/null || true
    sudo umount "$mount_dir" 2>/dev/null || true
    
    # Detach loop device
    sudo losetup -d "$loop_dev" 2>/dev/null || true
    loop_dev=""
    
    # Convert to target format
    case "$format" in
        qcow2)
            log_info "Converting to QCOW2 format..."
            qemu-img convert -f raw -O qcow2 "$raw_img" "$img_path"
            ;;
        img)
            log_info "Keeping as raw IMG format..."
            cp "$raw_img" "$img_path"
            ;;
        vdi)
            log_info "Converting to VDI format..."
            if command -v VBoxManage &> /dev/null; then
                VBoxManage convertfromraw "$raw_img" "$img_path" --format VDI
            else
                qemu-img convert -f raw -O vdi "$raw_img" "$img_path"
            fi
            ;;
        vmdk)
            log_info "Converting to VMDK format..."
            qemu-img convert -f raw -O vmdk "$raw_img" "$img_path"
            ;;
    esac
    
    if [ -f "$img_path" ]; then
        log_success "${format^^} disk image created successfully!"
        log_info "Location: $img_path"
        log_info "Size: $(ls -lh "$img_path" | awk '{print $5}')"
        echo ""
        log_info "To run with QEMU:"
        case "$format" in
            qcow2)
                echo "  qemu-system-x86_64 -hda $img_path -m 2G"
                ;;
            img)
                echo "  qemu-system-x86_64 -hda $img_path -m 2G"
                ;;
            vdi)
                echo "  VirtualBox: Create VM and attach $img_path"
                echo "  QEMU: qemu-system-x86_64 -hda $img_path -m 2G"
                ;;
            vmdk)
                echo "  VMware: Create VM and attach $img_path"
                echo "  QEMU: qemu-system-x86_64 -hda $img_path -m 2G"
                ;;
        esac
    else
        log_error "Disk image creation failed!"
        return 1
    fi
}

# =============================================================================
# CREATE ALL FORMATS
# =============================================================================

create_all_formats() {
    log_step "CREATING ALL IMAGE FORMATS"
    
    # Create ISO
    create_iso
    
    # Create QCOW2
    DISK_PATH="${SABAOS_DISK}/${IMAGE_NAME}.qcow2"
    create_disk_image "qcow2" "$DISK_PATH"
    
    # Create raw IMG
    DISK_PATH="${SABAOS_DISK}/${IMAGE_NAME}.img"
    create_disk_image "img" "$DISK_PATH"
    
    log_success "All image formats created!"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_step "SABAOS - Bootable Image Creation"
    
    # Create logs directory
    mkdir -p "${SABAOS_TEMP}/logs"
    
    # Parse format
    local format="${IMAGE_FORMAT}"
    
    case "$format" in
        iso)
            create_iso
            ;;
        qcow2)
            create_disk_image "qcow2" "$DISK_PATH"
            ;;
        img)
            create_disk_image "img" "$DISK_PATH"
            ;;
        vdi)
            DISK_PATH="${SABAOS_DISK}/${IMAGE_NAME}.vdi"
            create_disk_image "vdi" "$DISK_PATH"
            ;;
        vmdk)
            DISK_PATH="${SABAOS_DISK}/${IMAGE_NAME}.vmdk"
            create_disk_image "vmdk" "$DISK_PATH"
            ;;
        all)
            create_all_formats
            ;;
        *)
            log_error "Unknown format: $format"
            log_info "Supported formats: iso, qcow2, img, vdi, vmdk, all"
            exit 1
            ;;
    esac
    
    log_step "IMAGE CREATION COMPLETE"
}

main "$@"
