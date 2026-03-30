# Saba OS v2.0 - Fixed Build Scripts (Fishix Kernel Edition)

## Perubahan Utama

Semua script telah diperbaiki untuk menggunakan **Fishix Kernel** yang sudah ada di `../kernel` folder, bukan membangun kernel Linux dari nol.

## Struktur Folder yang Diharapkan

```
Fishix/
├── kernel/                    # Fishix kernel source (sudah ada)
│   ├── Makefile
│   ├── build/
│   │   └── fishix            # Kernel binary (hasil build)
│   └── ...
├── distro-files/              # Fishix distro files (sudah ada)
│   ├── limine.conf
│   └── ...
├── limine/                    # Limine bootloader (sudah ada)
│   └── ...
└── sabaos-builder/            # Folder ini (SabaOS build scripts)
    ├── build_sabaos.sh
    ├── Makefile
    ├── makeiso.sh
    ├── sabaos_builder.py
    └── verify_sources.sh
```

## Cara Penggunaan

### 1. Build Fishix Kernel (Jika Belum)

```bash
cd ../kernel
make
```

Atau dari folder sabaos-builder:

```bash
make fishix-kernel
```

### 2. Download Sources

```bash
# Via Python GUI
python3 sabaos_builder.py

# Atau via Makefile
make download-sources
```

### 3. Build Saba OS

#### Opsi A: Interactive Menu
```bash
sudo ./build_sabaos.sh
```

#### Opsi B: Via Makefile
```bash
# Build semua fase
make build-all

# Atau fase per fase
make phase0    # Persiapan
make phase1    # Cross-toolchain
make phase2    # Chroot & sistem dasar
make phase3    # Import Fishix kernel
make phase4    # Wayland
make phase5    # Konfigurasi sistem
make phase6    # Bootloader
```

### 4. Buat ISO

```bash
make iso
# atau
./makeiso.sh
```

## Fitur Baru

### build_sabaos.sh
- ✅ Auto-detect Fishix kernel di `../kernel`
- ✅ Auto-build Fishix kernel jika belum ada
- ✅ Menu baru: `k` untuk build Fishix kernel only
- ✅ Tidak membangun kernel Linux lagi

### Makefile
- ✅ Target `fishix-kernel` untuk build kernel Fishix
- ✅ Target `fishix-clean` untuk clean build Fishix
- ✅ Target `iso` untuk buat ISO
- ✅ Auto-detect path Fishix

### makeiso.sh
- ✅ Support Fishix kernel dari multiple lokasi
- ✅ Fallback ke bzImage jika fishix binary tidak ada
- ✅ Integrasi dengan distro-files

## Troubleshooting

### Fishix kernel tidak ditemukan
```bash
# Pastikan Fishix kernel ada di ../kernel
ls ../kernel/Makefile

# Build Fishix kernel
cd ../kernel && make
```

### Error: "No Makefile found in ../kernel"
```bash
# Clone Fishix kernel
git clone https://github.com/archanaberry/Fishix ../kernel
cd ../kernel && make
```

### Permission denied
```bash
chmod +x build_sabaos.sh makeiso.sh verify_sources.sh
sudo ./build_sabaos.sh
```

## Dependensi

### Debian/Ubuntu
```bash
make install-deps-debian
```

### Arch Linux
```bash
make install-deps-arch
```

## File Output

Setelah build berhasil:

```
/mnt/saba_os/
├── boot/
│   ├── fishix                    # Fishix kernel
│   ├── initramfs-sabaos.img      # Initramfs
│   └── limine/
│       └── limine.conf           # Bootloader config
├── bin/, sbin/, lib/, usr/       # Sistem dasar
└── etc/
    ├── os-release                # Info OS
    ├── hostname                  # Hostname
    ├── fstab                     # Filesystem table
    └── runit/                    # Init system
```

## Catatan Penting

1. **Fishix Kernel**: Script ini menggunakan kernel Fishix yang sudah ada, bukan membangun kernel Linux dari nol
2. **musl libc**: Sistem menggunakan musl libc sebagai C library (bukan glibc)
3. **runit**: Init system menggunakan runit (bukan systemd)
4. **Wayland**: Display server menggunakan Wayland (opsional, perlu build manual)

## Lisensi

Sama dengan lisensi Fishix kernel dan komponen yang digunakan.
