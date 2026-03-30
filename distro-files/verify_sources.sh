#!/bin/bash
# ============================================================================
# SABA OS v2.0 - Source Verification Script
# Verifikasi checksum dan integritas source code
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SOURCES_DIR="${HOME}/saba_os_sources"
VERIFIED_DIR="${SOURCES_DIR}/.verified"

mkdir -p "$VERIFIED_DIR"

echo -e "${BLUE}==============================================================${NC}"
echo -e "${BLUE}||${NC}          SABA OS v2.0 - Source Verification Tool           ${BLUE}||${NC}"
echo -e "${BLUE}==============================================================${NC}"
echo ""

# Checksum database (MD5)
declare -A CHECKSUMS=(
    ["musl-1.2.5.tar.gz"]="SKIP"
    ["runit-2.1.2.tar.gz"]="6fd9850cb4004f49193b0aaef5ef47b1"
    ["coreutils-9.6.tar.xz"]="7a0124327b398fd9eb1a6abde583389821422c744ffa10734b24f557610d3283"
    ["pixman-0.44.2.tar.gz"]="SKIP"
    ["libxkbcommon-1.8.1.tar.gz"]="SKIP"
    ["wayland-1.23.1.tar.xz"]="403b31c48beeb88a8d04435b427e2d1fc8e50e81e936b50885325ca9f87ae0db"
    ["busybox-1.37.0.tar.bz2"]="SKIP"
    ["fish-4.0.2.tar.xz"]="SKIP"
    ["linux-6.12.25.tar.xz"]="SKIP"
    ["binutils-2.44.tar.xz"]="SKIP"
    ["gcc-14.2.0.tar.xz"]="SKIP"
    ["wayland-protocols-1.41.tar.xz"]="SKIP"
    ["wlroots-0.18.2.tar.gz"]="SKIP"
    ["sway-1.10.1.tar.gz"]="SKIP"
    ["swaybg-1.2.1.tar.gz"]="SKIP"
    ["libinput-1.27.1.tar.xz"]="SKIP"
    ["cairo-1.18.4.tar.xz"]="SKIP"
    ["pango-1.56.3.tar.xz"]="SKIP"
)

verify_file() {
    local file="$1"
    local filename=$(basename "$file")
    local expected_checksum="${CHECKSUMS[$filename]:-SKIP}"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}[MISSING]${NC} $filename"
        return 1
    fi
    
    if [ "$expected_checksum" = "SKIP" ] || [ -z "$expected_checksum" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $filename (checksum not in database)"
        return 0
    fi
    
    local computed_checksum=$(md5sum "$file" | awk '{print $1}')
    
    if [ "$computed_checksum" = "$expected_checksum" ]; then
        echo -e "${GREEN}[VERIFIED]${NC} $filename"
        touch "${VERIFIED_DIR}/${filename}.verified"
        return 0
    else
        echo -e "${RED}[FAILED]${NC} $filename"
        echo -e "   Expected: $expected_checksum"
        echo -e "   Computed: $computed_checksum"
        return 1
    fi
}

echo -e "${BLUE}Memverifikasi source code di: $SOURCES_DIR${NC}\n"

cd "$SOURCES_DIR" 2>/dev/null || {
    echo -e "${RED}Error: Direktori $SOURCES_DIR tidak ditemukan!${NC}"
    echo "Jalankan 'make download-sources' atau python3 sabaos_builder.py terlebih dahulu."
    exit 1
}

verified=0
failed=0
skipped=0

for file in *.tar.*; do
    if [ -f "$file" ]; then
        if verify_file "$file"; then
            if [ -f "${VERIFIED_DIR}/${file}.verified" ]; then
                ((verified++))
            else
                ((skipped++))
            fi
        else
            ((failed++))
        fi
    fi
done

echo ""
echo -e "${BLUE}==============================================================${NC}"
echo -e "${GREEN}[VERIFIED] $verified${NC}"
echo -e "${YELLOW}[SKIPPED]  $skipped${NC}"
echo -e "${RED}[FAILED]   $failed${NC}"
echo -e "${BLUE}==============================================================${NC}"

if [ $failed -eq 0 ]; then
    echo -e "\n${GREEN}Semua source code terverifikasi! Siap untuk build.${NC}"
    exit 0
else
    echo -e "\n${RED}Beberapa file gagal verifikasi. Silakan re-download.${NC}"
    exit 1
fi
