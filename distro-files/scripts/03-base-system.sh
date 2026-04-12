#!/bin/bash
# =============================================================================
# SABAOS - Base System Build Script
# =============================================================================
# Build sistem dasar dengan cross-compilation toolchain
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

# Toolchain
export CROSS_DIR="${SABAOS_BUILD}/tools/cross"
export SYSROOT="${SABAOS_ROOTFS}"
export PATH="${CROSS_DIR}/bin:${PATH}"

# Export cross-compile variables
export CC="${TARGET}-gcc"
export CXX="${TARGET}-g++"
export AR="${TARGET}-ar"
export AS="${TARGET}-as"
export LD="${TARGET}-ld"
export RANLIB="${TARGET}-ranlib"
export STRIP="${TARGET}-strip"

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

extract_archive() {
    local archive="$1"
    local dest="$2"
    
    log_info "Extracting: $(basename $archive)"
    
    case "$archive" in
        *.tar.xz)
            tar -xf "$archive" -C "$dest"
            ;;
        *.tar.gz)
            tar -xzf "$archive" -C "$dest"
            ;;
        *.tar.bz2)
            tar -xjf "$archive" -C "$dest"
            ;;
        *.tar)
            tar -xf "$archive" -C "$dest"
            ;;
        *)
            log_error "Unknown archive format: $archive"
            return 1
            ;;
    esac
}

# =============================================================================
# ROOTFS SETUP
# =============================================================================

setup_rootfs() {
    log_step "SETTING UP ROOTFS"
    
    # Create standard directories
    mkdir -p "${SYSROOT}"/{bin,sbin,lib,lib64,usr,etc,var,tmp,dev,proc,sys,run,boot,root,home,mnt,media}
    mkdir -p "${SYSROOT}/usr"/{bin,sbin,lib,lib64,include,share,local}
    mkdir -p "${SYSROOT}/var"/{log,cache,lib,run,spool,tmp}
    mkdir -p "${SYSROOT}/etc"/{init.d,rc.d,profile.d,skel}
    
    # Set permissions
    chmod 755 "${SYSROOT}"
    chmod 750 "${SYSROOT}/root"
    chmod 755 "${SYSROOT}/tmp"
    chmod 555 "${SYSROOT}/proc" 2>/dev/null || true
    chmod 555 "${SYSROOT}/sys" 2>/dev/null || true
    
    log_success "Rootfs directories created"
}

# =============================================================================
# BUILD PACKAGES
# =============================================================================

build_busybox() {
    log_step "BUILDING BUSYBOX ${BUSYBOX_VER}"
    
    local src_dir="${SABAOS_BUILD}/busybox-${BUSYBOX_VER}"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/busybox-${BUSYBOX_VER}.tar.bz2" "${SABAOS_BUILD}"
    fi
    
    cd "$src_dir"
    
    # Create minimal config
    make distclean 2>/dev/null || true
    make defconfig 2>&1 | tee "${SABAOS_TEMP}/logs/busybox-config.log"
    
    # Enable static build
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_FEATURE_SHARED_BUSYBOX=y/# CONFIG_FEATURE_SHARED_BUSYBOX is not set/' .config
    
    # Cross-compile settings
    make oldconfig 2>/dev/null || true
    
    # Build
    log_info "Building busybox..."
    make $MAKEFLAGS CROSS_COMPILE="${TARGET}-" 2>&1 | tee "${SABAOS_TEMP}/logs/busybox-build.log"
    
    # Install
    log_info "Installing busybox..."
    make CONFIG_PREFIX="${SYSROOT}" install 2>&1 | tee "${SABAOS_TEMP}/logs/busybox-install.log"
    
    log_success "Busybox built successfully"
}

build_coreutils() {
    log_step "BUILDING COREUTILS ${COREUTILS_VER}"
    
    local src_dir="${SABAOS_BUILD}/coreutils-${COREUTILS_VER}"
    local build_dir="${SABAOS_BUILD}/build-coreutils"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/coreutils-${COREUTILS_VER}.tar.xz" "${SABAOS_BUILD}"
    fi
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Configuring coreutils..."
    "$src_dir/configure" \
        --prefix=/usr \
        --host="$TARGET" \
        --build=$("$src_dir/build-aux/config.guess") \
        --enable-install-program=hostname \
        --enable-no-install-program=kill,uptime \
        --disable-nls \
        --disable-rpath \
        2>&1 | tee "${SABAOS_TEMP}/logs/coreutils-configure.log"
    
    log_info "Building coreutils..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/coreutils-build.log"
    
    log_info "Installing coreutils..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/coreutils-install.log"
    
    log_success "Coreutils built successfully"
}

build_bash() {
    log_step "BUILDING BASH ${BASH_VER}"
    
    local src_dir="${SABAOS_BUILD}/bash-${BASH_VER}"
    local build_dir="${SABAOS_BUILD}/build-bash"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/bash-${BASH_VER}.tar.gz" "${SABAOS_BUILD}"
    fi
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Configuring bash..."
    "$src_dir/configure" \
        --prefix=/usr \
        --host="$TARGET" \
        --build=$("$src_dir/support/config.guess") \
        --without-bash-malloc \
        --disable-nls \
        --enable-readline \
        2>&1 | tee "${SABAOS_TEMP}/logs/bash-configure.log"
    
    log_info "Building bash..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/bash-build.log"
    
    log_info "Installing bash..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/bash-install.log"
    
    # Create sh symlink
    ln -sf bash "${SYSROOT}/usr/bin/sh" 2>/dev/null || true
    
    log_success "Bash built successfully"
}

build_ncurses() {
    log_step "BUILDING NCURSES ${NCURSES_VER}"
    
    local src_dir="${SABAOS_BUILD}/ncurses-${NCURSES_VER}"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/ncurses-${NCURSES_VER}.tar.gz" "${SABAOS_BUILD}"
    fi
    
    cd "$src_dir"
    
    # Clean
    make distclean 2>/dev/null || true
    
    log_info "Configuring ncurses..."
    ./configure \
        --prefix=/usr \
        --host="$TARGET" \
        --build=$(./config.guess) \
        --with-shared \
        --without-debug \
        --without-ada \
        --disable-stripping \
        --enable-widec \
        2>&1 | tee "${SABAOS_TEMP}/logs/ncurses-configure.log"
    
    log_info "Building ncurses..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/ncurses-build.log"
    
    log_info "Installing ncurses..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/ncurses-install.log"
    
    # Create compatibility symlinks
    ln -sf libncursesw.so "${SYSROOT}/usr/lib/libncurses.so" 2>/dev/null || true
    
    log_success "Ncurses built successfully"
}

build_zlib() {
    log_step "BUILDING ZLIB ${ZLIB_VER}"
    
    local src_dir="${SABAOS_BUILD}/zlib-${ZLIB_VER}"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/zlib-${ZLIB_VER}.tar.gz" "${SABAOS_BUILD}"
    fi
    
    cd "$src_dir"
    
    # Clean
    make distclean 2>/dev/null || true
    
    log_info "Configuring zlib..."
    CHOST="$TARGET" \
    ./configure \
        --prefix=/usr \
        --shared \
        --static \
        2>&1 | tee "${SABAOS_TEMP}/logs/zlib-configure.log"
    
    log_info "Building zlib..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/zlib-build.log"
    
    log_info "Installing zlib..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/zlib-install.log"
    
    log_success "Zlib built successfully"
}

build_util_linux() {
    log_step "BUILDING UTIL-LINUX ${UTIL_LINUX_VER}"
    
    local src_dir="${SABAOS_BUILD}/util-linux-${UTIL_LINUX_VER}"
    local build_dir="${SABAOS_BUILD}/build-util-linux"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/util-linux-${UTIL_LINUX_VER}.tar.xz" "${SABAOS_BUILD}"
    fi
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Configuring util-linux..."
    "$src_dir/configure" \
        --prefix=/usr \
        --host="$TARGET" \
        --build=$("$src_dir/autotools/config.guess") \
        --disable-nls \
        --disable-chfn-chsh \
        --disable-login \
        --disable-nologin \
        --disable-su \
        --disable-setpriv \
        --disable-runuser \
        --disable-pylibmount \
        --disable-static \
        --without-python \
        --without-systemd \
        --without-systemdsystemunitdir \
        2>&1 | tee "${SABAOS_TEMP}/logs/util-linux-configure.log"
    
    log_info "Building util-linux..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/util-linux-build.log"
    
    log_info "Installing util-linux..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/util-linux-install.log"
    
    log_success "Util-linux built successfully"
}

build_e2fsprogs() {
    log_step "BUILDING E2FSPROGS ${E2FSPROGS_VER}"
    
    local src_dir="${SABAOS_BUILD}/e2fsprogs-${E2FSPROGS_VER}"
    local build_dir="${SABAOS_BUILD}/build-e2fsprogs"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/e2fsprogs-${E2FSPROGS_VER}.tar.gz" "${SABAOS_BUILD}"
    fi
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Configuring e2fsprogs..."
    "$src_dir/configure" \
        --prefix=/usr \
        --host="$TARGET" \
        --build=$("$src_dir/config.guess") \
        --disable-nls \
        --disable-rpath \
        --disable-fuse2fs \
        --disable-defrag \
        --disable-imager \
        --disable-resizer \
        --disable-debugfs \
        --disable-testio-debug \
        --disable-uuidd \
        2>&1 | tee "${SABAOS_TEMP}/logs/e2fsprogs-configure.log"
    
    log_info "Building e2fsprogs..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/e2fsprogs-build.log"
    
    log_info "Installing e2fsprogs..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/e2fsprogs-install.log"
    
    log_success "E2fsprogs built successfully"
}

build_shadow() {
    log_step "BUILDING SHADOW ${SHADOW_VER}"
    
    local src_dir="${SABAOS_BUILD}/shadow-${SHADOW_VER}"
    local build_dir="${SABAOS_BUILD}/build-shadow"
    
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/shadow-${SHADOW_VER}.tar.xz" "${SABAOS_BUILD}"
    fi
    
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    log_info "Configuring shadow..."
    "$src_dir/configure" \
        --prefix=/usr \
        --host="$TARGET" \
        --build=$("$src_dir/autotools/config.guess") \
        --disable-nls \
        --disable-man \
        --without-selinux \
        --without-acl \
        --without-attr \
        --without-tcb \
        --without-nscd \
        --without-group-name-max-length \
        2>&1 | tee "${SABAOS_TEMP}/logs/shadow-configure.log"
    
    log_info "Building shadow..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/shadow-build.log"
    
    log_info "Installing shadow..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/shadow-install.log"
    
    log_success "Shadow built successfully"
}

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================

setup_system_config() {
    log_step "SETTING UP SYSTEM CONFIGURATION"
    
    # /etc/passwd
    cat > "${SYSROOT}/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
    
    # /etc/group
    cat > "${SYSROOT}/etc/group" << 'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:36:
wheel:x:39:
nogroup:x:99:
users:x:999:
EOF
    
    # /etc/hosts
    cat > "${SYSROOT}/etc/hosts" << 'EOF'
127.0.0.1  localhost sabaos
::1        localhost
EOF
    
    # /etc/hostname
    echo "sabaos" > "${SYSROOT}/etc/hostname"
    
    # /etc/os-release
    cat > "${SYSROOT}/etc/os-release" << 'EOF'
NAME="SabaOS"
VERSION="2.0"
ID=sabaos
ID_LIKE=""
PRETTY_NAME="SabaOS 2.0 - Sameko Saba"
VERSION_ID="2.0"
HOME_URL="https://github.com/archanaberry/SabaOS"
SUPPORT_URL="https://github.com/archanaberry/SabaOS/issues"
BUG_REPORT_URL="https://github.com/archanaberry/SabaOS/issues"
EOF
    
    # /etc/profile
    cat > "${SYSROOT}/etc/profile" << 'EOF'
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PS1='\u@\h:\w\$ '
export HOME=/root
export TERM=linux
EOF
    
    # /etc/inittab (for init)
    cat > "${SYSROOT}/etc/inittab" << 'EOF'
id:3:initdefault:

si::sysinit:/etc/init.d/rcS

~:S:wait:/sbin/sulogin

l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/reboot

1:2345:respawn:/sbin/getty 38400 tty1
2:2345:respawn:/sbin/getty 38400 tty2
3:2345:respawn:/sbin/getty 38400 tty3
4:2345:respawn:/sbin/getty 38400 tty4
EOF
    
    # Create init script
    mkdir -p "${SYSROOT}/etc/init.d"
    cat > "${SYSROOT}/etc/init.d/rcS" << 'EOF'
#!/bin/sh
# System initialization

# Mount proc and sys
echo "Mounting filesystems..."
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /run

# Remount root as read-write
mount -o remount,rw /

# Create necessary device nodes
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts

# Load modules if available
if [ -f /etc/modules ]; then
    while read module; do
        modprobe "$module" 2>/dev/null || true
    done < /etc/modules
fi

# Set hostname
hostname -F /etc/hostname 2>/dev/null || hostname sabaos

# Configure loopback
ip link set lo up
ip addr add 127.0.0.1/8 dev lo

echo "System initialization complete."
EOF
    chmod +x "${SYSROOT}/etc/init.d/rcS"
    
    log_success "System configuration created"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_step "SABAOS - Base System Build"
    
    # Create logs directory
    mkdir -p "${SABAOS_TEMP}/logs"
    
    # Setup rootfs
    setup_rootfs
    
    # Build packages
    build_busybox
    build_zlib
    build_ncurses
    build_coreutils
    build_bash
    build_util_linux
    build_e2fsprogs
    build_shadow
    
    # Setup configuration
    setup_system_config
    
    log_step "BASE SYSTEM BUILD COMPLETE"
    log_info "Rootfs location: ${SYSROOT}"
    log_info "Size:"
    du -sh "${SYSROOT}" 2>/dev/null || echo "N/A"
    log_success "Base system is ready!"
}

main "$@"
