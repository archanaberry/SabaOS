#!/bin/bash
# ============================================================================
# SABA OS BUILD SCRIPT v1.0
# Linux From Scratch 2026 - musl + runit + Wayland
# Maskot: Sameko Saba 🐟
# ============================================================================

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Konfigurasi
export SABA_VERSION="1.0"
export LFS=/mnt/saba_os
export SABA_TGT=$(uname -m)-saba-linux-musl
export MAKEFLAGS="-j$(nproc)"
export PATH=/tools/bin:/bin:/usr/bin

# Direktori
SOURCES_DIR="${HOME}/saba_os_sources"
BUILD_DIR="${LFS}/build"
LOGS_DIR="${BUILD_DIR}/logs"

# ============================================================================
# FUNGSI UTILITAS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}========================================${NC}\n"
}

# ============================================================================
# FASE 0: PERSIAPAN
# ============================================================================

phase0_preparation() {
    log_section "FASE 0: PERSIAPAN SISTEM"
    
    log_info "Membuat direktori kerja..."
    sudo mkdir -pv "$LFS"
    sudo mkdir -pv "${LFS}/tools"
    sudo mkdir -pv "${LFS}/sources"
    sudo mkdir -pv "$BUILD_DIR"
    sudo mkdir -pv "$LOGS_DIR"
    sudo mkdir -pv "${LFS}/boot"
    sudo mkdir -pv "${LFS}/etc"
    sudo mkdir -pv "${LFS}/bin"
    sudo mkdir -pv "${LFS}/sbin"
    sudo mkdir -pv "${LFS}/lib"
    sudo mkdir -pv "${LFS}/lib64"
    sudo mkdir -pv "${LFS}/usr"
    sudo mkdir -pv "${LFS}/var"
    
    log_info "Menyalin source code..."
    sudo cp -r "${SOURCES_DIR}"/* "${LFS}/sources/" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/sources"
    
    log_success "Persiapan selesai!"
}

# ============================================================================
# FASE 1: TOOLCHAIN CROSS-COMPILATION (musl)
# ============================================================================

phase1_toolchain() {
    log_section "FASE 1: MEMBANGUN CROSS-TOOLCHAIN (musl)"
    
    cd "${LFS}/sources"
    
    # 1. Binutils - Cross
    log_info "[1/4] Membangun Binutils (cross)..."
    if [ ! -f "${LOGS_DIR}/binutils_cross.done" ]; then
        tar -xf binutils-2.46.tar.xz 2>/dev/null || log_warning "Binutils sudah diekstrak"
        mkdir -pv binutils-build && cd binutils-build
        ../binutils-2.46/configure \
            --prefix=/tools \
            --with-sysroot="$LFS" \
            --with-lib-path="${LFS}/tools/lib" \
            --target="$SABA_TGT" \
            --disable-nls \
            --disable-werror \
            --enable-deterministic-archives \
            --disable-compressed-debug-sections \
            2>&1 | tee "${LOGS_DIR}/binutils_configure.log"
        make 2>&1 | tee "${LOGS_DIR}/binutils_make.log"
        make install 2>&1 | tee "${LOGS_DIR}/binutils_install.log"
        touch "${LOGS_DIR}/binutils_cross.done"
        cd ..
        log_success "Binutils cross selesai!"
    else
        log_warning "Binutils cross sudah dibangun, melewati..."
    fi
    
    # 2. musl libc headers
    log_info "[2/4] Menginstal musl libc headers..."
    if [ ! -f "${LOGS_DIR}/musl_headers.done" ]; then
        tar -xf musl-1.2.6.tar.gz 2>/dev/null || log_warning "musl sudah diekstrak"
        cd musl-1.2.6
        ./configure --prefix=/tools --target="$SABA_TGT" 2>&1 | tee "${LOGS_DIR}/musl_headers_configure.log"
        make install-headers 2>&1 | tee "${LOGS_DIR}/musl_headers_install.log"
        touch "${LOGS_DIR}/musl_headers.done"
        cd ..
        log_success "musl headers selesai!"
    else
        log_warning "musl headers sudah diinstal, melewati..."
    fi
    
    # 3. GCC - Cross Compiler (Static)
    log_info "[3/4] Membangun GCC (cross, static)..."
    if [ ! -f "${LOGS_DIR}/gcc_cross.done" ]; then
        tar -xf gcc-14.2.0.tar.xz 2>/dev/null || log_warning "GCC sudah diekstrak"
        cd gcc-14.2.0
        ./contrib/download_prerequisites 2>/dev/null || log_warning "Prerequisites mungkin sudah ada"
        cd ..
        
        mkdir -pv gcc-build && cd gcc-build
        ../gcc-14.2.0/configure \
            --prefix=/tools \
            --target="$SABA_TGT" \
            --with-sysroot="$LFS" \
            --with-newlib \
            --without-headers \
            --with-local-prefix="${LFS}/tools" \
            --with-native-system-header-dir="${LFS}/tools/include" \
            --disable-nls \
            --disable-shared \
            --disable-multilib \
            --disable-decimal-float \
            --disable-threads \
            --disable-libatomic \
            --disable-libgomp \
            --disable-libquadmath \
            --disable-libssp \
            --disable-libvtv \
            --disable-libstdcxx \
            --enable-languages=c,c++ \
            2>&1 | tee "${LOGS_DIR}/gcc_configure.log"
        make all-gcc 2>&1 | tee "${LOGS_DIR}/gcc_make.log"
        make all-target-libgcc 2>&1 | tee "${LOGS_DIR}/gcc_libgcc.log"
        make install-gcc 2>&1 | tee "${LOGS_DIR}/gcc_install.log"
        make install-target-libgcc 2>&1 | tee "${LOGS_DIR}/gcc_libgcc_install.log"
        touch "${LOGS_DIR}/gcc_cross.done"
        cd ..
        log_success "GCC cross selesai!"
    else
        log_warning "GCC cross sudah dibangun, melewati..."
    fi
    
    # 4. musl libc (Cross)
    log_info "[4/4] Membangun musl libc (cross)..."
    if [ ! -f "${LOGS_DIR}/musl_cross.done" ]; then
        cd musl-1.2.6
        CC="${SABA_TGT}-gcc" \
        CXX="${SABA_TGT}-g++" \
        AR="${SABA_TGT}-ar" \
        RANLIB="${SABA_TGT}-ranlib" \
        ./configure \
            --prefix=/tools \
            --target="$SABA_TGT" \
            --disable-shared \
            2>&1 | tee "${LOGS_DIR}/musl_configure.log"
        make 2>&1 | tee "${LOGS_DIR}/musl_make.log"
        make install 2>&1 | tee "${LOGS_DIR}/musl_install.log"
        touch "${LOGS_DIR}/musl_cross.done"
        cd ..
        log_success "musl libc cross selesai!"
    else
        log_warning "musl libc cross sudah dibangun, melewati..."
    fi
    
    log_success "Cross-toolchain selesai dibangun!"
}

# ============================================================================
# FASE 2: CHROOT & SISTEM DASAR
# ============================================================================

phase2_chroot() {
    log_section "FASE 2: MEMASUKI CHROOT & BUILD SISTEM DASAR"
    
    log_info "Membuat direktori sistem..."
    sudo mkdir -pv "${LFS}/dev"
    sudo mkdir -pv "${LFS}/proc"
    sudo mkdir -pv "${LFS}/sys"
    sudo mkdir -pv "${LFS}/run"
    sudo mkdir -pv "${LFS}/tmp"
    
    log_info "Mount virtual filesystems..."
    sudo mount -v --bind /dev "${LFS}/dev"
    sudo mount -vt proc proc "${LFS}/proc"
    sudo mount -vt sysfs sysfs "${LFS}/sys"
    sudo mount -vt tmpfs tmpfs "${LFS}/run"
    sudo mount -vt tmpfs tmpfs "${LFS}/tmp"
    
    log_info "Membuat skrip chroot..."
    cat > "${BUILD_DIR}/chroot_build.sh" << 'CHROOT_EOF'
#!/bin/bash
set -e

# Setup environment
export PATH=/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[CHROOT]${NC} Membangun sistem dasar Saba OS..."

# Create essential directories
mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

# Install coreutils
echo -e "${BLUE}[CHROOT]${NC} Menginstal Coreutils..."
cd /sources
tar -xf coreutils-9.6.tar.xz
cd coreutils-9.6
./configure --prefix=/usr --host=$SABA_TGT --build=$(build-aux/config.guess) \
    --enable-install-program=hostname --enable-no-install-program=kill,uptime
make
make install
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/1' /usr/share/man/man8/chroot.8
echo -e "${GREEN}[CHROOT]${NC} Coreutils selesai!"

# Install BusyBox untuk utilitas tambahan
echo -e "${BLUE}[CHROOT]${NC} Menginstal BusyBox..."
cd /sources
tar -xf busybox-1.37.0.tar.bz2
cd busybox-1.37.0
make defconfig
make CONFIG_PREFIX=/usr install
echo -e "${GREEN}[CHROOT]${NC} BusyBox selesai!"

# Install Fish Shell
echo -e "${BLUE}[CHROOT]${NC} Menginstal Fish Shell..."
cd /sources
tar -xf fish-4.5.0.tar.xz
cd fish-4.5.0
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
make
make install
ln -sfv /usr/bin/fish /bin/sh
echo -e "${GREEN}[CHROOT]${NC} Fish Shell selesai!"

# Install runit
echo -e "${BLUE}[CHROOT]${NC} Menginstal runit..."
cd /sources
tar -xf runit-2.1.2.tar.gz
cd admin/runit-2.1.2
package/install
cd src
make
make check
cp -v runit runit-init runsv runsvdir sv svlogd chpst utmpset /sbin/
echo -e "${GREEN}[CHROOT]${NC} runit selesai!"

echo -e "${GREEN}[CHROOT]${NC} Sistem dasar selesai dibangun!"
CHROOT_EOF
    
    chmod +x "${BUILD_DIR}/chroot_build.sh"
    
    log_info "Memasuki chroot..."
    sudo chroot "$LFS" /tools/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        PS1='(saba-chroot) \u:\w\$ ' \
        PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
        SABA_TGT="$SABA_TGT" \
        /bin/bash /build/chroot_build.sh 2>&1 | tee "${LOGS_DIR}/chroot_build.log"
    
    log_success "Chroot build selesai!"
}

# ============================================================================
# FASE 3: KERNEL FISHIX
# ============================================================================

phase3_kernel() {
    log_section "FASE 3: MENGOMPILASI KERNEL FISHIX"
    
    log_info "Mempersiapkan kernel Linux 6.18.20..."
    cd "${LFS}/sources"
    
    if [ ! -d "linux-6.18.20" ]; then
        tar -xf linux-6.18.20.tar.xz
    fi
    
    cd linux-6.18.20
    
    log_info "Membersihkan build sebelumnya..."
    make mrproper 2>/dev/null || true
    
    log_info "Membuat konfigurasi minimal untuk Saba OS..."
    cat > .config << 'KERNEL_CONFIG'
# Minimal kernel config for Saba OS
CONFIG_LOCALVERSION="-Fishix-1.0.5"
CONFIG_DEFAULT_HOSTNAME="saba-os"
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_NO_HZ_IDLE=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_BPF_SYSCALL=y
CONFIG_PREEMPT=y
CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
CONFIG_CGROUPS=y
CONFIG_MEMCG=y
CONFIG_BLK_CGROUP=y
CONFIG_CGROUP_SCHED=y
CONFIG_CFS_BANDWIDTH=y
CONFIG_RT_GROUP_SCHED=y
CONFIG_NAMESPACES=y
CONFIG_USER_NS=y
CONFIG_CHECKPOINT_RESTORE=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_EXPERT=y
CONFIG_KALLSYMS_ALL=y
CONFIG_PC104=y
CONFIG_SMP=y
CONFIG_X86_INTEL_LPSS=y
CONFIG_X86_AMD_PLATFORM_DEVICE=y
CONFIG_IOSF_MBI=y
CONFIG_SCHED_OMIT_FRAME_POINTER=y
CONFIG_HYPERVISOR_GUEST=y
CONFIG_PARAVIRT=y
CONFIG_X86_CPU_RESCTRL=y
CONFIG_X86_EXTENDED_PLATFORM=y
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFI_MIXED=y
CONFIG_HZ_1000=y
CONFIG_PHYSICAL_ALIGN=0x1000000
CONFIG_PM=y
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y
CONFIG_X86_INTEL_PSTATE=y
CONFIG_X86_AMD_PSTATE=y
CONFIG_ACPI=y
CONFIG_ACPI_BUTTON=y
CONFIG_ACPI_FAN=y
CONFIG_ACPI_DOCK=y
CONFIG_ACPI_PROCESSOR=y
CONFIG_ACPI_THERMAL=y
CONFIG_CPU_IDLE=y
CONFIG_PCI=y
CONFIG_PCIEPORTBUS=y
CONFIG_HOTPLUG_PCI=y
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y
CONFIG_BINFMT_MISC=y
CONFIG_IA32_EMULATION=y
CONFIG_COMPAT_32BIT_TIME=y
CONFIG_NET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_INET=y
CONFIG_NETFILTER=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_BLK_DEV_LOOP=y
CONFIG_VIRTIO_BLK=y
CONFIG_BLK_DEV_SD=y
CONFIG_SATA_AHCI=y
CONFIG_PATA_AMD=y
CONFIG_PATA_INTEL=y
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_CRYPT=y
CONFIG_NETDEVICES=y
CONFIG_VIRTIO_NET=y
CONFIG_E1000=y
CONFIG_E1000E=y
CONFIG_R8169=y
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_KEYBOARD_ATKBD=y
CONFIG_INPUT_MOUSE=y
CONFIG_MOUSE_PS2=y
CONFIG_SERIO=y
CONFIG_TTY=y
CONFIG_VT=y
CONFIG_CONSOLE_TRANSLATIONS=y
CONFIG_VT_CONSOLE=y
CONFIG_HW_CONSOLE=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_HW_RANDOM=y
CONFIG_HW_RANDOM_VIRTIO=y
CONFIG_THERMAL=y
CONFIG_DRM=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_DRM_BOCHS=y
CONFIG_FB=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_HDA_INTEL=y
CONFIG_SND_HDA_CODEC_GENERIC=y
CONFIG_SND_VIRTIO=y
CONFIG_USB=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_UHCI_HCD=y
CONFIG_USB_STORAGE=y
CONFIG_USB_HID=y
CONFIG_HID=y
CONFIG_HID_GENERIC=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_INPUT=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_MMIO_CMDLINE_DEVICES=y
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_BTRFS_FS=y
CONFIG_XFS_FS=y
CONFIG_FAT_FS=y
CONFIG_VFAT_FS=y
CONFIG_EXFAT_FS=y
CONFIG_NTFS_FS=y
CONFIG_NTFS3_FS=y
CONFIG_PROC_FS=y
CONFIG_PROC_KCORE=y
CONFIG_PROC_SYSCTL=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_HUGETLBFS=y
CONFIG_CONFIGFS_FS=y
CONFIG_SQUASHFS=y
CONFIG_NLS=y
CONFIG_NLS_DEFAULT="utf8"
CONFIG_NLS_CODEPAGE_437=y
CONFIG_NLS_ASCII=y
CONFIG_NLS_UTF8=y
CONFIG_SECURITY=y
CONFIG_SECURITY_SELINUX=y
CONFIG_SECURITY_APPARMOR=y
CONFIG_SECURITY_YAMA=y
CONFIG_CRYPTO=y
CONFIG_CRYPTO_AES=y
CONFIG_CRYPTO_XTS=y
CONFIG_CRYPTO_SHA256=y
CONFIG_CRYPTO_LIB_SHA256=y
CONFIG_DEBUG_KERNEL=y
CONFIG_DEBUG_FS=y
CONFIG_MAGIC_SYSRQ=y
CONFIG_DEBUG_STACK_USAGE=y
# Single Core Scheduler Optimization
CONFIG_SCHED_CORE=y
CONFIG_NR_CPUS=8
CONFIG_SCHED_SMT=y
CONFIG_SCHED_MC=y
CONFIG_SCHED_MC_PRIO=y
KERNEL_CONFIG
    
    log_info "Menjalankan oldconfig..."
    make olddefconfig 2>&1 | tee "${LOGS_DIR}/kernel_config.log"
    
    log_info "Mengompilasi kernel (ini akan memakan waktu)..."
    make -j$(nproc) 2>&1 | tee "${LOGS_DIR}/kernel_build.log"
    
    log_info "Menginstal kernel modules..."
    make modules_install INSTALL_MOD_PATH="$LFS" 2>&1 | tee "${LOGS_DIR}/kernel_modules.log"
    
    log_info "Menyalin kernel image..."
    cp -v arch/x86/boot/bzImage "${LFS}/boot/vmlinuz-Fishix-1.0.5"
    cp -v System.map "${LFS}/boot/System.map-6.18.20"
    cp -v .config "${LFS}/boot/config-6.18.20"
    
    log_success "Kernel Fishix 1.0.5 selesai dibangun!"
}

# ============================================================================
# FASE 4: WAYLAND & SWAY
# ============================================================================

phase4_wayland() {
    log_section "FASE 4: MENGINSTAL WAYLAND & SWAY"
    
    log_info "Membuat skrip build Wayland di chroot..."
    
    cat > "${BUILD_DIR}/build_wayland.sh" << 'WAYLAND_EOF'
#!/bin/bash
set -e

export PATH=/usr/bin:/usr/sbin:/bin:/sbin
export MAKEFLAGS="-j$(nproc)"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[WAYLAND]${NC} Membangun Wayland stack..."

# 1. Wayland
echo -e "${BLUE}[WAYLAND]${NC} 1/7: wayland..."
cd /sources
tar -xf wayland-1.23.1.tar.xz
cd wayland-1.23.1
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release -Ddocumentation=false
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} wayland selesai!"

# 2. wayland-protocols
echo -e "${BLUE}[WAYLAND]${NC} 2/7: wayland-protocols..."
cd /sources
tar -xf wayland-protocols-1.47.tar.xz
cd wayland-protocols-1.47
mkdir build && cd build
meson setup .. --prefix=/usr
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} wayland-protocols selesai!"

# 3. Pixman
echo -e "${BLUE}[WAYLAND]${NC} 3/7: pixman..."
cd /sources
tar -xf pixman-0.46.4.tar.gz
cd pixman-0.46.4
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} pixman selesai!"

# 4. libxkbcommon
echo -e "${BLUE}[WAYLAND]${NC} 4/7: libxkbcommon..."
cd /sources
tar -xf libxkbcommon-1.13.1.tar.gz
cd libxkbcommon-1.13.1
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release -Denable-docs=false
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} libxkbcommon selesai!"

# 5. libinput
echo -e "${BLUE}[WAYLAND]${NC} 5/7: libinput..."
cd /sources
tar -xf libinput-1.26.0.tar.xz
cd libinput-1.26.0
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release -Ddocumentation=false
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} libinput selesai!"

# 6. wlroots
echo -e "${BLUE}[WAYLAND]${NC} 6/7: wlroots..."
cd /sources
tar -xf wlroots-0.18.3.tar.gz
cd wlroots-0.18.3
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release -Dexamples=false
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} wlroots selesai!"

# 7. Sway
echo -e "${BLUE}[WAYLAND]${NC} 7/7: sway..."
cd /sources
tar -xf sway-1.11.tar.gz
cd sway-1.11
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release
ninja
ninja install
echo -e "${GREEN}[WAYLAND]${NC} sway selesai!"

# Install swaybg
cd /sources
tar -xf swaybg-1.2.1.tar.gz
cd swaybg-1.2.1
mkdir build && cd build
meson setup .. --prefix=/usr
ninja
ninja install

echo -e "${GREEN}[WAYLAND]${NC} Semua komponen Wayland selesai!"
WAYLAND_EOF
    
    chmod +x "${BUILD_DIR}/build_wayland.sh"
    
    sudo chroot "$LFS" /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        PS1='(saba-wayland) \u:\w\$ ' \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        /bin/bash /build/build_wayland.sh 2>&1 | tee "${LOGS_DIR}/wayland_build.log"
    
    log_success "Wayland & Sway selesai dibangun!"
}

# ============================================================================
# FASE 5: KONFIGURASI SISTEM
# ============================================================================

phase5_config() {
    log_section "FASE 5: KONFIGURASI SISTEM SABA OS"
    
    log_info "Membuat file konfigurasi sistem..."
    
    # /etc/os-release
    cat > "${LFS}/etc/os-release" << 'EOF'
NAME="Saba OS"
VERSION="1.0 (Sameko Saba)"
ID=sabaos
ID_LIKE=linuxfromscratch
PRETTY_NAME="Saba OS 1.0 🐟"
VERSION_ID="1.0"
HOME_URL="https://saba-os.org"
SUPPORT_URL="https://community.saba-os.org"
BUG_REPORT_URL="https://bugs.saba-os.org"
VERSION_CODENAME="sameko"
EOF
    
    # /etc/hostname
    echo "saba-os" > "${LFS}/etc/hostname"
    
    # /etc/fstab
    cat > "${LFS}/etc/fstab" << 'EOF'
# Begin /etc/fstab
/dev/sda1   /boot   vfat    defaults,noatime    0   2
/dev/sda2   /       ext4    defaults,noatime    0   1
/dev/sda3   swap    swap    pri=1               0   0
proc        /proc   proc    nosuid,noexec,nodev 0   0
sysfs       /sys    sysfs   nosuid,noexec,nodev 0   0
devpts      /dev/pts devpts gid=5,mode=620      0   0
tmpfs       /run    tmpfs   defaults            0   0
tmpfs       /tmp    tmpfs   defaults,nosuid,nodev 0 0
# End /etc/fstab
EOF
    
    # runit service directories
    sudo mkdir -pv "${LFS}/etc/runit"
    sudo mkdir -pv "${LFS}/etc/sv"
    sudo mkdir -pv "${LFS}/service"
    
    # runit stage 1
    cat > "${LFS}/etc/runit/1" << 'EOF'
#!/bin/sh
# Saba OS - Stage 1: System Initialization

PATH=/usr/bin:/usr/sbin:/bin:/sbin

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /tmp

# Create essential device nodes
[ -c /dev/null ] || mknod -m 666 /dev/null c 1 3
[ -c /dev/zero ] || mknod -m 666 /dev/zero c 1 5
[ -c /dev/random ] || mknod -m 666 /dev/random c 1 8
[ -c /dev/urandom ] || mknod -m 666 /dev/urandom c 1 9

# Load kernel modules
modprobe virtio_gpu 2>/dev/null || true
modprobe virtio_net 2>/dev/null || true
modprobe virtio_blk 2>/dev/null || true

# Setup networking
ip link set lo up

# Set hostname
hostname $(cat /etc/hostname 2>/dev/null || echo "saba-os")

echo "🐟 Saba OS initialized!"
EOF
    chmod +x "${LFS}/etc/runit/1"
    
    # runit stage 2
    cat > "${LFS}/etc/runit/2" << 'EOF'
#!/bin/sh
# Saba OS - Stage 2: Service Supervision

PATH=/usr/bin:/usr/sbin:/bin:/sbin

# Start service supervision
exec runsvdir /service 'log: ...........................................................................................................................................................................................................................................................................................................................................................................................................'
EOF
    chmod +x "${LFS}/etc/runit/2"
    
    # runit stage 3
    cat > "${LFS}/etc/runit/3" << 'EOF'
#!/bin/sh
# Saba OS - Stage 3: Shutdown

echo "🐟 Saba OS shutting down..."

# Stop all services
runsvctrl d /service/* 2>/dev/null || true
sleep 2

# Sync filesystems
sync

# Unmount filesystems
umount -a -r 2>/dev/null || true
EOF
    chmod +x "${LFS}/etc/runit/3"
    
    # Sway config
    sudo mkdir -pv "${LFS}/root/.config/sway"
    cat > "${LFS}/root/.config/sway/config" << 'EOF'
# Saba OS - Sway Configuration
# Tema: Fishy Ocean 🐟

# Font
font pango:monospace 10

# Wallpaper
output * bg /usr/share/backgrounds/saba/sameko_wallpaper.png fill

# Terminal
bindsym $mod+Return exec foot

# Launcher
bindsym $mod+d exec wmenu-run

# Kill window
bindsym $mod+Shift+q kill

# Reload config
bindsym $mod+Shift+c reload

# Exit
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit Sway?' -B 'Yes' 'swaymsg exit'

# Mod key
set $mod Mod4

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5

# Move to workspace
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3

# Split
bindsym $mod+b splith
bindsym $mod+v splitv

# Layout
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# Fullscreen
bindsym $mod+f fullscreen

# Floating
bindsym $mod+Shift+space floating toggle

# Focus
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Resize
mode "resize" {
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Status bar
bar {
    position top
    status_command while date +'%Y-%m-%d %H:%M:%S'; do sleep 1; done
    colors {
        statusline #00d4ff
        background #0a1628
        inactive_workspace #1a3a5c #0a1628 #5c7a99
        active_workspace #00d4ff #0a1628 #ffffff
    }
}

# Window decorations
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart

# Gaps
gaps inner 5
gaps outer 5

# Colors (Fishy Ocean Theme)
client.focused #00d4ff #0a1628 #ffffff #00d4ff #00d4ff
client.focused_inactive #1a3a5c #0a1628 #5c7a99 #1a3a5c #1a3a5c
client.unfocused #1a3a5c #0a1628 #5c7a99 #1a3a5c #1a3a5c

# Input
input * {
    xkb_layout us
    tap enabled
    natural_scroll enabled
}

# Output
output Virtual-1 resolution 2000x1200

# Idle
exec swayidle -w timeout 300 'swaylock -f -c 0a1628' timeout 600 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' before-sleep 'swaylock -f -c 0a1628'

# Polkit
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
EOF
    
    log_success "Konfigurasi sistem selesai!"
}

# ============================================================================
# FASE 6: BOOTLOADER
# ============================================================================

phase6_bootloader() {
    log_section "FASE 6: INSTALASI BOOTLOADER"
    
    log_info "Membuat initramfs..."
    
    cat > "${BUILD_DIR}/mkinitramfs.sh" << 'EOF'
#!/bin/bash
set -e

INITRAMFS_DIR=/tmp/initramfs
rm -rf $INITRAMFS_DIR
mkdir -p $INITRAMFS_DIR/{bin,sbin,etc,proc,sys,dev,run,tmp,lib,lib64,usr}

# Copy essential binaries
cp -v /bin/busybox $INITRAMFS_DIR/bin/
cp -v /bin/fish $INITRAMFS_DIR/bin/ 2>/dev/null || true
cp -v /sbin/runit-init $INITRAMFS_DIR/sbin/ 2>/dev/null || true

# Create symlinks for busybox
for applet in sh mount umount switch_root sleep echo cat; do
    ln -sfv busybox $INITRAMFS_DIR/bin/$applet
done

# Copy libraries
for lib in /lib/ld-musl*.so* /lib/libc.so; do
    cp -v $lib $INITRAMFS_DIR/lib/ 2>/dev/null || true
done

# Create init script
cat > $INITRAMFS_DIR/init << 'INITEOF'
#!/bin/sh
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t devtmpfs devtmpfs /dev
/bin/mount -t tmpfs tmpfs /run
/bin/mount -t tmpfs tmpfs /tmp

echo "🐟 Saba OS initramfs"
echo "Mounting root filesystem..."

# Wait for root device
sleep 1

# Mount root (adjust as needed)
/bin/mount -o ro /dev/sda2 /mnt 2>/dev/null || /bin/mount -o ro /dev/vda2 /mnt 2>/dev/null

# Switch to real root
exec /bin/switch_root /mnt /sbin/runit-init
INITEOF
chmod +x $INITRAMFS_DIR/init

# Create cpio archive
cd $INITRAMFS_DIR
find . | cpio -H newc -o | gzip -9 > /boot/initramfs-Fishix-1.0.5.img
echo "Initramfs created!"
EOF
    
    chmod +x "${BUILD_DIR}/mkinitramfs.sh"
    
    sudo chroot "$LFS" /bin/bash /build/mkinitramfs.sh 2>&1 | tee "${LOGS_DIR}/initramfs.log"
    
    log_info "Membuat skrip install bootloader..."
    
    cat > "${BUILD_DIR}/install_bootloader.sh" << 'EOF'
#!/bin/bash
# Install bootloader (EFISTUB atau GRUB)

if [ -d /sys/firmware/efi ]; then
    echo "Sistem UEFI terdeteksi, menggunakan EFISTUB..."
    
    # EFISTUB
    mkdir -p /boot/efi/EFI/SabaOS
    cp /boot/vmlinuz-Fishix-1.0.5 /boot/efi/EFI/SabaOS/
    cp /boot/initramfs-Fishix-1.0.5.img /boot/efi/EFI/SabaOS/
    
    # Create UEFI boot entry
    efibootmgr --create --disk /dev/sda --part 1 \
        --label "Saba OS 🐟" \
        --loader "\\EFI\\SabaOS\\vmlinuz-Fishix-1.0.5" \
        --unicode "initrd=\\EFI\\SabaOS\\initramfs-Fishix-1.0.5.img root=/dev/sda2 rw quiet" \
        --verbose
else
    echo "Sistem BIOS terdeteksi, menggunakan GRUB..."
    
    # Install GRUB
    grub-install --target=i386-pc /dev/sda
    
    # Create grub.cfg
    cat > /boot/grub/grub.cfg << 'GRUBEOF'
set timeout=5
set default=0

menuentry "Saba OS 🐟 (Fishix 1.0.5)" {
    linux /boot/vmlinuz-Fishix-1.0.5 root=/dev/sda2 rw quiet
    initrd /boot/initramfs-Fishix-1.0.5.img
}

menuentry "Saba OS (Recovery)" {
    linux /boot/vmlinuz-Fishix-1.0.5 root=/dev/sda2 rw single
    initrd /boot/initramfs-Fishix-1.0.5.img
}
GRUBEOF
fi

echo "Bootloader installed!"
EOF
    
    chmod +x "${BUILD_DIR}/install_bootloader.sh"
    
    log_success "Bootloader setup selesai!"
}

# ============================================================================
# MENU UTAMA
# ============================================================================

show_menu() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  🐟 ${MAGENTA}SABA OS BUILDER v1.0${NC} 🐟                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              Linux From Scratch 2026 - musl Edition           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Pilih fase build:${NC}"
    echo ""
    echo -e "  ${GREEN}0${NC}. Persiapan Sistem"
    echo -e "  ${GREEN}1${NC}. Build Cross-Toolchain (musl)"
    echo -e "  ${GREEN}2${NC}. Chroot & Sistem Dasar"
    echo -e "  ${GREEN}3${NC}. Kernel Fishix"
    echo -e "  ${GREEN}4${NC}. Wayland & Sway"
    echo -e "  ${GREEN}5${NC}. Konfigurasi Sistem"
    echo -e "  ${GREEN}6${NC}. Bootloader"
    echo ""
    echo -e "  ${YELLOW}a${NC}. Build All (Semua fase)"
    echo -e "  ${RED}q${NC}. Quit"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    while true; do
        show_menu
        read -p "Pilihan [0-6/a/q]: " choice
        
        case $choice in
            0) phase0_preparation ;;
            1) phase1_toolchain ;;
            2) phase2_chroot ;;
            3) phase3_kernel ;;
            4) phase4_wayland ;;
            5) phase5_config ;;
            6) phase6_bootloader ;;
            a|A)
                log_section "🚀 BUILD ALL - SABA OS"
                phase0_preparation
                phase1_toolchain
                phase2_chroot
                phase3_kernel
                phase4_wayland
                phase5_config
                phase6_bootloader
                log_section "🎉 SABA OS BUILD COMPLETE!"
                echo -e "${GREEN}Sistem siap di-boot!${NC}"
                echo -e "${BLUE}Lokasi: $LFS${NC}"
                ;;
            q|Q) 
                echo -e "${BLUE}🐟 Terima kasih telah menggunakan Saba OS Builder!${NC}"
                exit 0 
                ;;
            *) 
                log_error "Pilihan tidak valid!"
                ;;
        esac
        
        echo ""
        read -p "Tekan Enter untuk melanjutkan..."
    done
}

# Run main
main
