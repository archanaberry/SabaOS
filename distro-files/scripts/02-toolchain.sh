#!/bin/bash
# =============================================================================
# SABAOS - Cross-Compilation Toolchain Build Script
# =============================================================================
# Build cross-compilation toolchain dengan musl libc
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

# Toolchain directories
export TOOLS_DIR="${SABAOS_BUILD}/tools"
export CROSS_DIR="${TOOLS_DIR}/cross"
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
# EXTRACT FUNCTIONS
# =============================================================================

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
# BUILD FUNCTIONS
# =============================================================================

build_binutils() {
    log_step "BUILDING BINUTILS ${BINUTILS_VER}"
    
    local src_dir="${SABAOS_BUILD}/binutils-${BINUTILS_VER}"
    local build_dir="${SABAOS_BUILD}/build-binutils"
    
    # Extract
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/binutils-${BINUTILS_VER}.tar.xz" "${SABAOS_BUILD}"
    fi
    
    # Create build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Configure
    log_info "Configuring binutils..."
    "$src_dir/configure" \
        --prefix="$CROSS_DIR" \
        --target="$TARGET" \
        --with-sysroot="$SYSROOT" \
        --disable-nls \
        --disable-werror \
        --enable-deterministic-archives \
        --disable-compressed-debug-sections \
        2>&1 | tee "${SABAOS_TEMP}/logs/binutils-configure.log"
    
    # Build
    log_info "Building binutils..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/binutils-build.log"
    
    # Install
    log_info "Installing binutils..."
    make install 2>&1 | tee "${SABAOS_TEMP}/logs/binutils-install.log"
    
    log_success "Binutils built successfully"
}

build_gcc_stage1() {
    log_step "BUILDING GCC ${GCC_VER} (Stage 1)"
    
    local src_dir="${SABAOS_BUILD}/gcc-${GCC_VER}"
    local build_dir="${SABAOS_BUILD}/build-gcc-stage1"
    
    # Extract GCC
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/gcc-${GCC_VER}.tar.xz" "${SABAOS_BUILD}"
    fi
    
    # Extract prerequisites
    cd "$src_dir"
    if [ ! -d "gmp" ]; then
        extract_archive "${SABAOS_SOURCES}/gmp-${GMP_VER}.tar.xz" "${SABAOS_BUILD}"
        mv "${SABAOS_BUILD}/gmp-${GMP_VER}" "gmp"
    fi
    if [ ! -d "mpfr" ]; then
        extract_archive "${SABAOS_SOURCES}/mpfr-${MPFR_VER}.tar.xz" "${SABAOS_BUILD}"
        mv "${SABAOS_BUILD}/mpfr-${MPFR_VER}" "mpfr"
    fi
    if [ ! -d "mpc" ]; then
        extract_archive "${SABAOS_SOURCES}/mpc-${MPC_VER}.tar.gz" "${SABAOS_BUILD}"
        mv "${SABAOS_BUILD}/mpc-${MPC_VER}" "mpc"
    fi
    
    # Create build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Configure
    log_info "Configuring GCC stage 1..."
    "$src_dir/configure" \
        --prefix="$CROSS_DIR" \
        --target="$TARGET" \
        --with-sysroot="$SYSROOT" \
        --disable-nls \
        --enable-languages=c,c++ \
        --disable-libssp \
        --disable-libquadmath \
        --disable-libatomic \
        --disable-libgomp \
        --disable-threads \
        --disable-shared \
        --disable-decimal-float \
        --with-newlib \
        --without-headers \
        --with-arch=${TARGET_CPU} \
        2>&1 | tee "${SABAOS_TEMP}/logs/gcc-stage1-configure.log"
    
    # Build
    log_info "Building GCC stage 1..."
    make $MAKEFLAGS all-gcc 2>&1 | tee "${SABAOS_TEMP}/logs/gcc-stage1-build.log"
    
    # Install
    log_info "Installing GCC stage 1..."
    make install-gcc 2>&1 | tee "${SABAOS_TEMP}/logs/gcc-stage1-install.log"
    
    log_success "GCC stage 1 built successfully"
}

build_musl() {
    log_step "BUILDING MUSL ${MUSL_VER}"
    
    local src_dir="${SABAOS_BUILD}/musl-${MUSL_VER}"
    
    # Extract
    if [ ! -d "$src_dir" ]; then
        extract_archive "${SABAOS_SOURCES}/musl-${MUSL_VER}.tar.gz" "${SABAOS_BUILD}"
    fi
    
    cd "$src_dir"
    
    # Clean previous build
    make distclean 2>/dev/null || true
    
    # Configure
    log_info "Configuring musl..."
    CC="${CROSS_DIR}/bin/${TARGET}-gcc" \
    ./configure \
        --prefix=/ \
        --target="$TARGET" \
        --disable-shared \
        --enable-static \
        2>&1 | tee "${SABAOS_TEMP}/logs/musl-configure.log"
    
    # Build
    log_info "Building musl..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/musl-build.log"
    
    # Install to sysroot
    log_info "Installing musl to sysroot..."
    make DESTDIR="$SYSROOT" install 2>&1 | tee "${SABAOS_TEMP}/logs/musl-install.log"
    
    # Create necessary symlinks
    mkdir -p "${SYSROOT}/usr"
    ln -sf ../include "${SYSROOT}/usr/include" 2>/dev/null || true
    ln -sf ../lib "${SYSROOT}/usr/lib" 2>/dev/null || true
    
    log_success "Musl built successfully"
}

build_gcc_stage2() {
    log_step "BUILDING GCC ${GCC_VER} (Stage 2 - Final)"
    
    local src_dir="${SABAOS_BUILD}/gcc-${GCC_VER}"
    local build_dir="${SABAOS_BUILD}/build-gcc-stage2"
    
    # Create build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Configure
    log_info "Configuring GCC stage 2..."
    "$src_dir/configure" \
        --prefix="$CROSS_DIR" \
        --target="$TARGET" \
        --with-sysroot="$SYSROOT" \
        --disable-nls \
        --enable-languages=c,c++ \
        --enable-shared \
        --enable-threads=posix \
        --enable-libssp \
        --enable-libatomic \
        --enable-libgomp \
        --with-arch=${TARGET_CPU} \
        --enable-tls \
        --enable-initfini-array \
        2>&1 | tee "${SABAOS_TEMP}/logs/gcc-stage2-configure.log"
    
    # Build
    log_info "Building GCC stage 2..."
    make $MAKEFLAGS 2>&1 | tee "${SABAOS_TEMP}/logs/gcc-stage2-build.log"
    
    # Install
    log_info "Installing GCC stage 2..."
    make install 2>&1 | tee "${SABAOS_TEMP}/logs/gcc-stage2-install.log"
    
    log_success "GCC stage 2 built successfully"
}

# =============================================================================
# VERIFY TOOLCHAIN
# =============================================================================

verify_toolchain() {
    log_step "VERIFYING TOOLCHAIN"
    
    local gcc_path="${CROSS_DIR}/bin/${TARGET}-gcc"
    local gpp_path="${CROSS_DIR}/bin/${TARGET}-g++"
    local ld_path="${CROSS_DIR}/bin/${TARGET}-ld"
    local ar_path="${CROSS_DIR}/bin/${TARGET}-ar"
    
    log_info "Checking toolchain binaries..."
    
    if [ -x "$gcc_path" ]; then
        log_success "GCC: $(basename $($gcc_path --version 2>/dev/null | head -1))"
    else
        log_error "GCC not found!"
        return 1
    fi
    
    if [ -x "$gpp_path" ]; then
        log_success "G++: $(basename $($gpp_path --version 2>/dev/null | head -1))"
    else
        log_error "G++ not found!"
        return 1
    fi
    
    if [ -x "$ld_path" ]; then
        log_success "LD: $(basename $($ld_path --version 2>/dev/null | head -1))"
    else
        log_error "LD not found!"
        return 1
    fi
    
    if [ -x "$ar_path" ]; then
        log_success "AR: Found"
    else
        log_error "AR not found!"
        return 1
    fi
    
    # Test compile
    log_info "Testing cross-compilation..."
    local test_file="${SABAOS_TEMP}/test.c"
    echo 'int main() { return 0; }' > "$test_file"
    
    if "$gcc_path" -o "${SABAOS_TEMP}/test" "$test_file" 2>/dev/null; then
        log_success "Test compilation successful"
        rm -f "${SABAOS_TEMP}/test" "$test_file"
    else
        log_error "Test compilation failed!"
        rm -f "$test_file"
        return 1
    fi
    
    log_success "Toolchain verification complete"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_step "SABAOS - Toolchain Build"
    
    # Create directories
    mkdir -p "$TOOLS_DIR"
    mkdir -p "$CROSS_DIR"
    mkdir -p "$SYSROOT"
    mkdir -p "${SABAOS_TEMP}/logs"
    
    log_info "Tools directory: $TOOLS_DIR"
    log_info "Cross directory: $CROSS_DIR"
    log_info "Sysroot: $SYSROOT"
    
    # Build steps
    build_binutils
    build_gcc_stage1
    build_musl
    build_gcc_stage2
    verify_toolchain
    
    log_step "TOOLCHAIN BUILD COMPLETE"
    log_info "Cross-compiler location: ${CROSS_DIR}/bin/"
    log_info "Target: ${TARGET}"
    echo ""
    log_info "Add to PATH:"
    echo "  export PATH=\"${CROSS_DIR}/bin:\$PATH\""
    echo ""
    log_success "Toolchain is ready!"
}

main "$@"
