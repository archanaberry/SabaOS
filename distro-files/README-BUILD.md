# SabaOS Build System 🐟🐈

Sistem build lengkap untuk **SabaOS** - Sistem operasi LINUX-like independen berbasis Fishix kernel, musl libc, dan Wayland.

## 📋 Fitur

- **Dual Build Mode**: Compile mode (/tmp) atau Ready-to-use mode (distro-files/rootfs)
- **Fishix Kernel**: Integrasi penuh dengan Fishix kernel dari archanaberry
- **Meson Build**: Dukungan build kernel dengan meson
- **Multiple Disk Formats**: ISO, QCOW2, IMG, VDI, VMDK
- **Writable Disk Images**: ISO (read-only), QCOW2/IMG/VDI/VMDK (writable)
- **Interactive Menu**: Menu interaktif untuk kemudahan build
- **Chroot Environment**: Environment chroot untuk konfigurasi sistem

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/archanaberry/SabaOS.git
cd SabaOS
```

### 2. Pilih Mode Build

```bash
# Mode Compile (recommended untuk development)
export SABAOS_BUILD_MODE=compile

# Mode Ready-to-Use (untuk production)
export SABAOS_BUILD_MODE=ready
```

### 3. Build Sistem

```bash
# Full build dengan menu interaktif
./00-master-build.sh

# Atau dengan Makefile
make all

# Atau step-by-step
make download    # Download sources
make toolchain   # Build cross-toolchain
make base        # Build base system
make kernel      # Build Fishix kernel
make bootloader  # Setup Limine
make iso         # Create ISO
```

## 📁 Struktur Build Scripts

| Script | Fungsi |
|--------|--------|
| `00-master-build.sh` | Master script dengan menu interaktif |
| `01-download.sh` | Download semua source code |
| `02-toolchain.sh` | Build cross-compilation toolchain (musl-based) |
| `03-base-system.sh` | Build sistem dasar (busybox, coreutils, dll) |
| `04-kernel.sh` | Build Fishix kernel dengan meson |
| `05-bootloader.sh` | Setup Limine bootloader |
| `06-create-image.sh` | Create ISO/qcow2/img/vdi/vmdk |
| `07-chroot-lfs.sh` | Chroot environment management |
| `08-check-updates.sh` | Check package updates |
| `09-clean.sh` | Cleanup build artifacts |

## 💿 Disk Image Formats

### ISO (Read-Only)
```bash
make iso
# Output: iso/sabaos.iso
# Usage: Live CD/DVD, read-only
```

### QCOW2 (Writable - Dynamic)
```bash
make qcow2
# Output: disk/sabaos.qcow2
# Usage: QEMU/KVM, writable, dynamic allocation
```

### Raw IMG (Writable)
```bash
make img
# Output: disk/sabaos.img
# Usage: Direct write to disk, writable
```

### VDI (Writable - Dynamic)
```bash
make vdi
# Output: disk/sabaos.vdi
# Usage: VirtualBox, writable, dynamic allocation
```

### VMDK (Writable - Dynamic)
```bash
make vmdk
# Output: disk/sabaos.vmdk
# Usage: VMware, writable, dynamic allocation
```

## 🎯 Makefile Targets

### Main Targets
```bash
make all          # Full build
make build        # Build all components
make menu         # Interactive menu
make download     # Download sources
make toolchain    # Build toolchain
make base         # Build base system
make kernel       # Build Fishix kernel
make bootloader   # Setup bootloader
```

### Image Targets
```bash
make iso          # Create ISO
make qcow2        # Create QCOW2
make img          # Create raw IMG
make vdi          # Create VDI
make vmdk         # Create VMDK
make all-images   # Create all formats
```

### Utility Targets
```bash
make chroot       # Enter chroot environment
make check-updates # Check for updates
make config       # Show configuration
make status       # Show build status
make usage        # Show disk usage
```

### Clean Targets
```bash
make clean           # Clean build artifacts
make clean-all       # Clean everything
make distclean       # Full cleanup + sources
```

### QEMU Targets
```bash
make run-iso    # Run ISO in QEMU
make run-qcow2  # Run QCOW2 in QEMU
make run-img    # Run raw image in QEMU
```

## 🔧 Build Modes

### Compile Mode (Default)
- Download dan compile di `/tmp/sabaos-build/`
- Hasil sementara, cocok untuk development
- Tidak mengotori project directory

```bash
export SABAOS_BUILD_MODE=compile
./00-master-build.sh
```

### Ready-to-Use Mode
- Build langsung di `distro-files/rootfs/`
- Hasil permanen, cocok untuk production

```bash
export SABAOS_BUILD_MODE=ready
./00-master-build.sh
```

## 🐟 Fishix Kernel

Kernel Fishix di-download otomatis dari repository archanaberry:

```bash
# Download dan build Fishix kernel
make kernel

# Kernel binary: rootfs/boot/fishix
# Initramfs: rootfs/boot/initramfs-sabaos.img
```

### Manual Kernel Build
```bash
cd kernel
meson setup build
meson compile -C build
```

## 📦 Package Versions

Edit `versions.conf` untuk mengubah versi paket:

```bash
# Core Toolchain
GCC_VER="15.2.0"
MUSL_VER="1.2.6"
BINUTILS_VER="2.46"

# Bootloader
LIMINE_VER="11.3.1"

# Wayland/Graphics
WAYLAND_VER="1.23.1"
SWAY_VER="1.10.1"
```

## 🖥️ Chroot Environment

```bash
# Enter interactive chroot menu
make chroot

# Enter chroot shell directly
make chroot-shell

# Mount/unmount vfs
./scripts/07-chroot-lfs.sh mount
./scripts/07-chroot-lfs.sh umount
```

## 🔍 Check Updates

```bash
# Check all packages
make check-updates

# Check Fishix kernel only
make check-fishix
```

## 🧹 Cleanup

```bash
# Clean build artifacts
make clean

# Clean everything except sources
make clean-all

# Full cleanup including sources
make distclean

# Interactive cleanup menu
./scripts/09-clean.sh
```

## 🐧 Boot Structure

Setelah build berhasil, struktur bootable image:

```
iso/sabaos.iso atau disk/sabaos.qcow2
├── boot/
│   ├── fishix              # Fishix kernel
│   ├── initramfs-sabaos.img # Initramfs
│   └── limine/
│       ├── limine.conf     # Bootloader config
│       ├── limine-bios.sys
│       ├── limine-bios-cd.bin
│       └── limine-uefi-cd.bin
├── EFI/
│   └── BOOT/
│       ├── BOOTIA32.EFI
│       └── BOOTX64.EFI
└── boot.catalog
```

## 🚦 Boot Menu

```
SabaOS (Fishix)         - Standard boot
SabaOS (Debug)          - Debug mode
SabaOS (Recovery)       - Single user mode
```

## 🛠️ Dependencies

### Debian/Ubuntu
```bash
sudo apt-get install build-essential meson ninja-build git wget curl \
    xorriso qemu-utils parted dosfstools e2fsprogs
```

### Arch Linux
```bash
sudo pacman -S base-devel meson ninja git wget curl \
    libisoburn qemu-img parted dosfstools e2fsprogs
```

## 📝 Disk Image Specifications

| Format | Writable | Dynamic | Use Case |
|--------|----------|---------|----------|
| ISO | No | No | Live CD/DVD |
| QCOW2 | Yes | Yes | QEMU/KVM |
| IMG | Yes | No | Direct disk write |
| VDI | Yes | Yes | VirtualBox |
| VMDK | Yes | Yes | VMware |

## 🐛 Troubleshooting

### Error: "cross-compiler not found"
```bash
export PATH="${SABAOS_BUILD}/tools/cross/bin:$PATH"
```

### Error: "meson not found"
```bash
pip3 install meson
```

### Error: "Fishix kernel not found"
```bash
# Download Fishix manually
git clone https://github.com/archanaberry/Fishix kernel/
make kernel
```

## 📄 License

MIT License - See LICENSE file

## 🤝 Contributing

Contributions welcome! Please submit pull requests.

## 🐟 Sameko Saba

SabaOS - Slippery and Fast like a Mackerel 🐟

---

**Created by**: Archana Berry (Berry Lab Foundation)  
**Kernel**: Fishix by tunis4  
**License**: MIT
