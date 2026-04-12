#!/bin/bash
# =============================================================================
# SABAOS - Source Download Script
# =============================================================================
# Download semua source code untuk build SabaOS
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../versions.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# =============================================================================
# DOWNLOAD FUNCTION
# =============================================================================

download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    TOTAL=$((TOTAL + 1))
    
    if [ -f "${output}" ]; then
        log_warn "Already exists: $(basename ${output})"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi
    
    log_info "Downloading: ${description}"
    echo "       URL: ${url}"
    
    if wget --timeout=300 --connect-timeout=30 --tries=3 --show-progress -O "${output}.tmp" "${url}" 2>&1; then
        mv "${output}.tmp" "${output}"
        log_success "Downloaded: ${description}"
        SUCCESS=$((SUCCESS + 1))
        return 0
    else
        rm -f "${output}.tmp"
        log_error "Failed: ${description}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# =============================================================================
# URL BUILDERS
# =============================================================================

build_urls() {
    # Core Toolchain
    BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VER}.tar.gz"
    GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz"
    MUSL_URL="https://musl.libc.org/releases/musl-${MUSL_VER}.tar.gz"
    
    # GCC Prerequisites
    GMP_URL="https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VER}.tar.xz"
    MPFR_URL="https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VER}.tar.xz"
    MPC_URL="https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VER}.tar.gz"
    
    # Init & Bootloader
    DINIT_URL="https://github.com/davmac314/dinit/archive/refs/tags/v${DINIT_VER}.tar.gz"
    LIMINE_URL="https://github.com/limine-bootloader/limine/releases/download/v${LIMINE_VER}/limine-${LIMINE_VER}.tar.xz"
    
    # Core Utilities
    COREUTILS_URL="https://ftp.gnu.org/gnu/coreutils/coreutils-${COREUTILS_VER}.tar.xz"
    BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VER}.tar.bz2"
    BASH_URL="https://ftp.gnu.org/gnu/bash/bash-${BASH_VER}.tar.gz"
    SUDO_URL="https://www.sudo.ws/dist/sudo-${SUDO_VER}.tar.gz"
    
    # Filesystem
    E2FSPROGS_URL="https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v${E2FSPROGS_VER}/e2fsprogs-${E2FSPROGS_VER}.tar.gz"
    UTIL_LINUX_URL="https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v${UTIL_LINUX_VER}/util-linux-${UTIL_LINUX_VER}.tar.xz"
    
    # Networking
    DROPBEAR_URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VER}.tar.bz2"
    IPROUTE2_URL="https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-${IPROUTE2_VER}.tar.xz"
    IANA_ETC_URL="https://github.com/Mic92/iana-etc/releases/download/${IANA_ETC_VER}/iana-etc-${IANA_ETC_VER}.tar.gz"
    OPENSSH_URL="https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VER}.tar.gz"
    DHCPCD_URL="https://github.com/NetworkConfiguration/dhcpcd/releases/download/v${DHCPCD_VER}/dhcpcd-${DHCPCD_VER}.tar.xz"
    WPA_SUPPLICANT_URL="https://w1.fi/releases/wpa_supplicant-${WPA_SUPPLICANT_VER}.tar.gz"
    IW_URL="https://mirrors.edge.kernel.org/pub/software/network/iw/iw-${IW_VER}.tar.xz"
    
    # Libraries
    ZLIB_URL="https://zlib.net/fossils/zlib-${ZLIB_VER}.tar.gz"
    NCURSES_URL="https://invisible-island.net/archives/ncurses/ncurses-${NCURSES_VER}.tar.gz"
    OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz"
    
    # Editors
    VIM_URL="https://github.com/vim/vim/archive/refs/tags/v${VIM_VER}.tar.gz"
    NANO_URL="https://www.nano-editor.org/dist/latest/nano-${NANO_VER}.tar.xz"
    
    # System Utils
    SHADOW_URL="https://github.com/shadow-maint/shadow/releases/download/${SHADOW_VER}/shadow-${SHADOW_VER}.tar.xz"
    GREP_URL="https://ftp.gnu.org/gnu/grep/grep-${GREP_VER}.tar.xz"
    GZIP_URL="https://ftp.gnu.org/gnu/gzip/gzip-${GZIP_VER}.tar.xz"
    SED_URL="https://ftp.gnu.org/gnu/sed/sed-${SED_VER}.tar.xz"
    TAR_URL="https://ftp.gnu.org/gnu/tar/tar-${TAR_VER}.tar.xz"
    XZ_URL="https://github.com/tukaani-project/xz/releases/download/v${XZ_VER}/xz-${XZ_VER}.tar.xz"
    
    # Build Tools
    MAKE_URL="https://ftp.gnu.org/gnu/make/make-${MAKE_VER}.tar.gz"
    PKGCONF_URL="https://distfiles.ariadne.space/pkgconf/pkgconf-${PKGCONF_VER}.tar.xz"
    
    # Misc
    KMOD_URL="https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-${KMOD_VER}.tar.xz"
    KBD_URL="https://www.kernel.org/pub/linux/utils/kbd/kbd-${KBD_VER}.tar.xz"
    
    # Bootable Image Tools
    XORRISO_URL="https://www.gnu.org/software/xorriso/xorriso-${XORRISO_VER}.tar.gz"
    DOSFSTOOLS_URL="https://github.com/dosfstools/dosfstools/releases/download/v${DOSFSTOOLS_VER}/dosfstools-${DOSFSTOOLS_VER}.tar.gz"
    MTOOLS_URL="https://ftp.gnu.org/gnu/mtools/mtools-${MTOOLS_VER}.tar.gz"
    CPIO_URL="https://ftp.gnu.org/gnu/cpio/cpio-${CPIO_VER}.tar.gz"
    SQUASHFS_TOOLS_URL="https://github.com/plougher/squashfs-tools/releases/download/${SQUASHFS_TOOLS_VER}/squashfs-tools-${SQUASHFS_TOOLS_VER}.tar.gz"
    
    # Dev Toolchain
    AUTOCONF_URL="https://ftp.gnu.org/gnu/autoconf/autoconf-${AUTOCONF_VER}.tar.xz"
    AUTOMAKE_URL="https://ftp.gnu.org/gnu/automake/automake-${AUTOMAKE_VER}.tar.xz"
    LIBTOOL_URL="https://ftp.gnu.org/gnu/libtool/libtool-${LIBTOOL_VER}.tar.xz"
    M4_URL="https://ftp.gnu.org/gnu/m4/m4-${M4_VER}.tar.xz"
    BISON_URL="https://ftp.gnu.org/gnu/bison/bison-${BISON_VER}.tar.xz"
    FLEX_URL="https://github.com/westes/flex/releases/download/v${FLEX_VER}/flex-${FLEX_VER}.tar.gz"
    GAWK_URL="https://ftp.gnu.org/gnu/gawk/gawk-${GAWK_VER}.tar.xz"
    DIFFUTILS_URL="https://ftp.gnu.org/gnu/diffutils/diffutils-${DIFFUTILS_VER}.tar.xz"
    FINDUTILS_URL="https://ftp.gnu.org/gnu/findutils/findutils-${FINDUTILS_VER}.tar.xz"
    FILE_URL="https://astron.com/pub/file/file-${FILE_VER}.tar.gz"
    PATCH_URL="https://ftp.gnu.org/gnu/patch/patch-${PATCH_VER}.tar.xz"
    TEXINFO_URL="https://ftp.gnu.org/gnu/texinfo/texinfo-${TEXINFO_VER}.tar.xz"
    GETTEXT_URL="https://ftp.gnu.org/gnu/gettext/gettext-${GETTEXT_VER}.tar.xz"
    PERL_URL="https://www.cpan.org/src/5.0/perl-${PERL_VER}.tar.gz"
    PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"
    MESON_URL="https://github.com/mesonbuild/meson/releases/download/${MESON_VER}/meson-${MESON_VER}.tar.gz"
    NINJA_URL="https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VER}.tar.gz"
    CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz"
    GIT_URL="https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VER}.tar.xz"
    CURL_URL="https://curl.se/download/curl-${CURL_VER}.tar.xz"
    WGET_URL="https://ftp.gnu.org/gnu/wget/wget-${WGET_VER}.tar.gz"
    RSYNC_URL="https://download.samba.org/pub/rsync/rsync-${RSYNC_VER}.tar.gz"
    
    # Wayland/Graphics
    WAYLAND_URL="https://gitlab.freedesktop.org/wayland/wayland/-/releases/${WAYLAND_VER}/downloads/wayland-${WAYLAND_VER}.tar.xz"
    WAYLAND_PROTOCOLS_URL="https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/${WAYLAND_PROTOCOLS_VER}/downloads/wayland-protocols-${WAYLAND_PROTOCOLS_VER}.tar.xz"
    XORGPROTO_URL="https://xorg.freedesktop.org/archive/individual/proto/xorgproto-${XORGPROTO_VER}.tar.xz"
    LIBDRM_URL="https://gitlab.freedesktop.org/mesa/drm/-/archive/libdrm-${LIBDRM_VER}/drm-libdrm-${LIBDRM_VER}.tar.gz"
    LIBEVDEV_URL="https://www.freedesktop.org/software/libevdev/libevdev-${LIBEVDEV_VER}.tar.xz"
    LIBINPUT_URL="https://gitlab.freedesktop.org/libinput/libinput/-/archive/${LIBINPUT_VER}/libinput-${LIBINPUT_VER}.tar.bz2"
    LIBXKBCOMMON_URL="https://gitlab.freedesktop.org/xkbcommon/libxkbcommon/-/archive/${LIBXKBCOMMON_VER}/libxkbcommon-${LIBXKBCOMMON_VER}.tar.gz"
    SEATD_URL="https://git.sr.ht/~kennylevinsen/seatd/archive/${SEATD_VER}.tar.gz"
    PIXMAN_URL="https://cairographics.org/releases/pixman-${PIXMAN_VER}.tar.gz"
    CAIRO_URL="https://cairographics.org/releases/cairo-${CAIRO_VER}.tar.xz"
    PANGO_URL="https://download.gnome.org/sources/pango/${PANGO_VER%.*}/pango-${PANGO_VER}.tar.xz"
    HARFBUZZ_URL="https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VER}/harfbuzz-${HARFBUZZ_VER}.tar.xz"
    FREETYPE_URL="https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VER}.tar.xz"
    FONTCONFIG_URL="https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VER}.tar.xz"
    MESA_URL="https://archive.mesa3d.org/mesa-${MESA_VER}.tar.xz"
    LIBEPOXY_URL="https://download.gnome.org/sources/libepoxy/${LIBEPOXY_VER%.*}/libepoxy-${LIBEPOXY_VER}.tar.xz"
    WLROOTS_URL="https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/${WLROOTS_VER}/downloads/wlroots-${WLROOTS_VER}.tar.gz"
    WESTON_URL="https://gitlab.freedesktop.org/wayland/weston/-/releases/${WESTON_VER}/downloads/weston-${WESTON_VER}.tar.gz"
    SWAY_URL="https://github.com/swaywm/sway/releases/download/${SWAY_VER}/sway-${SWAY_VER}.tar.gz"
    XWAYLAND_URL="https://xorg.freedesktop.org/archive/individual/xserver/xwayland-${XWAYLAND_VER}.tar.xz"
    
    # Network/System Base
    CA_CERTIFICATES_URL="https://gitlab.archlinux.org/archlinux/packaging/packages/ca-certificates/-/archive/${CA_CERTIFICATES_VER}/ca-certificates-${CA_CERTIFICATES_VER}.tar.gz"
    TZDATA_URL="https://data.iana.org/time-zones/releases/tzdata${TZDATA_VER}.tar.gz"
    DBUS_URL="https://dbus.freedesktop.org/releases/dbus/dbus-${DBUS_VER}.tar.xz"
    EUDEV_URL="https://github.com/eudev-project/eudev/releases/download/v${EUDEV_VER}/eudev-${EUDEV_VER}.tar.gz"
    LIBCAP_URL="https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-${LIBCAP_VER}.tar.xz"
    ZSTD_URL="https://github.com/facebook/zstd/releases/download/v${ZSTD_VER}/zstd-${ZSTD_VER}.tar.gz"
    EXPAT_URL="https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VER//./_}/expat-${EXPAT_VER}.tar.xz"
    LIBARCHIVE_URL="https://libarchive.org/downloads/libarchive-${LIBARCHIVE_VER}.tar.xz"
    SQLITE_URL="https://sqlite.org/2025/sqlite-autoconf-${SQLITE_VER}.tar.gz"
    
    # Userland Extras
    FISH_URL="https://github.com/fish-shell/fish-shell/releases/download/${FISH_VER}/fish-${FISH_VER}.tar.xz"
    KITTY_URL="https://github.com/kovidgoyal/kitty/releases/download/v${KITTY_VER}/kitty-${KITTY_VER}.tar.xz"
    TMUX_URL="https://github.com/tmux/tmux/releases/download/${TMUX_VER}/tmux-${TMUX_VER}.tar.gz"
    
    # Additional Libraries
    LIBPNG_URL="https://download.sourceforge.net/libpng/libpng-${LIBPNG_VER}.tar.xz"
    LIBJPEG_TURBO_URL="https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VER}/libjpeg-turbo-${LIBJPEG_TURBO_VER}.tar.gz"
    LIBWEBP_URL="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${LIBWEBP_VER}.tar.gz"
}

# =============================================================================
# DOWNLOAD ALL
# =============================================================================

download_all() {
    log_info "Creating sources directory: ${SABAOS_SOURCES}"
    mkdir -p "${SABAOS_SOURCES}"
    
    build_urls
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING CORE TOOLCHAIN${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$BINUTILS_URL" "${SABAOS_SOURCES}/binutils-${BINUTILS_VER}.tar.xz" "binutils ${BINUTILS_VER}"
    download_file "$GCC_URL" "${SABAOS_SOURCES}/gcc-${GCC_VER}.tar.xz" "gcc ${GCC_VER}"
    download_file "$MUSL_URL" "${SABAOS_SOURCES}/musl-${MUSL_VER}.tar.gz" "musl ${MUSL_VER}"
    download_file "$GMP_URL" "${SABAOS_SOURCES}/gmp-${GMP_VER}.tar.xz" "gmp ${GMP_VER}"
    download_file "$MPFR_URL" "${SABAOS_SOURCES}/mpfr-${MPFR_VER}.tar.xz" "mpfr ${MPFR_VER}"
    download_file "$MPC_URL" "${SABAOS_SOURCES}/mpc-${MPC_VER}.tar.gz" "mpc ${MPC_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING INIT & BOOTLOADER${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$DINIT_URL" "${SABAOS_SOURCES}/dinit-${DINIT_VER}.tar.gz" "dinit ${DINIT_VER}"
    download_file "$LIMINE_URL" "${SABAOS_SOURCES}/limine-${LIMINE_VER}.tar.xz" "limine ${LIMINE_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING CORE UTILITIES${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$COREUTILS_URL" "${SABAOS_SOURCES}/coreutils-${COREUTILS_VER}.tar.xz" "coreutils ${COREUTILS_VER}"
    download_file "$BUSYBOX_URL" "${SABAOS_SOURCES}/busybox-${BUSYBOX_VER}.tar.bz2" "busybox ${BUSYBOX_VER}"
    download_file "$BASH_URL" "${SABAOS_SOURCES}/bash-${BASH_VER}.tar.gz" "bash ${BASH_VER}"
    download_file "$SUDO_URL" "${SABAOS_SOURCES}/sudo-${SUDO_VER}.tar.gz" "sudo ${SUDO_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING FILESYSTEM TOOLS${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$E2FSPROGS_URL" "${SABAOS_SOURCES}/e2fsprogs-${E2FSPROGS_VER}.tar.gz" "e2fsprogs ${E2FSPROGS_VER}"
    download_file "$UTIL_LINUX_URL" "${SABAOS_SOURCES}/util-linux-${UTIL_LINUX_VER}.tar.xz" "util-linux ${UTIL_LINUX_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING NETWORKING${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$DROPBEAR_URL" "${SABAOS_SOURCES}/dropbear-${DROPBEAR_VER}.tar.bz2" "dropbear ${DROPBEAR_VER}"
    download_file "$IPROUTE2_URL" "${SABAOS_SOURCES}/iproute2-${IPROUTE2_VER}.tar.xz" "iproute2 ${IPROUTE2_VER}"
    download_file "$IANA_ETC_URL" "${SABAOS_SOURCES}/iana-etc-${IANA_ETC_VER}.tar.gz" "iana-etc ${IANA_ETC_VER}"
    download_file "$OPENSSH_URL" "${SABAOS_SOURCES}/openssh-${OPENSSH_VER}.tar.gz" "openssh ${OPENSSH_VER}"
    download_file "$DHCPCD_URL" "${SABAOS_SOURCES}/dhcpcd-${DHCPCD_VER}.tar.xz" "dhcpcd ${DHCPCD_VER}"
    download_file "$WPA_SUPPLICANT_URL" "${SABAOS_SOURCES}/wpa_supplicant-${WPA_SUPPLICANT_VER}.tar.gz" "wpa_supplicant ${WPA_SUPPLICANT_VER}"
    download_file "$IW_URL" "${SABAOS_SOURCES}/iw-${IW_VER}.tar.xz" "iw ${IW_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING LIBRARIES${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$ZLIB_URL" "${SABAOS_SOURCES}/zlib-${ZLIB_VER}.tar.gz" "zlib ${ZLIB_VER}"
    download_file "$NCURSES_URL" "${SABAOS_SOURCES}/ncurses-${NCURSES_VER}.tar.gz" "ncurses ${NCURSES_VER}"
    download_file "$OPENSSL_URL" "${SABAOS_SOURCES}/openssl-${OPENSSL_VER}.tar.gz" "openssl ${OPENSSL_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING EDITORS${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$VIM_URL" "${SABAOS_SOURCES}/vim-${VIM_VER}.tar.gz" "vim ${VIM_VER}"
    download_file "$NANO_URL" "${SABAOS_SOURCES}/nano-${NANO_VER}.tar.xz" "nano ${NANO_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING SYSTEM UTILITIES${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$SHADOW_URL" "${SABAOS_SOURCES}/shadow-${SHADOW_VER}.tar.xz" "shadow ${SHADOW_VER}"
    download_file "$GREP_URL" "${SABAOS_SOURCES}/grep-${GREP_VER}.tar.xz" "grep ${GREP_VER}"
    download_file "$GZIP_URL" "${SABAOS_SOURCES}/gzip-${GZIP_VER}.tar.xz" "gzip ${GZIP_VER}"
    download_file "$SED_URL" "${SABAOS_SOURCES}/sed-${SED_VER}.tar.xz" "sed ${SED_VER}"
    download_file "$TAR_URL" "${SABAOS_SOURCES}/tar-${TAR_VER}.tar.xz" "tar ${TAR_VER}"
    download_file "$XZ_URL" "${SABAOS_SOURCES}/xz-${XZ_VER}.tar.xz" "xz ${XZ_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING BUILD TOOLS${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$MAKE_URL" "${SABAOS_SOURCES}/make-${MAKE_VER}.tar.gz" "make ${MAKE_VER}"
    download_file "$PKGCONF_URL" "${SABAOS_SOURCES}/pkgconf-${PKGCONF_VER}.tar.xz" "pkgconf ${PKGCONF_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING BOOTABLE IMAGE TOOLS${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$XORRISO_URL" "${SABAOS_SOURCES}/xorriso-${XORRISO_VER}.tar.gz" "xorriso ${XORRISO_VER}"
    download_file "$DOSFSTOOLS_URL" "${SABAOS_SOURCES}/dosfstools-${DOSFSTOOLS_VER}.tar.gz" "dosfstools ${DOSFSTOOLS_VER}"
    download_file "$MTOOLS_URL" "${SABAOS_SOURCES}/mtools-${MTOOLS_VER}.tar.gz" "mtools ${MTOOLS_VER}"
    download_file "$CPIO_URL" "${SABAOS_SOURCES}/cpio-${CPIO_VER}.tar.gz" "cpio ${CPIO_VER}"
    download_file "$SQUASHFS_TOOLS_URL" "${SABAOS_SOURCES}/squashfs-tools-${SQUASHFS_TOOLS_VER}.tar.gz" "squashfs-tools ${SQUASHFS_TOOLS_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING WAYLAND/GRAPHICS${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$WAYLAND_URL" "${SABAOS_SOURCES}/wayland-${WAYLAND_VER}.tar.xz" "wayland ${WAYLAND_VER}"
    download_file "$WAYLAND_PROTOCOLS_URL" "${SABAOS_SOURCES}/wayland-protocols-${WAYLAND_PROTOCOLS_VER}.tar.xz" "wayland-protocols ${WAYLAND_PROTOCOLS_VER}"
    download_file "$LIBDRM_URL" "${SABAOS_SOURCES}/drm-libdrm-${LIBDRM_VER}.tar.gz" "libdrm ${LIBDRM_VER}"
    download_file "$LIBINPUT_URL" "${SABAOS_SOURCES}/libinput-${LIBINPUT_VER}.tar.bz2" "libinput ${LIBINPUT_VER}"
    download_file "$LIBXKBCOMMON_URL" "${SABAOS_SOURCES}/libxkbcommon-${LIBXKBCOMMON_VER}.tar.gz" "libxkbcommon ${LIBXKBCOMMON_VER}"
    download_file "$SEATD_URL" "${SABAOS_SOURCES}/seatd-${SEATD_VER}.tar.gz" "seatd ${SEATD_VER}"
    download_file "$PIXMAN_URL" "${SABAOS_SOURCES}/pixman-${PIXMAN_VER}.tar.gz" "pixman ${PIXMAN_VER}"
    download_file "$CAIRO_URL" "${SABAOS_SOURCES}/cairo-${CAIRO_VER}.tar.xz" "cairo ${CAIRO_VER}"
    download_file "$PANGO_URL" "${SABAOS_SOURCES}/pango-${PANGO_VER}.tar.xz" "pango ${PANGO_VER}"
    download_file "$HARFBUZZ_URL" "${SABAOS_SOURCES}/harfbuzz-${HARFBUZZ_VER}.tar.xz" "harfbuzz ${HARFBUZZ_VER}"
    download_file "$FREETYPE_URL" "${SABAOS_SOURCES}/freetype-${FREETYPE_VER}.tar.xz" "freetype ${FREETYPE_VER}"
    download_file "$FONTCONFIG_URL" "${SABAOS_SOURCES}/fontconfig-${FONTCONFIG_VER}.tar.xz" "fontconfig ${FONTCONFIG_VER}"
    download_file "$MESA_URL" "${SABAOS_SOURCES}/mesa-${MESA_VER}.tar.xz" "mesa ${MESA_VER}"
    download_file "$WLROOTS_URL" "${SABAOS_SOURCES}/wlroots-${WLROOTS_VER}.tar.gz" "wlroots ${WLROOTS_VER}"
    download_file "$WESTON_URL" "${SABAOS_SOURCES}/weston-${WESTON_VER}.tar.gz" "weston ${WESTON_VER}"
    download_file "$SWAY_URL" "${SABAOS_SOURCES}/sway-${SWAY_VER}.tar.gz" "sway ${SWAY_VER}"
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  DOWNLOADING USERLAND EXTRAS${NC}"
    echo -e "${BLUE}========================================${NC}"
    download_file "$FISH_URL" "${SABAOS_SOURCES}/fish-${FISH_VER}.tar.xz" "fish ${FISH_VER}"
    download_file "$TMUX_URL" "${SABAOS_SOURCES}/tmux-${TMUX_VER}.tar.gz" "tmux ${TMUX_VER}"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  SABAOS - Source Download${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    log_info "Sources directory: ${SABAOS_SOURCES}"
    echo ""
    
    download_all
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  DOWNLOAD SUMMARY${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "  Total:   ${TOTAL}"
    echo -e "  Success: ${GREEN}${SUCCESS}${NC}"
    echo -e "  Skipped: ${YELLOW}${SKIPPED}${NC}"
    echo -e "  Failed:  ${RED}${FAILED}${NC}"
    echo ""
    
    if [ -d "${SABAOS_SOURCES}" ]; then
        log_info "Total size:"
        du -sh "${SABAOS_SOURCES}" 2>/dev/null || echo "N/A"
    fi
    
    if [ $FAILED -gt 0 ]; then
        exit 1
    fi
    
    exit 0
}

main "$@"
