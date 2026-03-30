#!/bin/bash
# ============================================================================
# SABA OS BUILD SCRIPT v1.0
# Linux From Scratch 2026 - musl + runit + Wayland
# Maskot: Sameko Saba 🐟
# ============================================================================

set -euo pipefail  # Exit on error and fail on unset vars
set -o pipefail

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
export PATH="${LFS}/tools/bin:/bin:/usr/bin"

# Direktori
export FISHIX_ROOT="$(cd .. && pwd)"  # Parent directory from  build script
export KERNEL_DIR="${FISHIX_ROOT}/kernel"

SOURCES_DIR="${HOME}/saba_os_sources"
BUILD_DIR="${LFS}/build"
LOGS_DIR="${BUILD_DIR}/logs"

# Source archive URLs for automatic download
declare -A SOURCE_URLS=(
    ["binutils-2.46.0.tar.xz"]="https://ftp.gnu.org/gnu/binutils/binutils-2.46.0.tar.xz"
    ["musl-1.2.6.tar.gz"]="https://musl.libc.org/releases/musl-1.2.6.tar.gz"
    ["gcc-14.2.0.tar.xz"]="https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz"
    ["busybox-1.37.0.tar.bz2"]="https://busybox.net/downloads/busybox-1.37.0.tar.bz2"
    ["linux-6.8.tar.xz"]="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"
)

# Kernel headers path
export KERNEL_HEADERS_INSTALL="${LFS}/usr/include"

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

download_archive() {
    local filename="$1"
    local url="${SOURCE_URLS[$filename]}"
    local dest="${SOURCES_DIR}/${filename}"

    if [ -f "$dest" ]; then
        return 0
    fi

    if [ -z "$url" ]; then
        log_error "No download URL configured for $filename"
        exit 1
    fi

    log_info "Downloading $filename from $url"
    mkdir -p "${SOURCES_DIR}"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$dest" "$url"
    else
        log_error "Neither curl nor wget is available for downloading sources"
        exit 1
    fi

    if [ ! -f "$dest" ]; then
        log_error "Download failed for $filename"
        exit 1
    fi
}

check_archive() {
    local archive_path="${SOURCES_DIR}/$1"
    if [ ! -f "$archive_path" ]; then
        log_warning "Source archive not found: $1"
        download_archive "$1"
    fi
}

log_section() {
    echo -e "\n${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}========================================${NC}\n"
}

is_mounted() {
    local target="$1"
    if mountpoint -q "$target" 2>/dev/null; then
        return 0
    fi
    grep -qs "[[:space:]]${target}[[:space:]]" /proc/mounts 2>/dev/null
}

mount_if_needed() {
    local source="$1"
    local target="$2"
    local fstype="$3"
    local opts="${4:-}"

    if is_mounted "$target"; then
        log_warning "$target already mounted, skipping..."
        return 0
    fi

    if [ -n "$opts" ]; then
        sudo mount -v -t "$fstype" -o "$opts" "$source" "$target"
    else
        sudo mount -v -t "$fstype" "$source" "$target"
    fi
}

# ============================================================================
# INSTALASI LINUX KERNEL HEADERS
# ============================================================================

install_kernel_headers() {
    log_info "Menginstal Linux kernel headers untuk BusyBox compilation..."
    
    if [ ! -d "${LFS}/sources/linux-6.8" ]; then
        log_info "Mengekstrak Linux kernel headers..."
        cd "${LFS}/sources"
        check_archive linux-6.8.tar.xz
        tar -xf linux-6.8.tar.xz || {
            log_error "Gagal mengekstrak linux-6.8.tar.xz"
            return 1
        }
    fi
    
    cd "${LFS}/sources/linux-6.8"
    
    # Clean and prepare header installation directory
    log_info "Menyiapkan direktori header..."
    mkdir -pv "${KERNEL_HEADERS_INSTALL}"
    rm -rf "${KERNEL_HEADERS_INSTALL}"/{linux,uapi,asm,asm-generic} 2>/dev/null || true
    
    # Install headers comprehensively
    log_info "Menyalin kernel headers ke ${KERNEL_HEADERS_INSTALL}..."
    
    # Copy all generic headers
    cp -r include/linux "${KERNEL_HEADERS_INSTALL}/" || true
    cp -r include/uapi "${KERNEL_HEADERS_INSTALL}/" || true
    cp -r include/asm-generic "${KERNEL_HEADERS_INSTALL}/" || true
    
    # Copy x86-specific headers
    mkdir -pv "${KERNEL_HEADERS_INSTALL}/asm"
    cp -r arch/x86/include/asm/* "${KERNEL_HEADERS_INSTALL}/asm/" 2>/dev/null || true
    
    # Copy asm/types.h from ARM (x86 doesn't have its own, but ARM's works for generic arch)
    if [ -f "arch/arm/include/uapi/asm/types.h" ]; then
        cp arch/arm/include/uapi/asm/types.h "${KERNEL_HEADERS_INSTALL}/asm/" 2>/dev/null || true
    fi
    
    # Create symlinks for headers that are in asm but referenced from linux
    cd "${KERNEL_HEADERS_INSTALL}/linux"
    ln -sf ../asm/posix_types.h posix_types.h 2>/dev/null || true
    ln -sf ../asm/posix_types_32.h posix_types_32.h 2>/dev/null || true
    ln -sf ../asm/posix_types_64.h posix_types_64.h 2>/dev/null || true
    ln -sf ../asm/posix_types_x32.h posix_types_x32.h 2>/dev/null || true
    
    log_success "Linux kernel headers berhasil diinstal!"
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
    if [ -d "${SOURCES_DIR}" ]; then
        sudo cp -r "${SOURCES_DIR}"/* "${LFS}/sources/" 2>/dev/null || true
    else
        log_warning "Direktori sumber tidak ditemukan: ${SOURCES_DIR}"
    fi

    # Own only the build directories and source directories, not mounted pseudo-filesystems.
    sudo chown -R $USER:$USER "${LFS}/sources" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/tools" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/build" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/boot" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/etc" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/bin" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/sbin" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/lib" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/lib64" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/usr" 2>/dev/null || true
    sudo chown -R $USER:$USER "${LFS}/var" 2>/dev/null || true

    # Install Linux kernel headers for BusyBox compilation
    install_kernel_headers

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
    BINUTILS_AR="${LFS}/tools/bin/${SABA_TGT}-ar"
    if [ -f "${LOGS_DIR}/binutils_cross.done" ] && [ -x "${BINUTILS_AR}" ]; then
        log_warning "Binutils cross sudah dibangun, melewati..."
    else
        if [ -f "${LOGS_DIR}/binutils_cross.done" ] && [ ! -x "${BINUTILS_AR}" ]; then
            log_warning "Binutils marker ada tetapi ${BINUTILS_AR} tidak ditemukan. Membangun ulang binutils..."
            rm -f "${LOGS_DIR}/binutils_cross.done"
        fi
        if [ ! -d binutils-2.46.0 ]; then
            check_archive binutils-2.46.0.tar.xz
            tar -xf "${SOURCES_DIR}/binutils-2.46.0.tar.xz"
        else
            log_warning "Binutils source already extracted"
        fi
        if [ ! -d binutils-2.46 ] && [ -d binutils-2.46.0 ]; then
            ln -s binutils-2.46.0 binutils-2.46
        fi
        rm -rf binutils-build
        mkdir -pv binutils-build && cd binutils-build
        ../binutils-2.46/configure \
            --prefix="${LFS}/tools" \
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
    fi
    
    # 2. GCC - Cross Compiler (Static)
    log_info "[2/4] Membangun GCC (cross, static)..."
    GCC_BIN="${LFS}/tools/bin/${SABA_TGT}-gcc"
    if [ -f "${LOGS_DIR}/gcc_cross.done" ]; then
        if [ ! -x "${GCC_BIN}" ]; then
            log_warning "GCC marker ada tetapi ${GCC_BIN} tidak ditemukan. Membangun ulang GCC..."
            rm -f "${LOGS_DIR}/gcc_cross.done"
        elif ! printf '#include <byteswap.h>\n' | "${GCC_BIN}" -E -xc - -o /dev/null >/dev/null 2>&1; then
            log_warning "GCC marker ada tetapi compiler tidak dapat menemukan musl headers. Membangun ulang GCC..."
            rm -f "${LOGS_DIR}/gcc_cross.done"
        fi
    fi
    if [ -f "${LOGS_DIR}/gcc_cross.done" ] && [ -x "${GCC_BIN}" ]; then
        log_warning "GCC cross sudah dibangun, melewati..."
    else
        if [ ! -d gcc-14.2.0 ]; then
            check_archive gcc-14.2.0.tar.xz
            tar -xf "${SOURCES_DIR}/gcc-14.2.0.tar.xz"
        else
            log_warning "GCC source already extracted"
        fi
        cd gcc-14.2.0
        ./contrib/download_prerequisites 2>/dev/null || log_warning "Prerequisites mungkin sudah ada"
        cd ..
        rm -rf gcc-build
        mkdir -pv gcc-build && cd gcc-build
        ../gcc-14.2.0/configure \
            --prefix="${LFS}/tools" \
            --target="$SABA_TGT" \
            --with-sysroot="$LFS" \
            --with-newlib \
            --without-headers \
            --with-local-prefix="/tools" \
            --with-native-system-header-dir="/tools/include" \
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
    fi
    
    # 3. musl libc headers
    log_info "[3/4] Menginstal musl libc headers..."
    if [ -f "${LOGS_DIR}/musl_headers.done" ] && [ ! -f "${LFS}/tools/include/byteswap.h" ]; then
        log_warning "Stale musl headers marker found but /tools/include/byteswap.h missing. Rebuilding musl headers..."
        rm -f "${LOGS_DIR}/musl_headers.done"
        rm -rf musl-1.2.6
    fi
    if [ ! -f "${LOGS_DIR}/musl_headers.done" ]; then
        if [ ! -d musl-1.2.6 ]; then
            check_archive musl-1.2.6.tar.gz
            tar -xf "${SOURCES_DIR}/musl-1.2.6.tar.gz"
        else
            log_warning "musl source already extracted"
        fi
        cd musl-1.2.6
        ./configure --prefix="${LFS}/tools" --target="$SABA_TGT" 2>&1 | tee "${LOGS_DIR}/musl_headers_configure.log"
        make install-headers 2>&1 | tee "${LOGS_DIR}/musl_headers_install.log"
        touch "${LOGS_DIR}/musl_headers.done"
        cd ..
        log_success "musl headers selesai!"
    else
        log_warning "musl headers sudah diinstal, melewati..."
    fi
    
    # 4. musl libc (Cross)
    log_info "[4/4] Membangun musl libc (cross)..."
    if [ -f "${LOGS_DIR}/musl_cross.done" ] && [ ! -f "${LFS}/tools/lib/libc.a" ]; then
        log_warning "Stale musl libc marker found but /tools/lib/libc.a missing. Rebuilding musl libc..."
        rm -f "${LOGS_DIR}/musl_cross.done"
    fi
    if [ ! -f "${LOGS_DIR}/musl_cross.done" ]; then
        cd musl-1.2.6
        CC="${SABA_TGT}-gcc" \
        CXX="${SABA_TGT}-g++" \
        AR="${SABA_TGT}-ar" \
        RANLIB="${SABA_TGT}-ranlib" \
        ./configure \
            --prefix="${LFS}/tools" \
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

    # 5. Prepare BusyBox for chroot /tools/bin/env and /tools/bin/sh
    log_info "[5/5] Menyiapkan BusyBox statis untuk chroot..."
    # Check if BusyBox needs extraction (check for Makefile to ensure complete extraction)
    if [ ! -f busybox-1.37.0/Makefile ]; then
        log_info "Extracting BusyBox source..."
        rm -rf busybox-1.37.0 2>/dev/null || true
        check_archive busybox-1.37.0.tar.bz2
        tar -xf "${SOURCES_DIR}/busybox-1.37.0.tar.bz2"
    else
        log_warning "BusyBox source already extracted"
    fi

    if [ -f "${LOGS_DIR}/busybox_chroot.done" ]; then
        cd busybox-1.37.0
        if [ ! -x "${LFS}/tools/bin/env" ] || [ ! -x "${LFS}/tools/bin/sh" ] || \
           grep -qE '^CONFIG_LOADFONT=y|^CONFIG_DESKTOP=y|^CONFIG_CONSOLE_TOOLS=y' .config 2>/dev/null; then
            log_warning "Stale BusyBox helper detected; rebuilding BusyBox helper..."
            rm -f "${LOGS_DIR}/busybox_chroot.done"
        fi
        cd ..
    fi

    if [ ! -f "${LOGS_DIR}/busybox_chroot.done" ]; then
        cd busybox-1.37.0
        make distclean || true
        make defconfig
        sed -i \
            -e 's/^CONFIG_STATIC=y/CONFIG_STATIC=y/' \
            -e 's/^CONFIG_OPENVT=y/# CONFIG_OPENVT is not set/' \
            -e 's/^CONFIG_CHVT=y/# CONFIG_CHVT is not set/' \
            -e 's/^CONFIG_DEALLOCVT=y/# CONFIG_DEALLOCVT is not set/' \
            -e 's/^CONFIG_FGCONSOLE=y/# CONFIG_FGCONSOLE is not set/' \
            -e 's/^CONFIG_LOADFONT=y/# CONFIG_LOADFONT is not set/' \
            -e 's/^CONFIG_SETFONT=y/# CONFIG_SETFONT is not set/' \
            -e 's/^CONFIG_KBD_MODE=y/# CONFIG_KBD_MODE is not set/' \
            -e 's/^CONFIG_SHOWKEY=y/# CONFIG_SHOWKEY is not set/' \
            -e 's/^CONFIG_DUMPKMAP=y/# CONFIG_DUMPKMAP is not set/' \
            -e 's/^CONFIG_SETLOGCONS=y/# CONFIG_SETLOGCONS is not set/' \
            -e 's/^CONFIG_HDPARM=y/# CONFIG_HDPARM is not set/' \
            -e 's/^CONFIG_FEATURE_LOADFONT_PSF2=y/# CONFIG_FEATURE_LOADFONT_PSF2 is not set/' \
            -e 's/^CONFIG_FEATURE_LOADFONT_RAW=y/# CONFIG_FEATURE_LOADFONT_RAW is not set/' \
            .config
        make CROSS_COMPILE="${SABA_TGT}-" CONFIG_PREFIX="${LFS}/tools" CFLAGS="-I${KERNEL_HEADERS_INSTALL}" install
        cd ..

        ln -sfv busybox "${LFS}/tools/bin/sh"
        ln -sfv busybox "${LFS}/tools/bin/env"
        chmod +x "${LFS}/tools/bin/sh" "${LFS}/tools/bin/env"
        touch "${LOGS_DIR}/busybox_chroot.done"
        log_success "BusyBox statis untuk chroot selesai!"
    else
        log_warning "BusyBox chroot helper sudah ada, melewati..."
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
    mount_if_needed /dev "${LFS}/dev" none bind
    mount_if_needed proc "${LFS}/proc" proc
    mount_if_needed sysfs "${LFS}/sys" sysfs
    mount_if_needed tmpfs "${LFS}/run" tmpfs
    mount_if_needed tmpfs "${LFS}/tmp" tmpfs
    
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

# Copy Linux kernel headers into chroot environment
echo -e "${BLUE}[CHROOT]${NC} Menyalin Linux kernel headers..."
if [ -d /sources/linux-6.8 ]; then
    mkdir -pv /usr/include
    rm -rf /usr/include/{linux,uapi,asm,asm-generic} 2>/dev/null || true
    # Copy all generic headers
    cp -r /sources/linux-6.8/include/linux /usr/include/ || true
    cp -r /sources/linux-6.8/include/uapi /usr/include/ || true
    cp -r /sources/linux-6.8/include/asm-generic /usr/include/ || true
    # Copy x86-specific headers
    mkdir -pv /usr/include/asm
    cp -r /sources/linux-6.8/arch/x86/include/asm/* /usr/include/asm/ 2>/dev/null || true
    # Copy asm/types.h from ARM (x86 doesn't have its own types.h)
    if [ -f /sources/linux-6.8/arch/arm/include/uapi/asm/types.h ]; then
        cp /sources/linux-6.8/arch/arm/include/uapi/asm/types.h /usr/include/asm/ 2>/dev/null || true
    fi
    # Create symlinks for headers that are in asm but referenced from linux
    cd /usr/include/linux
    ln -sf ../asm/posix_types.h posix_types.h 2>/dev/null || true
    ln -sf ../asm/posix_types_32.h posix_types_32.h 2>/dev/null || true
    ln -sf ../asm/posix_types_64.h posix_types_64.h 2>/dev/null || true
    ln -sf ../asm/posix_types_x32.h posix_types_x32.h 2>/dev/null || true
fi

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
# Check if we need to extract (look for Makefile)
if [ ! -f busybox-1.37.0/Makefile ]; then
    rm -rf busybox-1.37.0 2>/dev/null || true
    tar -xf busybox-1.37.0.tar.bz2
fi
cd busybox-1.37.0
make distclean || true
make defconfig
        # Disable console tools that need kernel headers
        sed -i \
            -e 's/^CONFIG_OPENVT=y/# CONFIG_OPENVT is not set/' \
            -e 's/^CONFIG_CHVT=y/# CONFIG_CHVT is not set/' \
            -e 's/^CONFIG_DEALLOCVT=y/# CONFIG_DEALLOCVT is not set/' \
            -e 's/^CONFIG_FGCONSOLE=y/# CONFIG_FGCONSOLE is not set/' \
            -e 's/^CONFIG_LOADFONT=y/# CONFIG_LOADFONT is not set/' \
            -e 's/^CONFIG_SETFONT=y/# CONFIG_SETFONT is not set/' \
            -e 's/^CONFIG_KBD_MODE=y/# CONFIG_KBD_MODE is not set/' \
            -e 's/^CONFIG_SHOWKEY=y/# CONFIG_SHOWKEY is not set/' \
            -e 's/^CONFIG_DUMPKMAP=y/# CONFIG_DUMPKMAP is not set/' \
            -e 's/^CONFIG_SETLOGCONS=y/# CONFIG_SETLOGCONS is not set/' \
            -e 's/^CONFIG_HDPARM=y/# CONFIG_HDPARM is not set/' \
            -e 's/^CONFIG_FEATURE_LOADFONT_PSF2=y/# CONFIG_FEATURE_LOADFONT_PSF2 is not set/' \
            -e 's/^CONFIG_FEATURE_LOADFONT_RAW=y/# CONFIG_FEATURE_LOADFONT_RAW is not set/' \
            .config
        make CFLAGS="-I/usr/include" CONFIG_PREFIX=/usr install

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
        PATH=/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin \
        SABA_TGT="$SABA_TGT" \
        /tools/bin/sh /build/chroot_build.sh 2>&1 | tee "${LOGS_DIR}/chroot_build.log"
    
    log_success "Chroot build selesai!"
}

# ============================================================================
# FASE 3: KERNEL FISHIX
# ============================================================================

phase3_kernel() {
    log_section "FASE 3: MENGIMPOR KERNEL FISHIX"
    
    FISHIX_KERNEL_DIR="${FISHIX_ROOT}/kernel"
    FISHIX_BUILD_DIR="${FISHIX_KERNEL_DIR}/build"
    KERNEL_BOOT_NAME="fishix"
    KERNEL_SRC=""

    log_info "Mengecek hasil build Fishix..."

    if [ -x "${FISHIX_BUILD_DIR}/fishix" ]; then
        KERNEL_SRC="${FISHIX_BUILD_DIR}/fishix"
        KERNEL_BOOT_NAME="fishix"
    elif [ -f "${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage" ]; then
        KERNEL_SRC="${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage"
        KERNEL_BOOT_NAME="vmlinuz-Fishix-1.0.5"
    else
        if [ ! -d "${FISHIX_KERNEL_DIR}" ]; then
            log_error "Kernel Fishix tidak ditemukan di ${FISHIX_KERNEL_DIR}!"
            log_error "Jalankan 'make import-kernel' terlebih dahulu!"
        else
            log_error "Kernel Fishix belum dibuild!"
            log_error "Build kernel Fishix terlebih dahulu di ${FISHIX_KERNEL_DIR}"
        fi
        exit 1
    fi

    log_info "Menyalin kernel Fishix ke sistem Saba OS..."

    # Copy kernel image
    cp -v "${KERNEL_SRC}" "${LFS}/boot/${KERNEL_BOOT_NAME}"
    
    # Copy System.map jika ada
    if [ -f "${FISHIX_KERNEL_DIR}/System.map" ]; then
        cp -v "${FISHIX_KERNEL_DIR}/System.map" \
              "${LFS}/boot/System.map-Fishix-1.0.5"
    fi
    
    # Copy config jika ada
    if [ -f "${FISHIX_KERNEL_DIR}/.config" ]; then
        cp -v "${FISHIX_KERNEL_DIR}/.config" \
              "${LFS}/boot/config-Fishix-1.0.5"
    fi
    
    # Copy modules jika sudah di-build
    if [ -d "${FISHIX_KERNEL_DIR}/modules" ]; then
        log_info "Menyalin kernel modules..."
        cp -rv "${FISHIX_KERNEL_DIR}/modules"/* \
               "${LFS}/lib/modules/" 2>/dev/null || true
    fi
    
    # Copy firmware jika ada
    if [ -d "${FISHIX_KERNEL_DIR}/firmware" ]; then
        log_info "Menyalin firmware..."
        cp -rv "${FISHIX_KERNEL_DIR}/firmware"/* \
               "${LFS}/lib/firmware/" 2>/dev/null || true
    fi
    
    log_success "Kernel Fishix berhasil diimpor ke Saba OS!"
    log_info "Kernel: ${LFS}/boot/${KERNEL_BOOT_NAME}"
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
    cp /boot/fishix /boot/efi/EFI/SabaOS/
    cp /boot/initramfs-Fishix-1.0.5.img /boot/efi/EFI/SabaOS/
    
    # Create UEFI boot entry
    efibootmgr --create --disk /dev/sda --part 1 \
        --label "Saba OS 🐟" \
        --loader "\\EFI\\SabaOS\\fishix" \
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
    linux /boot/fishix root=/dev/sda2 rw quiet
    initrd /boot/initramfs-Fishix-1.0.5.img
}

menuentry "Saba OS (Recovery)" {
    linux /boot/fishix root=/dev/sda2 rw single
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
