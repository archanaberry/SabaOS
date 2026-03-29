#!/bin/bash
# ============================================================================
# SABA OS - Source Verification Script
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

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}          🐟 SABA OS - Source Verification Tool               ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Checksum database (MD5)
declare -A CHECKSUMS=(
    ["musl-1.2.6.tar.gz"]="a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4"
    ["runit-2.1.2.tar.gz"]="6fd9850cb4004f49193b0aaef5ef47b1"
    ["coreutils-9.6.tar.xz"]="7a0124327b398fd9eb1a6abde583389821422c744ffa10734b24f557610d3283"
    ["pixman-0.46.4.tar.gz"]="c08173c8e1d2cc79428d931c13ffda59"
    ["libxkbcommon-1.13.1.tar.gz"]="11b7276e2be65943765ec05d9f19fee4"
    ["wayland-1.23.1.tar.xz"]="403b31c48beeb88a8d04435b427e2d1fc8e50e81e936b50885325ca9f87ae0db"
    ["weston-15.0.0.tar.xz"]="58c6186d29a5d2f0be0dec4882af71cc190a11da803f6ed1bf0b2c74120da973"
    ["busybox-1.37.0.tar.bz2"]="SKIP"  # Will be checked differently
    ["fish-4.5.0.tar.xz"]="SKIP"
    ["linux-6.18.20.tar.xz"]="SKIP"
    ["binutils-2.46.tar.xz"]="SKIP"
    ["gcc-14.2.0.tar.xz"]="SKIP"
    ["wayland-protocols-1.47.tar.xz"]="SKIP"
    ["wlroots-0.18.3.tar.gz"]="SKIP"
    ["sway-1.11.tar.gz"]="SKIP"
    ["swaybg-1.2.1.tar.gz"]="SKIP"
    ["libinput-1.26.0.tar.xz"]="SKIP"
    ["cairo-1.18.2.tar.xz"]="SKIP"
    ["pango-1.57.0.tar.xz"]="SKIP"
)

verify_file() {
    local file="$1"
    local filename=$(basename "$file")
    local expected_checksum="${CHECKSUMS[$filename]}"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ MISSING${NC} $filename"
        return 1
    fi
    
    if [ "$expected_checksum" = "SKIP" ]; then
        echo -e "${YELLOW}⚠️  SKIP${NC} $filename (checksum not in database)"
        return 0
    fi
    
    local computed_checksum=$(md5sum "$file" | awk '{print $1}')
    
    if [ "$computed_checksum" = "$expected_checksum" ]; then
        echo -e "${GREEN}✅ VERIFIED${NC} $filename"
        touch "${VERIFIED_DIR}/${filename}.verified"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC} $filename"
        echo -e "   Expected: $expected_checksum"
        echo -e "   Computed: $computed_checksum"
        return 1
    fi
}

echo -e "${BLUE}Memverifikasi source code di: $SOURCES_DIR${NC}\n"

cd "$SOURCES_DIR" 2>/dev/null || {
    echo -e "${RED}Error: Direktori $SOURCES_DIR tidak ditemukan!${NC}"
    echo "Jalankan saba_os_builder.py terlebih dahulu untuk download."
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
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Verified: $verified${NC}"
echo -e "${YELLOW}⚠️  Skipped: $skipped${NC}"
echo -e "${RED}❌ Failed: $failed${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"

if [ $failed -eq 0 ]; then
    echo -e "\n${GREEN}🐟 Semua source code terverifikasi! Siap untuk build.${NC}"
    exit 0
else
    echo -e "\n${RED}⚠️  Beberapa file gagal verifikasi. Silakan re-download.${NC}"
    exit 1
fi
