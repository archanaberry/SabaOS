#!/bin/bash
# ============================================================================
# SABA OS BUILD SCRIPT v2.0 - Fishix Kernel Edition
# Linux From Scratch 2026 - musl + runit + Wayland + Fishix Kernel
# Maskot: Sameko Saba 
# ============================================================================

set -euo pipefail  # Exit on error and fail on unset vars

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Konfigurasi
export SABA_VERSION="2.0"
export LFS=/mnt/saba_os
export SABA_TGT=$(uname -m)-saba-linux-musl
export MAKEFLAGS="-j$(nproc)"
export PATH="${LFS}/tools/bin:/bin:/usr/bin:/usr/sbin"

# Direktori
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FISHIX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"  # Parent directory (Fishix root)
FISHIX_KERNEL_DIR="${FISHIX_ROOT}/kernel"
FISHIX_BUILD_DIR="${FISHIX_KERNEL_DIR}/build"
FISHIX_DISTRO_FILES="${FISHIX_ROOT}/distro-files"

SOURCES_DIR="${HOME}/saba_os_sources"
BUILD_DIR="${LFS}/build"
LOGS_DIR="${BUILD_DIR}/logs"

# Source archive URLs for automatic download
declare -A SOURCE_URLS=(
    ["binutils-2.44.tar.xz"]="https://ftp.gnu.org/gnu/binutils/binutils-2.44.tar.xz"
    ["musl-1.2.5.tar.gz"]="https://musl.libc.org/releases/musl-1.2.5.tar.gz"
    ["gcc-14.2.0.tar.xz"]="https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz"
    ["busybox-1.36.1.tar.bz2"]="https://busybox.net/downloads/busybox-1.36.1.tar.bz2"
    ["coreutils-9.6.tar.xz"]="https://ftp.gnu.org/gnu/coreutils/coreutils-9.6.tar.xz"
    ["runit-2.1.2.tar.gz"]="http://smarden.org/runit/runit-2.1.2.tar.gz"
    ["fish-4.0.2.tar.xz"]="https://github.com/fish-shell/fish-shell/releases/download/4.0.2/fish-4.0.2.tar.xz"
    ["wayland-1.23.1.tar.xz"]="https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz"
    ["wayland-protocols-1.41.tar.xz"]="https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.41/downloads/wayland-protocols-1.41.tar.xz"
    ["wlroots-0.18.2.tar.gz"]="https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/0.18.2/downloads/wlroots-0.18.2.tar.gz"
    ["sway-1.10.1.tar.gz"]="https://github.com/swaywm/sway/releases/download/1.10.1/sway-1.10.1.tar.gz"
    ["swaybg-1.2.1.tar.gz"]="https://github.com/swaywm/swaybg/releases/download/v1.2.1/swaybg-1.2.1.tar.gz"
    ["libinput-1.27.1.tar.xz"]="https://gitlab.freedesktop.org/libinput/libinput/-/releases/1.27.1/downloads/libinput-1.27.1.tar.xz"
    ["libxkbcommon-1.8.1.tar.gz"]="https://github.com/xkbcommon/libxkbcommon/archive/xkbcommon-1.8.1.tar.gz"
    ["pixman-0.44.2.tar.gz"]="https://www.cairographics.org/releases/pixman-0.44.2.tar.gz"
    ["cairo-1.18.4.tar.xz"]="https://www.cairographics.org/releases/cairo-1.18.4.tar.xz"
    ["pango-1.56.3.tar.xz"]="https://download.gnome.org/sources/pango/1.56/pango-1.56.3.tar.xz"
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
    local url="${SOURCE_URLS[$filename]:-}"
    local dest="${SOURCES_DIR}/${filename}"

    if [ -f "$dest" ]; then
        log_info "File $filename sudah ada, melewati download"
        return 0
    fi

    if [ -z "$url" ]; then
        log_error "No download URL configured for $filename"
        return 1
    fi

    log_info "Downloading $filename from $url"
    mkdir -p "${SOURCES_DIR}"

    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar "$url" -o "$dest" || {
            log_error "Download failed for $filename"
            rm -f "$dest"
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget --progress=bar:force -O "$dest" "$url" || {
            log_error "Download failed for $filename"
            rm -f "$dest"
            return 1
        }
    else
        log_error "Neither curl nor wget is available for downloading sources"
        return 1
    fi

    if [ ! -f "$dest" ]; then
        log_error "Download failed for $filename"
        return 1
    fi
    
    log_success "Downloaded $filename successfully"
}

check_archive() {
    local archive_path="${SOURCES_DIR}/$1"
    if [ ! -f "$archive_path" ]; then
        log_warning "Source archive not found: $1"
        download_archive "$1" || return 1
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
        sudo mount -v -t "$fstype" -o "$opts" "$source" "$target" || true
    else
        sudo mount -v -t "$fstype" "$source" "$target" || true
    fi
}

# ============================================================================
# CHECK FISHIX KERNEL
# ============================================================================

check_fishix_kernel() {
    log_info "Checking Fishix kernel..."
    log_info "Fishix Root: $FISHIX_ROOT"
    log_info "Fishix Kernel Dir: $FISHIX_KERNEL_DIR"
    log_info "Fishix Build Dir: $FISHIX_BUILD_DIR"
    
    if [ ! -d "$FISHIX_KERNEL_DIR" ]; then
        log_error "Fishix kernel directory not found at $FISHIX_KERNEL_DIR!"
        log_info "Please ensure Fishix kernel is cloned/built at ../kernel"
        return 1
    fi
    
    # Check for built kernel
    if [ -f "${FISHIX_BUILD_DIR}/fishix" ]; then
        log_success "Found Fishix kernel: ${FISHIX_BUILD_DIR}/fishix"
        return 0
    elif [ -f "${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage" ]; then
        log_success "Found Fishix bzImage: ${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage"
        return 0
    else
        log_warning "Fishix kernel binary not found!"
        log_info "Please build Fishix kernel first by running 'make' in ${FISHIX_KERNEL_DIR}"
        return 1
    fi
}

# ============================================================================
# BUILD FISHIX KERNEL
# ============================================================================

build_fishix_kernel() {
    log_section "BUILDING FISHIX KERNEL"
    
    if [ ! -d "$FISHIX_KERNEL_DIR" ]; then
        log_error "Fishix kernel directory not found!"
        return 1
    fi
    
    cd "$FISHIX_KERNEL_DIR"
    
    log_info "Building Fishix kernel..."
    
    # Check if there's a Makefile in kernel directory
    if [ ! -f "Makefile" ]; then
        log_error "No Makefile found in $FISHIX_KERNEL_DIR"
        return 1
    fi
    
    # Build the kernel
    make clean 2>/dev/null || true
    make 2>&1 | tee "${LOGS_DIR}/fishix_build.log" || {
        log_error "Fishix kernel build failed!"
        return 1
    }
    
    log_success "Fishix kernel built successfully!"
}

# ============================================================================
# INSTALASI LINUX KERNEL HEADERS (untuk BusyBox)
# ============================================================================

install_kernel_headers() {
    log_info "Menginstal Fishix kernel headers untuk BusyBox compilation..."
    
    if [ ! -d "$FISHIX_KERNEL_DIR" ]; then
        log_error "Fishix kernel directory tidak ditemukan di: $FISHIX_KERNEL_DIR"
        log_error "Jalankan 'make kernel-selector' terlebih dahulu untuk download Fishix kernel"
        return 1
    fi
    
    # Prepare header installation directory
    log_info "Menyiapkan direktori header..."
    mkdir -pv "${KERNEL_HEADERS_INSTALL}"
    rm -rf "${KERNEL_HEADERS_INSTALL}"/{linux,uapi,asm,asm-generic} 2>/dev/null || true
    
    # Install headers from Fishix kernel
    log_info "Menyalin Fishix kernel headers..."
    
    if [ -d "$FISHIX_KERNEL_DIR/include" ]; then
        cp -r "$FISHIX_KERNEL_DIR/include/linux" "${KERNEL_HEADERS_INSTALL}/" 2>/dev/null || true
        cp -r "$FISHIX_KERNEL_DIR/include/uapi" "${KERNEL_HEADERS_INSTALL}/" 2>/dev/null || true
        cp -r "$FISHIX_KERNEL_DIR/include/asm-generic" "${KERNEL_HEADERS_INSTALL}/" 2>/dev/null || true
    fi
    
    # Try to copy architecture-specific headers
    if [ -d "$FISHIX_KERNEL_DIR/arch/x86/include/asm" ]; then
        mkdir -pv "${KERNEL_HEADERS_INSTALL}/asm"
        cp -r "$FISHIX_KERNEL_DIR/arch/x86/include/asm/"* "${KERNEL_HEADERS_INSTALL}/asm/" 2>/dev/null || true
    fi
    
    log_success "Fishix kernel headers berhasil diinstal"
}

# ============================================================================
# FASE 0: PERSIAPAN
# ============================================================================

phase0_preparation() {
    log_section "FASE 0: PERSIAPAN SISTEM"
    
    # Check Fishix kernel first
    if ! check_fishix_kernel; then
        log_warning "Fishix kernel not found. You can build it later in Phase 3."
    fi
    
    # Check prerequisites
    log_info "Memeriksa prerequisites..."
    
    local required_tools=("gcc" "g++" "make" "patch" "bison" "flex" "gzip" "xz")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warning "$tool tidak ditemukan, mungkin diperlukan"
        fi
    done
    
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
    sudo mkdir -pv "${LFS}/dev"
    sudo mkdir -pv "${LFS}/proc"
    sudo mkdir -pv "${LFS}/sys"
    sudo mkdir -pv "${LFS}/run"
    sudo mkdir -pv "${LFS}/tmp"
    
    log_info "Menyalin source code..."
    if [ -d "${SOURCES_DIR}" ]; then
        sudo cp -r "${SOURCES_DIR}"/* "${LFS}/sources/" 2>/dev/null || true
    else
        log_warning "Direktori sumber tidak ditemukan: ${SOURCES_DIR}"
        log_info "Mendownload sources yang diperlukan..."
        mkdir -p "${SOURCES_DIR}"
    fi
    
    # Download essential sources (sans Linux kernel - menggunakan Fishix)
    log_info "Mendownload sources esensial..."
    log_info "Catatan: Kernel menggunakan Fishix (bukan Linux kernel)"
    cd "${SOURCES_DIR}"
    download_archive "musl-1.2.5.tar.gz" || true
    download_archive "binutils-2.44.tar.xz" || true
    download_archive "gcc-14.2.0.tar.xz" || true
    download_archive "busybox-1.36.1.tar.bz2" || true
    download_archive "coreutils-9.6.tar.xz" || true
    download_archive "runit-2.1.2.tar.gz" || true
    
    # Copy to LFS sources
    sudo cp -r "${SOURCES_DIR}"/* "${LFS}/sources/" 2>/dev/null || true
    
    # Own directories
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
    install_kernel_headers || log_warning "Kernel headers installation had issues"
    
    log_success "Persiapan selesai!"
}

# ============================================================================
# FASE 1: TOOLCHAIN CROSS-COMPILATION (musl)
# ============================================================================

phase1_toolchain() {
    log_section "FASE 1: MEMBANGUN CROSS-TOOLCHAIN (musl)"
    
    cd "${LFS}/sources"
    
    # 1. Binutils - Cross
    log_info "[1/5] Membangun Binutils (cross)..."
    BINUTILS_AR="${LFS}/tools/bin/${SABA_TGT}-ar"
    if [ -f "${LOGS_DIR}/binutils_cross.done" ] && [ -x "${BINUTILS_AR}" ]; then
        log_warning "Binutils cross sudah dibangun, melewati..."
    else
        rm -f "${LOGS_DIR}/binutils_cross.done"
        if [ ! -d binutils-2.44 ]; then
            check_archive binutils-2.44.tar.xz || return 1
            tar -xf "${SOURCES_DIR}/binutils-2.44.tar.xz"
        fi
        rm -rf binutils-build
        mkdir -pv binutils-build && cd binutils-build
        ../binutils-2.44/configure \
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
    log_info "[2/5] Membangun GCC (cross, static)..."
    GCC_BIN="${LFS}/tools/bin/${SABA_TGT}-gcc"
    if [ -f "${LOGS_DIR}/gcc_cross.done" ] && [ -x "${GCC_BIN}" ]; then
        log_warning "GCC cross sudah dibangun, melewati..."
    else
        rm -f "${LOGS_DIR}/gcc_cross.done"
        if [ ! -d gcc-14.2.0 ]; then
            check_archive gcc-14.2.0.tar.xz || return 1
            tar -xf "${SOURCES_DIR}/gcc-14.2.0.tar.xz"
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
    log_info "[3/5] Menginstal musl libc headers..."
    if [ -f "${LOGS_DIR}/musl_headers.done" ] && [ -f "${LFS}/tools/include/stdio.h" ]; then
        log_warning "musl headers sudah diinstal, melewati..."
    else
        rm -f "${LOGS_DIR}/musl_headers.done"
        if [ ! -d musl-1.2.5 ]; then
            check_archive musl-1.2.5.tar.gz || return 1
            tar -xf "${SOURCES_DIR}/musl-1.2.5.tar.gz"
        fi
        cd musl-1.2.5
        ./configure --prefix="${LFS}/tools" --target="$SABA_TGT" 2>&1 | tee "${LOGS_DIR}/musl_headers_configure.log"
        make install-headers 2>&1 | tee "${LOGS_DIR}/musl_headers_install.log"
        touch "${LOGS_DIR}/musl_headers.done"
        cd ..
        log_success "musl headers selesai!"
    fi
    
    # 4. musl libc (Cross)
    log_info "[4/5] Membangun musl libc (cross)..."
    if [ -f "${LOGS_DIR}/musl_cross.done" ] && [ -f "${LFS}/tools/lib/libc.a" ]; then
        log_warning "musl libc cross sudah dibangun, melewati..."
    else
        rm -f "${LOGS_DIR}/musl_cross.done"
        cd musl-1.2.5
        make distclean 2>/dev/null || true
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
    fi
    
    # 5. Prepare BusyBox for chroot /tools/bin/env and /tools/bin/sh
    log_info "[5/5] Menyiapkan BusyBox statis untuk chroot (v1.36.1 - SabaOS Profile)..."
    if [ ! -f busybox-1.36.1/Makefile ]; then
        log_info "Extracting BusyBox 1.36.1 source..."
        rm -rf busybox-1.36.1 2>/dev/null || true
        check_archive busybox-1.36.1.tar.bz2 || return 1
        tar -xf "${SOURCES_DIR}/busybox-1.36.1.tar.bz2"
    fi
    
    if [ -f "${LOGS_DIR}/busybox_chroot.done" ] && [ -x "${LFS}/tools/bin/env" ] && [ -x "${LFS}/tools/bin/sh" ]; then
        log_warning "BusyBox chroot helper sudah ada, melewati..."
    else
        rm -f "${LOGS_DIR}/busybox_chroot.done"
        cd busybox-1.36.1
        make distclean 2>/dev/null || true
        make defconfig
        # Disable problematic features
        sed -i \
            -e 's/^CONFIG_STATIC=.*/CONFIG_STATIC=y/' \
            -e 's/^CONFIG_FEATURE_PREFER_APPLETS=.*/CONFIG_FEATURE_PREFER_APPLETS=y/' \
            -e 's/^CONFIG_BUSYBOX_EXEC_PATH=.*/CONFIG_BUSYBOX_EXEC_PATH="\/tools\/bin\/busybox"/' \
        -e 's/^CONFIG_STATIC=.*/CONFIG_STATIC=y/' \
        -e 's/^CONFIG_PIE=.*/CONFIG_PIE=y/' \
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
        make CROSS_COMPILE="${SABA_TGT}-" CONFIG_PREFIX="${LFS}/tools" install 2>&1 | tee "${LOGS_DIR}/busybox_chroot.log"
        cd ..
        
        ln -sfv busybox "${LFS}/tools/bin/sh"
        ln -sfv busybox "${LFS}/tools/bin/env"
        chmod +x "${LFS}/tools/bin/sh" "${LFS}/tools/bin/env"
        touch "${LOGS_DIR}/busybox_chroot.done"
        log_success "BusyBox statis untuk chroot selesai!"
    fi
    
    log_success "Cross-toolchain selesai dibangun!"
}

# ============================================================================
# FASE 2: CHROOT & SISTEM DASAR
# ============================================================================

phase2_chroot() {
    log_section "FASE 2: MEMASUKI CHROOT & BUILD SISTEM DASAR"
    
    log_info "Mount virtual filesystems..."
    mount_if_needed /dev "${LFS}/dev" none bind
    mount_if_needed proc "${LFS}/proc" proc
    mount_if_needed sysfs "${LFS}/sys" sysfs
    mount_if_needed tmpfs "${LFS}/run" tmpfs "nosuid,nodev,mode=755"
    mount_if_needed tmpfs "${LFS}/tmp" tmpfs "nosuid,nodev,mode=1777"
    
    # Create essential device nodes
    sudo mknod -m 666 "${LFS}/dev/null" c 1 3 2>/dev/null || true
    sudo mknod -m 666 "${LFS}/dev/zero" c 1 5 2>/dev/null || true
    sudo mknod -m 666 "${LFS}/dev/random" c 1 8 2>/dev/null || true
    sudo mknod -m 666 "${LFS}/dev/urandom" c 1 9 2>/dev/null || true
    sudo mknod -m 666 "${LFS}/dev/tty" c 5 0 2>/dev/null || true
    
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

# Copy Fishix kernel headers into chroot environment
echo -e "${BLUE}[CHROOT]${NC} Menyalin Fishix kernel headers..."
FISHIX_KERNEL_PATH="${FISHIX_ROOT}/kernel"
if [ -d "$FISHIX_KERNEL_PATH/include" ]; then
    mkdir -pv /usr/include
    rm -rf /usr/include/{linux,uapi,asm,asm-generic} 2>/dev/null || true
    cp -r "$FISHIX_KERNEL_PATH/include/linux" /usr/include/ 2>/dev/null || true
    cp -r "$FISHIX_KERNEL_PATH/include/uapi" /usr/include/ 2>/dev/null || true
    cp -r "$FISHIX_KERNEL_PATH/include/asm-generic" /usr/include/ 2>/dev/null || true
    if [ -d "$FISHIX_KERNEL_PATH/arch/x86/include/asm" ]; then
        mkdir -pv /usr/include/asm
        cp -r "$FISHIX_KERNEL_PATH/arch/x86/include/asm/"* /usr/include/asm/ 2>/dev/null || true
    fi
    echo -e "${GREEN}[CHROOT]${NC} Fishix kernel headers berhasil disalin!"
else
    echo -e "${YELLOW}[CHROOT]${NC} Fishix kernel headers tidak ditemukan, lanjutkan konfigurasi manualelf jika diperlukan"
fi

# Install musl libc final
echo -e "${BLUE}[CHROOT]${NC} Menginstal musl libc final..."
cd /sources
if [ -d musl-1.2.5 ]; then
    cd musl-1.2.5
    make distclean 2>/dev/null || true
    ./configure --prefix=/usr --disable-shared 2>&1 | tee /build/logs/musl_final_configure.log
    make 2>&1 | tee /build/logs/musl_final_make.log
    make install 2>&1 | tee /build/logs/musl_final_install.log
    echo -e "${GREEN}[CHROOT]${NC} musl libc final selesai!"
fi

# Install coreutils
echo -e "${BLUE}[CHROOT]${NC} Menginstal Coreutils..."
cd /sources
if [ -f coreutils-9.6.tar.xz ]; then
    tar -xf coreutils-9.6.tar.xz
    cd coreutils-9.6
    ./configure --prefix=/usr --enable-install-program=hostname --enable-no-install-program=kill,uptime 2>&1 | tee /build/logs/coreutils_configure.log
    make 2>&1 | tee /build/logs/coreutils_make.log
    make install 2>&1 | tee /build/logs/coreutils_install.log
    mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin 2>/dev/null || true
    mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin 2>/dev/null || true
    mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin 2>/dev/null || true
    mv -v /usr/bin/chroot /usr/sbin 2>/dev/null || true
    echo -e "${GREEN}[CHROOT]${NC} Coreutils selesai!"
fi

# Install BusyBox untuk utilitas tambahan
echo -e "${BLUE}[CHROOT]${NC} Menginstal BusyBox..."
cd /sources
if [ -f busybox-1.36.1.tar.bz2 ]; then
    tar -xf busybox-1.36.1.tar.bz2
    cd busybox-1.36.1
    make distclean 2>/dev/null || true
    make defconfig
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
        .config
    make CONFIG_PREFIX=/usr install 2>&1 | tee /build/logs/busybox_install.log
    echo -e "${GREEN}[CHROOT]${NC} BusyBox selesai!"
fi

# Install runit
echo -e "${BLUE}[CHROOT]${NC} Menginstal runit..."
cd /sources
if [ -f runit-2.1.2.tar.gz ]; then
    tar -xf runit-2.1.2.tar.gz
    cd admin/runit-2.1.2
    package/install 2>&1 | tee /build/logs/runit_install.log || true
    cd src
    make 2>&1 | tee /build/logs/runit_make.log
    cp -v runit runit-init runsv runsvdir sv svlogd chpst utmpset /sbin/ 2>/dev/null || true
    echo -e "${GREEN}[CHROOT]${NC} runit selesai!"
fi

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
        /tools/bin/sh /build/chroot_build.sh 2>&1 | tee "${LOGS_DIR}/chroot_build.log" || {
        log_warning "Chroot build had some issues, continuing..."
    }
    
    log_success "Chroot build selesai!"
}

# ============================================================================
# FASE 3: KERNEL FISHIX
# ============================================================================

phase3_kernel() {
    log_section "FASE 3: MENGIMPOR KERNEL FISHIX"
    
    log_info "Fishix Root Directory: $FISHIX_ROOT"
    log_info "Fishix Kernel Directory: $FISHIX_KERNEL_DIR"
    log_info "Fishix Build Directory: $FISHIX_BUILD_DIR"
    
    # Check if Fishix kernel exists
    if [ ! -d "$FISHIX_KERNEL_DIR" ]; then
        log_error "Fishix kernel directory not found at $FISHIX_KERNEL_DIR!"
        log_info "Please ensure you have Fishix kernel at ../kernel"
        log_info "You can clone it with: git clone https://github.com/archanaberry/Fishix ../kernel"
        return 1
    fi
    
    # Check for built kernel
    KERNEL_SRC=""
    KERNEL_NAME=""
    
    if [ -f "${FISHIX_BUILD_DIR}/fishix" ]; then
        KERNEL_SRC="${FISHIX_BUILD_DIR}/fishix"
        KERNEL_NAME="fishix"
        log_success "Found Fishix kernel binary: $KERNEL_SRC"
    elif [ -f "${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage" ]; then
        KERNEL_SRC="${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage"
        KERNEL_NAME="fishix"
        log_success "Found Fishix bzImage: $KERNEL_SRC"
    else
        log_warning "Fishix kernel binary not found!"
        log_info "Attempting to build Fishix kernel..."
        
        # Try to build Fishix kernel
        cd "$FISHIX_KERNEL_DIR"
        
        if [ ! -f "Makefile" ]; then
            log_error "No Makefile found in $FISHIX_KERNEL_DIR"
            log_error "Please ensure Fishix kernel is properly cloned"
            return 1
        fi
        
        log_info "Building Fishix kernel..."
        make clean 2>/dev/null || true
        make 2>&1 | tee "${LOGS_DIR}/fishix_build.log" || {
            log_error "Fishix kernel build failed!"
            return 1
        }
        
        # Check again after build
        if [ -f "${FISHIX_BUILD_DIR}/fishix" ]; then
            KERNEL_SRC="${FISHIX_BUILD_DIR}/fishix"
            KERNEL_NAME="fishix"
        elif [ -f "arch/x86/boot/bzImage" ]; then
            KERNEL_SRC="${FISHIX_KERNEL_DIR}/arch/x86/boot/bzImage"
            KERNEL_NAME="fishix"
        else
            log_error "Fishix kernel build did not produce expected output!"
            return 1
        fi
    fi
    
    log_info "Menyalin kernel Fishix ke sistem Saba OS..."
    
    # Copy kernel image
    cp -v "$KERNEL_SRC" "${LFS}/boot/${KERNEL_NAME}"
    
    # Copy System.map jika ada
    if [ -f "${FISHIX_KERNEL_DIR}/System.map" ]; then
        cp -v "${FISHIX_KERNEL_DIR}/System.map" "${LFS}/boot/System.map-fishix"
    elif [ -f "${FISHIX_BUILD_DIR}/System.map" ]; then
        cp -v "${FISHIX_BUILD_DIR}/System.map" "${LFS}/boot/System.map-fishix"
    fi
    
    # Copy config jika ada
    if [ -f "${FISHIX_KERNEL_DIR}/.config" ]; then
        cp -v "${FISHIX_KERNEL_DIR}/.config" "${LFS}/boot/config-fishix"
    fi
    
    # Copy modules jika sudah di-build
    if [ -d "${FISHIX_KERNEL_DIR}/modules" ]; then
        log_info "Menyalin kernel modules..."
        mkdir -pv "${LFS}/lib/modules"
        cp -rv "${FISHIX_KERNEL_DIR}/modules"/* "${LFS}/lib/modules/" 2>/dev/null || true
    fi
    
    # Copy firmware jika ada
    if [ -d "${FISHIX_KERNEL_DIR}/firmware" ]; then
        log_info "Menyalin firmware..."
        mkdir -pv "${LFS}/lib/firmware"
        cp -rv "${FISHIX_KERNEL_DIR}/firmware"/* "${LFS}/lib/firmware/" 2>/dev/null || true
    fi
    
    log_success "Kernel Fishix berhasil diimpor ke Saba OS!"
    log_info "Kernel: ${LFS}/boot/${KERNEL_NAME}"
}

# ============================================================================
# FASE 4: WAYLAND & SWAY (Simplified)
# ============================================================================

phase4_wayland() {
    log_section "FASE 4: MENGINSTAL WAYLAND & SWAY"
    
    log_info "Catatan: Wayland stack memerlukan banyak dependensi."
    log_info "Membuat konfigurasi dasar untuk Wayland..."
    
    # Create basic directories
    mkdir -pv "${LFS}/usr/share/wayland-sessions"
    mkdir -pv "${LFS}/usr/share/backgrounds/saba"
    
    # Create a simple session file
    cat > "${LFS}/usr/share/wayland-sessions/sway.desktop" << 'EOF'
[Desktop Entry]
Name=Sway
Comment=Sway Wayland compositor
Exec=/usr/bin/sway
Type=Application
EOF
    
    log_warning "Wayland stack lengkap memerlukan build manual dalam chroot"
    log_warning "dengan semua dependensi (meson, ninja, pkg-config, dll)"
    
    log_success "Konfigurasi Wayland dasar selesai!"
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
VERSION="2.0 (Sameko Saba)"
ID=sabaos
ID_LIKE=linuxfromscratch
PRETTY_NAME="Saba OS 2.0"
VERSION_ID="2.0"
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

echo "Saba OS initialized!"
EOF
    chmod +x "${LFS}/etc/runit/1"
    
    # runit stage 2
    cat > "${LFS}/etc/runit/2" << 'EOF'
#!/bin/sh
# Saba OS - Stage 2: Service Supervision

PATH=/usr/bin:/usr/sbin:/bin:/sbin

# Start service supervision
exec runsvdir /service 'log: .......................................................................................................................................................................................................'
EOF
    chmod +x "${LFS}/etc/runit/2"
    
    # runit stage 3
    cat > "${LFS}/etc/runit/3" << 'EOF'
#!/bin/sh
# Saba OS - Stage 3: Shutdown

echo "Saba OS shutting down..."

# Stop all services
runsvctrl d /service/* 2>/dev/null || true
sleep 2

# Sync filesystems
sync

# Unmount filesystems
umount -a -r 2>/dev/null || true
EOF
    chmod +x "${LFS}/etc/runit/3"
    
    # Create getty service
    mkdir -pv "${LFS}/etc/sv/getty-tty1"
    cat > "${LFS}/etc/sv/getty-tty1/run" << 'EOF'
#!/bin/sh
exec /sbin/getty 38400 tty1
EOF
    chmod +x "${LFS}/etc/sv/getty-tty1/run"
    
    ln -sv "${LFS}/etc/sv/getty-tty1" "${LFS}/service/" 2>/dev/null || true
    
    # Create /sbin/init symlink to runit
    ln -sfv /etc/runit/2 "${LFS}/sbin/init" 2>/dev/null || true
    
    log_success "Konfigurasi sistem selesai!"
}

# ============================================================================
# FASE 6: BOOTLOADER & INITRAMFS
# ============================================================================

phase6_bootloader() {
    log_section "FASE 6: INSTALASI BOOTLOADER & INITRAMFS"
    
    log_info "Membuat initramfs..."
    
    cat > "${BUILD_DIR}/mkinitramfs.sh" << 'EOF'
#!/bin/bash
set -e

INITRAMFS_DIR=/tmp/initramfs
rm -rf $INITRAMFS_DIR
mkdir -p $INITRAMFS_DIR/{bin,sbin,etc,proc,sys,dev,run,tmp,lib,lib64,usr,newroot}

# Copy essential binaries
if [ -f /bin/busybox ]; then
    cp -v /bin/busybox $INITRAMFS_DIR/bin/
else
    cp -v /tools/bin/busybox $INITRAMFS_DIR/bin/ 2>/dev/null || echo "BusyBox not found"
fi

# Create symlinks for busybox
for applet in sh mount umount switch_root sleep echo cat mkdir mknod; do
    ln -sfv busybox $INITRAMFS_DIR/bin/$applet 2>/dev/null || true
done

# Copy libraries
for lib in /lib/ld-musl*.so* /lib/libc.so* /tools/lib/ld-musl*.so* /tools/lib/libc.so*; do
    if [ -f "$lib" ]; then
        cp -v "$lib" $INITRAMFS_DIR/lib/ 2>/dev/null || true
    fi
done

# Create init script
cat > $INITRAMFS_DIR/init << 'INITEOF'
#!/bin/sh
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t devtmpfs devtmpfs /dev
/bin/mount -t tmpfs tmpfs /run
/bin/mount -t tmpfs tmpfs /tmp

echo "Saba OS initramfs"
echo "Mounting root filesystem..."

# Wait for root device
sleep 1

# Try to mount root filesystem
for device in /dev/sda2 /dev/vda2 /dev/nvme0n1p2 /dev/hda2; do
    if [ -b "$device" ]; then
        echo "Trying to mount $device..."
        if /bin/mount -o ro "$device" /newroot 2>/dev/null; then
            echo "Root filesystem mounted on $device"
            break
        fi
    fi
done

# Check if root is mounted
if [ -d /newroot/bin ] || [ -d /newroot/sbin ]; then
    echo "Switching to real root..."
    exec /bin/switch_root /newroot /sbin/init
else
    echo "Failed to mount root filesystem!"
    echo "Dropping to emergency shell..."
    /bin/sh
fi
INITEOF
chmod +x $INITRAMFS_DIR/init

# Create cpio archive
cd $INITRAMFS_DIR
find . | cpio -H newc -o | gzip -9 > /boot/initramfs-sabaos.img
echo "Initramfs created at /boot/initramfs-sabaos.img"
ls -lh /boot/initramfs-sabaos.img
EOF
    
    chmod +x "${BUILD_DIR}/mkinitramfs.sh"
    
    # Run initramfs creation in chroot
    sudo chroot "$LFS" /tools/bin/env -i \
        HOME=/root \
        PATH=/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin \
        /tools/bin/sh /build/mkinitramfs.sh 2>&1 | tee "${LOGS_DIR}/initramfs.log" || {
        log_warning "Initramfs creation had issues"
    }
    
    log_info "Membuat konfigurasi bootloader..."
    
    # Create bootloader config for limine
    mkdir -pv "${LFS}/boot/limine"
    
    cat > "${LFS}/boot/limine/limine.conf" << 'EOF'
TIMEOUT=5
DEFAULT_ENTRY=1

:Saba OS (Fishix)
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw quiet

:Saba OS (Fishix Recovery)
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw single

:Saba OS (Fishix Debug)
    PROTOCOL=linux
    KERNEL_PATH=boot:///boot/fishix
    MODULE_PATH=boot:///boot/initramfs-sabaos.img
    CMDLINE=root=/dev/sda2 rw debug
EOF
    
    log_success "Bootloader setup selesai!"
    log_info "Untuk menginstall bootloader, gunakan:"
    log_info "  limine bios-install /dev/sda  (untuk BIOS)"
    log_info "  atau copy EFI files untuk UEFI"
}

# ============================================================================
# MENU UTAMA
# ============================================================================

show_menu() {
    echo ""
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${CYAN}||${NC}              ${MAGENTA}SABA OS BUILDER v2.0${NC} - Fishix Edition       ${CYAN}||${NC}"
    echo -e "${CYAN}||${NC}              Linux From Scratch - musl + Fishix           ${CYAN}||${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo ""
    echo -e "${BLUE}Pilih fase build:${NC}"
    echo ""
    echo -e "  ${GREEN}0${NC}. Persiapan Sistem"
    echo -e "  ${GREEN}1${NC}. Build Cross-Toolchain (musl)"
    echo -e "  ${GREEN}2${NC}. Chroot & Sistem Dasar"
    echo -e "  ${GREEN}3${NC}. Build/Import Kernel Fishix"
    echo -e "  ${GREEN}4${NC}. Wayland & Sway (Basic)"
    echo -e "  ${GREEN}5${NC}. Konfigurasi Sistem"
    echo -e "  ${GREEN}6${NC}. Bootloader & Initramfs"
    echo ""
    echo -e "  ${YELLOW}a${NC}. Build All (Semua fase)"
    echo -e "  ${YELLOW}k${NC}. Build Fishix Kernel Only"
    echo -e "  ${RED}q${NC}. Quit"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_warning "Script ini sebaiknya dijalankan dengan sudo untuk beberapa operasi"
        log_warning "Beberapa fase mungkin gagal tanpa akses root"
    fi
    
    # Show Fishix info
    log_info "Saba OS Builder v2.0 - Fishix Edition"
    log_info "Fishix Root: $FISHIX_ROOT"
    log_info "Fishix Kernel Dir: $FISHIX_KERNEL_DIR"
    
    while true; do
        show_menu
        read -p "Pilihan [0-6/a/k/q]: " choice
        
        case $choice in
            0) phase0_preparation ;;
            1) phase1_toolchain ;;
            2) phase2_chroot ;;
            3) phase3_kernel ;;
            4) phase4_wayland ;;
            5) phase5_config ;;
            6) phase6_bootloader ;;
            a|A)
                log_section "BUILD ALL - SABA OS (Fishix Edition)"
                phase0_preparation
                phase1_toolchain
                phase2_chroot
                phase3_kernel
                phase4_wayland
                phase5_config
                phase6_bootloader
                log_section "SABA OS BUILD COMPLETE!"
                echo -e "${GREEN}Sistem siap di-boot!${NC}"
                echo -e "${BLUE}Lokasi: $LFS${NC}"
                echo -e "${BLUE}Kernel: ${LFS}/boot/fishix${NC}"
                echo -e "${BLUE}Initramfs: ${LFS}/boot/initramfs-sabaos.img${NC}"
                ;;
            k|K)
                log_section "BUILD FISHIX KERNEL ONLY"
                build_fishix_kernel
                ;;
            q|Q) 
                echo -e "${BLUE}Terima kasih telah menggunakan Saba OS Builder!${NC}"
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
