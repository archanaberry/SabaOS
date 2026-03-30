# Saba OS v2.0 - Fishix Kernel Edition
## Dengan Kernel Selector Interaktif

---

## 📋 Perubahan Utama

Sistem build Saba OS telah diperbarui dengan fitur **Kernel Selector Interaktif**:

### ✓ Kernel Selector (BARU)
- Menu interaktif untuk memilih sumber Fishix Kernel
- Support 3 opsi: Official (tunis4), Community (archanaberry), Custom URL
- Otomatis download, ekstrak, dan setup kernel
- Menangani subdirectory - pindahkan semua konten 1 level ke atas

### ✓ Removed: Linux Kernel 6.12.25
- Script **tidak lagi** download/build Linux kernel
- Menghapus `linux-6.12.25.tar.xz` dari SOURCE_URLS
- Menghapus kode ekstraksi Linux kernel
- Semua kernel headers diambil dari **Fishix kernel** saja

### ✓ Updated: build_sabaos.sh
- Fungsi `install_kernel_headers()` sekarang menggunakan Fishix
- Verifikasi Fishix kernel directory sebelum build
- Error handling untuk missing kernel

### ✓ Updated: sabaos_builder.py
- Kategori "Kernel & Boot" → "Boot & Init"
- Dihapus: `linux_kernel` entry (145 MB)
- Runit sekarang catatan: "(Linux kernel menggunakan Fishix)"

---

## 📁 Struktur Folder

```
/workspaces/SabaOS/
├── kernel/                          # ← Fishix kernel (didownload otomatis)
│   ├── kernel/                      # Real kernel source
│   │   ├── Makefile
│   │   ├── arch/
│   │   ├── include/                 # Header files (untuk Linux compat)
│   │   └── ...
│   ├── distro-files/
│   ├── limine.conf
│   ├── Makefile
│   ├── README.md
│   └── ...
│
├── distro-files/                    # ← Build scripts
│   ├── fishix_kernel_selector.sh    # ← NEW: Interactive selector
│   ├── build_sabaos.sh
│   ├── Makefile
│   ├── sabaos_builder.py
│   ├── makeiso.sh
│   ├── README_KERNEL_SELECTOR.md    # ← This file
│   └── ...
│
└── limine/                          # Bootloader
    └── ...
```

---

## 🚀 Quick Start

### Opsi 1: Build Saba OS Lengkap (RECOMMENDED)

```bash
cd distro-files
make build-all
```

**Yang akan terjadi:**
1. Kernel Selector muncul - pilih sumber Fishix
2. Kernel otomatis download & setup
3. Semua phase (0-6) dijalankan otomatis

### Opsi 2: Interactive Menu

```bash
cd distro-files
make menu
# atau
make build-sabaos
```

**Yang akan terjadi:**
1. Kernel Selector muncul
2. Menu fase-per-fase (0-6) dengan pilihan interaktif

### Opsi 3: Kernel Selector Saja

```bash
cd distro-files
make kernel-selector
```

Hanya download & setup kernel, tidak build Saba OS.

---

## 🎯 Menu Kernel Selector

Saat menjalankan `make build-all` atau `make menu`, akan muncul:

```
========================================
  FISHIX KERNEL SELECTOR v1.0
========================================

Pilih sumber Fishix Kernel:

  1) Official (tunis4)
     https://github.com/tunis4/Fishix
  
  2) Community (archanaberry)
     https://github.com/archanaberry/Fishix
  
  3) Custom URL
  
  0) Batalkan

Pilihan Anda [0-3]: _
```

### Pilihan 1: Official (tunis4)
- Repository resmi Fishix
- URL: `https://github.com/tunis4/Fishix`
- Branch: `main`

### Pilihan 2: Community (archanaberry)
- Fork dari archanaberry
- URL: `https://github.com/archanaberry/Fishix`
- Branch: `main`

### Pilihan 3: Custom URL
- Masukkan URL repository custom
- Bisa pilih branch berbeda
- Format: `https://github.com/username/Fishix`

### Pilihan 0: Batalkan
- Exit tanpa download

---

## 📥 Download & Setup Kernel

### Cara Kerja `fishix_kernel_selector.sh`:

```
┌─────────────────────────────────────────┐
│ 1. URL INPUT                            │
│    Minta URL repository Fishix          │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 2. DOWNLOAD                             │
│    Download archive (tar.gz/.tar.bz2)   │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 3. EXTRACT                              │
│    Ekstrak ke .fishix_temp/             │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 4. DETECT SUBDIRECTORY                  │
│    Cek apakah ada Fishix-main/ atau     │
│    struktur langsung                    │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 5. MOVE TO KERNEL/                      │
│    Pindahkan konten ke ../kernel/       │
│    (tidak ada level subdirectory)       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 6. VERIFY                               │
│    Cek Makefile & struktur kernel       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 7. CLEANUP                              │
│    Hapus .fishix_temp/                  │
└─────────────────────────────────────────┘
```

### Contoh Output:

```bash
$ make kernel-selector

Running Fishix Kernel Selector...

========================================
  FISHIX KERNEL SELECTOR v1.0
========================================

Pilih sumber Fishix Kernel:
  1) Official (tunis4)
  2) Community (archanaberry)
  3) Custom URL
  0) Batalkan

Pilihan Anda [0-3]: 2
[INFO] Memilih: Community (archanaberry)

========================================
  DOWNLOAD FISHIX KERNEL
========================================

[INFO] URL: https://github.com/archanaberry/Fishix
[INFO] Branch: main
[INFO] Downloading dari: https://github.com/archanaberry/Fishix/archive/refs/heads/main.tar.gz
    #####################                  [42%] 
[✓] Download selesai: /workspaces/SabaOS/.fishix_temp/Fishix-main.tar.gz
[INFO] Mengekstrak archive...
[✓] Archive berhasil diekstrak
[INFO] Ditemukan subdirectory: Fishix-main
[INFO] Memindahkan konten ke kernel directory...
[✓] Konten Fishix berhasil dipindahkan ke /workspaces/SabaOS/kernel
[INFO] Membersihkan file temporary...

========================================
  VERIFIKASI KERNEL
========================================

[✓] Kernel directory ditemukan: /workspaces/SabaOS/kernel
[✓] Ditemukan Makefile
[INFO] Struktur kernel:
total 764
drwxrwxr-x+ 5 codespace codespace   4096 Mar 28 10:34 .
-rw-rw-r--  1 codespace codespace   1200 Mar 28 10:34 Makefile
-rw-rw-r--  1 codespace codespace   1859 Mar 28 10:34 README.md
drwxrwxr-x+ 5 codespace codespace   4096 Mar 28 10:34 kernel
drwxrwxr-x+ 5 codespace codespace   4096 Mar 28 10:34 distro-files
...
[✓] Setup kernel selesai!
```

---

## 📊 Makefile Targets

| Target | Deskripsi |
|--------|-----------|
| `make kernel-selector` | Jalankan Kernel Selector interaktif |
| `make fishix-kernel` | Build Fishix kernel |
| `make fishix-clean` | Clean Fishix kernel build |
| `make download-sources` | Download tools/libraries (tidak termasuk kernel) |
| `make menu` | Interactive menu build (dengan kernel selector) |
| `make build-sabaos` | Alias untuk `make menu` |
| `make build-all` | Build semua fase otomatis |
| `make phase0` | Build Phase 0: Persiapan |
| `make phase1` | Build Phase 1: Cross-Toolchain |
| `make phase2` | Build Phase 2: Chroot & Base |
| `make phase3` | Build Phase 3: Import Fishix Kernel |
| `make phase4` | Build Phase 4: Wayland & Sway |
| `make phase5` | Build Phase 5: Konfigurasi |
| `make phase6` | Build Phase 6: Bootloader |
| `make iso` | Buat ISO bootable |
| `make verify` | Verifikasi environment |
| `make clean` | Hapus log files |
| `make clean-all` | Hapus semua build artifacts |
| `make help` | Tampilkan bantuan |

---

## 🔧 Build Phases

### Phase 0: Persiapan Sistem
- Setup directory structure
- Verifikasi tools yang diperlukan
- Setup mount points

### Phase 1: Cross-Toolchain (musl)
- Build Binutils
- Build GCC (cross compiler)
- Build musl libc

### Phase 2: Chroot & Sistem Dasar
- Setup chroot environment
- Build tools dalam chroot
- Install base system

### Phase 3: Import Fishix Kernel
- Salin Fishix kernel headers
- Setup kernel untuk compilation
- Build sistem dengan kernel compat

### Phase 4: Wayland & Sway
- Build Wayland
- Build wlroots
- Build Sway window manager

### Phase 5: Konfigurasi Sistem
- Setup init system (runit)
- Konfigurasi boot
- Install shell (bash/fish)

### Phase 6: Bootloader
- Setup Limine bootloader
- Konfigurasi boot chain
- Persiapan ISO

---

## 🐛 Troubleshooting

### ❌ "Fishix kernel directory tidak ditemukan"

**Penyebab:** `make kernel-selector` belum dijalankan

**Solusi:**
```bash
make kernel-selector
```

Atau jalankan `make build-all` dan pilih salah satu opsi kernel

---

### ❌ "Makefile tidak ditemukan di kernel directory"

**Penyebab:** Kernel directory ada tapi kosong atau struktur salah

**Solusi:**
```bash
# Jalankan selector lagi
make kernel-selector

# Atau manual check
ls -la ../kernel/
```

---

### ❌ "Download gagal"

**Penyebab:** Network error atau URL error

**Solusi:**
```bash
# Coba lagi
make kernel-selector

# Atau gunakan Custom URL dengan fork lokal:
# Pilih opsi 3, masukkan URL custom
```

---

### ❌ "syntax error near unexpected token"

**Penyebab:** Build script corrupt atau error

**Solusi:**
```bash
# Re-clone repository
git clone https://github.com/archanaberry/SabaOS.git
cd SabaOS/distro-files
make build-all
```

---

### ❌ "Binary tidak ditemukan di /sources/busybox"

**Penyebab:** Phase sebelumnya gagal

**Solusi:**
```bash
# Check log files
cat phase1.log
cat phase2.log

# Jalankan ulang phase yang gagal
make phase1
make phase2
```

---

## 📝 Environment Variables

Script menggunakan variables berikut:

```bash
SCRIPT_DIR              # Directory tempat script berada
FISHIX_ROOT             # Parent directory SabaOS
KERNEL_DIR              # Target kernel directory (../kernel)
TEMP_DIR                # Temporary folder (.fishix_temp)
LFS                     # Build environment (/mnt/saba_os)
SABA_TGT                # Build target (x86_64-saba-linux-musl)
KERNEL_HEADERS_INSTALL  # Kernel headers location ($LFS/usr/include)
```

---

## 💾 Supported Archive Formats

Kernel Selector support ekstraksi otomatis:
- `.tar.gz`
- `.tar.bz2`
- `.tar.xz`
- `.tar`
- `.zip`

---

## 📚 File Locations

| File | Lokasi | Deskripsi |
|------|--------|-----------|
| `fishix_kernel_selector.sh` | `distro-files/` | Kernel selector script |
| `build_sabaos.sh` | `distro-files/` | Main build script |
| `Makefile` | `distro-files/` | Build targets |
| `sabaos_builder.py` | `distro-files/` | GUI builder (optional) |
| Kernel source | `../kernel/` | Fishix kernel (otomatis) |
| Build logs | `distro-files/*.log` | Phase logs |

---

## ✅ Checklist Build

- [ ] Clone/extract SabaOS
- [ ] `cd distro-files`
- [ ] `make build-all`
- [ ] Pilih kernel (1/2/3)
- [ ] Tunggu kernel download
- [ ] Tunggu semua phase selesai
- [ ] Check untuk errors di log files
- [ ] `make iso` untuk create ISO
- [ ] Test ISO dengan QEMU/VirtualBox

---

## 🔗 Useful Links

- **Fishix Official**: https://github.com/tunis4/Fishix
- **Fishix Fork**: https://github.com/archanaberry/Fishix
- **SabaOS Repo**: https://github.com/archanaberry/SabaOS
- **Limine Bootloader**: https://limine-bootloader.org/

---

## 📄 Notes

- Kernel Selector adalah **mandatory** untuk build Saba OS
- Archive otomatis dihapus setelah ekstrak (tidak memakan space)
- Build process memerlukan sudo access
- Total build time: ~30-60 menit tergantung CPU/network
- Diskspace minimal: 50GB untuk full build

---

**Last Updated:** March 30, 2026  
**Version:** 2.0 (Fishix Edition dengan Kernel Selector)
