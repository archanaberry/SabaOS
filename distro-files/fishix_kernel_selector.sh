#!/bin/bash
# ============================================================================
# FISHIX KERNEL SELECTOR v1.0
# Interactive menu untuk memilih sumber Fishix kernel
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Konfigurasi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FISHIX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KERNEL_DIR="${FISHIX_ROOT}/kernel"
TEMP_DIR="${FISHIX_ROOT}/.fishix_temp"

# URL konfigs
declare -A FISHIX_SOURCES=(
    ["official"]="https://github.com/tunis4/Fishix"
    ["archanaberry"]="https://github.com/archanaberry/Fishix"
)

# ============================================================================
# FUNGSI UTILITAS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_section() {
    echo -e "\n${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}========================================${NC}\n"
}

cleanup_temp() {
    if [ -d "$TEMP_DIR" ]; then
        log_info "Membersihkan file temporary..."
        rm -rf "$TEMP_DIR"
    fi
}

extract_and_move() {
    local archive_path="$1"
    local extract_dir="$TEMP_DIR/extract"
    
    log_info "Mengekstrak archive..."
    mkdir -p "$extract_dir"
    
    # Tentukan tipe compression
    case "$archive_path" in
        *.tar.gz)
            tar -xzf "$archive_path" -C "$extract_dir"
            ;;
        *.tar.bz2)
            tar -xjf "$archive_path" -C "$extract_dir"
            ;;
        *.tar.xz)
            tar -xJf "$archive_path" -C "$extract_dir"
            ;;
        *.tar)
            tar -xf "$archive_path" -C "$extract_dir"
            ;;
        *.zip)
            unzip -q "$archive_path" -d "$extract_dir"
            ;;
        *)
            log_error "Format archive tidak dikenal: $archive_path"
            return 1
            ;;
    esac
    
    log_success "Archive berhasil diekstrak"
    
    # Cek apakah ada subdirectory
    local contents=($(ls -A "$extract_dir"))
    
    if [ ${#contents[@]} -eq 1 ] && [ -d "$extract_dir/${contents[0]}" ]; then
        # Ada subdirectory tunggal - pindahkan semuanya ke atas satu level
        log_info "Ditemukan subdirectory: ${contents[0]}"
        log_info "Memindahkan konten ke kernel directory..."
        
        # Hapus kernel dir lama jika ada
        if [ -d "$KERNEL_DIR" ]; then
            rm -rf "$KERNEL_DIR"
        fi
        
        # Pindahkan subdirectory menjadi kernel dir
        mv "$extract_dir/${contents[0]}" "$KERNEL_DIR"
    else
        # Tidak ada subdirectory atau multiple items
        if [ -d "$KERNEL_DIR" ]; then
            rm -rf "$KERNEL_DIR"
        fi
        mv "$extract_dir"/* "$FISHIX_ROOT/"
    fi
    
    log_success "Konten Fishix berhasil dipindahkan ke $KERNEL_DIR"
}

download_fishix() {
    local url="$1"
    local branch="${2:-main}"
    
    log_section "DOWNLOAD FISHIX KERNEL"
    log_info "URL: $url"
    log_info "Branch: $branch"
    
    # Tentukan format download (zip atau tar.gz)
    local archive_name="Fishix-${branch}.tar.gz"
    local download_url="${url}/archive/refs/heads/${branch}.tar.gz"
    local archive_path="${TEMP_DIR}/${archive_name}"
    
    log_info "Downloading dari: $download_url"
    
    mkdir -p "$TEMP_DIR"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar "$download_url" -o "$archive_path" || {
            log_error "Download gagal!"
            cleanup_temp
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget --progress=bar:force -O "$archive_path" "$download_url" || {
            log_error "Download gagal!"
            cleanup_temp
            return 1
        }
    else
        log_error "curl atau wget tidak tersedia"
        return 1
    fi
    
    if [ ! -f "$archive_path" ]; then
        log_error "Download gagal - file tidak ditemukan"
        cleanup_temp
        return 1
    fi
    
    log_success "Download selesai: $archive_path"
    
    # Extract dan move
    extract_and_move "$archive_path" || {
        cleanup_temp
        return 1
    }
    
    cleanup_temp
}

verify_kernel() {
    log_section "VERIFIKASI KERNEL"
    
    if [ ! -d "$KERNEL_DIR" ]; then
        log_error "Kernel directory tidak ditemukan: $KERNEL_DIR"
        return 1
    fi
    
    log_success "Kernel directory ditemukan: $KERNEL_DIR"
    
    # Cek Makefile
    if [ -f "$KERNEL_DIR/Makefile" ]; then
        log_success "Ditemukan Makefile"
    else
        log_warning "Makefile tidak ditemukan di kernel directory"
    fi
    
    # List struktur
    log_info "Struktur kernel:"
    ls -la "$KERNEL_DIR" | head -20
    
    return 0
}

# ============================================================================
# MENU INTERAKTIF
# ============================================================================

show_menu() {
    log_section "FISHIX KERNEL SELECTOR"
    echo "Pilih sumber Fishix Kernel:"
    echo ""
    echo "  ${CYAN}1)${NC} Official (tunis4)"
    echo "     ${YELLOW}https://github.com/tunis4/Fishix${NC}"
    echo ""
    echo "  ${CYAN}2)${NC} Community (archanaberry)"
    echo "     ${YELLOW}https://github.com/archanaberry/Fishix${NC}"
    echo ""
    echo "  ${CYAN}3)${NC} Custom URL"
    echo ""
    echo "  ${CYAN}0)${NC} Batalkan"
    echo ""
    echo -n "Pilihan Anda [0-3]: "
}

main() {
    log_section "FISHIX KERNEL SELECTOR v1.0"
    
    # Jika sudah ada kernel directory
    if [ -d "$KERNEL_DIR" ]; then
        log_warning "Kernel directory sudah ada di: $KERNEL_DIR"
        echo -e "${YELLOW}Apakah Anda ingin mengganti dengan yang baru?${NC}"
        echo ""
        echo "  ${CYAN}1)${NC} Ya, ganti dengan yang baru"
        echo "  ${CYAN}2)${NC} Tidak, gunakan yang ada"
        echo "  ${CYAN}0)${NC} Batalkan"
        echo ""
        echo -n "Pilihan [0-2]: "
        read -r keep_existing
        
        case "$keep_existing" in
            1)
                log_warning "Akan menghapus kernel directory yang ada..."
                sleep 2
                ;;
            2)
                log_success "Menggunakan kernel yang sudah ada"
                verify_kernel
                return 0
                ;;
            0)
                log_warning "Dibatalkan oleh user"
                return 1
                ;;
            *)
                log_error "Pilihan tidak valid"
                return 1
                ;;
        esac
    fi
    
    # Menu pilihan kernel
    while true; do
        show_menu
        read -r choice
        
        case "$choice" in
            1)
                log_info "Memilih: Official (tunis4)"
                download_fishix "${FISHIX_SOURCES[official]}" "main"
                verify_kernel
                log_success "Setup kernel selesai!"
                return 0
                ;;
            2)
                log_info "Memilih: Community (archanaberry)"
                download_fishix "${FISHIX_SOURCES[archanaberry]}" "main"
                verify_kernel
                log_success "Setup kernel selesai!"
                return 0
                ;;
            3)
                echo ""
                echo "Masukkan URL repository Fishix:"
                echo "  (Contoh: https://github.com/username/Fishix)"
                echo ""
                echo -n "URL: "
                read -r custom_url
                
                if [ -z "$custom_url" ]; then
                    log_error "URL tidak boleh kosong"
                    continue
                fi
                
                echo ""
                echo -n "Branch [default: main]: "
                read -r custom_branch
                custom_branch="${custom_branch:-main}"
                
                log_info "Memilih: Custom ($custom_url)"
                download_fishix "$custom_url" "$custom_branch"
                verify_kernel
                log_success "Setup kernel selesai!"
                return 0
                ;;
            0)
                log_warning "Dibatalkan oleh user"
                return 1
                ;;
            *)
                log_error "Pilihan tidak valid! Pilih 0-3"
                sleep 1
                clear
                ;;
        esac
    done
}

# ============================================================================
# ENTRY POINT
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
