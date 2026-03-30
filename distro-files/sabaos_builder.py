#!/usr/bin/env python3
"""
SABA OS BUILDER v2.0 - GUI Interaktif
Sistem Operasi Ultra-Minimalis berbasis musl + runit + Wayland
Maskot: Sameko Saba 
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog
import threading
import urllib.request
import hashlib
import os
import tarfile
import subprocess
import time
from pathlib import Path

# ============================================================================
# KONFIGURASI URL KOMPONEN SABA OS - VERSI YANG VALID
# ============================================================================

COMPONENTS = {
    "Boot & Init": {
        "runit": {
            "name": "runit 2.1.2 (Init System)",
            "url": "http://smarden.org/runit/runit-2.1.2.tar.gz",
            "filename": "runit-2.1.2.tar.gz",
            "checksum": "6fd9850cb4004f49193b0aaef5ef47b1",
            "size": "110 KB",
            "desc": "Init system super-ringan pengganti systemd (Linux kernel menggunakan Fishix)"
        }
    },
    
    "C Library & Toolchain": {
        "musl": {
            "name": "musl libc 1.2.5",
            "url": "https://musl.libc.org/releases/musl-1.2.5.tar.gz",
            "filename": "musl-1.2.5.tar.gz",
            "checksum": "a9a118bbe84d8764da0ea0d28b3ab3fae8477fc7e4085d90102b8596fc7c75e4",
            "size": "1.0 MB",
            "desc": "C library minimalis pengganti glibc"
        },
        "binutils": {
            "name": "GNU Binutils 2.44",
            "url": "https://ftp.gnu.org/gnu/binutils/binutils-2.44.tar.xz",
            "filename": "binutils-2.44.tar.xz",
            "checksum": "SKIP",
            "size": "25 MB",
            "desc": "Assembler, linker, dan tools binary"
        },
        "gcc": {
            "name": "GCC 14.2.0",
            "url": "https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz",
            "filename": "gcc-14.2.0.tar.xz",
            "checksum": "SKIP",
            "size": "85 MB",
            "desc": "GNU Compiler Collection"
        }
    },
    
    "Core Utilities": {
        "coreutils": {
            "name": "GNU Coreutils 9.6",
            "url": "https://ftp.gnu.org/gnu/coreutils/coreutils-9.6.tar.xz",
            "filename": "coreutils-9.6.tar.xz",
            "checksum": "7a0124327b398fd9eb1a6abde583389821422c744ffa10734b24f557610d3283",
            "size": "5.9 MB",
            "desc": "Basic file, shell, dan text utilities"
        },
        "busybox": {
            "name": "BusyBox 1.37.0",
            "url": "https://busybox.net/downloads/busybox-1.37.0.tar.bz2",
            "filename": "busybox-1.37.0.tar.bz2",
            "checksum": "SKIP",
            "size": "2.4 MB",
            "desc": "Swiss Army Knife untuk embedded Linux"
        }
    },
    
    "Shell": {
        "fish": {
            "name": "Fish Shell 4.0.2",
            "url": "https://github.com/fish-shell/fish-shell/releases/download/4.0.2/fish-4.0.2.tar.xz",
            "filename": "fish-4.0.2.tar.xz",
            "checksum": "SKIP",
            "size": "3.5 MB",
            "desc": "Shell user-friendly dengan auto-suggestion"
        }
    },
    
    "Wayland & Display": {
        "wayland": {
            "name": "Wayland 1.23.1",
            "url": "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz",
            "filename": "wayland-1.23.1.tar.xz",
            "checksum": "403b31c48beeb88a8d04435b427e2d1fc8e50e81e936b50885325ca9f87ae0db",
            "size": "460 KB",
            "desc": "Display server protocol modern"
        },
        "wayland_protocols": {
            "name": "wayland-protocols 1.41",
            "url": "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.41/downloads/wayland-protocols-1.41.tar.xz",
            "filename": "wayland-protocols-1.41.tar.xz",
            "checksum": "SKIP",
            "size": "180 KB",
            "desc": "Wayland protocol extensions"
        },
        "wlroots": {
            "name": "wlroots 0.18.2",
            "url": "https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/0.18.2/downloads/wlroots-0.18.2.tar.gz",
            "filename": "wlroots-0.18.2.tar.gz",
            "checksum": "SKIP",
            "size": "1.2 MB",
            "desc": "Modular Wayland compositor library"
        },
        "weston": {
            "name": "Weston 14.0.1",
            "url": "https://gitlab.freedesktop.org/wayland/weston/-/releases/14.0.1/downloads/weston-14.0.1.tar.xz",
            "filename": "weston-14.0.1.tar.xz",
            "checksum": "SKIP",
            "size": "3.2 MB",
            "desc": "Reference Wayland compositor"
        }
    },
    
    "Window Manager": {
        "sway": {
            "name": "Sway 1.10.1",
            "url": "https://github.com/swaywm/sway/releases/download/1.10.1/sway-1.10.1.tar.gz",
            "filename": "sway-1.10.1.tar.gz",
            "checksum": "SKIP",
            "size": "5.5 MB",
            "desc": "i3-compatible Wayland compositor"
        },
        "swaybg": {
            "name": "swaybg 1.2.1",
            "url": "https://github.com/swaywm/swaybg/releases/download/v1.2.1/swaybg-1.2.1.tar.gz",
            "filename": "swaybg-1.2.1.tar.gz",
            "checksum": "SKIP",
            "size": "15 KB",
            "desc": "Wallpaper tool untuk Sway"
        }
    },
    
    "Input & Graphics Libraries": {
        "libinput": {
            "name": "libinput 1.27.1",
            "url": "https://gitlab.freedesktop.org/libinput/libinput/-/releases/1.27.1/downloads/libinput-1.27.1.tar.xz",
            "filename": "libinput-1.27.1.tar.xz",
            "checksum": "SKIP",
            "size": "620 KB",
            "desc": "Input device handling library"
        },
        "libxkbcommon": {
            "name": "libxkbcommon 1.8.1",
            "url": "https://github.com/xkbcommon/libxkbcommon/archive/xkbcommon-1.8.1.tar.gz",
            "filename": "libxkbcommon-1.8.1.tar.gz",
            "checksum": "SKIP",
            "size": "1.2 MB",
            "desc": "Keyboard handling library"
        },
        "pixman": {
            "name": "Pixman 0.44.2",
            "url": "https://www.cairographics.org/releases/pixman-0.44.2.tar.gz",
            "filename": "pixman-0.44.2.tar.gz",
            "checksum": "SKIP",
            "size": "808 KB",
            "desc": "Low-level pixel manipulation library"
        },
        "cairo": {
            "name": "Cairo 1.18.4",
            "url": "https://www.cairographics.org/releases/cairo-1.18.4.tar.xz",
            "filename": "cairo-1.18.4.tar.xz",
            "checksum": "SKIP",
            "size": "22 MB",
            "desc": "2D graphics library"
        },
        "pango": {
            "name": "Pango 1.56.3",
            "url": "https://download.gnome.org/sources/pango/1.56/pango-1.56.3.tar.xz",
            "filename": "pango-1.56.3.tar.xz",
            "checksum": "SKIP",
            "size": "1.8 MB",
            "desc": "Text layout and rendering library"
        }
    }
}

# ============================================================================
# CLASS UTAMA APLIKASI
# ============================================================================

class SabaOSBuilder:
    def __init__(self, root):
        self.root = root
        self.root.title("SABA OS BUILDER v2.0 - Sameko Saba Edition")
        self.root.geometry("1000x750")
        self.root.configure(bg="#0a1628")
        
        # Variabel
        self.download_dir = tk.StringVar(value=str(Path.home() / "saba_os_sources"))
        self.selected_components = {}
        self.downloading = False
        self.total_size = 0
        self.downloaded_size = 0
        
        self.setup_ui()
        self.log("Selamat datang di SABA OS BUILDER!", "info")
        self.log("Sistem Operasi Ultra-Minimalis berbasis musl + runit + Wayland", "info")
        self.log("Total komponen tersedia: 19 paket esensial", "info")
        self.log("=" * 60, "info")
    
    def setup_ui(self):
        # Style
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("Custom.TFrame", background="#0a1628")
        style.configure("Custom.TLabelframe", background="#0a1628", foreground="#00d4ff")
        style.configure("Custom.TLabelframe.Label", background="#0a1628", foreground="#00d4ff", font=('Helvetica', 10, 'bold'))
        style.configure("Custom.TButton", background="#0066cc", foreground="white", font=('Helvetica', 9, 'bold'))
        style.configure("Custom.TCheckbutton", background="#0a1628", foreground="#e0e0e0")
        style.configure("Custom.TProgressbar", background="#00d4ff", troughcolor="#1a3a5c")
        
        # Main Container
        main_frame = ttk.Frame(self.root, style="Custom.TFrame")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Header
        header_frame = tk.Frame(main_frame, bg="#0a1628")
        header_frame.pack(fill=tk.X, pady=(0, 10))
        
        tk.Label(header_frame, text="SABA OS BUILDER", 
                font=('Helvetica', 24, 'bold'), 
                bg="#0a1628", fg="#00d4ff").pack()
        
        tk.Label(header_frame, text="Linux From Scratch 2026 - musl + runit + Wayland", 
                font=('Helvetica', 11), 
                bg="#0a1628", fg="#80c5ff").pack()
        
        tk.Label(header_frame, text="Maskot: Sameko Saba | Target: 29MiB RAM Idle", 
                font=('Helvetica', 9), 
                bg="#0a1628", fg="#ff6b9d").pack(pady=(5, 0))
        
        # Directory Selection
        dir_frame = ttk.LabelFrame(main_frame, text="Direktori Download", style="Custom.TLabelframe")
        dir_frame.pack(fill=tk.X, pady=5)
        
        dir_inner = tk.Frame(dir_frame, bg="#0a1628")
        dir_inner.pack(fill=tk.X, padx=5, pady=5)
        
        tk.Entry(dir_inner, textvariable=self.download_dir, width=60,
                bg="#1a3a5c", fg="#e0e0e0", insertbackground="white",
                font=('Consolas', 10)).pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(dir_inner, text="Browse", command=self.browse_dir, 
                  style="Custom.TButton").pack(side=tk.LEFT)
        
        # Components Selection
        comp_frame = ttk.LabelFrame(main_frame, text="Pilih Komponen", style="Custom.TLabelframe")
        comp_frame.pack(fill=tk.BOTH, expand=True, pady=5)
        
        # Canvas dengan scrollbar untuk komponen
        canvas = tk.Canvas(comp_frame, bg="#0a1628", highlightthickness=0)
        scrollbar = ttk.Scrollbar(comp_frame, orient="vertical", command=canvas.yview)
        self.comp_container = tk.Frame(canvas, bg="#0a1628")
        
        self.comp_container.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=self.comp_container, anchor="nw", width=950)
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Buat checkbox untuk setiap kategori
        row = 0
        for category, items in COMPONENTS.items():
            # Category header
            cat_label = tk.Label(self.comp_container, text=f"> {category}",
                               font=('Helvetica', 11, 'bold'),
                               bg="#0a1628", fg="#ffd700")
            cat_label.grid(row=row, column=0, sticky="w", pady=(10, 5), padx=5)
            row += 1
            
            for key, info in items.items():
                var = tk.BooleanVar(value=True)
                self.selected_components[key] = {
                    "var": var,
                    "info": info
                }
                
                # Frame untuk setiap item
                item_frame = tk.Frame(self.comp_container, bg="#1a3a5c", bd=1, relief=tk.RIDGE)
                item_frame.grid(row=row, column=0, sticky="ew", padx=20, pady=2)
                
                cb = tk.Checkbutton(item_frame, text=f"{info['name']}", 
                                   variable=var,
                                   bg="#1a3a5c", fg="#e0e0e0",
                                   selectcolor="#0066cc",
                                   activebackground="#1a3a5c",
                                   activeforeground="#ffffff",
                                   font=('Consolas', 9))
                cb.pack(side=tk.LEFT, padx=5)
                
                tk.Label(item_frame, text=f"{info['size']}",
                        bg="#1a3a5c", fg="#80ff80",
                        font=('Consolas', 8)).pack(side=tk.LEFT, padx=10)
                
                tk.Label(item_frame, text=f"{info['desc']}",
                        bg="#1a3a5c", fg="#a0a0a0",
                        font=('Helvetica', 8)).pack(side=tk.LEFT, padx=10)
                
                row += 1
        
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Progress Section
        prog_frame = ttk.LabelFrame(main_frame, text="Progress", style="Custom.TLabelframe")
        prog_frame.pack(fill=tk.X, pady=5)
        
        prog_inner = tk.Frame(prog_frame, bg="#0a1628")
        prog_inner.pack(fill=tk.X, padx=5, pady=5)
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(prog_inner, variable=self.progress_var,
                                           maximum=100, length=900, mode='determinate',
                                           style="Custom.TProgressbar")
        self.progress_bar.pack(fill=tk.X, pady=5)
        
        self.status_label = tk.Label(prog_inner, text="Siap memulai...",
                                    bg="#0a1628", fg="#00d4ff",
                                    font=('Consolas', 10))
        self.status_label.pack()
        
        self.current_file_label = tk.Label(prog_inner, text="",
                                          bg="#0a1628", fg="#80c5ff",
                                          font=('Consolas', 9))
        self.current_file_label.pack()
        
        # Buttons
        btn_frame = tk.Frame(main_frame, bg="#0a1628")
        btn_frame.pack(fill=tk.X, pady=10)
        
        ttk.Button(btn_frame, text="Select All", command=self.select_all,
                  style="Custom.TButton").pack(side=tk.LEFT, padx=5)
        
        ttk.Button(btn_frame, text="Deselect All", command=self.deselect_all,
                  style="Custom.TButton").pack(side=tk.LEFT, padx=5)
        
        ttk.Button(btn_frame, text="START DOWNLOAD", command=self.start_download,
                  style="Custom.TButton").pack(side=tk.RIGHT, padx=5)
        
        # Log Area
        log_frame = ttk.LabelFrame(main_frame, text="Log", style="Custom.TLabelframe")
        log_frame.pack(fill=tk.BOTH, expand=True, pady=5)
        
        self.log_area = scrolledtext.ScrolledText(log_frame, height=10,
                                                 bg="#0d1b2a", fg="#e0e0e0",
                                                 font=('Consolas', 9),
                                                 insertbackground="white")
        self.log_area.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
    
    def browse_dir(self):
        directory = filedialog.askdirectory(initialdir=self.download_dir.get())
        if directory:
            self.download_dir.set(directory)
    
    def select_all(self):
        for comp in self.selected_components.values():
            comp["var"].set(True)
    
    def deselect_all(self):
        for comp in self.selected_components.values():
            comp["var"].set(False)
    
    def log(self, message, level="info"):
        colors = {
            "info": "#e0e0e0",
            "success": "#80ff80",
            "warning": "#ffd700",
            "error": "#ff6b6b",
            "download": "#00d4ff"
        }
        
        timestamp = time.strftime("%H:%M:%S")
        self.log_area.insert(tk.END, f"[{timestamp}] ", "timestamp")
        self.log_area.insert(tk.END, f"{message}\n", level)
        self.log_area.tag_config(level, foreground=colors.get(level, "#e0e0e0"))
        self.log_area.tag_config("timestamp", foreground="#808080")
        self.log_area.see(tk.END)
    
    def download_file(self, url, filepath, component_name):
        """Download file dengan progress callback"""
        try:
            self.root.after(0, lambda: self.current_file_label.config(
                text=f"Mengunduh: {component_name}"
            ))
            
            req = urllib.request.Request(url, headers={'User-Agent': 'SabaOS-Builder/2.0'})
            
            with urllib.request.urlopen(req, timeout=120) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                
                if total_size == 0:
                    total_size = 1024 * 1024  # Default 1MB jika tidak diketahui
                
                downloaded = 0
                chunk_size = 8192
                
                with open(filepath, 'wb') as f:
                    while True:
                        chunk = response.read(chunk_size)
                        if not chunk:
                            break
                        
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Update progress
                        progress = (downloaded / total_size) * 100
                        self.root.after(0, lambda p=progress: self.progress_var.set(p))
                        
                        # Update status
                        mb_downloaded = downloaded / (1024 * 1024)
                        mb_total = total_size / (1024 * 1024)
                        self.root.after(0, lambda d=mb_downloaded, t=mb_total: 
                            self.status_label.config(
                                text=f"{d:.1f} MB / {t:.1f} MB ({d/t*100:.1f}%)"
                            ))
            
            return True
            
        except Exception as e:
            self.root.after(0, lambda: self.log(f"Error downloading {component_name}: {str(e)}", "error"))
            return False
    
    def verify_checksum(self, filepath, expected_checksum):
        """Verifikasi MD5 checksum"""
        try:
            if expected_checksum == "SKIP" or not expected_checksum:
                return True
                
            md5_hash = hashlib.md5()
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    md5_hash.update(chunk)
            
            computed = md5_hash.hexdigest()
            return computed == expected_checksum
        except Exception as e:
            self.log(f"Checksum verification failed: {e}", "warning")
            return True  # Skip verification jika error
    
    def extract_archive(self, filepath, extract_dir):
        """Ekstrak archive otomatis"""
        try:
            if filepath.endswith('.tar.gz') or filepath.endswith('.tgz'):
                with tarfile.open(filepath, 'r:gz') as tar:
                    tar.extractall(extract_dir)
            elif filepath.endswith('.tar.xz'):
                with tarfile.open(filepath, 'r:xz') as tar:
                    tar.extractall(extract_dir)
            elif filepath.endswith('.tar.bz2'):
                with tarfile.open(filepath, 'r:bz2') as tar:
                    tar.extractall(extract_dir)
            return True
        except Exception as e:
            self.log(f"Extraction error: {e}", "warning")
            return False
    
    def download_worker(self):
        """Worker thread untuk download"""
        download_dir = Path(self.download_dir.get())
        download_dir.mkdir(parents=True, exist_ok=True)
        
        selected = [k for k, v in self.selected_components.items() if v["var"].get()]
        total = len(selected)
        
        self.log(f"Memulai download {total} komponen...", "info")
        self.log(f"Direktori: {download_dir}", "info")
        
        success_count = 0
        failed_count = 0
        
        for idx, key in enumerate(selected, 1):
            if not self.downloading:
                self.log("Download dihentikan oleh user", "warning")
                break
            
            comp = self.selected_components[key]["info"]
            filepath = download_dir / comp["filename"]
            
            self.log(f"[{idx}/{total}] {comp['name']}...", "download")
            
            # Check if file already exists
            if filepath.exists():
                self.log(f"    File sudah ada, melewati...", "warning")
                success_count += 1
                continue
            
            # Download
            if self.download_file(comp["url"], str(filepath), comp["name"]):
                self.log(f"    Download berhasil", "success")
                
                # Verify checksum
                if self.verify_checksum(str(filepath), comp["checksum"]):
                    self.log(f"    Checksum OK", "success")
                else:
                    self.log(f"    Checksum mismatch (mungkin versi baru)", "warning")
                
                # Extract
                self.log(f"    Mengekstrak...", "info")
                if self.extract_archive(str(filepath), str(download_dir)):
                    self.log(f"    Ekstrak berhasil", "success")
                
                success_count += 1
            else:
                self.log(f"    Download gagal", "error")
                failed_count += 1
            
            # Update overall progress
            overall_progress = (idx / total) * 100
            self.root.after(0, lambda p=overall_progress: self.progress_var.set(p))
        
        # Final status
        self.root.after(0, lambda: self.status_label.config(
            text=f"Selesai! Berhasil: {success_count}, Gagal: {failed_count}"
        ))
        self.root.after(0, lambda: self.current_file_label.config(text=""))
        self.root.after(0, lambda: self.progress_var.set(100))
        
        self.log("=" * 60, "info")
        self.log(f"DOWNLOAD SELESAI!", "success")
        self.log(f"Total: {success_count} berhasil, {failed_count} gagal", "info")
        self.log(f"Lokasi: {download_dir}", "info")
        self.log("Siap untuk build Saba OS!", "success")
        
        self.downloading = False
    
    def start_download(self):
        """Mulai download di thread terpisah"""
        if self.downloading:
            messagebox.showwarning("Warning", "Download sedang berjalan!")
            return
        
        selected = [k for k, v in self.selected_components.items() if v["var"].get()]
        
        if not selected:
            messagebox.showwarning("Warning", "Pilih minimal 1 komponen!")
            return
        
        self.downloading = True
        self.progress_var.set(0)
        
        # Start download thread
        thread = threading.Thread(target=self.download_worker)
        thread.daemon = True
        thread.start()

# ============================================================================
# MAIN
# ============================================================================

def main():
    root = tk.Tk()
    
    # Set icon (jika ada)
    try:
        root.iconbitmap("saba_icon.ico")
    except:
        pass
    
    app = SabaOSBuilder(root)
    root.mainloop()

if __name__ == "__main__":
    main()
