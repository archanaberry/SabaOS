# 🐟 SABA OS - Linux From Scratch 2026

**Sistem Operasi Ultra-Minimalis berbasis musl + runit + Wayland**

> *"Slippery and Fast like a Mackerel"* 🐟

---

## 📋 Spesifikasi Target

| Komponen | Nilai |
|----------|-------|
| **OS** | Saba OS - Sameko Saba |
| **Kernel** | Fishix 1.0.5 (Linux 6.18.20 LTS) |
| **Libc** | musl 1.2.6 (bukan glibc!) |
| **Init** | runit 2.1.2 (bukan systemd!) |
| **Shell** | fish 4.5.0 |
| **Display** | Wayland 1.23.1 |
| **WM** | Sway 1.11 |
| **Target RAM Idle** | ~29 MiB |
| **Total Paket** | ~79 |

---

## 📦 Isi Paket

### 1. `saba_os_builder.py`
**GUI Downloader Interaktif** - Python + Tkinter

Fitur:
- ✅ Progress bar real-time
- ✅ Pilih komponen yang akan di-download
- ✅ Verifikasi checksum otomatis
- ✅ Ekstrak archive otomatis
- ✅ Logging lengkap

### 2. `build_saba_os.sh`
**Build Script Bash** - LFS Automation

Fase Build:
- **Fase 0**: Persiapan direktori
- **Fase 1**: Cross-toolchain (musl-based)
- **Fase 2**: Chroot & sistem dasar
- **Fase 3**: Kernel Fishix 1.0.5
- **Fase 4**: Wayland & Sway
- **Fase 5**: Konfigurasi sistem
- **Fase 6**: Bootloader

---

## 🚀 Cara Penggunaan

### Langkah 1: Download Source Code

```bash
# Install dependensi GUI (jika belum ada)
sudo apt install python3 python3-tk  # Debian/Ubuntu
sudo pacman -S python tk             # Arch

# Jalankan GUI downloader
python3 saba_os_builder.py
```

Atau download manual dari URL berikut:

### URL Komponen Esensial

#### Kernel & Boot
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| Linux Kernel | 6.18.20 LTS | https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.20.tar.xz | 136 MB |
| runit | 2.1.2 | http://smarden.org/runit/runit-2.1.2.tar.gz | 110 KB |

#### C Library & Toolchain
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| musl libc | 1.2.6 | https://musl.libc.org/releases/musl-1.2.6.tar.gz | 1.0 MB |
| GNU Binutils | 2.46 | https://ftp.gnu.org/gnu/binutils/binutils-2.46.0.tar.xz | 25 MB |
| GCC | 14.2.0 | https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz | 85 MB |

#### Core Utilities
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| GNU Coreutils | 9.6 | https://ftp.gnu.org/gnu/coreutils/coreutils-9.6.tar.xz | 5.9 MB |
| BusyBox | 1.37.0 | https://busybox.net/downloads/busybox-1.37.0.tar.bz2 | 2.4 MB |

#### Shell
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| Fish Shell | 4.5.0 | https://github.com/fish-shell/fish-shell/releases/download/4.5.0/fish-4.5.0.tar.xz | 3.5 MB |

#### Wayland & Display
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| Wayland | 1.23.1 | https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz | 460 KB |
| wayland-protocols | 1.47 | https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.47/downloads/wayland-protocols-1.47.tar.xz | 180 KB |
| wlroots | 0.18.3 | https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/0.18.3/downloads/wlroots-0.18.3.tar.gz | 1.2 MB |
| Weston | 15.0.0 | https://gitlab.freedesktop.org/wayland/weston/-/releases/15.0.0/downloads/weston-15.0.0.tar.xz | 3.2 MB |

#### Window Manager
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| Sway | 1.11 | https://github.com/swaywm/sway/releases/download/1.11/sway-1.11.tar.gz | 5.5 MB |
| swaybg | 1.2.1 | https://github.com/swaywm/swaybg/releases/download/v1.2.1/swaybg-1.2.1.tar.gz | 15 KB |

#### Input & Graphics Libraries
| Paket | Versi | URL | Size |
|-------|-------|-----|------|
| libinput | 1.26.0 | https://gitlab.freedesktop.org/libinput/libinput/-/releases/1.26.0/downloads/libinput-1.26.0.tar.xz | 620 KB |
| libxkbcommon | 1.13.1 | https://github.com/lfs-book/libxkbcommon/archive/v1.13.1/libxkbcommon-1.13.1.tar.gz | 1.2 MB |
| Pixman | 0.46.4 | https://www.cairographics.org/releases/pixman-0.46.4.tar.gz | 808 KB |
| Cairo | 1.18.2 | https://www.cairographics.org/releases/cairo-1.18.2.tar.xz | 22 MB |
| Pango | 1.57.0 | https://download.gnome.org/sources/pango/1.57/pango-1.57.0.tar.xz | 1.8 MB |

---

### Langkah 2: Build Sistem

```bash
# Beri izin eksekusi
chmod +x build_saba_os.sh

# Jalankan build (interactive menu)
sudo ./build_saba_os.sh

# Atau build semua fase sekaligus
sudo ./build_saba_os.sh
# Pilih 'a' untuk Build All
```

---

## 🏗️ Arsitektur Saba OS

```
┌─────────────────────────────────────────────────────────────┐
│                    USER SPACE                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Sway WM │  │  Fish    │  │  Coreutils│  │  BusyBox │   │
│  │  (Wayland)│  │  Shell   │  │          │  │          │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    WAYLAND COMPOSITOR                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  wlroots 0.18.3 + wayland 1.23.1                   │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    GRAPHICS STACK                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Pixman  │  │  Cairo   │  │  Pango   │  │ libinput │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    KERNEL SPACE                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Fishix 1.0.5 (Linux 6.18.20 LTS)                   │   │
│  │  - Single Core Scheduler Optimization              │   │
│  │  - VirtIO GPU/Net/Blk support                      │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    C LIBRARY                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  musl libc 1.2.6 (NOT glibc!)                       │   │
│  │  - Lightweight, fast, simple                        │   │
│  │  - Static linking friendly                          │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    INIT SYSTEM                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  runit 2.1.2 (NOT systemd!)                         │   │
│  │  - Stage 1: Initialization                          │   │
│  │  - Stage 2: Service supervision                     │   │
│  │  - Stage 3: Shutdown                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎨 Tema: Fishy Ocean

```
Primary Colors:
- Background:  #0a1628 (Deep Ocean)
- Foreground:  #e0e0e0 (Silver Fish)
- Accent:      #00d4ff (Ocean Blue)
- Secondary:   #ff6b9d (Coral Pink)
- Success:     #80ff80 (Seafoam)
- Warning:     #ffd700 (Sunlight)
```

---

## 📊 Perbandingan dengan Distro Lain

| Distro | Init | Libc | WM | RAM Idle |
|--------|------|------|-----|----------|
| **Saba OS** | runit | musl | Sway | **~29 MiB** |
| Void Linux | runit | musl/glibc | X11/Sway | ~150 MiB |
| Alpine | OpenRC | musl | - | ~50 MiB |
| Arch | systemd | glibc | Sway | ~400 MiB |
| Debian | systemd | glibc | GNOME | ~800 MiB |

---

## ⚠️ Catatan Penting

1. **musl vs glibc**: Beberapa aplikasi proprietary mungkin tidak berjalan dengan musl
2. **runit**: Tidak ada `systemctl`, gunakan `sv` untuk manajemen service
3. **Wayland**: Tidak ada X11, gunakan aplikasi Wayland-native
4. **Build Time**: Proses build LFS membutuhkan waktu 4-8 jam tergantung hardware

---

## 🐛 Troubleshooting

### Error: "cannot find -lc"
```bash
# Pastikan musl libc terinstal dengan benar
export LIBRARY_PATH=/tools/lib:/usr/lib
```

### Error: Wayland tidak bisa start
```bash
# Cek permission
usermod -aG video,audio,input,seat $USER

# Cek log
sway -d 2>&1 | tee sway.log
```

### Error: Kernel tidak boot
```bash
# Rebuild initramfs
chroot $LFS /build/mkinitramfs.sh

# Cek bootloader
efibootmgr -v  # untuk UEFI
grub-install /dev/sda  # untuk BIOS
```

---

## 📚 Referensi

- [Linux From Scratch](https://www.linuxfromscratch.org/)
- [musl libc](https://musl.libc.org/)
- [runit](http://smarden.org/runit/)
- [Sway](https://swaywm.org/)
- [Wayland](https://wayland.freedesktop.org/)

---

## 🐟 Tentang Sameko Saba

**Sameko Saba** adalah VTuber indie yang debut pada Juni 2025 dan mencapai 1 juta subscriber hanya dalam 3 hari! Maskot Saba OS terinspirasi dari karakter "Catfish Girl" yang ikonik ini.

---

## 📜 Lisensi

Saba OS Builder dirilis di bawah MIT License.

Kernel Linux dirilis di bawah GPL v2.

musl libc dirilis di bawah MIT License.

---

**🐟 Dibuat dengan cinta untuk komunitas VTuber dan Linux enthusiast!**

*"Keep it simple, keep it fishy!"* 🐟
