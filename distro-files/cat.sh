#!/usr/bin/env bash

# ===============================
# Recursive Cat Script dengan Filter Except
# Usage:
#   ./cat.sh output.file [folder]
#   ./cat.sh output.file [folder] -fe ext1,ext2,ext3  <- KECUALIKAN ext ini
#   ./cat.sh output.file -fe ext1,ext2
# ===============================

# Inisialisasi variabel
OUTPUT=""
TARGET="."
EXCEPT_EXT=""
USE_EXCEPT=false

# Parsing argumen
while [[ $# -gt 0 ]]; do
    case $1 in
        -fe)
            USE_EXCEPT=true
            EXCEPT_EXT="$2"
            shift 2
            ;;
        *)
            if [ -z "$OUTPUT" ]; then
                OUTPUT="$1"
            elif [ "$TARGET" = "." ]; then
                TARGET="$1"
            fi
            shift
            ;;
    esac
done

# Cek argumen wajib
if [ -z "$OUTPUT" ]; then
    echo "Usage: $0 output.file [folder] [-fe extensions]"
    echo ""
    echo "Contoh:"
    echo "  $0 hasil.txt ./folder              # Semua file"
    echo "  $0 hasil.txt ./folder -fe png      # KECUALI png"
    echo "  $0 hasil.txt ./folder -fe png,svg  # KECUALI png dan svg"
    echo "  $0 hasil.txt -fe exe,dll,tmp       # KECUALI exe, dll, tmp"
    exit 1
fi

# Konversi except extension ke lowercase dan ganti koma dengan pipe untuk regex
if [ "$USE_EXCEPT" = true ]; then
    # Convert ke lowercase dan buat pattern regex
    EXCEPT_PATTERN=$(echo "$EXCEPT_EXT" | tr '[:upper:]' '[:lower:]' | tr ',' '|')
    echo "Filter except aktif: $EXCEPT_EXT (file dengan ext ini akan diSKIP)"
fi

# Kosongkan file output
> "$OUTPUT"

# Fungsi untuk cek apakah file harus diSKIP
check_except() {
    local filename="$1"
    local ext_lower=$(echo "$filename" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')

    if [ "$USE_EXCEPT" = false ]; then
        return 1  # Tidak ada filter except, jangan skip
    fi

    # Cek apakah extension match dengan pattern yang dikecualikan
    if echo "$ext_lower" | grep -qE "^($EXCEPT_PATTERN)$"; then
        return 0  # Match, artinya SKIP file ini
    else
        return 1  # Tidak match, artinya LANJUTKAN (tidak di-skip)
    fi
}

# Fungsi rekursif
process_dir() {
    local dir="$1"

    for item in "$dir"/*; do
        # Skip jika tidak ada file
        [ -e "$item" ] || continue

        if [ -d "$item" ]; then
            # Rekursif masuk folder
            process_dir "$item"

        elif [ -f "$item" ]; then
            # Cek filter except - SKIP jika match
            if check_except "$item"; then
                continue  # Skip file ini
            fi

            # Tulis header
            echo "=== ${item#./} ===" >> "$OUTPUT"

            # Isi file
            cat "$item" >> "$OUTPUT"

            # Newline pemisah
            echo -e "\n" >> "$OUTPUT"
        fi
    done
}

process_dir "$TARGET"

if [ "$USE_EXCEPT" = true ]; then
    echo "Selesai -> $OUTPUT (dikecualikan: $EXCEPT_EXT)"
else
    echo "Selesai -> $OUTPUT"
fi

